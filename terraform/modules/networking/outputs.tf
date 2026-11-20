# Outputs do modulo networking
# Consumidos pelo modulo raiz para passar IDs aos modulos compute e database
# TODO: (producao) Expor tambem os IDs das route tables privadas para que
#       um futuro modulo de NAT Gateway possa associar rotas corretamente.

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Lista de IDs das subnets publicas (us-east-1a e us-east-1b)"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  description = "Lista de IDs das subnets privadas (us-east-1a e us-east-1b) — usadas pelo RDS"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "sg_app_id" {
  description = "ID do security group sg-app (HTTP 80 + SSH restrito)"
  value       = aws_security_group.sg_app.id
}

output "sg_db_id" {
  description = "ID do security group sg-db (PostgreSQL 5432 somente a partir do sg-app)"
  value       = aws_security_group.sg_db.id
}