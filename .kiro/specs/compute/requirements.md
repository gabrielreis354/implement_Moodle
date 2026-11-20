# Requirements Document

## Introduction

Este documento especifica os requisitos do módulo Terraform `compute`, localizado em `terraform/modules/compute/`. O módulo provisiona uma instância EC2 Amazon Linux 2023 (`t3.micro`) em subnet pública, com `iam_instance_profile = "LabInstanceProfile"`, e executa um script de bootstrap (`user_data.sh`) que instala Docker Engine ≥ 24 e Docker Compose v2 (binário baixado do GitHub), clona o repositório do projeto, grava o arquivo `.env` com as credenciais do RDS e as configurações do Moodle, e sobe o Moodle com `docker compose -f docker/docker-compose.aws.yml up -d --build`. O `.env` é gravado em `/home/ec2-user/implement_Moodle/docker/.env` com permissão 600. `MOODLE_WWWROOT` é calculado no shell via IMDSv2. O módulo expõe os outputs `public_ip` e `public_dns`. Todas as restrições do AWS Academy Learner Lab se aplicam: nenhum recurso `aws_iam_*` pode ser criado; Route 53, ACM e CloudFront são proibidos; somente HTTP na porta 80.

## Glossary

- **Compute_Module**: O módulo Terraform em `terraform/modules/compute/` responsável por provisionar a instância EC2 e o script de bootstrap.
- **EC2_Instance**: O recurso `aws_instance` do tipo `t3.micro` provisionado pelo Compute_Module na subnet pública.
- **AMI_Data_Source**: O bloco `data "aws_ami"` que resolve dinamicamente o ID da Amazon Machine Image mais recente do Amazon Linux 2023, sem hardcodar nenhum valor `ami-*`.
- **User_Data_Script**: O arquivo `terraform/modules/compute/user_data.sh` lido via `templatefile()` pelo Compute_Module; executado pelo EC2 no primeiro boot.
- **LabInstanceProfile**: O instance profile IAM pré-existente no AWS Academy Learner Lab; referenciado por string literal no campo `iam_instance_profile` da EC2_Instance — nunca criado como recurso Terraform.
- **RDS_Connection_Vars**: O conjunto de variáveis Terraform com `sensitive = true` que transportam endpoint, porta, nome do banco, usuário e senha do RDS até o User_Data_Script via `templatefile()`.
- **SG_App**: O ID do security group `sg-app` criado pelo módulo networking, recebido como variável de entrada pelo Compute_Module; permite tráfego TCP 80 e 22 na EC2_Instance.
- **Moodle_Env_File**: O arquivo `/home/ec2-user/implement_Moodle/docker/.env` gravado pelo User_Data_Script com as variáveis de conexão RDS e configuração do Moodle; permissão 600.
- **Repo_URL**: URL do repositório Git clonado pelo User_Data_Script; recebida via variável `repo_url` do módulo.
- **Repo_Branch**: Branch do repositório a clonar; recebida via variável `repo_branch` do módulo.
- **IMDSv2**: O serviço de metadados da instância EC2 na versão 2, que requer um token de sessão obtido via `PUT http://169.254.169.254/latest/api/token` antes de qualquer consulta de metadado.
- **TODO_Marker**: O comentário `# TODO: (produção)` obrigatório em cada arquivo `.tf` e `.sh` do módulo, exigido pelo teste `test_todo_comments.py`.
- **Terraform_Root**: O diretório raiz `terraform/` contendo `main.tf`, `variables.tf` e `outputs.tf` que orquestra todos os módulos filhos.
- **Terraform_Root_Module**: O módulo raiz Terraform em `terraform/` que declara o provider AWS e invoca os módulos networking, database e compute.
- **Terraform_Provider**: O bloco `provider "aws"` declarado no módulo raiz, responsável por autenticar chamadas à API AWS com as credenciais temporárias do Learner Lab.

## Requirements

### Requirement 1: Estrutura de arquivos obrigatória do módulo

**User Story:** As a estudante, I want the compute module to contain the three required Terraform files, so that the property tests in `test_terraform_module_structure.py` pass and the module integrates correctly with the root module.

#### Acceptance Criteria

