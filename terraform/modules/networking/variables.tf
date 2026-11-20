# Variaveis do modulo networking
# TODO: (producao) Parametrizar os CIDRs de cada subnet individualmente para permitir
#       roteamento mais granular entre camadas (app, db, mgmt).

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorizado a acessar a porta 22 do sg-app. Nao pode ser 0.0.0.0/0."
  type        = string

  validation {
    # cidrhost() falha se o valor nao for um CIDR valido; can() transforma a falha em false
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0)) && var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "ssh_allowed_cidr deve ser um CIDR valido (x.x.x.x/32) e nao pode ser 0.0.0.0/0. Use o IP publico da sua maquina."
  }
}

variable "project_name" {
  description = "Prefixo usado nas tags Name de todos os recursos"
  type        = string
  default     = "moodle"
}

variable "tags" {
  description = "Tags adicionais aplicadas a todos os recursos do modulo"
  type        = map(string)
  default     = {}
}