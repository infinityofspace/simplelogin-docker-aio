# Install npm packages
FROM node:10.17.0-alpine AS npm

ARG VERSION=master

RUN apk add git \
    && git clone --depth 1 -b "$(echo $VERSION | cut -d'-' -f1)" https://github.com/simple-login/app.git /src

RUN mkdir -p /code/static \
    && cp /src/static/package*.json /code/static/ \
    && cd /code/static && npm ci

FROM python:3.12-alpine AS uv-builder

COPY --from=ghcr.io/astral-sh/uv:0.7.3 /uv /bin/uv

WORKDIR /app

RUN apk add --no-cache gcc g++ re2-dev git python3-dev musl-dev libffi-dev cmake ninja-build \
    build-base cython py3-pybind11-dev re2-dev

COPY --from=npm /src/uv.lock /src/pyproject.toml ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

COPY --from=npm /code /code
COPY --from=npm /src ./

## Final image ##
FROM python:3.12-alpine

RUN apk add --no-cache netcat-openbsd re2 re2-dev libffi gnupg supervisor postfix postfix-pgsql \
    && mkdir -p /var/log/supervisord /var/run/supervisord \
    && mkdir -p /var/spool/postfix/etc/

COPY --from=uv-builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

COPY --from=npm /src .

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