1. THE Compute_Module SHALL contain the file `main.tf` no diretório `terraform/modules/compute/`.
2. THE Compute_Module SHALL contain the file `variables.tf` no diretório `terraform/modules/compute/`.
3. THE Compute_Module SHALL contain the file `outputs.tf` no diretório `terraform/modules/compute/`.
4. THE Compute_Module SHALL contain o arquivo `user_data.sh` no diretório `terraform/modules/compute/`.
5. WHEN `terraform fmt -check -recursive` é executado na raiz do diretório `terraform/`, THE Compute_Module SHALL produzir exit code 0.
6. WHEN `terraform validate` é executado na raiz do diretório `terraform/`, THE Compute_Module SHALL produzir exit code 0 sem erros de sintaxe ou de referência.
7. THE Compute_Module SHALL conter ao menos um comentário no formato `# TODO: (produção) …` em cada um dos arquivos `main.tf`, `variables.tf` e `outputs.tf`.

---

### Requirement 2: Resolução dinâmica da AMI via data source

**User Story:** As a estudante, I want the EC2 instance AMI to be resolved via a data source, so that the module always uses the latest Amazon Linux 2023 image without any hardcoded `ami-*` string in the codebase.

#### Acceptance Criteria

1. THE AMI_Data_Source SHALL ser declarado como `data "aws_ami"` em `terraform/modules/compute/main.tf` com `most_recent = true`.
2. THE AMI_Data_Source SHALL filtrar por `name` usando o padrão `al2023-ami-2023.*-x86_64` (evita a variante minimal) e por `virtualization-type` igual a `hvm`, ambos dentro do bloco `filter` do mesmo recurso `data "aws_ami"`.
3. THE AMI_Data_Source SHALL especificar `owners = ["amazon"]` para garantir a origem oficial.
4. WHEN o plano Terraform for gerado, THE Compute_Module SHALL referenciar a AMI exclusivamente via `data.aws_ami.<nome>.id` no atributo `ami` do recurso `aws_instance`, sem nenhum literal correspondendo ao padrão `ami-[0-9a-f]{8,17}` em qualquer arquivo dentro de `terraform/modules/compute/`.
5. IF o bloco `data "aws_ami"` retornar zero resultados para o padrão `al2023-ami-*-x86_64` com `owners = ["amazon"]` na região `us-east-1`, THEN THE Compute_Module SHALL falhar o `terraform plan` com mensagem de erro indicando que nenhuma AMI correspondente foi encontrada, sem criar o recurso `aws_instance`.

---

### Requirement 3: Provisionamento da instância EC2

**User Story:** As a estudante, I want a single EC2 `t3.micro` instance provisioned in the public subnet with the LabInstanceProfile attached, so that Moodle can be accessed via HTTP on port 80 within the AWS Academy Learner Lab constraints.

#### Acceptance Criteria

1. THE Compute_Module SHALL declarar exatamente um recurso `aws_instance` em `terraform/modules/compute/main.tf`.
2. THE EC2_Instance SHALL usar `instance_type = var.instance_type`, com valor padrão `"t3.micro"` definido em `terraform/modules/compute/variables.tf`.
3. THE EC2_Instance SHALL ser posicionada em `subnet_id = var.public_subnet_id`, onde `var.public_subnet_id` é uma variável de entrada obrigatória sem valor padrão declarada em `terraform/modules/compute/variables.tf`.
4. THE EC2_Instance SHALL usar `vpc_security_group_ids = [var.sg_app_id]`, onde `var.sg_app_id` é uma variável de entrada obrigatória sem valor padrão declarada em `terraform/modules/compute/variables.tf`.
5. THE EC2_Instance SHALL conter `iam_instance_profile = "LabInstanceProfile"` como string literal hardcoded, sem referenciar nenhuma variável ou recurso IAM.
6. IF qualquer bloco `resource "aws_iam_role"`, `resource "aws_iam_user"`, `resource "aws_iam_policy"` ou `resource "aws_iam_instance_profile"` for declarado em qualquer arquivo `.tf` dentro de `terraform/modules/compute/`, THEN THE Compute_Module SHALL falhar na verificação da propriedade P4, e o pipeline de validação SHALL rejeitar o plano com erro explícito.
7. THE EC2_Instance SHALL conter `user_data = templatefile("${path.module}/user_data.sh", local.user_data_vars)`, onde `local.user_data_vars` é um bloco `locals` declarado no mesmo `main.tf` contendo ao menos `db_host`, `db_port`, `db_name`, `db_user`, `db_password`, `moodle_admin_user`, `moodle_admin_password`, `moodle_admin_email`, `moodle_site_name`, `repo_url` e `repo_branch`.
8. THE EC2_Instance SHALL conter a tag `Name` com valor igual a `var.instance_name`, sendo `var.instance_name` uma variável de entrada de tipo `string` com valor padrão `"moodle-ec2"` declarada em `terraform/modules/compute/variables.tf`.
9. WHEN `terraform plan` for executado no diretório `terraform/`, THE Compute_Module SHALL produzir exatamente um recurso do tipo `aws_instance` no plan output, sem erros de validação e sem divergências de formatação.

