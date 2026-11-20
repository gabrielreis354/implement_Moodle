#!/bin/bash
# user_data.sh — Bootstrap da EC2: instala Docker, clona o repo e sobe o Moodle.
# Processado por templatefile() do Terraform: placeholders de template (cifrão + chaves) são substituídos no plan.
# Variáveis de shell usam escape $${...} nas expansões para não serem consumidas pelo templatefile.

# =============================================================================
# Task 5.1 — Cabeçalho: modo estrito e log centralizado
# =============================================================================
set -euo pipefail
exec >> /var/log/user-data.log 2>&1
echo "=== user-data iniciado em $(date) ==="

# =============================================================================
# Task 5.2 — Instalar Docker, Git e Docker Compose v2
# =============================================================================
# docker-compose-plugin NÃO existe no Amazon Linux 2023; o Compose v2 é
# instalado como binário do GitHub no diretório de plugins do Docker CLI.

dnf install -y docker git

COMPOSE_VERSION="v2.29.7"
COMPOSE_URL="https://github.com/docker/compose/releases/download/$${COMPOSE_VERSION}/docker-compose-linux-x86_64"
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "$${COMPOSE_URL}" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# =============================================================================
# Task 5.3 — Habilitar e iniciar o serviço Docker
# =============================================================================
systemctl enable docker
systemctl start docker

# Validar instalação do Compose após o daemon estar em execução
docker compose version

# =============================================================================
# Task 5.4 — Criar 2 GB de swap (t3.micro tem apenas 1 GB de RAM)
# =============================================================================
# Necessário para evitar OOM durante o "docker compose --build".

fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# =============================================================================
# Task 5.5 — Clonar o repositório Git
# =============================================================================
# ${repo_url} e ${repo_branch} são substituídos pelo templatefile() do Terraform.

git clone --branch ${repo_branch} ${repo_url} /home/ec2-user/implement_Moodle

# =============================================================================
# Task 5.6 — Obter hostname público via IMDSv2
# =============================================================================
# IMDSv2 é obrigatório no Amazon Linux 2023 (IMDSv1 desabilitado por padrão).
# TOKEN e PUBLIC_HOSTNAME são variáveis de shell: atribuição sem chaves, mas
# expansões dentro de strings usam $${...} para sobreviver ao templatefile().

TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")

PUBLIC_HOSTNAME=$(curl -sH "X-aws-ec2-metadata-token: $${TOKEN}" \
  "http://169.254.169.254/latest/meta-data/public-hostname")

# Fallback: se public-hostname vier vazio, usar o IPv4 público
if [ -z "$${PUBLIC_HOSTNAME}" ]; then
  PUBLIC_HOSTNAME=$(curl -sH "X-aws-ec2-metadata-token: $${TOKEN}" \
    "http://169.254.169.254/latest/meta-data/public-ipv4")
fi

echo "Hostname público: $${PUBLIC_HOSTNAME}"

# =============================================================================
# Task 5.7 — Gravar /home/ec2-user/implement_Moodle/docker/.env
# =============================================================================
# Todos os placeholders de template abaixo são substituídos pelo templatefile() antes do boot.
# Apenas MOODLE_WWWROOT usa $${PUBLIC_HOSTNAME} — variável de shell em runtime.

cat > /home/ec2-user/implement_Moodle/docker/.env <<EOF
MOODLE_DATABASE_HOST=${db_host}
MOODLE_DATABASE_PORT_NUMBER=${db_port}
MOODLE_DATABASE_NAME=${db_name}
MOODLE_DATABASE_USER=${db_user}
MOODLE_DATABASE_PASSWORD=${db_password}
MOODLE_USERNAME=${moodle_admin_user}
MOODLE_PASSWORD=${moodle_admin_password}
MOODLE_EMAIL=${moodle_admin_email}
MOODLE_SITE_NAME=${moodle_site_name}
MOODLE_WWWROOT=http://$${PUBLIC_HOSTNAME}
EOF

chmod 600 /home/ec2-user/implement_Moodle/docker/.env
chown -R ec2-user:ec2-user /home/ec2-user/implement_Moodle

# =============================================================================
# Task 5.8 — Aguardar RDS estar acessível via TCP (até 120 s)
# =============================================================================
# ${db_host} e ${db_port} são substituídos pelo templatefile().
# ATTEMPTS e MAX_ATTEMPTS são variáveis de shell — usam $${...} nas expansões.

echo "Aguardando RDS em ${db_host}:${db_port}..."
ATTEMPTS=0
MAX_ATTEMPTS=24

until (echo > /dev/tcp/${db_host}/${db_port}) 2>/dev/null; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ $${ATTEMPTS} -ge $${MAX_ATTEMPTS} ]; then
    echo "ERRO: RDS ${db_host}:${db_port} não acessível após 120s. Abortando."
    exit 1
  fi
  echo "Tentativa $${ATTEMPTS}/$${MAX_ATTEMPTS} — aguardando 5s..."
  sleep 5
done

echo "RDS acessível."

# =============================================================================
# Task 5.9 — Subir o Moodle com Docker Compose
# =============================================================================
# docker-compose.aws.yml já existe no repositório clonado — NÃO é gerado aqui.

cd /home/ec2-user/implement_Moodle
docker compose -f docker/docker-compose.aws.yml up -d --build

echo "=== user-data concluído em $(date) ==="

# =============================================================================
# Task 5.10 — TODO markers para produção
# =============================================================================
# TODO: (produção) adicionar verificação de saúde do Moodle após o compose up
# (ex.: curl -f http://localhost/login/index.php) e enviar notificação via
# SNS em caso de falha no bootstrap, garantindo visibilidade operacional.

# TODO: (produção) substituir o clone público por autenticação via IAM +
# CodeCommit ou GitHub App, e adicionar verificação de integridade do
# repositório (git verify-commit) antes de executar qualquer artefato clonado.
