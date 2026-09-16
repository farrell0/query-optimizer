#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
pid_file="$project_dir/.local-runtime/web-ui.pid"

if [[ ! -f "$pid_file" ]]; then
   echo "Query plan management web UI is not running."
   exit 0
fi
pid="$(<"$pid_file")"
if kill -0 "$pid" 2>/dev/null; then
   kill "$pid"
fi
rm -f "$pid_file"
echo "Query plan management web UI stopped."
