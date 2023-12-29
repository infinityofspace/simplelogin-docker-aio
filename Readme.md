# SimpleLogin Docker AIO

Docker image for SimpleLogin [A]ll [I]n [O]ne

## Table of Contents

1. [About](#about)
2. [Requirements](#requirements)
3. [Usage](#usage)
4. [Configuration](#configuration)
5. [Changes](#changes)
6. [Versioning](#versioning)
7. [License](#license)

## About

This docker image contains all the services needed to run SimpleLogin. It bundles the following parts:

- postfix
- web app
- email handler
- job runner

Note: you still need a postgresql database to run SimpleLogin. You can use the official postgresql docker image which is
used in the docker-compose example file. For more information, see the [Usage](#usage) section.

## Requirements

The following general requirements are needed for running SimpleLogin:

- domain name
- access to dns entries for this domain
- tsl cert for the domain
- public ip address
- open port 25

In addition, the following minimum system requirements are required:
- 1 core
- min. 512MB free RAM
- docker

## Usage

Download the sample [docker-compose file](docker-compose.yml) and get the two environment files [db.env](db.env)
and [simplelogin.env](simplelogin.env).
You need a TSL certificate and key file for the web app. Now adjust the environment files to your needs and start
everything with:

_Note: before you start the docker compose stack, please make sure you configured all required E-Mail parts. For more
information, see the [Configuration](#configuration) section._

```commandline
docker-compose up -d
```

## Configuration

The file [simplelogin.env](simplelogin.env) contains the two environment variables `TLS_CERT_FILE` and `TLS_CERT_KEY`,
which must be defined in advance so that postfix can use TSL encryption.

By default, the image uses in the postifx configuration the two
blocklists [zen.spamhaus.org](https://www.spamhaus.org/zen/)
and [bl.spamcop.net](https://www.spamcop.net/bl.shtml). You can adjust the postfix configuration by mounting your own
`main.cf` file to `/etc/postfix/main.cf`, e.g.:

```yaml
services:
  simplelogin:
    ...
    volumes:
      - ./main.cf:/etc/postfix/main.cf
    ...
```

Before you start you have to setup a DKIM, MX, SPF and DMARC record for your domain. Please follow the instructions in
the official simplelogin [documentation](https://github.com/simple-login/app#dkim).

## Changes

The following changes were made to the original SimpleLogin image:

- the default nameserver in the [simplelogin.env](simplelogin.env) file was changed from `1.1.1.1` to `9.9.9.9`
- images are build for amd64 and arm64 instead of only amd64
- base image uses alpine
- reduced image size by 75% (440MB vs 1.73GB from `app-ci:v4.36.4` image)

## Versioning

The image version is the same as the SimpleLogin version. The image version is suffixed with a release number, e.g.
`1.0.0-1` means that the image is based on SimpleLogin `1.0.0` and it is the first release of the image.

The following tags are available:

- `v*`: tagged version
- `latest`: equal to latest tagged version
- `nightly`: build every 3 day from the master branch of the SimpleLogin git repo
- `dev`: build for each change on the dev branch

_Note: the `nightly` and `dev` tags are not intended for productive use_

## License

This project is licensed under the AGPLv3 license - see the [License](License) file for details.

Furthermore, this project uses the [SimpleLogin project](https://github.com/simple-login/app), you can find the original
AGPLv3 license [here](https://github.com/simple-login/app/blob/master/LICENSE).

This project is not associated with the SimpleLogin project nor SimpleLogin SAS.

If you like SimpleLogin, please consider supporting the original
project [here](https://github.com/simple-login/app#donations-welcome).