---

### Requirement 4: Variáveis de entrada do módulo

**User Story:** As a estudante, I want all module input variables declared with types, descriptions, validations, and `sensitive = true` only where strictly necessary, so that no secret is hardcoded and all inputs are validated at plan time.

#### Acceptance Criteria

1. THE Compute_Module SHALL declarar em `variables.tf` a variável `public_subnet_id` do tipo `string` sem valor padrão e com `description` não vazia.
2. THE Compute_Module SHALL declarar em `variables.tf` a variável `sg_app_id` do tipo `string` sem valor padrão e com `description` não vazia.
3. THE Compute_Module SHALL declarar em `variables.tf` a variável `instance_type` do tipo `string` com valor padrão `"t3.micro"` e bloco `validation` que rejeita strings vazias.
4. THE Compute_Module SHALL declarar em `variables.tf` a variável `db_host` do tipo `string` sem valor padrão e sem `sensitive` (host não é segredo).
5. THE Compute_Module SHALL declarar em `variables.tf` a variável `db_port` do tipo `number` com valor padrão `5432` e bloco `validation` que aceita somente valores entre 1 e 65535 inclusive.
6. THE Compute_Module SHALL declarar em `variables.tf` a variável `db_name` do tipo `string` sem valor padrão e sem `sensitive`.
7. THE Compute_Module SHALL declarar em `variables.tf` a variável `db_user` do tipo `string` sem valor padrão e sem `sensitive`.
8. THE Compute_Module SHALL declarar em `variables.tf` a variável `db_password` do tipo `string` com `sensitive = true`, sem valor padrão, e bloco `validation` que rejeita strings com comprimento menor que 8 caracteres.
9. THE Compute_Module SHALL declarar em `variables.tf` a variável `instance_name` do tipo `string` com valor padrão `"moodle-ec2"` e bloco `validation` que rejeita strings vazias.
10. THE Compute_Module SHALL declarar em `variables.tf` a variável `moodle_admin_user` do tipo `string` com valor padrão `"admin"` e `description` não vazia.
11. THE Compute_Module SHALL declarar em `variables.tf` a variável `moodle_admin_password` do tipo `string` com `sensitive = true`, sem valor padrão, e bloco `validation` que rejeita strings com comprimento menor que 8 caracteres e que não contenham ao menos uma letra maiúscula, uma minúscula, um dígito e um símbolo (qualquer caractere não alfanumérico).
12. THE Compute_Module SHALL declarar em `variables.tf` a variável `moodle_admin_email` do tipo `string` sem valor padrão e com `description` não vazia.
13. THE Compute_Module SHALL declarar em `variables.tf` a variável `moodle_site_name` do tipo `string` com valor padrão `"Moodle"` e `description` não vazia.
14. THE Compute_Module SHALL declarar em `variables.tf` a variável `repo_url` do tipo `string` sem valor padrão e com `description` não vazia.
15. THE Compute_Module SHALL declarar em `variables.tf` a variável `repo_branch` do tipo `string` com valor padrão `"main"` e `description` não vazia.
16. IF `db_password` ou `moodle_admin_password` aparecerem em texto puro em qualquer bloco `output` do módulo sem `sensitive = true` no output, THEN THE Compute_Module SHALL produzir erro em `terraform validate`.
17. IF `public_subnet_id` ou `sg_app_id` receberem string vazia como valor, THEN THE Compute_Module SHALL falhar em `terraform plan` com mensagem de erro indicando qual variável é inválida.

