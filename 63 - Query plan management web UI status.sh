#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
pid_file="$project_dir/.local-runtime/web-ui.pid"

if [[ -f "$pid_file" ]] && kill -0 "$(<"$pid_file")" 2>/dev/null; then
   echo "Running (PID $(<"$pid_file"))"
   curl -fsS http://127.0.0.1:5048/api/state
   echo
else
   echo "Stopped"
fi
