# ==============================================================================
# STAGE 1: BUILDER (Usa PHP-FPM Alpine para máxima compatibilidade e segurança)
# ==============================================================================
# CORREÇÃO: Usando a tag FPM Alpine, que é mais estável no Docker Hub.
FROM php:8.2-fpm-alpine AS builder

# Define o diretório de trabalho do builder
WORKDIR /app

# Copia os arquivos da aplicação
COPY ./app/ ./

# Se a aplicação usasse Composer, o comando seria:
# RUN composer install --no-dev --prefer-dist --optimize-autoloader

# ==============================================================================
# STAGE 2: PRODUCTION (Imagem final de execução com PHP-FPM e Apache)
# ==============================================================================
FROM php:8.2-fpm-alpine AS production

# Define o diretório de trabalho
WORKDIR /var/www/html

# Instala o Apache e as ferramentas de configuração (Alpine usa 'apk')
RUN apk update && \
    apk add --no-cache apache2 apache2-utils bash \
    && rm -rf /var/cache/apk/*

# Habilita módulos essenciais do Apache:
# - proxy_fcgi: para se comunicar com o PHP-FPM
# - dir: para configurar o index.php
# - rewrite: módulo de reescrita de URL
RUN sed -i 's/^#\(LoadModule proxy_module modules\/mod_proxy.so\)/\1/' /etc/apache2/httpd.conf && \
    sed -i 's/^#\(LoadModule proxy_fcgi_module modules\/mod_proxy_fcgi.so\)/\1/' /etc/apache2/httpd.conf && \
    sed -i 's/^#\(LoadModule dir_module modules\/mod_dir.so\)/\1/' /etc/apache2/httpd.conf && \
    sed -i 's/^#\(LoadModule rewrite_module modules\/mod_rewrite.so\)/\1/' /etc/apache2/httpd.conf

# Configura o Virtual Host padrão do Apache para usar PHP-FPM (FastCGI)
# Esta configuração diz ao Apache para enviar todos os arquivos .php para o PHP-FPM.
COPY ./docker-configs/default.conf /etc/apache2/conf.d/default.conf

# Copia a aplicação do stage 'builder'
COPY --from=builder /app/ /var/www/html/

# Ajusta permissões e define o usuário não-root (www-data é o UID 82 no Alpine)
RUN chown -R 82:82 /var/www/html \
    && chmod -R 755 /var/www/html

# Define o usuário não-root para execução segura 
USER 82

# A porta 80 é a porta padrão do Apache dentro do container
EXPOSE 80

# Comando principal para iniciar o Apache.
# O PHP-FPM já estará rodando em background pois a imagem base é 'fpm'.
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
