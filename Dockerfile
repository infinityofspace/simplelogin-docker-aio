# Install npm packages
FROM node:10.17.0-alpine AS npm

ENV SIMPLELOGIN_VERSION=v4.36.4
ENV IMAGE_VERSION=$SIMPLELOGIN_VERSION-1

RUN apk add git \
    && git clone --depth 1 -b $SIMPLELOGIN_VERSION https://github.com/simple-login/app.git /src

RUN mkdir -p /code/static \
    && cp /src/static/package*.json /code/static/ \
    && cd /code/static && npm ci

# Main image
FROM python:3.10

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE 1
# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED 1

# Add poetry to PATH
ENV PATH="${PATH}:/root/.local/bin"

WORKDIR /code

# Copy poetry files
COPY --from=npm /src/poetry.lock /src/pyproject.toml ./

ENV DEBIAN_FRONTEND=noninteractive

# Install all requirements and setup poetry
RUN pip install -U pip \
    && apt-get update \
    && apt install -yq curl netcat-traditional gcc python3-dev gnupg git libre2-dev cmake ninja-build supervisor postfix postfix-pgsql \
    && curl -sSL https://install.python-poetry.org | python3 - \
    # Remove curl from the image
    && apt-get purge -y curl \
    # Run poetry
    && poetry config virtualenvs.create false \
    && poetry install  --no-interaction --no-ansi --no-root \
    # Clear apt cache \
    && apt-get purge -y libre2-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/log/supervisord /var/run/supervisord

# copy npm packages
COPY --from=npm /code /code

# copy everything else into /code
COPY --from=npm /src .

# copy postfix configs
COPY configs/postfix/main.cf /etc/postfix/main.cf
COPY configs/postfix/pgsql-relay-domains.cf /etc/postfix/pgsql-relay-domains.cf
COPY configs/postfix/pgsql-transport-maps.cf /etc/postfix/pgsql-transport-maps.cf

COPY configs/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY entrypoint.sh .

EXPOSE 7777 25

ENV WEBAPP_WORKERS=2

CMD ["./entrypoint.sh"]

LABEL org.opencontainers.image.source="https://github.com/infinityofspace/simplelogin-docker-aio"
LABEL org.opencontainers.image.licenses="AGPLv3"
LABEL org.opencontainers.image.version=$IMAGE_VERSION
