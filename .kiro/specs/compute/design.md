# Design Document

## Overview

O módulo Terraform `compute` provisiona a camada de execução do Moodle no AWS Academy Learner Lab. Ele declara um único recurso `aws_instance` (tipo `t3.micro`) em subnet pública, resolve a AMI do Amazon Linux 2023 dinamicamente via data source para nunca congelar um ID de imagem, anexa o instance profile pré-existente `LabInstanceProfile` por string literal (sem criar nenhum recurso `aws_iam_*`), e injeta um script de bootstrap (`user_data.sh`) que instala Docker Engine ≥ 24 e Docker Compose v2 (binário baixado do GitHub), cria 2 GB de swap, clona o repositório via Git, grava o arquivo `/home/ec2-user/implement_Moodle/docker/.env` com permissão 600 contendo as credenciais RDS e as configurações do Moodle, calcula `MOODLE_WWWROOT` via IMDSv2 e sobe o Moodle com `docker compose -f docker/docker-compose.aws.yml up -d --build`.

A comunicação entre módulos acontece somente por variáveis de entrada e outputs: o módulo raiz passa os valores do módulo `networking` (subnet pública, security group) e do módulo `database` (endpoint, porta, credenciais) ao módulo `compute`; o módulo `compute` devolve `public_ip` e `public_dns`.

Restrições inegociáveis do ambiente:
- Nenhum recurso `aws_iam_*`, `aws_route53_*`, `aws_acm_*` ou `aws_cloudfront_*`. O arquivo `docker/docker-compose.aws.yml` já existe no repositório — não é gerado pelo script.
- Somente HTTP na porta 80.
- Região `us-east-1`, provider AWS `~> 5.0`.
- Credenciais temporárias do Learner Lab (inclui `aws_session_token`).
- Todo arquivo `.tf` e `.sh` deve conter ao menos um `# TODO: (produção) …`.

---

## Architecture

```mermaid
graph TD
    subgraph "terraform/ (root module)"
        ROOT[main.tf]
    end

    subgraph "modules/networking"
        NET_OUT[outputs: public_subnet_ids, sg_app_id]
    end

    subgraph "modules/database"
        DB_OUT[outputs: db_host, db_port, db_name, db_user, db_password]
    end

    subgraph "modules/compute"
        AMI[data aws_ami\nal2023-ami-2023.*-x86_64\nmost_recent=true]
        LOCALS[locals user_data_vars\ndb_host, db_port, db_name\ndb_user, db_password\nmoodle_admin_*, repo_url, repo_branch]
        EC2[resource aws_instance\nt3.micro\nLabInstanceProfile]
        UDSH[user_data.sh\nvia templatefile]
        VARS[variables.tf\npublic_subnet_id, sg_app_id\ninstance_type, instance_name\ndb_host, db_port\ndb_name, db_user, db_password*\nmoodle_admin_*, repo_url, repo_branch]
        OUTS[outputs.tf\npublic_ip, public_dns]
    end

    subgraph "EC2 (first boot)"
        DNF[dnf install docker git]
        COMPOSE_BIN[curl GitHub → /usr/local/lib/docker/cli-plugins/docker-compose\nchmod +x + docker compose version]
        SWAP[fallocate 2G + mkswap + swapon]
        DOCKER[systemctl enable+start docker]
        CLONE[git clone ${repo_url} branch ${repo_branch}\n→ /home/ec2-user/implement_Moodle]
        IMDS[IMDSv2: PUT token → GET public-hostname]
        ENV[grava .env com 10 vars em\n/home/ec2-user/implement_Moodle/docker/.env\npermissão 600]
        WAIT[TCP wait RDS ≤120s]
        UP[docker compose -f docker/docker-compose.aws.yml up -d --build]
    end

    ROOT -->|public_subnet_id\nsg_app_id| VARS
    NET_OUT -->|public_subnet_ids[0]\nsg_app_id| ROOT
    DB_OUT -->|db_host, db_port\ndb_name, db_user\ndb_password| ROOT
    ROOT -->|db_* vars| VARS
    VARS --> LOCALS
    AMI --> EC2
    LOCALS --> UDSH
    UDSH --> EC2
    EC2 --> OUTS
    EC2 -.->|user_data| DNF
    DNF --> COMPOSE_BIN
    COMPOSE_BIN --> SWAP
    SWAP --> DOCKER
    DOCKER --> CLONE
    CLONE --> IMDS
    IMDS --> ENV
    ENV --> WAIT
    WAIT --> UP
```

