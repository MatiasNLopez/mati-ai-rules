## RTK — Token-Optimized CLI (MANDATORY)

`rtk` is a global CLI proxy that compresses output (60-90% token savings). Prefix ALL diagnostic/read-only commands with `rtk`:
git, ls, tree, cat (`rtk read`), grep, find, diff, curl, wget, psql, aws,
npm run (build/test/lint), pnpm (install/lint), tsc, vitest, prisma, next, prettier, playwright,
pytest, pip, ruff, mypy, gh, docker (ps/compose ps/logs), kubectl,
cargo (test/build/clippy), go (test/build/vet), golangci-lint

**DO NOT prefix** (no RTK proxy): pnpm dev/build/test/add, npm install, cargo run, docker compose up, python manage.py *

If an `rtk` command fails, retry without the `rtk` prefix.

Helpers: `rtk err <cmd>` errors only | `rtk test <cmd>` failures only | `rtk summary <cmd>` 2-line summary
