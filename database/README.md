# Database

This is where the actual MNP business logic lives — table definitions, packages,
and the migration scripts that create them. The .NET solution in `src/` is a thin
communication layer: it opens connections, calls package procedures/functions,
and maps rows to .NET types. It does not re-implement validation or state-machine
rules that belong here.

## Layout

- `schema/` — DDL for tables, indexes, constraints, sequences. Numbered and applied
  in order (`001_`, `002_`, ...). Never edit an already-applied script in place —
  add a new numbered script for changes.
- `packages/` — PL/SQL package specs (`.pks`) and bodies (`.pkb`). One package per
  aggregate/workflow (e.g. `pkg_porting_requests`). Package bodies hold the
  validation and state-transition logic; the spec is the only thing .NET code
  needs to know about.

## Conventions

- Tables: `mnp_<plural_noun>`, snake_case columns.
- Packages: `pkg_<aggregate>`. Public functions/procedures: `fn_`/`pr_` prefix.
- Status/enum-like columns are `VARCHAR2` with a `CHECK` constraint, not lookup
  tables — keeps the valid set visible in one place. The .NET side maps these to
  an enum (see `PortingStatusMapping` in `Mnp.Infrastructure.Database`).
- Errors raised as a dedicated exception number (`RAISE_APPLICATION_ERROR(-200xx, ...)`)
  caught by the data-access layer so callers get a meaningful exception rather than
  a raw `ORA-` error.
- Reads that return more than one column go through a `SYS_REFCURSOR` OUT parameter
  so .NET can map a result set without needing an object type.

## Applying scripts

No migration tool is wired up yet (Flyway/Liquibase are natural fits once there's a
shared dev/test database). For now, apply in order with SQL*Plus or SQLcl, always
`schema/` before `packages/`:

```bash
sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 @schema/001_create_porting_requests_table.sql
sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 @packages/pkg_porting_requests.pks
sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 @packages/pkg_porting_requests.pkb
```

For local dev against the Podman/Docker Oracle container, see the root
[README's Local Oracle section](../README.md#local-oracle-dev) — it runs
`sqlplus` inside the container instead, since no local Oracle client is assumed.
