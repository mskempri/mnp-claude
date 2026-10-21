#!/usr/bin/env bash
# Runs the full local stack (Mnp.MockExternalApis, Mnp.Worker, Mnp.Api) with
# each process's stdout/stderr redirected to its own file under logs/,
# instead of needing to background/redirect them by hand each time.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

mkdir -p logs

if command -v podman >/dev/null 2>&1; then
  ENGINE=podman
elif command -v docker >/dev/null 2>&1; then
  ENGINE=docker
else
  echo "Neither podman nor docker found on PATH -- cannot start the local Oracle DB." >&2
  echo "Install one (see README.md), or start Oracle manually, then re-run this script." >&2
  exit 1
fi

if [ "$ENGINE" = podman ] && ! podman info >/dev/null 2>&1; then
  echo "Starting podman machine..."
  podman machine start
fi

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

echo "Starting local Oracle DB (mnp-oracle)..."
$ENGINE compose up -d

echo "Waiting for Oracle to be ready..."
for i in $(seq 1 90); do
  if $ENGINE exec mnp-oracle /opt/oracle/healthcheck.sh >/dev/null 2>&1; then
    echo "Oracle is ready."
    break
  fi
  if [ "$i" -eq 90 ]; then
    echo "Oracle didn't become ready in time -- check '$ENGINE logs mnp-oracle'." >&2
    exit 1
  fi
  sleep 2
done

dotnet build

pids=()

dotnet run --project src/Mnp.MockExternalApis > logs/mock-external-apis.log 2>&1 &
pids+=("$!")
dotnet run --project src/Mnp.Worker > logs/worker.log 2>&1 &
pids+=("$!")
dotnet run --project src/Mnp.Api > logs/api.log 2>&1 &
pids+=("$!")

trap 'kill "${pids[@]}" 2>/dev/null' EXIT INT TERM

echo "Started Mnp.MockExternalApis, Mnp.Worker, Mnp.Api (PIDs: ${pids[*]})"
echo "Logs:  logs/mock-external-apis.log  logs/worker.log  logs/api.log"
echo "Tail everything:  tail -f logs/*.log"
echo "Stop everything:  Ctrl+C"

wait
