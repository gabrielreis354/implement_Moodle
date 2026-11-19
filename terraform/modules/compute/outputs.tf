# -----------------------------------------------------------------------------
# Módulo: compute
# Arquivo: outputs.tf
# Descrição: Expõe o IP público e o DNS público da instância EC2 do Moodle
#            para consumo pelo módulo raiz (root module) e por outros módulos.
# Tasks implementadas: 4.1 (public_ip), 4.2 (public_dns), 4.3 (TODO marker).
# -----------------------------------------------------------------------------

# TODO: (produção) publicar public_ip e public_dns no AWS SSM Parameter Store
# (aws_ssm_parameter) com tier "Standard" e type "String", permitindo que
# pipelines de CI/CD e outros serviços consultem o endpoint sem precisar de
# outputs Terraform diretos — reduz acoplamento entre stacks.

# =============================================================================
# Task 4.1 — Output: endereço IP público alocado na instância EC2
# =============================================================================
# Retorna o IPv4 público atribuído automaticamente pela AWS na subnet pública.
# Usado para acesso direto via HTTP (porta 80) enquanto não há load balancer.

output "public_ip" {
  description = "Endereço IPv4 público da instância EC2 do Moodle, atribuído automaticamente pela AWS na subnet pública."
  value       = aws_instance.moodle.public_ip
}

# =============================================================================
# Task 4.2 — Output: DNS público resolvível da instância EC2
# =============================================================================
# O FQDN público (ex: ec2-X-X-X-X.compute-1.amazonaws.com) é necessário para
# compor MOODLE_WWWROOT no user_data.sh via IMDSv2 e para verificação de saúde.

output "public_dns" {
  description = "Nome DNS público (FQDN) da instância EC2 do Moodle, utilizado para compor a URL do Moodle e verificações de saúde."
  value       = aws_instance.moodle.public_dns
}
