# ==============================================================================
# STAGE 1: BUILDER (Usa PHP-FPM Alpine para máxima compatibilidade e segurança)
# ==============================================================================
FROM php:8.2-fpm-alpine AS builder

WORKDIR /app
COPY ./app/ ./

# ==============================================================================
# STAGE 2: PRODUCTION (Imagem final de execução com PHP-FPM e Apache)
# ==============================================================================
FROM php:8.2-fpm-alpine AS production

WORKDIR /var/www/html

# Instala o Apache e cria diretório de logs com permissões corretas
RUN apk update && \
    apk add --no-cache apache2 apache2-utils bash \
    && mkdir -p /var/www/logs \
    && chown -R 82:82 /var/www \
    && chmod -R 755 /var/www \
    && rm -rf /var/cache/apk/*

# Habilita módulos do Apache
RUN sed -i 's/^#\(LoadModule proxy_module modules\/mod_proxy.so\)/\1/' /etc/apache2/httpd.conf && \
    sed -i 's/^#\(LoadModule proxy_fcgi_module modules\/mod_proxy_fcgi.so\)/\1/' /etc/apache2/httpd.conf && \
    sed -i 's/^#\(LoadModule dir_module modules\/mod_dir.so\)/\1/' /etc/apache2/httpd.conf && \
    sed -i 's/^#\(LoadModule rewrite_module modules\/mod_rewrite.so\)/\1/' /etc/apache2/httpd.conf

# Configura ServerName para evitar warning
RUN echo "ServerName localhost" >> /etc/apache2/httpd.conf

# Configura o Virtual Host (use um arquivo correto ou configure inline)
RUN echo '<VirtualHost *:80>' > /etc/apache2/conf.d/default.conf && \
    echo '  ServerName localhost' >> /etc/apache2/conf.d/default.conf && \
    echo '  DocumentRoot /var/www/html' >> /etc/apache2/conf.d/default.conf && \
    echo '  ErrorLog /var/www/logs/error.log' >> /etc/apache2/conf.d/default.conf && \
    echo '  CustomLog /var/www/logs/access.log combined' >> /etc/apache2/conf.d/default.conf && \
    echo '  <Directory "/var/www/html">' >> /etc/apache2/conf.d/default.conf && \
    echo '    Options -Indexes +FollowSymLinks' >> /etc/apache2/conf.d/default.conf && \
    echo '    AllowOverride All' >> /etc/apache2/conf.d/default.conf && \
    echo '    Require all granted' >> /etc/apache2/conf.d/default.conf && \
    echo '  </Directory>' >> /etc/apache2/conf.d/default.conf && \
    echo '  <FilesMatch \.php$>' >> /etc/apache2/conf.d/default.conf && \
    echo '    SetHandler "proxy:fcgi://127.0.0.1:9000"' >> /etc/apache2/conf.d/default.conf && \
    echo '  </FilesMatch>' >> /etc/apache2/conf.d/default.conf && \
    echo '</VirtualHost>' >> /etc/apache2/conf.d/default.conf

# Copia a aplicação
COPY --from=builder /app/ /var/www/html/

# Ajusta permissões FINAIS
RUN chown -R 82:82 /var/www && \
    chmod -R 755 /var/www

USER 82
EXPOSE 80

# Inicia ambos serviços: PHP-FPM e Apache
CMD sh -c "php-fpm -D && /usr/sbin/httpd -D FOREGROUND"