> `*` = variáveis com `sensitive = true` (`db_password`, `moodle_admin_password`)

---

## Components and Interfaces

### `main.tf`

Responsabilidades:
1. Declarar o `data "aws_ami"` que resolve o ID mais recente do AL2023.
2. Declarar o bloco `locals` com o mapa `user_data_vars` que alimenta o `templatefile()`.
3. Declarar o único recurso `aws_instance`.

Pseudocódigo / assinaturas:

```hcl
# Resolve dinamicamente o AMI mais recente do Amazon Linux 2023
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter { name = "name"               values = ["al2023-ami-2023.*-x86_64"] }
  filter { name = "virtualization-type" values = ["hvm"] }
}

locals {
  user_data_vars = {
    db_host              = var.db_host
    db_port              = var.db_port
    db_name              = var.db_name
    db_user              = var.db_user
    db_password          = var.db_password
    moodle_admin_user    = var.moodle_admin_user
    moodle_admin_password = var.moodle_admin_password
    moodle_admin_email   = var.moodle_admin_email
    moodle_site_name     = var.moodle_site_name
    repo_url             = var.repo_url
    repo_branch          = var.repo_branch
  }
}

resource "aws_instance" "moodle" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.sg_app_id]
  iam_instance_profile   = "LabInstanceProfile"
  user_data              = templatefile("${path.module}/user_data.sh", local.user_data_vars)

  tags = { Name = var.instance_name }

  # TODO: (produção) adicionar volume EBS separado para /var/moodledata com encrypt=true
}
```

### `variables.tf`

Declara todas as entradas do módulo com tipos, descriptions, validações e `sensitive` onde aplicável.

| Variável | Tipo | Padrão | Sensitive | Validação |
|---|---|---|---|---|
| `public_subnet_id` | `string` | — | não | (obrigatória, sem default) |
| `sg_app_id` | `string` | — | não | (obrigatória, sem default) |
| `instance_type` | `string` | `"t3.micro"` | não | rejeita string vazia |
| `instance_name` | `string` | `"moodle-ec2"` | não | rejeita string vazia |
| `db_host` | `string` | — | **não** | (obrigatória) |
| `db_port` | `number` | `5432` | não | 1 ≤ porta ≤ 65535 |
| `db_name` | `string` | — | **não** | (obrigatória) |
| `db_user` | `string` | — | **não** | (obrigatória) |
| `db_password` | `string` | — | **sim** | comprimento ≥ 8 |
| `moodle_admin_user` | `string` | `"admin"` | não | (opcional) |
| `moodle_admin_password` | `string` | — | **sim** | ≥8 chars; maiúscula + minúscula + dígito + símbolo |
| `moodle_admin_email` | `string` | — | não | (obrigatória) |
| `moodle_site_name` | `string` | `"Moodle"` | não | (opcional) |
| `repo_url` | `string` | — | não | (obrigatória) |
| `repo_branch` | `string` | `"main"` | não | (opcional) |

### `outputs.tf`

```hcl
output "public_ip" {
  description = "IPv4 público da instância EC2"
  value       = aws_instance.moodle.public_ip
  # TODO: (produção) adicionar sensitive=true e expor via SSM Parameter Store
}

output "public_dns" {
  description = "DNS público da instância EC2"
  value       = aws_instance.moodle.public_dns
}
```

### `user_data.sh`

Script executado pelo EC2 no primeiro boot. Recebe as variáveis de conexão RDS por substituição de template via `templatefile()`.

