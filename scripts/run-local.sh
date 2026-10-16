#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

mkdir -p logs

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
