# Modulo networking — VPC, subnets, IGW, route tables e security groups
# Regiao alvo: us-east-1 (AZs us-east-1a e us-east-1b)
# NÃO cria recursos aws_iam_* (restricao do ambiente AWS Academy)
# TODO: (producao) Adicionar NAT Gateway nas subnets publicas para permitir
#       que instancias privadas (RDS, futuros workers) alcancem a internet
#       de forma controlada.

# ------------------------------------------------------------------
# Data source: confirma AZs disponiveis na regiao (us-east-1a / us-east-1b)
# Usado para vincular subnets a AZs de forma declarativa
# ------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# ------------------------------------------------------------------
# VPC principal
# enable_dns_hostnames = true: necessario para que a EC2 receba
#   public DNS hostname (usado pelo Moodle como URL base)
# ------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc"
  })
}

# ------------------------------------------------------------------
# Subnets publicas (us-east-1a e us-east-1b)
# map_public_ip_on_launch = true: EC2 lancadas aqui recebem IP publico
# ------------------------------------------------------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1) # 10.0.1.0/24
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-a"
  })
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2) # 10.0.2.0/24
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-b"
  })
}

# ------------------------------------------------------------------
# Subnets privadas (us-east-1a e us-east-1b)
# Usadas pelo RDS (subnet group exige >= 2 AZs)
# ------------------------------------------------------------------
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10) # 10.0.10.0/24
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-a"
  })
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 11) # 10.0.11.0/24
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-b"
  })
}

# ------------------------------------------------------------------
# Internet Gateway — permite acesso externo as subnets publicas
# ------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-igw"
  })
}

# ------------------------------------------------------------------
# Route table publica: rota default 0.0.0.0/0 -> IGW
# Associada as duas subnets publicas
# ------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-rt-public"
  })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------
# Security Group: sg-app
# ingress 80  — aberto a internet (acesso HTTP ao Moodle)
# ingress 22  — restrito ao CIDR do operador (var.ssh_allowed_cidr)
# egress livre — necessario para pull de imagens Docker e atualizacoes
# TODO: (producao) Remover ingress 22 e substituir por AWS Systems Manager
#       Session Manager para acesso sem abrir portas SSH.
# ------------------------------------------------------------------
resource "aws_security_group" "sg_app" {
  name        = "${var.project_name}-sg-app"
  description = "SG da camada de aplicacao: HTTP publico, SSH restrito"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH restrito ao operador"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "Egress livre"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-sg-app"
  })
}

# ------------------------------------------------------------------
# Security Group: sg-db
# ingress 5432 — somente a partir do sg-app (sem CIDR aberto)
# egress livre — necessario para atualizacoes internas da instancia RDS
# TODO: (producao) Avaliar remover egress livre do sg-db; RDS gerenciado
#       pela AWS normalmente nao precisa de saida irrestrita.
# ------------------------------------------------------------------
resource "aws_security_group" "sg_db" {
  name        = "${var.project_name}-sg-db"
  description = "SG do banco de dados: PostgreSQL acessivel somente pelo sg-app"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "PostgreSQL somente a partir do sg-app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_app.id]
  }

  egress {
    description = "Egress livre"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-sg-db"
  })
}