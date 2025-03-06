# Install npm packages
FROM node:10.17.0-alpine AS npm

ARG VERSION=master

RUN apk add git \
    && git clone --depth 1 -b "$(echo $VERSION | cut -d'-' -f1)" https://github.com/simple-login/app.git /src

RUN mkdir -p /code/static \
    && cp /src/static/package*.json /code/static/ \
    && cd /code/static && npm ci

FROM ghcr.io/astral-sh/uv:0.6-debian-slim AS uv-builder

ENV UV_LINK_MODE=copy
ENV UV_COMPILE_BYTECODE=1
ENV UV_PYTHON_PREFERENCE=only-managed
ENV UV_PYTHON_INSTALL_DIR=/python

RUN apt-get update \
    && apt-get install -y gcc python3-dev gnupg git libre2-dev build-essential pkg-config cmake ninja-build clang

WORKDIR /app

COPY --from=npm /src/.python-version .
RUN uv python install $(cat .python-version)

COPY --from=npm /src/uv.lock /src/pyproject.toml ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

COPY --from=npm /code /code
COPY --from=npm /src ./

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

## Final image ##
FROM debian:12-slim

RUN apt-get update \
    && apt-get install -y netcat-openbsd libre2-dev libffi-dev gnupg supervisor postfix postfix-pgsql \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=uv-builder --chown=python:python /python /python
COPY --from=uv-builder --chown=app:app /app /app
ENV PATH="/app/.venv/bin:$PATH"

# copy postfix configs
COPY configs/postfix/main.cf /etc/postfix/main.cf
COPY configs/postfix/pgsql-relay-domains.cf /etc/postfix/pgsql-relay-domains.cf
COPY configs/postfix/pgsql-transport-maps.cf /etc/postfix/pgsql-transport-maps.cf

COPY configs/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY entrypoint.sh .

EXPOSE 7777 25

ENV WEBAPP_WORKERS=2

CMD ["sh", "entrypoint.sh"]

LABEL org.opencontainers.image.source="https://github.com/infinityofspace/simplelogin-docker-aio"
LABEL org.opencontainers.image.licenses="AGPLv3"
LABEL org.opencontainers.image.version=$VERSION
