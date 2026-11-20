# Steering — Prova P2 (Moodle Docker AWS Challenge)

Contexto: fork de `AleTavares/implement_Moodle`. Ambiente AWS Academy Learner Lab, região `us-east-1`, credenciais temporárias (inclui `aws_session_token`).

## Regras inegociáveis
- NUNCA criar `aws_iam_*`; EC2 usa `iam_instance_profile = "LabInstanceProfile"`.
- NUNCA usar Route 53, ACM, CloudFront. Só HTTP:80.
- Sem segredos no repositório: `.env`, `*.tfvars`, `*.tfstate`, `*.pem` fora do Git. Variáveis sensíveis com `sensitive = true`.
- Commits semânticos (`feat:`, `fix:`, `docs:`, `chore:`). Nunca commitar na `main`; branch `feature/terraform-aws`.

## Terraform (estrutura obrigatória)
`terraform/{versions.tf,main.tf,variables.tf,outputs.tf}` e `terraform/modules/{networking,compute,database}/{main.tf,variables.tf,outputs.tf}`. Provider AWS `~> 5.0`.
- networking: VPC (CIDR documentado), ≥2 subnets públicas e ≥2 privadas em AZs distintas, IGW, route table pública, `sg-app` (80 aberto; 22 só `var.ssh_allowed_cidr`; egress livre) e `sg-db` (5432 somente a partir do `sg-app`).
- database: RDS PostgreSQL 15 `db.t3.micro`, subnet group nas privadas (≥2 AZs), `publicly_accessible = false`, credenciais por variável; outputs host/porta/nome/usuário/senha.
- compute: EC2 `t3.micro` (AL2023 via data source de AMI), subnet pública, `LabInstanceProfile`, `user_data.sh` via `templatefile()` (instala Docker + Compose v2, grava `.env` com o endpoint do RDS, `docker compose up -d`); outputs `public_ip`, `public_dns`.
- Validações: `terraform fmt -check -recursive`, `terraform validate`, `terraform plan`.

## Qualidade
SOLID/DRY/KISS/YAGNI; módulos pequenos e coesos; comentários explicam o porquê. Cada arquivo implementado mantém ao menos um `# TODO: (produção) …` real (exigência do teste do template).

## Entrega
Evidências no fork; ao repo da disciplina vai só `entregas/provaSegundoBi/6325149/entrega.md` com links.
