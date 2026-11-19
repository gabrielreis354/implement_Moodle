# Implementation Plan: Módulo Terraform Compute

## Overview

Implementação incremental dos quatro arquivos do módulo `terraform/modules/compute/`: `variables.tf`, `main.tf`, `outputs.tf` e `user_data.sh`. A ordem respeita as dependências de referência — variáveis e data source antes do recurso `aws_instance`, outputs depois do recurso, script de bootstrap depois das variáveis que ele consome. Cada arquivo recebe ao menos um `# TODO: (produção)` para satisfazer P2/`test_todo_comments.py`. O script instala Docker Engine via `dnf`, baixa o binário Docker Compose v2 do GitHub, cria 2 GB de swap, clona o repositório via Git, grava `/home/ec2-user/implement_Moodle/docker/.env` com 10 variáveis (incluindo `MOODLE_WWWROOT` obtido via IMDSv2) e executa `docker compose -f docker/docker-compose.aws.yml up -d --build`. O arquivo `docker/docker-compose.aws.yml` já existe no repositório — o script NÃO o grava.

## Tasks

- [x] 1. Criar `variables.tf` com todas as variáveis de entrada do módulo
  - [x] 1.1 Declarar variáveis de rede: `public_subnet_id` e `sg_app_id` (tipo `string`, sem default, `description` não vazia)
    - Satisfaz os critérios de aceitação 4.1 e 4.2
    - _Requirements: 4.1, 4.2_
  - [x] 1.2 Declarar variáveis de instância: `instance_type` (default `"t3.micro"`, validation rejeita string vazia) e `instance_name` (default `"moodle-ec2"`, validation rejeita string vazia)
    - Satisfaz os critérios 4.3 e 4.9
    - _Requirements: 3.2, 3.8, 4.3, 4.9_
  - [x] 1.3 Declarar variáveis do RDS sem sensitive: `db_host`, `db_name`, `db_user` (tipo `string`, sem default); e `db_password` (`sensitive = true`, sem default, validation comprimento ≥ 8)
    - `db_host`, `db_name`, `db_user` NÃO são sensitive (apenas host/nome/usuário); somente `db_password`
    - Satisfaz os critérios 4.4, 4.6, 4.7 e 4.8
    - _Requirements: 4.4, 4.6, 4.7, 4.8_
  - [x] 1.4 Declarar variável `db_port` (tipo `number`, default `5432`, validation 1 ≤ porta ≤ 65535)
    - Satisfaz o critério 4.5
    - _Requirements: 4.5_
  - [x] 1.5 Adicionar ao menos um comentário `# TODO: (produção)` em `variables.tf`
    - Satisfaz P2 e o critério 7.2; necessário para `test_todo_comments.py` passar
    - _Requirements: 7.2_
  - [x] 1.6 Declarar variáveis do Moodle e do repositório: `moodle_admin_user` (default `"admin"`), `moodle_admin_password` (`sensitive = true`, sem default, validation: ≥8 chars com maiúscula + minúscula + dígito + símbolo), `moodle_admin_email` (sem default), `moodle_site_name` (default `"Moodle"`), `repo_url` (sem default) e `repo_branch` (default `"main"`)
    - Satisfaz os critérios 4.10–4.15
    - _Requirements: 4.10, 4.11, 4.12, 4.13, 4.14, 4.15_

- [x] 2. Criar `main.tf` com data source AMI, locals e recurso `aws_instance`
  - [x] 2.1 Declarar `data "aws_ami" "al2023"` com `most_recent = true`, `owners = ["amazon"]` e filtros `al2023-ami-2023.*-x86_64` / `hvm`
    - Padrão `al2023-ami-2023.*-x86_64` evita a variante minimal; sem nenhum literal `ami-*` hardcoded — satisfaz P3 e os critérios 2.1, 2.2, 2.3
    - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - [x] 2.2 Declarar bloco `locals { user_data_vars = { db_host, db_port, db_name, db_user, db_password, moodle_admin_user, moodle_admin_password, moodle_admin_email, moodle_site_name, repo_url, repo_branch } }` referenciando as variáveis de `variables.tf`
    - Alimenta o `templatefile()` com os 11 campos — satisfaz o critério 3.7
    - _Requirements: 3.7_
  - [x] 2.3 Declarar exatamente um `resource "aws_instance" "moodle"` com `ami`, `instance_type`, `subnet_id`, `vpc_security_group_ids`, `iam_instance_profile = "LabInstanceProfile"` (string literal), `user_data = templatefile(...)` e tag `Name`
    - Satisfaz P1, P4 e os critérios 3.1–3.8; `iam_instance_profile` hardcoded como string literal, nenhum `aws_iam_*`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 8.1_
  - [x] 2.4 Adicionar ao menos um comentário `# TODO: (produção)` em `main.tf`
    - Satisfaz P2 e o critério 7.1; necessário para `test_todo_comments.py` passar
    - _Requirements: 7.1_

