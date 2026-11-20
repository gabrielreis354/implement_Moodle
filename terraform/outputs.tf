# Saídas exibidas após o terraform apply (terraform output).
#
# TODO: (produção) Expor a URL pública do ALB/CloudFront com HTTPS em vez do DNS
#       direto da instância EC2.

output "moodle_url" {
  description = "URL pública do Moodle (HTTP, porta 80). A instalação leva alguns minutos após o apply."
  value       = "http://${module.compute.public_dns}"
}

output "ec2_public_dns" {
  description = "DNS público da instância EC2 (use no scripts/health-check.sh)."
  value       = module.compute.public_dns
}

output "ec2_public_ip" {
  description = "IPv4 público da instância EC2."
  value       = module.compute.public_ip
}

output "rds_endpoint" {
  description = "Endpoint do RDS no formato host:porta (acessível somente de dentro da VPC)."
  value       = "${module.database.db_host}:${module.database.db_port}"
}

output "vpc_id" {
  description = "ID da VPC criada."
  value       = module.networking.vpc_id
}
