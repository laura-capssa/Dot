# ==============================================================================
# STAGE 1: BUILDER (Usa Alpine, mais leve e seguro)
# ==============================================================================
# CORREÇÃO AQUI: A tag correta no Docker Hub inclui a versão do Alpine (ex: alpine3.18)
FROM php:8.2-cli-alpine3.18 AS builder

# Define o diretório de trabalho do builder
WORKDIR /app

# Copia os arquivos da aplicação
COPY ./app/ ./

# Se a aplicação usasse Composer, o comando seria:
# RUN composer install --no-dev --prefer-dist --optimize-autoloader

# ==============================================================================
# STAGE 2: PRODUCTION (Imagem final de execução)
# ==============================================================================
# CORREÇÃO AQUI: Usando php:8.2-apache-alpine3.18 para a imagem final de produção.
FROM php:8.2-apache-alpine3.18 AS production

# Define o diretório de trabalho do Apache
WORKDIR /var/www/html

# Copia a aplicação do stage 'builder'
COPY --from=builder /app/ /var/www/html/

# Instala pacotes essenciais e limpa o cache (ALPINE USA 'apk')
# Adiciona o 'mod_rewrite' que pode ser útil em apps PHP
RUN apk update && \
    apk add --no-cache bash apache2-mod-rewrite \
    && rm -rf /var/cache/apk/*

# Habilita o mod_rewrite
RUN a2enmod rewrite

# 💡 CORREÇÃO DO 'NOT FOUND' (Manutenção)
# Garante que o index.php seja o arquivo padrão do Apache.
RUN sed -i 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/' /etc/apache2/conf.d/dir.conf

# Ajusta permissões e troca para usuário não-root 
# O usuário 'www-data' é o usuário padrão do servidor Apache.
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Define o usuário não-root para execução segura 
USER www-data

# A porta 80 é a porta padrão do Apache dentro do container
EXPOSE 80

# Comando para iniciar o servidor web
CMD ["apache2-foreground"]