- [x] 3. Checkpoint — verificar formatação e ausência de IAM
  - Confirmar que `main.tf` e `variables.tf` não contêm `aws_iam_*`, não contêm `ami-` hardcoded, e possuem `# TODO:`. Confirmar também que `variables.tf` contém as variáveis `repo_url`, `repo_branch` e as variáveis do Moodle. Prosseguir somente se ambos os arquivos estiverem corretos.

- [x] 4. Criar `outputs.tf` com os outputs obrigatórios
  - [x] 4.1 Declarar output `public_ip` com `value = aws_instance.moodle.public_ip` e `description` não vazia
    - Satisfaz P6 e o critério 5.1
    - _Requirements: 5.1, 5.4_
  - [x] 4.2 Declarar output `public_dns` com `value = aws_instance.moodle.public_dns` e `description` não vazia
    - Satisfaz P6 e o critério 5.2
    - _Requirements: 5.2, 5.5_
  - [x] 4.3 Adicionar ao menos um comentário `# TODO: (produção)` em `outputs.tf`
    - Satisfaz P2 e o critério 7.3; necessário para `test_todo_comments.py` passar
    - _Requirements: 7.3_

- [x] 5. Criar `user_data.sh` com bootstrap do Docker e Moodle
  - [x] 5.1 Adicionar cabeçalho `#!/bin/bash`, `set -euo pipefail` e redirecionamento `exec >> /var/log/user-data.log 2>&1`
    - Satisfaz o critério 6.11 (qualquer falha interrompe execução e é registrada no log)
    - _Requirements: 6.11_
  - [x] 5.2 Instalar Docker e Git via `dnf install -y docker git`; baixar binário do Docker Compose v2 do GitHub para `/usr/local/lib/docker/cli-plugins/docker-compose` via `curl -SL`, aplicar `chmod +x` e validar com `docker compose version`
    - Satisfaz P7 e os critérios 6.1, 6.2; substitui o pacote `docker-compose-plugin` que NÃO existe no Amazon Linux 2023
    - _Requirements: 6.1, 6.2_
  - [x] 5.3 Habilitar e iniciar o Docker com `systemctl enable docker && systemctl start docker`
    - Satisfaz o critério 6.3
    - _Requirements: 6.3_
  - [x] 5.4 Criar 2 GB de swap: `fallocate -l 2G /swapfile`, `chmod 600 /swapfile`, `mkswap /swapfile`, `swapon /swapfile`
    - Necessário porque `t3.micro` tem apenas 1 GB de RAM e o `docker compose --build` pode falhar por OOM
    - Satisfaz o critério 6.4
    - _Requirements: 6.4_
  - [x] 5.5 Clonar o repositório com `git clone --branch ${repo_branch} ${repo_url} /home/ec2-user/implement_Moodle`
    - Os placeholders `${repo_branch}` e `${repo_url}` são sintaxe do `templatefile()` do Terraform
    - Satisfaz o critério 6.5
    - _Requirements: 6.5_
  - [x] 5.6 Obter hostname via IMDSv2: primeiro `TOKEN=$(curl -sX PUT .../latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')` e depois `PUBLIC_HOSTNAME=$(curl -sH "X-aws-ec2-metadata-token: $${TOKEN}" .../latest/meta-data/public-hostname)`; variáveis de shell devem usar escape `$${...}` pois o arquivo é processado pelo `templatefile()` do Terraform
    - IMDSv2 é obrigatório no Amazon Linux 2023 (IMDSv1 está desabilitado por padrão)
    - Satisfaz o critério 6.6
    - _Requirements: 6.6_
  - [x] 5.7 Gravar `/home/ec2-user/implement_Moodle/docker/.env` com as 10 variáveis substituídas pelo `templatefile()`: `MOODLE_DATABASE_HOST=${db_host}`, `MOODLE_DATABASE_PORT_NUMBER=${db_port}`, `MOODLE_DATABASE_NAME=${db_name}`, `MOODLE_DATABASE_USER=${db_user}`, `MOODLE_DATABASE_PASSWORD=${db_password}`, `MOODLE_USERNAME=${moodle_admin_user}`, `MOODLE_PASSWORD=${moodle_admin_password}`, `MOODLE_EMAIL=${moodle_admin_email}`, `MOODLE_SITE_NAME=${moodle_site_name}`, `MOODLE_WWWROOT=http://$${PUBLIC_HOSTNAME}`; aplicar `chmod 600` no arquivo
    - Nenhum placeholder `${...}` não substituído pelo Terraform deve permanecer; `$${PUBLIC_HOSTNAME}` é variável de shell (escape duplo)
    - Satisfaz o critério 6.7
    - _Requirements: 6.7_
  - [x] 5.8 Implementar loop de espera TCP no endpoint RDS: 24 tentativas × 5s usando `bash /dev/tcp/${db_host}/${db_port}`; se esgotar, registrar erro em `/var/log/user-data.log` e encerrar com `exit 1`
    - Satisfaz o critério 6.8
    - _Requirements: 6.8_
  - [x] 5.9 Executar `cd /home/ec2-user/implement_Moodle && docker compose -f docker/docker-compose.aws.yml up -d --build`
    - `docker-compose.aws.yml` já existe no repositório clonado — NÃO é gerado pelo script
    - Satisfaz P7 e o critério 6.9
    - _Requirements: 6.9_
  - [x] 5.10 Adicionar ao menos um comentário `# TODO: (produção)` em `user_data.sh`
    - Satisfaz P2 e o critério 7.4; necessário para `test_todo_comments.py` passar
    - _Requirements: 7.4_