---

### Requirement 5: Outputs obrigatórios do módulo

**User Story:** As a estudante, I want the module to expose `public_ip` and `public_dns` as outputs, so that the root module can display the access URL after `terraform apply` and the health-check script can receive the EC2 address.

#### Acceptance Criteria

1. THE Compute_Module SHALL declarar em `outputs.tf` o output `public_ip` com `value = aws_instance.<nome>.public_ip`.
2. THE Compute_Module SHALL declarar em `outputs.tf` o output `public_dns` com `value = aws_instance.<nome>.public_dns`.
3. THE Compute_Module SHALL declarar exatamente os outputs `public_ip` e `public_dns` como saídas públicas mínimas obrigatórias, sem outputs adicionais não documentados.
4. WHEN `terraform output public_ip` é executado após `terraform apply` com EC2_Instance em estado `running`, THE Compute_Module SHALL retornar um endereço IPv4 público no formato `X.X.X.X` onde cada octeto está entre 0 e 255.
5. WHEN `terraform output public_dns` é executado após `terraform apply` com EC2_Instance em estado `running`, THE Compute_Module SHALL retornar o DNS público no formato `ec2-<ip-com-hífens>.compute-1.amazonaws.com`.
6. IF a EC2_Instance não possui IP público atribuído no momento do `terraform output`, THEN THE Compute_Module SHALL retornar string vazia para `public_ip` e string vazia para `public_dns`, sem interromper a execução do Terraform.

---

### Requirement 6: Script de bootstrap `user_data.sh`

**User Story:** As a estudante, I want the `user_data.sh` script to automatically install Docker, clone the repository, and start Moodle on EC2 first boot, so that the instance is self-provisioning without manual SSH steps after `terraform apply`.

#### Acceptance Criteria

1. THE User_Data_Script SHALL conter a instrução `dnf install -y docker` para instalar o Docker Engine no Amazon Linux 2023, seguida de `dnf install -y git` para instalar o Git.
2. THE User_Data_Script SHALL baixar o binário do Docker Compose v2 do release oficial do GitHub para `/usr/local/lib/docker/cli-plugins/docker-compose` via `curl -SL https://github.com/docker/compose/releases/download/<versão>/docker-compose-linux-x86_64`, aplicar `chmod +x` no binário e validar com `docker compose version`.
3. THE User_Data_Script SHALL conter ambos `systemctl enable docker` e `systemctl start docker` para garantir que o serviço Docker esteja habilitado no boot e em execução antes de qualquer comando `docker compose`.
4. THE User_Data_Script SHALL criar 2 GB de espaço de swap com `fallocate -l 2G /swapfile`, `chmod 600 /swapfile`, `mkswap /swapfile` e `swapon /swapfile` antes de qualquer operação de build do Docker, pois a instância `t3.micro` tem apenas 1 GB de RAM.
5. THE User_Data_Script SHALL clonar o repositório `${repo_url}` na branch `${repo_branch}` em `/home/ec2-user/implement_Moodle` usando `git clone --branch ${repo_branch} ${repo_url}`.
6. THE User_Data_Script SHALL obter o hostname público via IMDSv2: primeiro obtendo um token com `curl -sX PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60'` e depois consultando `curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-hostname`; como o arquivo é processado por `templatefile()`, variáveis de shell devem usar escape `$${TOKEN}` e `$${PUBLIC_HOSTNAME}`.
7. THE User_Data_Script SHALL gravar o arquivo `/home/ec2-user/implement_Moodle/docker/.env` com permissão 600, contendo as variáveis: `MOODLE_DATABASE_HOST`, `MOODLE_DATABASE_PORT_NUMBER`, `MOODLE_DATABASE_NAME`, `MOODLE_DATABASE_USER`, `MOODLE_DATABASE_PASSWORD`, `MOODLE_USERNAME`, `MOODLE_PASSWORD`, `MOODLE_EMAIL`, `MOODLE_SITE_NAME` e `MOODLE_WWWROOT=http://$${PUBLIC_HOSTNAME}`; nenhum placeholder `${...}` não substituído pelo Terraform deve permanecer no arquivo gravado.
8. THE User_Data_Script SHALL implementar loop de espera TCP no endpoint RDS por até 120 segundos (24 tentativas × 5 s cada) usando `bash /dev/tcp` antes de executar o compose.
9. WHEN o User_Data_Script for executado no primeiro boot da EC2_Instance, THE User_Data_Script SHALL executar `docker compose -f docker/docker-compose.aws.yml up -d --build` a partir do diretório `/home/ec2-user/implement_Moodle/`, somente após o serviço Docker estar em execução, o clone do repositório estar completo, o `.env` gravado e o RDS acessível.
10. IF o endpoint RDS não estiver acessível dentro de 120 segundos, THEN THE User_Data_Script SHALL registrar mensagem de erro em `/var/log/user-data.log` e encerrar com exit code diferente de zero sem executar o compose.
11. IF qualquer comando individual do User_Data_Script encerrar com exit code diferente de zero, THEN THE User_Data_Script SHALL registrar o nome do comando e seu exit code em `/var/log/user-data.log` e interromper a execução subsequente (`set -euo pipefail`).

