# Install npm packages
FROM node:10.17.0-alpine AS npm

ARG VERSION=master

RUN apk add git \
    && git clone --depth 1 -b "$(echo $VERSION | cut -d'-' -f1)" https://github.com/simple-login/app.git /src

RUN mkdir -p /code/static \
    && cp /src/static/package*.json /code/static/ \
    && cd /code/static && npm ci

FROM ghcr.io/astral-sh/uv:0.6-debian-slim AS uv-builder

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE=1
# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED=1

WORKDIR /code

COPY --from=npm /src/.python-version .
RUN uv python install $(cat .python-version)
RUN uv venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY --from=npm /src/pyproject.toml /src/uv.lock ./

# Install all requirements and setup poetry
RUN apt-get update \
    && apt-get install -y gcc python3-dev gnupg git libre2-dev build-essential pkg-config cmake ninja-build bash clang \
    && uv sync

# copy npm packages
COPY --from=npm /code /code

# copy everything else into /code
COPY --from=npm /src .

RUN uv build

## Final image ##
FROM python:3.12-alpine

RUN apk add --no-cache netcat-openbsd re2 re2-dev libffi gnupg supervisor postfix postfix-pgsql \
    && mkdir -p /var/log/supervisord /var/run/supervisord \
    && mkdir -p /var/spool/postfix/etc/

COPY --from=uv-builder /opt/venv /opt/venv
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
