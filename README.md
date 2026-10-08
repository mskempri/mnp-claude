# Mobile Number Portability (MNP) Platform

.NET communication layer + Oracle PL/SQL business logic for mobile number
porting requests.

## Architecture

Business rules (validation, state transitions) live in PL/SQL packages in the
database. .NET exists to move data across process/network boundaries: HTTP in
from clients, SQL to/from Oracle, HTTP out to external carrier-network APIs.
Keep new logic in the database unless it's genuinely about shaping or routing
data (DTO mapping, HTTP concerns, retries).

```
Client -> Mnp.Api (controllers)
             -> Mnp.Application (orchestration: PortingRequestService)
                  -> Mnp.Infrastructure.Database  -> Oracle (PKG_PORTING_REQUESTS)
                  -> Mnp.Infrastructure.ExternalApis -> external carrier-network APIs
```

| Project | Responsibility |
|---|---|
| `src/Mnp.Api` | ASP.NET Core Web API — controllers, DI composition root, config |
| `src/Mnp.Application` | Orchestration services and the abstractions (`IPortingRequestRepository`, `ICarrierNetworkClient`) they depend on |
| `src/Mnp.Domain` | Plain entities/enums shared across layers — no framework dependencies |
| `src/Mnp.Infrastructure.Database` | Calls Oracle PL/SQL packages via ODP.NET (`Oracle.ManagedDataAccess.Core`) |
| `src/Mnp.Infrastructure.ExternalApis` | Outbound HTTP clients to external carrier/registry APIs, with resilience (retry/timeout/circuit breaker) |
| `database/` | Table DDL and PL/SQL packages — see [database/README.md](database/README.md) |

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
`localhost:1521/FREEPDB1`. Apply the schema/package scripts once it's up:

```bash
source .env
podman exec -i mnp-oracle sqlplus -s mnp_app/"$APP_USER_PASSWORD"@localhost:1521/FREEPDB1 \
  < database/schema/001_create_porting_requests_table.sql
podman exec -i mnp-oracle sqlplus -s mnp_app/"$APP_USER_PASSWORD"@localhost:1521/FREEPDB1 \
  < database/packages/pkg_porting_requests.pks
podman exec -i mnp-oracle sqlplus -s mnp_app/"$APP_USER_PASSWORD"@localhost:1521/FREEPDB1 \
  < database/packages/pkg_porting_requests.pkb
```

See [database/README.md](database/README.md) for script conventions.

## Setup

1. Install the SDK (already done on this machine via `brew install dotnet`; add
   `/opt/homebrew/opt/dotnet/libexec` to `DOTNET_ROOT` and your `PATH` if not
   using the cask install).
2. Configure secrets instead of editing `appsettings.json` (keeps real
   connection strings out of source control):
   ```bash
   cd src/Mnp.Api
   dotnet user-secrets init
   dotnet user-secrets set "ConnectionStrings:Oracle" "User Id=mnp_app;Password=<APP_USER_PASSWORD from .env>;Data Source=localhost:1521/FREEPDB1;"
   dotnet user-secrets set "CarrierNetwork:BaseUrl" "https://sandbox.carrier-network.example/"
   ```
3. Build and run:
   ```bash
   dotnet build
   dotnet run --project src/Mnp.Api
   ```

## Testing

```bash
dotnet test
```

`tests/Mnp.Application.Tests` and `tests/Mnp.Infrastructure.Database.Tests` are
scaffolded (xUnit) but currently empty — add tests as behavior is implemented.

## Status

Scaffolding only: solution structure, DI wiring, one end-to-end vertical slice
(submit/get a porting request) wired from controller through to a PL/SQL
package, as a template for the real endpoints to follow. The read path
(`GET /api/porting-requests/{id}`, `GET /api/porting-requests?msisdn=`) and the
package's state-transition logic have been verified against a real local
Oracle instance. The submit path's external carrier-network call is wired but
untested against a real/sandbox API (`CarrierNetworkOptions.BaseUrl` is still a
placeholder).
