FROM php:7.3-apache
MAINTAINER Serhii Matrunchyk <serhii@digitalidea.studio>
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash \
    && apt-get install -y --no-install-recommends \
      nodejs \
      cron \
      supervisor \
      git \
      rsync \
      openssh-client \
      screenfetch \
      libzip-dev \
      zlib1g-dev \
      libpng-dev \
      libfreetype6-dev \
      libjpeg62-turbo-dev \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -r /var/lib/apt/lists/* \
    && pecl install xdebug-2.7.2 \
    && docker-php-ext-configure gd \
      --with-freetype-dir=/usr/include/ \
      --with-jpeg-dir=/usr/include/
RUN docker-php-ext-install -j$(nproc) \
      gd \
      bcmath \
      sockets \
      pcntl \
      zip \
      exif \
      pdo_mysql \
    && docker-php-ext-enable \
      xdebug
# Install AWS Environment
RUN curl -sL https://bootstrap.pypa.io/get-pip.py | python3 \
  && pip3 install awscli
# Disable XDebug on the CLI
#RUN phpdismod -s cli xdebug
COPY artisan /var/www/html
RUN chmod 0755 /var/www/html/artisan
# Add crontab file in the cron directory
ADD crontab /etc/cron.d/timeragent-cron
# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/timeragent-cron
# Supervisor
ADD ./supervisord.conf /etc/supervisor/supervisord.conf
# Set PHP configurations
COPY php.ini /usr/local/etc/php/php.ini
## Install codesniffer
RUN curl -O https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar
RUN chmod +x phpcs.phar
RUN mv phpcs.phar /usr/local/bin/phpcs
## Install mess detector
# RUN wget http://static.phpmd.org/php/latest/phpmd.phar
# RUN chmod +x phpmd.phar
# RUN mv phpmd.phar /usr/local/bin/phpmd
## Install PHPUnit
RUN curl -O https://phar.phpunit.de/phpunit-8.phar
RUN chmod +x phpunit-8.phar
RUN mv phpunit-8.phar /usr/local/bin/phpunit
### Install composer & Configure apache
#######################################
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf
RUN a2enmod rewrite
RUN a2ensite 000-default
RUN mkdir -p /var/www/html/public
RUN chown -R www-data: /var/www
#RUN a2enmod ssl
#RUN a2ensite default-ssl
RUN sed -i -e "s/html/html\/public/g" /etc/apache2/sites-enabled/000-default.conf
#RUN sed -i -e "s/html/html\/public/g" /etc/apache2/sites-enabled/default-ssl.conf
#RUN sed -i -e "s/html/html\/public/g" /etc/apache2/sites-enabled/default-ssl.conf
RUN echo '\n\
<Directory /var/www/>\n\
        Options Indexes FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
</Directory>' >> /etc/apache2/conf-enabled/security.conf
RUN ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log

ADD ./start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]
