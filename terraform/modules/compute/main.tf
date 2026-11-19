# -----------------------------------------------------------------------------
# Módulo: compute
# Arquivo: main.tf
# Descrição: Data source AMI do Amazon Linux 2023, locals com mapa de vars
#            para user_data.sh, e recurso aws_instance do Moodle.
# Tasks implementadas: 2.1 (data source AMI), 2.2 (locals user_data_vars),
#                      2.3 (resource aws_instance), 2.4 (TODO marker).
# -----------------------------------------------------------------------------

# TODO: (produção) adicionar volume EBS separado para /var/moodledata com
# encrypt = true e kms_key_id apontando para uma CMK gerenciada pelo cliente,
# garantindo criptografia em repouso para os dados do Moodle.

# =============================================================================
# Task 2.1 — Data source: AMI mais recente do Amazon Linux 2023 (x86_64/HVM)
# =============================================================================
# O padrão "al2023-ami-2023.*-x86_64" exclui a variante minimal
# (al2023-ami-minimal-*) e qualquer imagem de terceiros.
# Nenhum ID ami-* é hardcoded; o Terraform resolve o valor no plan.

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# Task 2.2 — Locals: mapa de variáveis injetadas no user_data.sh via
#            templatefile(). Todos os 11 campos referenciados em variables.tf.
# =============================================================================

locals {
  user_data_vars = {
    db_host               = var.db_host
    db_port               = var.db_port
    db_name               = var.db_name
    db_user               = var.db_user
    db_password           = var.db_password
    moodle_admin_user     = var.moodle_admin_user
    moodle_admin_password = var.moodle_admin_password
    moodle_admin_email    = var.moodle_admin_email
    moodle_site_name      = var.moodle_site_name
    repo_url              = var.repo_url
    repo_branch           = var.repo_branch
  }
}

# =============================================================================
# Task 2.3 — Recurso: instância EC2 com Amazon Linux 2023 e bootstrap Moodle
# =============================================================================
# iam_instance_profile é string literal hardcoded — nunca uma variável ou
# referência a recurso aws_iam_*, conforme restrição do AWS Academy Learner Lab.
# user_data_replace_on_change = true garante que alterações no script de
# bootstrap disparem substituição da instância no próximo apply.

resource "aws_instance" "moodle" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.sg_app_id]
  iam_instance_profile   = "LabInstanceProfile"

  user_data                   = templatefile("${path.module}/user_data.sh", local.user_data_vars)
  user_data_replace_on_change = true

  tags = {
    Name = var.instance_name
  }

  # TODO: (produção) adicionar volume EBS separado para /var/moodledata com
  # encrypt = true e kms_key_id apontando para uma CMK gerenciada pelo cliente,
  # garantindo criptografia em repouso para os dados do Moodle.
}
