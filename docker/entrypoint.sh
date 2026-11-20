#!/bin/bash
# =============================================================================
# Entrypoint do contêiner Moodle
# Na primeira execução (sem config.php) instala o Moodle via CLI usando as
# variáveis MOODLE_* do .env; nas seguintes apenas inicia o Apache.
# Corrige o template original, que abria o instalador web (sem config.php).
# TODO: Em produção, mover as senhas para um gerenciador de segredos e rodar o
#       cron do Moodle (admin/cli/cron.php) em um contêiner separado.
# =============================================================================
set -euo pipefail

WEB_ROOT=/var/www/html
CONFIG="${WEB_ROOT}/config.php"

# Aguarda o PostgreSQL aceitar conexões (o healthcheck do compose cobre o local;
# na EC2 o RDS pode demorar alguns segundos a mais).
wait_for_db() {
    local tries=60
    # shellcheck disable=SC2016  # aspas simples intencionais: o código PHP lê as variáveis via getenv()
    until php -r '
        $c = @pg_connect(sprintf("host=%s port=%s dbname=%s user=%s password=%s connect_timeout=3",
            getenv("MOODLE_DATABASE_HOST"), getenv("MOODLE_DATABASE_PORT_NUMBER"),
            getenv("MOODLE_DATABASE_NAME"), getenv("MOODLE_DATABASE_USER"),
            getenv("MOODLE_DATABASE_PASSWORD")));
        exit($c ? 0 : 1);'; do
        tries=$((tries - 1))
        if [ "$tries" -le 0 ]; then
            echo "[entrypoint] banco indisponível após 60 tentativas" >&2
            exit 1
        fi
        echo "[entrypoint] aguardando o banco (${tries} tentativas restantes)…"
        sleep 5
    done
}

install_moodle() {
    echo "[entrypoint] config.php ausente — instalando o Moodle via CLI…"
    su -s /bin/bash www-data -c "php ${WEB_ROOT}/admin/cli/install.php \
        --non-interactive --agree-license \
        --lang=pt_br \
        --wwwroot='${MOODLE_WWWROOT}' \
        --dataroot=/var/moodledata \
        --dbtype=pgsql \
        --dbhost='${MOODLE_DATABASE_HOST}' \
        --dbport='${MOODLE_DATABASE_PORT_NUMBER}' \
        --dbname='${MOODLE_DATABASE_NAME}' \
        --dbuser='${MOODLE_DATABASE_USER}' \
        --dbpass='${MOODLE_DATABASE_PASSWORD}' \
        --fullname='${MOODLE_SITE_NAME}' \
        --shortname=Moodle \
        --adminuser='${MOODLE_USERNAME}' \
        --adminpass='${MOODLE_PASSWORD}' \
        --adminemail='${MOODLE_EMAIL}'"
}

if [ ! -f "$CONFIG" ]; then
    wait_for_db
    install_moodle
fi

exec "$@"
