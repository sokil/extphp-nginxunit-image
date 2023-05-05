# Extended PHP With Nginx Unit Docker Image

Base Docker image for php with extension and Nginx Unit on board. Clone and customize for your needs.

## Build

### GitLab

```
stages:
  - docker-build-image

.docker-build-image:
  stage: docker-build-image
  image: docker
  variables:
    # DOCKER_BUILD_TARGET: <Defined in child job>
    DOCKER_IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME-$DOCKER_BUILD_TARGET
    DOCKER_BUILDKIT: 1
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - |
      docker build --pull \
        -t ${DOCKER_IMAGE_TAG} \
        -f ./Dockerfile \
        --target=${DOCKER_BUILD_TARGET} .
    - docker push $DOCKER_IMAGE_TAG
  tags:
    - shared

docker-build-dev-image:
  extends: .docker-build-image
  variables:
    DOCKER_BUILD_TARGET: "dev"

docker-build-prod-image:
  extends: .docker-build-image
  variables:
    DOCKER_BUILD_TARGET: "prod"

docker-build-prod-debug-image:
  extends: .docker-build-image
  variables:
    DOCKER_BUILD_TARGET: "prod-debug"
```

## Usage

### Extending from base image

Supported images:

| Mode       | Description                                                                                                                                      |
|------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| dev        | Development build. Used for development and testing. Contains XDebug. MUST be used for development and testing in pipelines only.                |
| prod       | Production build. Used for production only. No debug tools. MUST be used when deployed to any infrastructure to provide immutable infrastructure |
| prod-debug | Production build with enabled debug on Nginx Unit                                                                                                |

Image `dev` MUST be used ONLY in development environment in a local machine of developer.
Image `prod` MUST be used on all environments: review app, staging, production.
Image `prod-debug` MAY be used on all environments, when need to debug Nginx Unit.

### Configuration

#### PHP Configuration

Predefined PHP configs:

| Filename          | Description                                                             |
|-------------------|-------------------------------------------------------------------------|
| php.common.ini    | Priority - 20. Defined common settings for all build modes              |
| php.dev.base.ini  | Priority - 30. Defined base settings for `dev` build mode               |
| php.prod.base.ini | Priority - 30. Defined base settings for `prod`/`prod-debug` build mode |

To override some base configuration in child Docker image just add your own PHP config.

For `dev` build mode:
```
COPY php.dev.custom.ini /usr/local/etc/php/conf.d/40-php.dev.custom.ini
```

For `prod` build mode:
```
COPY php.prod.custom.ini /usr/local/etc/php/conf.d/40-php.prod.custom.ini
```

#### Entrypoint tasks

Use this feature carefully.

When image built in `prod` mode, id MUST do nothing during entrypoint phase except running process: no migrations
and deployments. This is done for preventing fail on image deployment to production.
Sometimes we may need this tasks in `prod` build but in test stage, for example `prod` image must be used in `testing`
stage and migrations here may be run automatically. You may define this tasks in `entrypoint.dev.sh` file.

#### Add app version in environment variables

Add this to your child image:

```
ARG APP_VERSION=nightly
ENV APP_VERSION=${APP_VERSION}
```

Then you will be able to configure app version in CI/CD pipeline, for example for Gitlab in `gitlab-ci.yml`:

```
variables:
    APP_VERSION: $CI_COMMIT_REF_NAME-$CI_COMMIT_SHORT_SHA

build-docker:
  stage: build-docker
  image: docker
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - |
      docker build --pull \
        -t ${DOCKER_IMAGE_TAG} \
        -f /Dockerfile \
        --build-arg APP_VERSION=${APP_VERSION} \
        .
    - docker push $DOCKER_IMAGE_TAG
```

## Arguments

Docker image may be parametrised by next arguments:

| ARG                | Default | Description                                                       |
|--------------------|---------|-------------------------------------------------------------------|
| NGINX_UNIT_VERSION | 1.29.1  | Version of Nginx Unit                                             |
| PHP_VERSION        | 8.1     | Version of PHP                                                    |
| APCU_VERSION       | 5.1.22  | Version of APCU Extension                                         |
| AMQP_VERSION       | 1.11.0  | Version of AMQP Extension                                         |
| MEMCACHED_VERSION  | 3.2.0   | Version of Memcached Extension                                    |
| RDKAFKA_VERSION    | 6.0.3   | Version of Rdkafka Extension                                      |
| XDEBUG_VERSION     | 3.2.1   | Version of XDebug. Dev build only                                 |

## Environment variables

Next environment variables available inside container:

| ARG            | Description                   |
|----------------|-------------------------------|
| PHP_IDE_CONFIG | Used with XDebug on dev build |

## Development mode

Image build in two modes: development and production

Development image contains pre-configured XDebug. To configure it in your project, add this to
your `docker-compose.yml` file:

```yaml
version: '3.4'

services:
  php:
    image: "extphp-nginxunit-image:0.1.0-dev"
    environment:
      - XDEBUG_MODE=develop,debug,coverage,profile
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Profiling results may be found at `/var/log/php-profiler`
