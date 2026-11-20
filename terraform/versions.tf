# Versões exigidas: Terraform CLI e provider AWS.
# O provider fica em ~> 5.0 (qualquer 5.x) para reproduzir o ambiente do desafio.
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
