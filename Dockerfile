#1.Base Image
#FROM alpine
FROM php:7.2-fpm-alpine

# ensure www-data user exists
#RUN set -x \
#	&& addgroup -g 82  -S www-data \
#	&& adduser -u 82 -D -S -G www-data www-data

# Environments
ENV TIMEZONE            Asia/Shanghai
ENV PHP_MEMORY_LIMIT    512M
ENV MAX_UPLOAD          50M
ENV PHP_MAX_FILE_UPLOAD 200
ENV PHP_MAX_POST        100M
ENV COMPOSER_ALLOW_SUPERUSER 1


#安装nginx supervisor 等软件
RUN apk add --update nginx \
openssh \
supervisor \
git \
curl \
curl-dev \
make \
zlib-dev \
build-base \
zsh \
vim \
vimdiff \
wget \
sudo

#2.ADD-PHP-FPM

# Mirror mirror switch to Alpine Linux - http://dl-4.alpinelinux.org/alpine/
RUN apk update \
	&& apk upgrade \
	&& apk add \
		curl \
		tzdata \
		php7-fpm\
	    php7 \
	    php7-dev \
	    php7-apcu \
	    php7-bcmath \
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
 	&& cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
	&& echo "${TIMEZONE}" > /etc/timezone \
	&& apk del tzdata \
 	&& rm -rf /var/cache/apk/*

#install yac
RUN pecl install yac-2.0.2 && \
echo -e "[yac] \
extension=yac.so \
yac.enable=1 \
yac.keys_memory_size=4M \
yac.values_memory_size=64M \
yac.compress_threshold=-1 \
yac.enable_cli=0" > /etc/php7/conf.d/yac.ini && \
pecl clear-cache

#RUN pecl install yac-2.0.1 && /usr/local/bin/docker-php-ext-enable yac

#RUN wget http://pecl.php.net/get/yac-2.1.1.tgz -O /tmp/yac.tar.tgz \
#    && pecl install /tmp/yac.tar.tgz \
#    && rm -rf /tmp/yac.tar.tgz \
#    && docker-php-ext-enable yac

#RUN wget http://pecl.php.net/get/yac-2.1.1.tgz -O yac.tgz \
#    && mkdir -p yac \
#    && tar -zxvf yac.tgz -C yac --strip-components=1 \
#    && rm yac.tgz \
#    && ( \
#        cd yac \
#        && phpize \
#        && ./configure --enable-yac \
#        && make -j$(nproc) \
#        && make install \
#    ) \
#    && rm -r yac \
#    && docker-php-ext-enable yac

# https://github.com/docker-library/php/issues/240
# https://gist.github.com/guillemcanal/be3db96d3caa315b4e2b8259cab7d07e
# https://forum.alpinelinux.org/forum/installation/php-iconv-issue

RUN mkdir -p /usr/local/var/log/php7/
RUN mkdir -p /usr/local/var/run/
COPY docker/php/php-fpm.conf /etc/php7/
COPY docker/php/www.conf /etc/php7/php-fpm.d/

#RUN apk add --no-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing gnu-libiconv
#ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php
#RUN rm -rf /var/cache/apk/*

# Set environments
RUN sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /etc/php7/php.ini && \
	sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php7/php.ini && \
	sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /etc/php7/php.ini && \
	sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php7/php.ini && \
	sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php7/php.ini && \
	sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" /etc/php7/php.ini

#3.Install-Composer
RUN curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/bin/ --filename=composer



#4.ADD-NGINX
RUN apk add nginx
COPY docker/nginx/conf.d/default.conf /etc/nginx/conf.d/
COPY docker/nginx/nginx.conf /etc/nginx/
COPY docker/nginx/cert/ /etc/nginx/cert/

RUN mkdir -p /usr/share/nginx/html/public/
COPY docker/php/index.php /usr/share/nginx/html/public/
#RUN mkdir -p /run/nginx
#RUN touch /run/nginx/nginx.pid
# Expose volumes

VOLUME ["/usr/share/nginx/html", "/usr/local/var/log/php7", "/var/run/"]
WORKDIR /usr/share/nginx/html


#5.ADD-SUPERVISOR
RUN apk add supervisor \
 && rm -rf /var/cache/apk/*

# Define mountable directories.
VOLUME ["/etc/supervisor/conf.d", "/var/log/supervisor/"]
COPY docker/supervisor/conf.d/ /etc/supervisor/conf.d/

#6.ADD-CRONTABS
COPY docker/crontabs/default /var/spool/cron/crontabs/
RUN cat /var/spool/cron/crontabs/default >> /var/spool/cron/crontabs/root
RUN mkdir -p /var/log/cron \
 && touch /var/log/cron/cron.log

VOLUME /var/log/cron

#7.ADD-REDIS
#RUN apk add redis

#8.ADD-MARIADB
#RUN apk add mariadb=10.3.12-r2
#VOLUME /var/lib/mysql

#设置环境变量，便于管理
#ENV MARIADB_USER root
#ENV MARIADB_PASS 123456
##初始化数据库
#COPY ./mariadb/db_init.sh /etc/
#RUN chmod 775 /etc/db_init.sh
#RUN /etc/db_init.sh

#导出端口
#EXPOSE 3306

#添加启动文件
#ADD ./mariadb/run.sh /root/run.sh
#RUN chmod 775 /root/run.sh
#设置默认启动命令
#CMD ["/root/run.sh"]

#9.添加启动脚本
# Define working directory.
WORKDIR /usr/share/nginx/html
COPY docker/entrypoint.sh /usr/share/nginx/
RUN chmod +x /usr/share/nginx/entrypoint.sh

#CMD ["supervisord", "--nodaemon", "--configuration", "/etc/supervisor/conf.d/supervisord.conf"]
ENTRYPOINT ["/usr/share/nginx/entrypoint.sh"]
