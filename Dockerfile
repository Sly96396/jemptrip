FROM php:8.3-fpm-alpine

# Install system dependencies
RUN apk update && apk add --no-cache \
    nginx \
    supervisor \
    curl \
    zip \
    unzip \
    libpng-dev \
    libzip-dev \
    libxml2-dev

# Install PHP extensions
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    opcache \
    gd \
    zip \
    xml

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Configure nginx
COPY docker/nginx.conf /etc/nginx/http.d/default.conf

# Configure PHP-FPM
COPY docker/www.conf /usr/local/etc/php-fpm.d/www.conf

# Configure supervisord
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set up document root
RUN mkdir -p /var/www/html
WORKDIR /var/www/html


# Copy project file
COPY project/ /var/www/html

# Expose port 80 for nginx
EXPOSE 80

# Start supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]