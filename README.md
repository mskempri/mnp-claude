# Mobile Number Portability (MNP) Platform

.NET communication layer + Oracle PL/SQL business logic for mobile number
porting requests.


## Prerequisites

- .NET 10 SDK
- Access to an Oracle database. For local dev, `docker-compose.yml` at the repo
  root runs [gvenzl/oracle-free](https://github.com/gvenzl/oci-oracle-free) (a
  community image built specifically for this kind of dev/test use — no Oracle
  registry login needed, native arm64 + amd64 images) under Podman or Docker.

## Local Oracle (dev)

```bash
cp .env.example .env   # fill in ORACLE_PASSWORD / APP_USER_PASSWORD, or generate your own
podman machine start   # if using Podman and the VM isn't already running
podman compose up -d   # or: docker compose up -d
podman logs -f mnp-oracle   # watch for "DATABASE IS READY TO USE!" (first run takes a few minutes)
```

This creates an `mnp_app` user in the `FREEPDB1` pluggable database, reachable at
`localhost:1521/FREEPDB1`. Set up the schema by running the full database
export — tables, reference/config seed data (workflow rules, timers, holidays,
notification routing, fraud/outbox config), indexes, and PL/SQL packages, all
in the correct order in one file:

```bash
source .env
podman exec -i mnp-oracle sqlplus -s mnp_app/"$APP_USER_PASSWORD"@localhost:1521/FREEPDB1 \
  < database_export_with_seed_data.sql
```

## Setup

1. Install the SDK (already done on this machine via `brew install dotnet`; add
   `/opt/homebrew/opt/dotnet/libexec` to `DOTNET_ROOT` and your `PATH` if not
   using the cask install).
2. Configure the Oracle connection string via user-secrets instead of editing
   `appsettings.json` (keeps real connection strings out of source control):
   ```bash
   cd src/Mnp.Api
   dotnet user-secrets init
   dotnet user-secrets set "ConnectionStrings:Oracle" "User Id=mnp_app;Password=<APP_USER_PASSWORD from .env>;Data Source=localhost:1521/FREEPDB1;"
   cd ../..
   ```
   `CarrierNetwork:BaseUrl` doesn't need a secret for local dev — it already
   points at `Mnp.MockExternalApis` via `appsettings.Development.json`.
3. Build, then run the mock external API, the outbox relay worker, and the API.
   `scripts/run-local.sh` starts all three and redirects each one's logs to
   its own file under `logs/`, so you don't have to manage backgrounding or
   redirection by hand:
   ```bash
   scripts/run-local.sh
   # in another terminal:
   tail -f logs/*.log
   ```

## Testing

```bash
dotnet test
```

`tests/Mnp.Application.Tests` and `tests/Mnp.Infrastructure.Database.Tests` are
scaffolded (xUnit) but currently empty — add tests as behavior is implemented.
