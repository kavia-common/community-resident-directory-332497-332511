# Resident Directory Database: Migrations & Seed (Local Dev)

This container uses `startup.sh` + `db_connection.txt` as the canonical startup/connection mechanism.

## Quickstart (recommended)

From `resident_directory_database/`:

```bash
./scripts/dev_setup.sh
```

This will:
1) start PostgreSQL if needed (`startup.sh`)
2) apply migrations (`scripts/migrate.sh`)
3) seed dev data (`scripts/seed.sh`)

## Migrations

- Migrations live in `migrations/*.sql` and are applied in lexical order.
- Applied migrations are tracked in `schema_migrations`.

Commands:

```bash
./scripts/migrate.sh
```

Inspect migration status:

```sql
SELECT * FROM schema_migrations ORDER BY applied_at;
```

## Seed data

Dev seed is defined in `seed/seed_dev.sql`.

```bash
./scripts/seed.sh
```

Reset and reseed (DANGEROUS; truncates tables):

```bash
./scripts/seed.sh --reset
```

## Optional: run migrations/seed automatically on startup

By default, `startup.sh` only starts PostgreSQL and writes `db_connection.txt`.

You can opt-in to automatic bootstrapping:

```bash
export RUN_MIGRATIONS_ON_STARTUP=true
export RUN_SEED_ON_STARTUP=true
./startup.sh
```

## Notes

- All scripts read the connection command from `db_connection.txt`.
- If you need to connect manually:

```bash
cat db_connection.txt
```

Relevant Source Paths:
- `startup.sh`
- `db_connection.txt`
- `scripts/migrate.sh`
- `scripts/seed.sh`
- `scripts/dev_setup.sh`
- `migrations/001_init.sql`
- `seed/seed_dev.sql`
