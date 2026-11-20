# Módulo database — RDS PostgreSQL 15 para o Moodle
# Recursos: aws_db_subnet_group + aws_db_instance
# NÃO cria recursos aws_iam_* (perfil IAM é gerenciado pelo LabInstanceProfile da conta Academy)
# TODO: (produção) Habilitar multi_az = true e backup_retention_period >= 7 para alta disponibilidade

# ------------------------------------------------------------------
# Subnet group: RDS exige ao menos 2 subnets em AZs diferentes
# As subnets privadas são fornecidas pelo módulo networking
# ------------------------------------------------------------------
# ATENCAO: a descricao do DB Subnet Group aceita apenas caracteres ASCII (sem acentos nem simbolos como >=).
resource "aws_db_subnet_group" "this" {
  name        = "${var.identifier}-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "Subnet group privado para a instancia RDS do Moodle (2 AZs)"

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

# ------------------------------------------------------------------
# Instância RDS PostgreSQL 15
# publicly_accessible = false: acesso apenas via sg-app dentro da VPC
# skip_final_snapshot  = true: simplifica teardown no ambiente de lab
# TODO: (produção) Definir skip_final_snapshot = false e final_snapshot_identifier
# ------------------------------------------------------------------
resource "aws_db_instance" "this" {
  identifier        = var.identifier
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_user
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.sg_db_id]

  publicly_accessible     = false
  multi_az                = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0

  tags = merge(var.tags, {
    Name = var.identifier
  })
}