---

### Requirement 7: Comentários TODO obrigatórios

**User Story:** As a estudante, I want every `.tf` and `.sh` file in the module to contain at least one `# TODO: (produção)` comment, so that the property test `test_todo_comments.py` passes and future production hardening points are documented.

#### Acceptance Criteria

1. THE Compute_Module SHALL conter ao menos um comentário `# TODO:` no arquivo `terraform/modules/compute/main.tf`, onde o marcador é seguido de texto não vazio descrevendo um ponto de melhoria para produção.
2. THE Compute_Module SHALL conter ao menos um comentário `# TODO:` no arquivo `terraform/modules/compute/variables.tf`, onde o marcador é seguido de texto não vazio descrevendo um ponto de melhoria para produção.
3. THE Compute_Module SHALL conter ao menos um comentário `# TODO:` no arquivo `terraform/modules/compute/outputs.tf`, onde o marcador é seguido de texto não vazio descrevendo um ponto de melhoria para produção.
4. THE User_Data_Script SHALL conter ao menos um comentário `# TODO:` no arquivo `terraform/modules/compute/user_data.sh`, onde o marcador é seguido de texto não vazio descrevendo um ponto de melhoria para produção.
5. THE Terraform_Root SHALL conter ao menos um comentário `# TODO:` em cada um dos arquivos `terraform/main.tf`, `terraform/variables.tf` e `terraform/outputs.tf`, onde cada marcador é seguido de texto não vazio descrevendo um ponto de melhoria para produção.
6. WHEN `test_todo_comments.py` é executado via `pytest`, THE Compute_Module SHALL produzir 0 falhas relacionadas a arquivos nos diretórios `terraform/` e `docker/`, exceto `terraform/versions.tf` que é explicitamente excluído pelo teste.

---

### Requirement 8: Conformidade com restrições do AWS Academy Learner Lab

**User Story:** As a estudante, I want the module to strictly comply with AWS Academy Learner Lab restrictions, so that `terraform apply` succeeds without `AccessDenied` errors and the solution runs within the educational environment constraints.

#### Acceptance Criteria

1. IF qualquer bloco `resource "aws_iam_*"` for encontrado em qualquer arquivo `.tf` dentro de `terraform/modules/compute/`, THEN THE Compute_Module SHALL ser rejeitado na revisão de código, registrando o nome do arquivo e número da linha onde o recurso proibido foi encontrado.
2. IF qualquer referência a `resource "aws_route53_*"`, `resource "aws_acm_*"` ou `resource "aws_cloudfront_*"` for encontrada em qualquer arquivo `.tf` dentro de `terraform/` ou de seus submódulos, THEN THE Compute_Module SHALL ser rejeitado na revisão de código, registrando o nome do arquivo e número da linha onde o recurso proibido foi encontrado.
3. THE Compute_Module SHALL declarar regras de ingress no security group `sg-app` somente para HTTP na porta 80 e SSH na porta 22 (esta restrita ao `var.ssh_allowed_cidr`), sem nenhuma regra de ingress para portas 443, 8443 ou qualquer outra associada a HTTPS/TLS.
4. THE Terraform_Root_Module SHALL declarar o provider AWS com `region = "us-east-1"` e todos os módulos filhos SHALL herdar essa região sem sobrescrevê-la.
