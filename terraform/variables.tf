# Variáveis do módulo raiz. Valores reais ficam em terraform.tfvars (ignorado
# pelo Git); o arquivo terraform.tfvars.example mostra o formato.
#
# TODO: (produção) Receber segredos de um gerenciador (AWS Secrets Manager ou
#       variáveis de ambiente TF_VAR_*) em vez de arquivo .tfvars local.

variable "aws_region" {
  description = "Região AWS. O AWS Academy Learner Lab só permite us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo usado nos nomes e tags dos recursos."
  type        = string
  default     = "moodle"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC (as subnets são derivadas dele com cidrsubnet)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "ssh_allowed_cidr" {
  description = "Seu IP público em formato CIDR (x.x.x.x/32) autorizado a usar a porta 22. Obrigatório; 0.0.0.0/0 é rejeitado pelo módulo networking."
  type        = string
}

# ---- Banco de dados (RDS) --------------------------------------------------

variable "db_name" {
  description = "Nome do banco criado no RDS."
  type        = string
  default     = "moodle"
}

variable "db_user" {
  description = "Usuário master do RDS (não usar 'admin', reservado pelo RDS)."
  type        = string
  default     = "moodleadmin"
}

variable "db_password" {
  description = "Senha do usuário master do RDS: somente letras e números, mínimo 8 caracteres (validada no módulo database)."
  type        = string
  sensitive   = true
}

# ---- Moodle ----------------------------------------------------------------

variable "moodle_admin_user" {
  description = "Usuário administrador criado na instalação automática do Moodle."
  type        = string
  default     = "admin"
}

variable "moodle_admin_password" {
  description = "Senha do administrador do Moodle: mínimo 8 com maiúscula, minúscula, número e um símbolo entre @ ! - _ % (validada no módulo compute)."
  type        = string
  sensitive   = true
}

variable "moodle_admin_email" {
  description = "E-mail do administrador do Moodle."
  type        = string
  default     = "admin@example.com"
}

variable "moodle_site_name" {
  description = "Nome exibido no site Moodle."
  type        = string
  default     = "Moodle Challenge"
}

# ---- Código que a EC2 clona no primeiro boot --------------------------------

variable "repo_url" {
  description = "URL pública do repositório que a EC2 clona (contém docker/Dockerfile, entrypoint.sh e docker-compose.aws.yml)."
  type        = string
  default     = "https://github.com/gabrielreis354/implement_Moodle.git"
}

variable "repo_branch" {
  description = "Branch clonada pela EC2. Trocar para main depois do merge da solução."
  type        = string
  default     = "feature/terraform-aws"
}
