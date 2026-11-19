# Variáveis do módulo database
# TODO: (produção) Usar AWS Secrets Manager para db_password em vez de variável Terraform

variable "private_subnet_ids" {
  description = "IDs das subnets privadas para o subnet group do RDS (mínimo 2, em AZs distintas)"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "São necessárias ao menos 2 subnets privadas em AZs distintas para o subnet group do RDS."
  }
}

variable "sg_db_id" {
  description = "ID do security group sg-db que permite acesso ao RDS apenas a partir do sg-app"
  type        = string
}

variable "db_name" {
  description = "Nome do banco de dados criado na instância RDS"
  type        = string
  default     = "moodle"
}

variable "db_user" {
  description = "Usuário master do RDS (não usar 'admin', reservado pelo RDS)"
  type        = string
  default     = "moodleadmin"
}

variable "db_password" {
  description = "Senha do usuário master do RDS. Apenas letras e números, mínimo 8 caracteres."
  type        = string
  sensitive   = true

  validation {
    condition = alltrue([
      length(var.db_password) >= 8,
      can(regex("^[A-Za-z0-9]+$", var.db_password))
    ])
    error_message = "A senha deve conter apenas letras e números (sem símbolos especiais) e ter no mínimo 8 caracteres."
  }
}

variable "identifier" {
  description = "Identificador único da instância RDS (usado no nome AWS)"
  type        = string
  default     = "moodle-db"
}

variable "tags" {
  description = "Tags adicionais aplicadas a todos os recursos do módulo"
  type        = map(string)
  default     = {}
}
