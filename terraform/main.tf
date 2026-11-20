# Módulo raiz: liga os três módulos (networking -> database -> compute).
# Cada módulo só enxerga suas variáveis de entrada; é aqui que as SAÍDAS de um
# módulo são conectadas às ENTRADAS do outro.
#
# TODO: (produção) Usar backend remoto (S3 com bloqueio de estado) e ambientes
#       separados (dev/stage/prod) em vez de um único estado local.

provider "aws" {
  region = var.aws_region

  # Tags aplicadas automaticamente a todos os recursos criados por este provider.
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Course    = "devops-2026-2"
    }
  }
}

# ---------------------------------------------------------------------------
# 1) Rede: VPC, subnets públicas/privadas, IGW, route table e security groups
# ---------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  project_name     = var.project_name
  vpc_cidr         = var.vpc_cidr
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

# ---------------------------------------------------------------------------
# 2) Banco: RDS PostgreSQL nas subnets privadas, protegido pelo sg-db
# ---------------------------------------------------------------------------
module "database" {
  source = "./modules/database"

  private_subnet_ids = module.networking.private_subnet_ids
  sg_db_id           = module.networking.sg_db_id

  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
}

# ---------------------------------------------------------------------------
# 3) Aplicação: EC2 que instala Docker e sobe o Moodle apontando para o RDS.
#    Depende implicitamente do módulo database (usa db_host), então o Terraform
#    só cria a EC2 depois que o RDS estiver disponível.
# ---------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  public_subnet_id = module.networking.public_subnet_ids[0]
  sg_app_id        = module.networking.sg_app_id

  db_host     = module.database.db_host
  db_port     = module.database.db_port
  db_name     = module.database.db_name
  db_user     = module.database.db_user
  db_password = module.database.db_password

  moodle_admin_user     = var.moodle_admin_user
  moodle_admin_password = var.moodle_admin_password
  moodle_admin_email    = var.moodle_admin_email
  moodle_site_name      = var.moodle_site_name

  repo_url    = var.repo_url
  repo_branch = var.repo_branch
}
