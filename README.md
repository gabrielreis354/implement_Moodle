# Moodle Docker AWS Challenge

Este repositório contém a **solução** do desafio: o Moodle 4.1 rodando em contêineres (Docker) e implantado na AWS (Learner Lab) por infraestrutura como código (Terraform), com pipelines de CI no GitHub Actions. O ambiente Docker local, os módulos Terraform (`networking`, `database`, `compute`), o workflow `terraform-plan.yml` e o desenho técnico ([`docs/architecture-design.md`](docs/architecture-design.md)) estão implementados e validados. O ponto de partida foi um template educacional da disciplina de DevOps (UniFAAT), cujos erros propositais foram corrigidos.

→ **[Leia o desafio completo](CHALLENGE.md)**


## Pré-requisitos

Antes de começar, verifique se você tem as seguintes ferramentas instaladas e configuradas:

| Ferramenta | Versão mínima | Observação |
|---|---|---|
| [Docker Engine](https://docs.docker.com/get-docker/) | 24.x | Inclui o Docker Compose v2 (`docker compose`) |
| [Terraform](https://developer.hashicorp.com/terraform/install) | 1.5+ | Provider AWS `~> 5.0` |
| [AWS CLI](https://aws.amazon.com/cli/) | 2.x | Para configurar as credenciais do Learn Lab |
| [Git](https://git-scm.com/) | 2.x | Para clonar/forkar o template |
| [Python](https://www.python.org/) | 3.8+ | Para rodar os testes (`pytest` + `hypothesis`) |
| Conta AWS Learn Lab | — | Credenciais temporárias obtidas no portal AWS Academy |

> O ambiente **AWS Learn Lab** fornece credenciais temporárias com permissões restritas (sem IAM, Route 53, ACM ou CloudFront). Consulte [`docs/aws-learn-lab-setup.md`](docs/aws-learn-lab-setup.md) para configurá-las.



## Estrutura do Repositório

```
.
├── .github/
│   └── workflows/                       # Pipelines de CI/CD (GitHub Actions)
│       ├── docker-lint.yml              #   - Lint do Dockerfile (hadolint)
│       ├── health-check.yml             #   - Health check manual (workflow_dispatch)
│       ├── terraform-plan.yml           #   - terraform plan a cada PR (comenta o plan no PR)
│       └── terraform-validate.yml       #   - fmt-check + validate
├── docker/                              # Ambiente Docker local de referência (funcional)
│   ├── .env.example                     #   - Variáveis de ambiente documentadas
│   ├── Dockerfile                       #   - Imagem Moodle customizada (extensões PHP)
│   ├── entrypoint.sh                    #   - Instala o Moodle via CLI na 1ª execução
│   ├── docker-compose.yml               #   - Local: Moodle + PostgreSQL 15
│   └── docker-compose.aws.yml           #   - EC2: só o Moodle (banco = RDS)
├── docs/                                # Documentação do desafio
│   ├── architecture-design-template.md  #   - Template do desenho técnico (entrega do aluno)
│   ├── architecture.md                  #   - Arquitetura de referência (gabarito)
│   ├── aws-learn-lab-setup.md           #   - Credenciais e limitações do Learn Lab
│   ├── evaluation-rubric.md             #   - Rubrica de avaliação
│   ├── img/                             #   - Imagens usadas na documentação
│   ├── security-practices.md            #   - Boas práticas de segurança
│   ├── terraform-guide.md               #   - Guia dos comandos Terraform
│   └── troubleshooting.md              #   - Problemas comuns e soluções
├── terraform/                           # Infraestrutura AWS (Terraform)
│   ├── versions.tf · main.tf · variables.tf · outputs.tf
│   ├── terraform.tfvars.example         #   - Modelo de valores (o .tfvars real não é versionado)
│   └── modules/{networking,database,compute}/
├── .kiro/                               # Steering e Spec do Kiro (módulo compute)
├── screenshots/                         # Evidências (Docker, Kiro, terraform plan)
├── scripts/
│   └── health-check.sh                  # Verificação automatizada do Moodle
├── tests/                               # Testes de propriedade (pytest + Hypothesis)
│   ├── conftest.py                      #   - Fixtures compartilhadas (repo_root)
│   ├── test_architecture_template_sections.py
│   ├── test_compose_no_hardcoded_creds.py
│   ├── test_dockerfile_extensions.py
│   ├── test_docs_exist.py
│   ├── test_gitignore_patterns.py
│   ├── test_health_check.py
│   ├── test_terraform_module_structure.py
│   ├── test_todo_comments.py
│   └── test_workflow_step_comments.py
├── .gitignore                           # Padrões de segurança (secrets, estado, etc.)
├── CHALLENGE.md                         # Objetivos, entregas e critérios do desafio
├── LICENSE                              # Licença do projeto
├── pyproject.toml                       # Configuração do projeto e dependências de teste
└── README.md                            # Este arquivo (ponto de entrada)
```

> **Nota:** o diretório `terraform/` foi criado nesta solução (não faz parte do template). Veja a seção [Infraestrutura AWS com Terraform](#infraestrutura-aws-com-terraform), o desenho da solução em [`docs/architecture-design.md`](docs/architecture-design.md) e o [`CHALLENGE.md`](CHALLENGE.md).



## Ambiente Docker Local

O template entrega um stack Docker funcional para você validar o Moodle localmente antes do deploy na AWS.

```bash
# 1. Entre no diretório docker/
cd docker

# 2. Copie o arquivo de exemplo e preencha as senhas
cp .env.example .env
#    Edite .env e substitua os valores de exemplo (POSTGRES_PASSWORD, MOODLE_PASSWORD, etc.)

# 3. Suba os contêineres (Moodle + PostgreSQL)
docker compose up -d

# 4. Acesse o Moodle no navegador
#    → http://localhost:8080
```

Comandos úteis para gerenciar o ambiente:

```bash
docker compose ps              # Verifica o status dos contêineres
docker compose logs -f moodle  # Acompanha os logs do Moodle
docker compose down            # Para e remove os contêineres
docker compose down -v         # Para e remove os contêineres E os volumes (apaga os dados)
```

> **Instalação automática:** na primeira execução o `entrypoint.sh` instala o Moodle por linha de comando (gera o `config.php`), então **não há instalador web** a preencher. O login é o usuário/senha definidos em `MOODLE_USERNAME` e `MOODLE_PASSWORD` no `.env`.
>
> **Porta 8080 ocupada ou reservada (comum no Windows)?** Defina `MOODLE_HOST_PORT=8081` e `MOODLE_WWWROOT=http://localhost:8081` no `docker/.env` (os dois devem coincidir) e acesse `http://localhost:8081`.

O `docker-compose.yml` mapeia a porta `8080` do host (configurável por `MOODLE_HOST_PORT`) para a porta `80` do contêiner Moodle e garante que o Moodle só inicia após o PostgreSQL estar saudável (`depends_on: condition: service_healthy`). Os dados são persistidos em volumes nomeados (`db_data`, `moodle_data`, `moodle_www`).

### Health Check

Após subir o ambiente (local ou na AWS), valide se o Moodle está respondendo corretamente:

```bash
./scripts/health-check.sh http://localhost:8080
# Para a instância EC2 na AWS, use o DNS público:
# ./scripts/health-check.sh http://ec2-XX-XX-XX-XX.compute-1.amazonaws.com
```

O script realiza **3 verificações** em sequência, com até 3 tentativas (intervalo de 30s):

| Verificação | O que testa |
|---|---|
| (a) | HTTP 200 na URL raiz |
| (b) | HTTP 200 em `/login/index.php` |
| (c) | Presença da string `Moodle` no corpo da resposta |

**Interpretando a saída:**

- **`exit 0`** com `[✓]`: Moodle saudável — as 3 verificações passaram.
- **`exit 1`** com `[✗]` + diagnóstico: falhou após 3 tentativas. O script indica qual verificação específica falhou (`raiz`, `login` ou `conteudo`) e sugere comandos de troubleshooting (`docker compose logs`, `curl`, etc.).



## Infraestrutura AWS com Terraform

A infraestrutura está em `terraform/` e é composta por **3 módulos** em `terraform/modules/`, ligados pelo módulo raiz (`terraform/main.tf`):

| Módulo | O que provisiona |
|---|---|
| **`networking`** | VPC `10.0.0.0/16` (DNS hostnames habilitado), 2 subnets públicas e 2 privadas em `us-east-1a/1b`, Internet Gateway, route table pública, `sg-app` (80 aberto, 22 só do seu IP) e `sg-db` (5432 somente a partir do `sg-app`) |
| **`database`** | DB Subnet Group (subnets privadas, 2 AZs) e RDS PostgreSQL 15 `db.t3.micro`, 20 GB, `publicly_accessible = false` |
| **`compute`** | EC2 `t3.micro` (Amazon Linux 2023) com `LabInstanceProfile` (sem criar IAM) e `user_data.sh` via `templatefile()`: instala Docker + Compose v2, clona o repositório, grava o `.env` com os dados do RDS e sobe o Moodle |

Restrições do AWS Learner Lab respeitadas: nenhum `aws_iam_*`, `aws_route53_*`, `aws_acm_*` nem `aws_cloudfront_*`; região `us-east-1`; acesso por HTTP no DNS público da EC2. Detalhes e justificativas em [`docs/architecture-design.md`](docs/architecture-design.md).

### Como aplicar

```bash
# 1. Credenciais temporárias do Learner Lab (AWS Details → AWS CLI), incluindo o session token
aws sts get-caller-identity          # confirme que NÃO é root (esperado: assumed-role/voclabs)

# 2. Valores reais (arquivo ignorado pelo Git)
cd terraform
cp terraform.tfvars.example terraform.tfvars
#    Edite: ssh_allowed_cidr (seu IP /32), db_password (letras e números) e moodle_admin_password

# 3. Validar e planejar (nada é criado)
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan                       # esperado: Plan: 14 to add, 0 to change, 0 to destroy

# 4. Criar (RDS leva alguns minutos; o Moodle instala sozinho no boot da EC2)
terraform apply

# 5. Obter a URL pública do Moodle e validar
terraform output moodle_url          # http://ec2-X-X-X-X.compute-1.amazonaws.com
../scripts/health-check.sh "$(terraform output -raw moodle_url)"

# 6. SEMPRE destruir ao terminar (evita consumo de crédito)
terraform destroy
```

> O Moodle leva alguns minutos após o `apply` para ficar disponível (a EC2 constrói a imagem e instala o Moodle no primeiro boot). Se necessário, aumente a espera do health-check: `MAX_RETRIES=10 ./scripts/health-check.sh <URL>`. Para acompanhar o boot: `/var/log/user-data.log` na instância.

Para a sequência completa de comandos e a saída esperada, consulte o **[Guia do Terraform](docs/terraform-guide.md)**.

## CI/CD

O repositório inclui pipelines de GitHub Actions em `.github/workflows/`:

| Workflow | Gatilho | O que faz |
|---|---|---|
| [`terraform-validate.yml`](.github/workflows/terraform-validate.yml) | `push` / `pull_request` em `main` | Executa `terraform fmt -check` e `terraform validate` (falha listando arquivos com problemas de formatação) |
| [`docker-lint.yml`](.github/workflows/docker-lint.yml) | `push` / `pull_request` em `main` | Executa `hadolint` no `docker/Dockerfile` |
| [`terraform-plan.yml`](.github/workflows/terraform-plan.yml) | `pull_request` em `main` / `workflow_dispatch` | Roda `init`, `fmt -check`, `validate` e `plan` e **comenta o plan no PR**; falha se o plan falhar. Exige os secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_SESSION_TOKEN` (expiram em ~4 h no Learner Lab) |
| [`health-check.yml`](.github/workflows/health-check.yml) | `workflow_dispatch` (input `moodle_url`) | Torna `health-check.sh` executável e o roda contra a URL informada |

> Cada step dos workflows contém um comentário explicativo descrevendo o que a etapa faz.



## Documentação

Toda a documentação de apoio está em `docs/`:

| Documento | Descrição |
|---|---|
| [`docs/architecture-design.md`](docs/architecture-design.md) | **Desenho técnico da solução entregue** (diagrama, decisões, componentes, segurança, escalabilidade e custo) |
| [`docs/architecture-design-template.md`](docs/architecture-design-template.md) | Template para você preencher e entregar como `docs/architecture-design.md` (entrega obrigatória) |
| [`docs/architecture.md`](docs/architecture.md) | Arquitetura de referência da solução AWS (gabarito para professores/monitores) |
| [`docs/aws-learn-lab-setup.md`](docs/aws-learn-lab-setup.md) | Como obter credenciais temporárias do AWS Academy e as limitações do Learn Lab |
| [`docs/terraform-guide.md`](docs/terraform-guide.md) | Guia de referência dos comandos Terraform (`init`, `plan`, `apply`, `destroy`) |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Problemas comuns (porta 8080, healthcheck do DB, credenciais expiradas, etc.) e soluções |
| [`docs/evaluation-rubric.md`](docs/evaluation-rubric.md) | Rubrica de avaliação com critérios e pontuações |
| [`docs/security-practices.md`](docs/security-practices.md) | Boas práticas de segurança (secrets, least privilege, estado do Terraform) |



## Testes

Os testes validam a estrutura e configuração do repositório usando **pytest** + **[Hypothesis](https://hypothesis.readthedocs.io/)** (property-based testing, 100 iterações por propriedade). Eles inspecionam o sistema de arquivos e **não** requerem infraestrutura AWS.

```bash
# Instale as dependências (se ainda não tiver)
pip install pytest hypothesis pyyaml

# Rode todos os testes a partir da raiz do repositório
pytest tests/ -v
```

Os testes cobrem, entre outros: extensões PHP obrigatórias no Dockerfile, ausência de credenciais literais no `docker-compose.yml`, padrões do `.gitignore`, estrutura dos módulos Terraform, comentários `# TODO:` nos arquivos de configuração, comentários nos steps dos workflows, seções do template de arquitetura e o comportamento do `health-check.sh`.



## Avaliação

A avaliação do desafio segue a rubrica detalhada em [`docs/evaluation-rubric.md`](docs/evaluation-rubric.md), que pontua infraestrutura provisionada, Moodle acessível, segurança, documentação e o desenho técnico de arquitetura.

> **Critério eliminatório:** a ausência do arquivo `docs/architecture-design.md` (gerado por você a partir de [`docs/architecture-design-template.md`](docs/architecture-design-template.md)) resulta em desclassificação automática, independentemente da pontuação nas demais categorias.
