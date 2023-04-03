##################
# Common PHP
##################
ARG NGINX_UNIT_VERSION=1.29.1
ARG PHP_VERSION=8.1

FROM nginx/unit:${NGINX_UNIT_VERSION}-php${PHP_VERSION} as common

ARG APCU_VERSION=5.1.22
ARG AMQP_VERSION=1.11.0
ARG MEMCACHED_VERSION=3.2.0
ARG RDKAFKA_VERSION=6.0.3

WORKDIR /var/www

COPY --from=composer:2.5.5 /usr/bin/composer /usr/bin/composer
COPY ./entrypoint.sh /entrypoint.sh
COPY ./php/php.common.ini /usr/local/etc/php/conf.d/20-php.common.ini
COPY ./config.json /docker-entrypoint.d/config.json

RUN \
    apt-get update && \
    apt-get install -y \
      # For extension installation. Remove after use
      ${PHPIZE_DEPS} \
      # common \
      libzip-dev \
      zip \
      # RabbitMQ
      librabbitmq-dev libssh-dev \
      # Kafka
      librdkafka-dev  \
      # memcached \
      libmemcached-dev \
      # ext-intl
      libicu-dev \
      # ext-gmp
      libgmp-dev \
    && \
    pecl channel-update pecl.php.net && \
    printf "\n" | pecl install amqp-${AMQP_VERSION} && \
    printf "\n" | pecl install apcu-${APCU_VERSION} && \
    printf "\n" | pecl install rdkafka-${RDKAFKA_VERSION} && \
    printf "\n" | pecl install memcached-${MEMCACHED_VERSION} && \
    docker-php-ext-install pdo_mysql zip pcntl intl gmp && \
    docker-php-ext-enable amqp apcu rdkafka opcache memcached && \
    pecl clear-cache && \
    apt-get purge -y ${PHPIZE_DEPS} && \
    apt-get autoremove -y

RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["unitd", "--no-daemon", "--control", "unix:/var/run/control.unit.sock", "--log", "/dev/stdout"]

##################
# Development PHP
##################
FROM common as dev

ARG XDEBUG_VERSION=3.2.1

ENV PHP_IDE_CONFIG="serverName=api"

RUN \
    apt-get update && \
    apt-get install -y ${PHPIZE_DEPS} default-mysql-client && \
    pecl channel-update pecl.php.net && \
    pecl install xdebug-${XDEBUG_VERSION} && \
    docker-php-ext-enable xdebug && \
    pecl clear-cache && \
    apt-get autoremove -y

RUN ln -s $PHP_INI_DIR/php.ini-development $PHP_INI_DIR/php.ini
COPY ./php/php.dev.base.ini /usr/local/etc/php/conf.d/30-php.dev.base.ini

##################
# Production PHP
##################
FROM common as prod

RUN ln -s $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY ./php/php.prod.base.ini /usr/local/etc/php/conf.d/30-php.prod.base.ini

##################
# Production Debug PHP
##################
FROM prod as prod-debug

CMD ["unitd-debug", "--no-daemon", "--control", "unix:/var/run/control.unit.sock", "--log", "/dev/stdout"]
