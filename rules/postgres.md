## PostgreSQL — Dynamic Credential Resolution

The Postgres MCP server starts with a default local connection (`postgres@localhost:5432/postgres`).

When the user asks for a SQL/postgres operation on a **specific project or directory**, resolve credentials on-the-fly using:

```bash
source <(PROJECT_DIR=/path/to/project bash /home/matiaslopez/.config/opencode/scripts/postgres-mcp-wrapper.sh --print-env 2>/dev/null)
psql "$DATABASE_URI" -c "SELECT ..."
```

The wrapper searches for config files in this priority:
1. `.env` — `DATABASE_URI` / `DATABASE_URL` / `BBDD_*` keys
2. `gradle.properties` — `bbdd.sid`, `bbdd.user`, `bbdd.password`
3. `config/Openbravo.properties` — `bbdd.url`, `bbdd.sid`, `bbdd.user`, `bbdd.password`
4. `Openbravo.properties` — same as above
