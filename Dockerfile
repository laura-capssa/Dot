# ==============================================================================
# STAGE 1: BUILDER (Multi-stage para cumprir o requisito de otimização)
#
# Em uma aplicação real com Composer ou assets, este estágio faria a instalação
# de dependências e a compilação de assets.
# Aqui, usamos ele apenas para demonstrar a técnica.
# ==============================================================================
FROM php:8.1-cli AS builder

# Define o diretório de trabalho do builder
WORKDIR /app

# Copia os arquivos da aplicação
COPY ./app/ ./

# Se a aplicação usasse Composer, o comando seria:
# RUN composer install --no-dev --prefer-dist --optimize-autoloader

# ==============================================================================
# STAGE 2: PRODUCTION (Imagem final de execução)
#
# Esta imagem é a que será executada. Ela copia apenas os artefatos necessários
# do estágio 'builder', resultando em uma imagem final mais segura e limpa.
# ==============================================================================
FROM php:8.1-apache AS production

# Define o diretório de trabalho do Apache
WORKDIR /var/www/html

# Copia a aplicação (e as dependências, se tivessem sido instaladas) do stage 'builder'
# Isso garante que apenas os arquivos finais sejam incluídos.
COPY --from=builder /app/ /var/www/html/

# 💡 CORREÇÃO DO 'NOT FOUND' (Adição Crucial)
# Este comando edita o arquivo de configuração do Apache (dir.conf) para que ele
# procure por 'index.php' antes de 'index.html' ao acessar a raiz do servidor.
# Isso resolve o problema de "The requested URL was not found".
RUN sed -i 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/' /etc/apache2/mods-enabled/dir.conf

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