# Outputs do módulo database
# db_host expõe apenas o hostname (address), NÃO o endpoint (host:porta)
# TODO: (produção) Considerar expor o ARN da instância para integração com Secrets Manager

output "db_host" {
  description = "Hostname do RDS (sem porta) — use este valor para DB_HOST no Moodle"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Porta TCP do PostgreSQL (padrão 5432)"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Nome do banco de dados criado na instância RDS"
  value       = aws_db_instance.this.db_name
}

output "db_user" {
  description = "Usuário master da instância RDS"
  value       = aws_db_instance.this.username
}

output "db_password" {
  description = "Senha do usuário master (sensitive)"
  value       = aws_db_instance.this.password
  sensitive   = true
}
