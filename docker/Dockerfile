# =============================================================================
# Dockerfile — Moodle 4.1 customizado com extensões PHP obrigatórias
# Base: php:8.1-apache (imagem oficial PHP com Apache)
#
# Referência de extensões obrigatórias:
#   https://moodledev.io/docs/gettingstarted/requirements
#
# Requisitos: 1.5 (Moodle 4.1+), 1.11 (extensões PHP obrigatórias), 2.4 (# TODO:)
# =============================================================================

FROM php:8.1-apache

# -----------------------------------------------------------------------------
# Instala as dependências de sistema necessárias para as extensões PHP
# e ferramentas utilitárias do ambiente de produção
# -----------------------------------------------------------------------------
# DL3008 ignorado: as versões dos pacotes apt flutuam com o release Debian da imagem
# base php:8.1-apache; fixá-las quebraria o build a cada atualização da base.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    # pkg-config — necessário para que o configure do PHP encontre as bibliotecas
    pkg-config \
    # Dependência de oniguruma para a extensão mbstring (codificação multibyte)
    libonig-dev \
    # Dependência de libzip para a extensão zip
    libzip-dev \
    # Dependência de libicu para a extensão intl (internacionalização)
    libicu-dev \
    # Dependência de libpq para a extensão pdo_pgsql (PostgreSQL)
    libpq-dev \
    # Dependências de libpng e libjpeg para a extensão gd (imagens)
    libpng-dev \
    libjpeg-dev \
    # Dependência de libsodium para a extensão sodium (criptografia Moodle 4.1+)
    libsodium-dev \
    # Dependência de libxml2 para a extensão simplexml
    libxml2-dev \
    # Dependência de libcurl para a extensão curl
    libcurl4-openssl-dev \
    # Ferramentas de rede e utilitários gerais
    curl \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Configura e instala a extensão gd com suporte a JPEG
# (precisa de configuração prévia ao install para habilitar libjpeg)
# -----------------------------------------------------------------------------
# (unificado com o install abaixo para evitar RUNs consecutivos — hadolint DL3059)
#
# Instala as extensões PHP obrigatórias para o Moodle 4.x
#
# Extensões NÃO instaladas aqui pois já vêm embutidas no PHP:
#   - iconv   (built-in)
#   - openssl (built-in)
#   - ctype   (built-in)
#   - zlib    (built-in)
#   - json    (built-in no PHP 8+)
# -----------------------------------------------------------------------------
RUN docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install \
    # Codificação multibyte de strings (obrigatório para i18n no Moodle)
    mbstring \
    # Cliente HTTP (utilizado para integração de plugins e notificações)
    curl \
    # Compressão/descompressão de arquivos ZIP (upload de plugins/cursos)
    zip \
    # Parsing de XML simples (feeds RSS e comunicação SOAP)
    simplexml \
    # Internacionalização e formatação de datas/números por locale
    intl \
    # Driver PDO para PostgreSQL
    pdo_pgsql \
    # Driver NATIVO do PostgreSQL (pg_connect) — o Moodle usa esta extensão, não o PDO.
    # Corrigido: estava ausente e impedia a conexão do Moodle com o banco.
    pgsql \
    # SOAP (web services) e EXIF (metadados de imagens) — recomendadas pelo Moodle
    soap \
    exif \
    # Processamento de imagens (thumbnails, avatares de usuários)
    gd \
    # Cache de opcodes PHP (melhora performance de produção)
    opcache \
    # Funções criptográficas modernas (obrigatório no Moodle 4.1+)
    sodium

# TODO: Adicione aqui extensões PHP opcionais necessárias para plugins adicionais.
# Exemplos de extensões comuns em ambientes Moodle avançados:
#
#   RUN docker-php-ext-install xmlrpc   # Integração com sistemas externos via XML-RPC
#   RUN pecl install redis && docker-php-ext-enable redis  # Cache Redis/sessões distribuídas
#   RUN pecl install apcu  && docker-php-ext-enable apcu   # Cache local APCu (alternativa ao Redis)
#   RUN docker-php-ext-install ldap     # Autenticação via LDAP/Active Directory

# -----------------------------------------------------------------------------
# Configura o OPcache com parâmetros recomendados para o Moodle em produção
# -----------------------------------------------------------------------------
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.use_cwd=1'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# -----------------------------------------------------------------------------
# Configura o PHP com parâmetros recomendados para o Moodle
# (max_input_vars elevado é necessário para formulários longos do Moodle)
# -----------------------------------------------------------------------------
RUN { \
    echo 'max_input_vars=5000'; \
    echo 'post_max_size=128M'; \
    echo 'upload_max_filesize=128M'; \
    echo 'memory_limit=256M'; \
    echo 'max_execution_time=300'; \
} > /usr/local/etc/php/conf.d/moodle-recommended.ini

# -----------------------------------------------------------------------------
# Baixa e instala o Moodle 4.1 a partir do repositório oficial
# O código é extraído em /var/www/html (DocumentRoot padrão do Apache)
# -----------------------------------------------------------------------------
ENV MOODLE_VERSION=4.1

RUN curl -fsSL \
    "https://download.moodle.org/download.php/direct/stable401/moodle-latest-401.tgz" \
    -o /tmp/moodle.tgz \
    && tar -xzf /tmp/moodle.tgz -C /tmp \
    && cp -r /tmp/moodle/. /var/www/html/ \
    && rm -rf /tmp/moodle.tgz /tmp/moodle \
    && chown -R www-data:www-data /var/www/html

# -----------------------------------------------------------------------------
# Cria o diretório moodledata fora do DocumentRoot (exigido pelo Moodle)
# e ajusta permissões para o usuário do Apache
# -----------------------------------------------------------------------------
#
# Também cria o symlink /var/www/moodledata -> /var/moodledata (caminho padrão
# esperado pelo instalador) e habilita o módulo Apache rewrite (URLs limpas).
# Unificado em um único RUN para evitar RUNs consecutivos (hadolint DL3059).
# -----------------------------------------------------------------------------
RUN mkdir -p /var/moodledata \
    && chown -R www-data:www-data /var/moodledata \
    && chmod 0770 /var/moodledata \
    && ln -s /var/moodledata /var/www/moodledata \
    && a2enmod rewrite

# -----------------------------------------------------------------------------
# Copia o arquivo de configuração do VirtualHost customizado para o Apache
# Nota: o arquivo apache-moodle.conf é opcional; sem ele, o Apache usa o
# VirtualHost padrão que já aponta para /var/www/html
# -----------------------------------------------------------------------------
# COPY apache-moodle.conf /etc/apache2/sites-available/000-default.conf

# -----------------------------------------------------------------------------
# Entrypoint: instala o Moodle via CLI na primeira execução (gera o config.php)
# e depois inicia o Apache em primeiro plano.
# -----------------------------------------------------------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Porta exposta pelo contêiner (mapeada para 8080 no host via docker-compose.yml)
EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
