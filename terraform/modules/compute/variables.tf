# -----------------------------------------------------------------------------
# Módulo: compute
# Arquivo: variables.tf
# Descrição: Variáveis de entrada do módulo EC2 / bootstrap do Moodle.
# Tasks implementadas: 1.1 (rede), 1.2 (instância), 1.3 (RDS), 1.4 (porta).
# Tasks 1.5 e 1.6 (TODO marker + variáveis Moodle/repo) serão adicionadas
# na próxima iteração.
# -----------------------------------------------------------------------------

# TODO: (produção) adicionar validações de formato para public_subnet_id e
# sg_app_id usando regex que confirme o prefixo "subnet-" e "sg-"
# respectivamente, garantindo que valores incorretos falhem no plan e não
# somente em tempo de apply.

# =============================================================================
# Task 1.1 — Variáveis de rede
# =============================================================================

variable "public_subnet_id" {
  type        = string
  description = "ID da subnet pública onde a instância EC2 será provisionada. Deve pertencer à VPC criada pelo módulo networking."
}

variable "sg_app_id" {
  type        = string
  description = "ID do security group sg-app criado pelo módulo networking. Permite tráfego TCP 80 (HTTP) e 22 (SSH restrito)."
}

# =============================================================================
# Task 1.2 — Variáveis de instância
# =============================================================================

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Tipo da instância EC2. O AWS Academy Learner Lab suporta t3.micro sem custo adicional de cota."

  validation {
    condition     = length(var.instance_type) > 0
    error_message = "instance_type não pode ser uma string vazia."
  }
}

variable "instance_name" {
  type        = string
  default     = "moodle-ec2"
  description = "Valor da tag Name aplicada à instância EC2. Usado para identificação no console AWS."

  validation {
    condition     = length(var.instance_name) > 0
    error_message = "instance_name não pode ser uma string vazia."
  }
}

# =============================================================================
# Task 1.3 — Variáveis de conexão ao RDS
# =============================================================================

variable "db_host" {
  type        = string
  description = "Endpoint do RDS PostgreSQL gerado pelo módulo database. Exemplo: moodle-db.xxxx.us-east-1.rds.amazonaws.com."
}

variable "db_name" {
  type        = string
  description = "Nome do banco de dados PostgreSQL criado no RDS."
}

variable "db_user" {
  type        = string
  description = "Usuário master do banco de dados PostgreSQL no RDS."
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Senha do usuário master do RDS. Deve conter apenas letras (A-Z, a-z) e dígitos (0-9), com no mínimo 8 caracteres. Símbolos especiais não são aceitos pois alguns drivers JDBC e URLs de conexão do Moodle requerem encoding adicional."

  validation {
    condition     = can(regex("^[A-Za-z0-9]{8,}$", var.db_password))
    error_message = "db_password deve ter no mínimo 8 caracteres e conter apenas letras (A-Z, a-z) e dígitos (0-9), sem espaços ou símbolos especiais."
  }
}

# =============================================================================
# Task 1.4 — Porta do banco de dados
# =============================================================================

variable "db_port" {
  type        = number
  default     = 5432
  description = "Porta TCP do PostgreSQL no RDS. Deve estar entre 1 e 65535. O padrão 5432 é a porta convencional do PostgreSQL."

  validation {
    condition     = var.db_port >= 1 && var.db_port <= 65535
    error_message = "db_port deve ser um número entre 1 e 65535 (inclusive)."
  }
}

# =============================================================================
# Task 1.6 — Variáveis do Moodle e do repositório Git
# =============================================================================

variable "moodle_admin_user" {
  type        = string
  default     = "admin"
  description = "Login do administrador da interface web do Moodle. Usado na instalação inicial para criar a conta de superusuário."
}

variable "moodle_admin_password" {
  type        = string
  sensitive   = true
  description = "Senha do administrador Moodle. Mínimo 8 caracteres com ao menos uma letra maiúscula, uma minúscula, um dígito e um dos símbolos permitidos: @ ! - _ %. Símbolos como $, #, espaço, aspas e contrabarra são proibidos para evitar problemas de interpolação no .env e no JDBC."

  validation {
    # RE2 (Terraform) não suporta lookahead (?=...): uma verificação por exigência.
    condition = alltrue([
      length(var.moodle_admin_password) >= 8,
      can(regex("^[A-Za-z0-9@!_%-]+$", var.moodle_admin_password)),
      can(regex("[A-Z]", var.moodle_admin_password)),
      can(regex("[a-z]", var.moodle_admin_password)),
      can(regex("[0-9]", var.moodle_admin_password)),
      can(regex("[@!_%-]", var.moodle_admin_password)),
    ])
    error_message = "moodle_admin_password deve ter no mínimo 8 caracteres e conter ao menos uma maiúscula, uma minúscula, um dígito e um dos símbolos: @ ! - _ %."
  }
}

variable "moodle_admin_email" {
  type        = string
  description = "Endereço de e-mail do administrador Moodle. Utilizado para recuperação de senha e notificações do sistema."
}

variable "moodle_site_name" {
  type        = string
  default     = "Moodle"
  description = "Nome do site exibido na barra de título e no cabeçalho da instalação Moodle."
}

variable "repo_url" {
  type        = string
  description = "URL HTTPS do repositório Git a clonar na instância EC2 durante o bootstrap. Exemplo: https://github.com/usuario/implement_Moodle.git"
}

variable "repo_branch" {
  type        = string
  default     = "main"
  description = "Branch do repositório Git que será clonada na instância EC2. Deve existir no repositório informado em repo_url."
}
