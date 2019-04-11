# alpine:latest at 2019-01-04T21:27:39IST
FROM alpine@sha256:46e71df1e5191ab8b8034c5189e325258ec44ea739bba1e5645cff83c9048ff1

LABEL "com.github.actions.icon"="star"
LABEL "com.github.actions.color"="ffd33d"
LABEL "com.github.actions.name"="Deploy WordPress"
LABEL "com.github.actions.description"="This task will deploy an application"

# Environments
ENV TIMEZONE                 Asia/Kolkata
ENV PHP_MEMORY_LIMIT         512M
ENV MAX_UPLOAD               50M
ENV PHP_MAX_FILE_UPLOAD      200
ENV PHP_MAX_POST             100M
ENV PHP_INI_DIR              /etc/php7/php.ini
ENV HOME                     /root
ENV PATH                     "/composer/vendor/bin:~/.local/bin:$PATH"
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME            /composer
ENV VAULT_VERSION            1.0.2

# PHP-CLI installation inspired from https://github.com/bravist/php-cli-alpine-aliyun-app/blob/master/Dockerfile
# https://github.com/matriphe/docker-alpine-php/blob/master/7.0/FPM/Dockerfile

RUN apk update \
    && apk upgrade \
    && apk add \
        bash \
        jq \
        curl \
        git \
        tzdata \
        rsync \
        yarn \
        mysql-client \
        subversion \
        unzip \
        wget \
        zip \
        openssh-client \
        php7 \
        php7-dev \
        php7-apcu \
        php7-bcmath \
        php7-bz2 \
        php7-xmlwriter \
        php7-ctype \
        php7-curl \
        php7-exif \
        php7-iconv \
        php7-intl \
        php7-json \
        php7-mbstring\
        php7-opcache \
        php7-openssl \
        php7-pcntl \
        php7-pdo \
        php7-mysqlnd \
        php7-mysqli \
        php7-pdo_mysql \
        php7-pdo_pgsql \
        php7-phar \
        php7-posix \
        php7-session \
        php7-xml \
        php7-simplexml \
        php7-mcrypt \
        php7-xsl \
        php7-zip \
        php7-zlib \
        php7-dom \
        php7-redis\
        php7-tokenizer \
        php7-gd \
        php7-fileinfo \
        php7-zmq \
        php7-memcached \
        php7-xmlreader \
        python \
        py2-pip \
    && pip install shyaml \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && apk del tzdata \
    && pip install shyaml \
    && rm -rf /var/cache/apk/*

# https://github.com/docker-library/php/issues/240
# https://gist.github.com/guillemcanal/be3db96d3caa315b4e2b8259cab7d07e
# https://forum.alpinelinux.org/forum/installation/php-iconv-issue
# https://github.com/gliderlabs/docker-alpine/issues/157#issuecomment-200860301

RUN rm -rf /var/cache/apk/*

# Set environments
RUN sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" "$PHP_INI_DIR" && \
    sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" "$PHP_INI_DIR" && \
    sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" "$PHP_INI_DIR" && \
    sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" "$PHP_INI_DIR" && \
    sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" "$PHP_INI_DIR" && \
    sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" "$PHP_INI_DIR"

# Update php config
RUN mkdir -p "/etc/php7/conf.d" && \
    echo "memory_limit=-1" > "/etc/php7/conf.d/memory-limit.ini" && \
    echo "date.timezone=Asia/Kolkata" > "/etc/php7/conf.d/date_timezone.ini"

# Setup wp-cli
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Setup composer
RUN mkdir -p /composer && \
    curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/bin/ --filename=composer
COPY composer.* /composer/
RUN cd /composer && composer install

# Setup Vault
RUN wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip && \
    unzip vault_${VAULT_VERSION}_linux_amd64.zip && \
    rm vault_${VAULT_VERSION}_linux_amd64.zip && \
    mv vault /usr/local/bin/vault

COPY deploy.php hosts.yml /
COPY *.sh /
RUN chmod +x /*.sh

ENTRYPOINT ["/entrypoint.sh"]