Fluxo de execução:

```
1.  set -euo pipefail + exec >> /var/log/user-data.log 2>&1
2.  dnf install -y docker git
3.  curl -SL https://github.com/docker/compose/releases/download/<VERSÃO>/docker-compose-linux-x86_64 \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    docker compose version   # valida instalação
4.  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
5.  systemctl enable docker && systemctl start docker
6.  git clone --branch ${repo_branch} ${repo_url} /home/ec2-user/implement_Moodle
7.  IMDSv2:
      TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token \
              -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')
      → escape como $${TOKEN} no templatefile
      PUBLIC_HOSTNAME=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" \
              http://169.254.169.254/latest/meta-data/public-hostname)
      → escape como $${PUBLIC_HOSTNAME} no templatefile
8.  grava /home/ec2-user/implement_Moodle/docker/.env com 10 variáveis:
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
    chmod 600 /home/ec2-user/implement_Moodle/docker/.env
9.  loop TCP wait: até 24 tentativas × 5s = 120s máx.
      usa /dev/tcp/${db_host}/${db_port} (bash builtin)
      se esgotar: loga erro e exit 1
10. cd /home/ec2-user/implement_Moodle
    docker compose -f docker/docker-compose.aws.yml up -d --build
# TODO: (produção) adicionar monitoramento via CloudWatch Agent e alarme de CPU
```

**Nota:** O arquivo `docker/docker-compose.aws.yml` já existe no repositório. O User_Data_Script não o grava — apenas o referencia no comando `docker compose -f docker/docker-compose.aws.yml up -d --build`. Ele expõe o serviço Moodle na porta 80, usa `env_file: .env` para carregar as variáveis gravadas pelo script, e não declara serviço `db` (banco é o RDS externo).

---

## Data Models

### Mapa `local.user_data_vars`

```hcl
{
  db_host               = string   # endpoint do RDS
  db_port               = number   # porta TCP do PostgreSQL (padrão 5432)
  db_name               = string   # nome do banco
  db_user               = string   # usuário do banco
  db_password           = string   # senha do banco (sensitive, ≥8 chars)
  moodle_admin_user     = string   # usuário admin do Moodle (padrão "admin")
  moodle_admin_password = string   # senha admin do Moodle (sensitive)
  moodle_admin_email    = string   # e-mail do admin
  moodle_site_name      = string   # nome do site (padrão "Moodle")
  repo_url              = string   # URL do repositório Git
  repo_branch           = string   # branch a clonar (padrão "main")
}
```

### Outputs do módulo

```
public_ip  : string  # ex. "54.210.12.3"   — vazio se EC2 sem IP público
public_dns : string  # ex. "ec2-54-210-12-3.compute-1.amazonaws.com" — vazio se ausente
```

### Fluxo de integração com módulo raiz

```hcl
# terraform/main.tf (fragmento)
module "compute" {
  source                = "./modules/compute"
  public_subnet_id      = module.networking.public_subnet_ids[0]
  sg_app_id             = module.networking.sg_app_id
  db_host               = module.database.db_host
  db_port               = module.database.db_port
  db_name               = module.database.db_name
  db_user               = module.database.db_user
  db_password           = module.database.db_password
  moodle_admin_user     = var.moodle_admin_user
  moodle_admin_password = var.moodle_admin_password
  moodle_admin_email    = var.moodle_admin_email
  moodle_site_name      = var.moodle_site_name
  repo_url              = var.repo_url
  repo_branch           = var.repo_branch
}
```

---

## Error Handling

