# Notas de progresso — validação do ambiente (TF Aula 11)

Data: 2026-11-12 · Aluno: Gabriel Reis Cunha (RA 6325149)

Validação do ambiente Docker local do template, feita em uma cópia de teste
(Docker 29, WSL2). Nenhuma infraestrutura foi aplicada na AWS.

## Resultado

| Verificação | Resultado |
|---|---|
| `docker compose config` | OK |
| `docker build` (PHP 8.1.34, Moodle 4.1.22) | OK |
| `docker compose up -d` | `db` healthy, `moodle` em execução |
| `GET /` | redireciona para `/install.php` (instalador web) |

## Achados

1. **Sem `config.php`**: o Moodle sobe no instalador web. As variáveis
   `MOODLE_*` do compose seguem a convenção da imagem Bitnami e nada as consome
   neste Dockerfile (`php:8.1-apache` + tarball do Moodle).
2. **Extensão PHP `pgsql` ausente**: só há `pdo_pgsql`; `pg_connect()` não
   existe, e o driver PostgreSQL do Moodle depende dela. Também faltam `soap` e
   `exif` (recomendadas).
3. **`env_file: .env.example`** no compose: o `.env` real é ignorado pelo
   `env_file`; só a interpolação `${VAR}` o lê. Alterar senhas apenas no `.env`
   pode deixar `db` e `moodle` com senhas diferentes.
4. **`.gitignore`** não cobre `.terraform/` e `*.tfstate`, e ignora `.kiro/`
   (que precisa ser versionado para a Spec do Kiro).
5. Nomes dos volumes trocados (`moodle_data` em `/var/www/html`,
   `moodle_www` em `/var/moodledata`).
6. Porta `8080` indisponível neste ambiente Docker/WSL; com `8081` funcionou.

## Próximos passos

Corrigir os achados com o Kiro (Spec do módulo `compute`), criar os módulos
Terraform (`networking`, `compute`, `database`), implementar o
`terraform-plan.yml` e preencher `docs/architecture-design.md`.