- [x] 6. Checkpoint final — confirmar propriedades P1–P7
  - Verificar estaticamente: exatamente 1 `aws_instance` (P1), `# TODO:` em todos os quatro arquivos (P2), sem `ami-*` hardcoded (P3), sem `aws_iam_*` (P4), três arquivos `.tf` presentes (P5), `public_ip`/`public_dns` em `outputs.tf` (P6), `docker compose -f docker/docker-compose.aws.yml up -d --build` e `dnf install` em `user_data.sh` (P7). Garantir que `terraform fmt -check -recursive` retorne exit 0 e que `terraform validate` retorne exit 0.

## Notes

- Tarefas marcadas com `*` são opcionais e podem ser puladas para um MVP mais rápido
- A ordem das tarefas respeita dependências: `variables.tf` → `main.tf` → `outputs.tf` → `user_data.sh`
- `iam_instance_profile = "LabInstanceProfile"` deve ser string literal em `main.tf` — nunca uma variável ou referência a recurso IAM
- Nenhum `aws_iam_*` pode ser declarado em nenhum arquivo `.tf` do módulo (restrição do Learner Lab)
- Os placeholders `${db_*}`, `${moodle_*}`, `${repo_*}` em `user_data.sh` são sintaxe do `templatefile()` do Terraform, não variáveis de shell
- O arquivo `docker/docker-compose.aws.yml` já existe no repositório — NÃO é criado pelo script. O script clona o repositório e referencia esse arquivo no comando `docker compose -f`.
- O pacote `docker-compose-plugin` NÃO existe no Amazon Linux 2023. O Docker Compose v2 é instalado como binário baixado do GitHub para `/usr/local/lib/docker/cli-plugins/docker-compose`.
- Variáveis de shell dentro de `user_data.sh` que são processadas pelo `templatefile()` do Terraform precisam de escape duplo (`$${TOKEN}`, `$${PUBLIC_HOSTNAME}`). Variáveis passadas pelo templatefile usam `${...}` simples.

## Desvios

Ajustes em relação ao texto original da Spec, registrados após a implementação:

1. **Task 5.6** — o texto original usava uma atribuição com cifrão escapado antes do nome da variável, o que resultaria em comando inexistente no shell. A atribuição correta é `TOKEN=$(curl ...)`; o escape `$${...}` vale apenas para expansões dentro do template. Texto corrigido acima.
2. **`mkdir -p /usr/local/lib/docker/cli-plugins`** antes do download do Compose (diretório inexistente no AL2023) e versão fixada em `v2.29.7`.
3. **Fallback `public-ipv4`** quando `public-hostname` vier vazio.
4. **Comentários do `user_data.sh`** continham placeholders sem escape e quebravam o `templatefile()` (erro de sintaxe na linha 3); reescritos sem cifrão. *Corrigido pelo Claude Code.*
5. **Validação de `moodle_admin_password`** usava lookahead, não suportado pelo RE2 do Terraform (dentro de `can()` o erro era engolido e toda senha era rejeitada); trocada por `alltrue([...])` com um `regex` por exigência. *Corrigido pelo Claude Code.*
6. **Task 5.10** — os `# TODO: (produção)` existiam em `user_data.sh`, mas a task estava sem marcação; marcada manualmente.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "1.4"] },
    { "id": 1, "tasks": ["1.5", "1.6"] },
    { "id": 2, "tasks": ["2.1", "2.2"] },
    { "id": 3, "tasks": ["2.3"] },
    { "id": 4, "tasks": ["2.4", "4.1", "4.2"] },
    { "id": 5, "tasks": ["4.3", "5.1"] },
    { "id": 6, "tasks": ["5.2", "5.3", "5.4"] },
    { "id": 7, "tasks": ["5.5"] },
    { "id": 8, "tasks": ["5.6"] },
    { "id": 9, "tasks": ["5.7"] },
    { "id": 10, "tasks": ["5.8"] },
    { "id": 11, "tasks": ["5.9", "5.10"] }
  ]
}
```
