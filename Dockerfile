FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

LABEL "com.github.actions.icon"="upload-cloud"
LABEL "com.github.actions.color"="yellow"
LABEL "com.github.actions.name"="Deploy WordPress"
LABEL "com.github.actions.description"="Deploy WordPress code to a server"
LABEL "org.opencontainers.image.source"="https://github.com/rtCamp/action-deploy-wordpress"


ENV PATH                     "/composer/vendor/bin:~/.local/bin:$PATH"
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME            /composer

RUN apt update && \
	apt install -y \
		bash \
		git \
		curl \
		jq \
		rsync \
		zip \
		unzip \
		python3-pip \
		software-properties-common && \
		add-apt-repository ppa:ondrej/php && \
		apt update && \
		apt-get install -y php7.4-cli php7.4-curl php7.4-json php7.4-mbstring php7.4-xml php7.4-iconv php7.4-yaml && \
		pip3 install shyaml && \
		rm -rf /var/lib/apt/lists/*

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

RUN curl -sL https://deb.nodesource.com/setup_16.x | bash && \
	apt install -y nodejs && \
	rm -rf /var/lib/apt/lists/*

COPY deploy.php hosts.yml /
COPY *.sh /
RUN chmod +x /*.sh

ENTRYPOINT ["/entrypoint.sh"]
