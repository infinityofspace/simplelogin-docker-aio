# Install npm packages
FROM node:10.17.0-alpine AS npm

ARG VERSION=master

RUN apk add git \
    && git clone --depth 1 -b "$(echo $VERSION | cut -d'-' -f1)" https://github.com/simple-login/app.git /src

RUN mkdir -p /code/static \
    && cp /src/static/package*.json /code/static/ \
    && cd /code/static && npm ci


FROM python:3.10-alpine as poetry-builder

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE 1
# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED 1

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /code

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy poetry files
COPY --from=npm /src/poetry.lock /src/pyproject.toml ./

# Install all requirements and setup poetry
RUN apk add --no-cache poetry gcc g++ re2-dev git python3-dev musl-dev libffi-dev cmake ninja-build \
    && if [[ $(uname -m) == arm* || $(uname -m) == aarch64 ]]; then \
         apk add --no-cache postgresql-dev ninja build-base; \
         pip install psycopg2; \
       fi \
    && poetry export -f requirements.txt | pip install -r /dev/stdin

# copy npm packages
COPY --from=npm /code /code

# copy everything else into /code
COPY --from=npm /src .

RUN poetry build && pip install dist/*.whl


FROM python:3.10-alpine

RUN apk add --no-cache netcat-openbsd re2 re2-dev libffi gnupg supervisor postfix postfix-pgsql \
    && mkdir -p /var/log/supervisord /var/run/supervisord \
    && mkdir -p /var/spool/postfix/etc/

COPY --from=poetry-builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# copy postfix configs
COPY configs/postfix/main.cf /etc/postfix/main.cf
COPY configs/postfix/pgsql-relay-domains.cf /etc/postfix/pgsql-relay-domains.cf
COPY configs/postfix/pgsql-transport-maps.cf /etc/postfix/pgsql-transport-maps.cf

COPY configs/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR /code

COPY --from=npm /src .
COPY entrypoint.sh .

# apply patches
#COPY patches /code

EXPOSE 7777 25

ENV WEBAPP_WORKERS=2

CMD ["sh", "entrypoint.sh"]

LABEL org.opencontainers.image.source="https://github.com/infinityofspace/simplelogin-docker-aio"
LABEL org.opencontainers.image.licenses="AGPLv3"
LABEL org.opencontainers.image.version=$VERSION
