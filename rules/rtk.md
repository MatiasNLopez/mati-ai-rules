## RTK — Token-Optimized CLI (MANDATORY)

`rtk` is installed globally. It proxies CLI commands and compresses output (60-90% token savings). **Always use `rtk` prefix** for these commands instead of running them directly:

| Instead of | Use |
|---|---|
| `git status`, `git diff`, `git log` | `rtk git status`, `rtk git diff`, `rtk git log` |
| `git add`, `git commit`, `git push` | `rtk git add`, `rtk git commit`, `rtk git push` |
| `git branch`, `git stash` | `rtk git branch`, `rtk git stash` |
| `ls`, `tree` | `rtk ls`, `rtk tree` |
| `cat <file>` | `rtk read <file>` |
| `grep -r <pattern>` | `rtk grep -r <pattern>` |
| `find . -name <pattern>` | `rtk find . -name <pattern>` |
| `diff <a> <b>` | `rtk diff <a> <b>` |
| `pnpm lint` / `npm run lint` | `rtk lint` |
| `pnpm install` | `rtk pnpm install` |
| `npm run build` / `npm run test` | `rtk npm run build`, `rtk npm run test` |
| `tsc --noEmit` / `npx tsc --noEmit` | `rtk tsc --noEmit` |
| `pytest` / `python -m pytest` | `rtk pytest` |
| `pip install` | `rtk pip install` |
| `ruff check` / `ruff format --check` | `rtk ruff check`, `rtk ruff format --check` |
| `mypy` | `rtk mypy` |
| `gh pr list`, `gh pr view`, `gh issue list` | `rtk gh pr list`, `rtk gh pr view`, `rtk gh issue list` |
| `docker ps`, `docker compose ps/logs` | `rtk docker ps`, `rtk docker compose ps` |
| `kubectl get pods/svc` | `rtk kubectl get pods`, `rtk kubectl get svc` |
| `cargo test/build/clippy` | `rtk cargo test`, `rtk cargo build`, `rtk cargo clippy` |
| `go test/build/vet` | `rtk go test ./...`, `rtk go build ./...` |
| `vitest` / `npx vitest` | `rtk vitest` |
| `prisma generate/migrate` | `rtk prisma generate`, `rtk prisma migrate dev` |
| `next build` | `rtk next` |
| `prettier --check` | `rtk prettier --check .` |
| `playwright test` | `rtk playwright test` |
| `golangci-lint run` | `rtk golangci-lint run` |
| `curl <url>` | `rtk curl <url>` |
| `aws <subcommand>` | `rtk aws <subcommand>` |
| `psql` | `rtk psql` |
| `wget <url>` | `rtk wget <url>` |

Do NOT prefix: `pnpm dev`, `pnpm build`, `pnpm test`, `pnpm add`, `npm install`, `cargo run`, `docker compose up`, `python manage.py runserver`, `python manage.py migrate`, `python manage.py makemigrations` — these have no RTK proxy.

Use `rtk err <command>` to run any command and show only errors/warnings.
Use `rtk test <command>` to run tests and show only failures.
Use `rtk summary <command>` for a 2-line heuristic summary of any output.