| Condição de erro | Comportamento esperado |
|---|---|
| Data source `aws_ami` retorna 0 resultados | `terraform plan` falha com erro do próprio Terraform indicando que nenhuma AMI foi encontrada; nenhum `aws_instance` é criado |
| `public_subnet_id` ou `sg_app_id` vazios | `terraform plan` falha com mensagem de validação da variável indicando qual campo é inválido |
| `db_password` com menos de 8 caracteres | `terraform plan` falha com mensagem do bloco `validation` |
| `curl` do binário do Docker Compose do GitHub falha (timeout/404) | `set -euo pipefail` interrompe o script; erro registrado em `/var/log/user-data.log`; a instância fica sem Moodle mas EC2 está running |
| Qualquer recurso `aws_iam_*` declarado | Detectado pelos testes de conformidade estática; rejeitado na revisão de código |
| RDS não acessível em 120s no boot | `user_data.sh` loga erro em `/var/log/user-data.log` e encerra com `exit 1` sem executar `docker compose up -d` |
| `docker-compose.aws.yml` ausente no repositório clonado | `docker compose` falha ao tentar ler o arquivo; erro registrado no log |
| Qualquer comando do `user_data.sh` falha | `set -euo pipefail` garante interrupção imediata; saída capturada no log |

---

## Testing Strategy

### Por que Property-Based Testing não se aplica aqui

O módulo `compute` é declarativo (IaC — Terraform HCL e shell script). Não há funções com domínio de entrada amplo para exploração probabilística; as propriedades são binárias (arquivo existe ou não, string presente ou ausente, recurso proibido ausente ou presente). Usar um framework PBT para gerar 100+ instâncias de `.tf` não revelaria mais defeitos do que uma verificação estática única.

A estratégia correta para IaC é: **testes de conformidade estática** (lint, grep, ast-parse) para verificar propriedades estruturais, complementados por **testes de integração** (terraform validate / plan) para verificar semântica.

### Propriedades de correção (P1–P7) e mapeamento para requisitos

As propriedades abaixo são verificadas pelos testes `pytest` existentes em `tests/`.

| Propriedade | Descrição | Requisito(s) | Tipo de teste |
|---|---|---|---|
| **P1** | O módulo declara exatamente um `resource "aws_instance"` | 3.1, 3.9 | Conformidade estática (grep/AST) |
| **P2** | Todo arquivo `.tf` e `.sh` contém `# TODO:` | 7.1–7.4 | Conformidade estática (grep) |
| **P3** | Nenhum literal `ami-[0-9a-f]{8,17}` nos arquivos do módulo | 2.4 | Conformidade estática (regex) |
| **P4** | Nenhum bloco `resource "aws_iam_*"` no módulo | 3.6, 8.1 | Conformidade estática (grep) |
| **P5** | Os três arquivos `main.tf`, `variables.tf`, `outputs.tf` existem | 1.1–1.3 | Verificação de existência de arquivo |
| **P6** | `public_ip` e `public_dns` declarados em `outputs.tf` | 5.1–5.2 | Conformidade estática (grep/AST) |
| **P7** | `user_data.sh` contém `docker compose -f docker/docker-compose.aws.yml up -d --build` e `dnf install` | 6.1, 6.9 | Conformidade estática (grep) |

### Testes automatizados existentes

Os arquivos em `tests/` já cobrem as propriedades acima:

- `test_terraform_module_structure.py` — P5 (estrutura de arquivos)
- `test_todo_comments.py` — P2 (marcadores TODO)
- `test_architecture_template_sections.py` — conformidade de documentação
- `test_compose_no_hardcoded_creds.py` — ausência de credenciais hardcoded

### Testes de integração (manuais / CI)

```bash
cd terraform
terraform fmt -check -recursive      # formatação
terraform init                        # inicializa providers
terraform validate                    # valida sintaxe e referências
terraform plan -out=tfplan            # verifica que exatamente 1 aws_instance é planejado
```

Esses comandos são executados pelo workflow `.github/workflows/terraform-validate.yml` e `terraform-plan.yml` existentes.

### Cobertura de edge cases por testes unitários

- `db_password` com 7 caracteres → `terraform plan` deve falhar com erro de validação.
- `instance_type` vazio → `terraform plan` deve falhar com erro de validação.
- `public_subnet_id` como string vazia → `terraform plan` deve falhar.
- Data source AMI sem resultados (região incorreta) → `terraform plan` deve falhar com mensagem clara.
