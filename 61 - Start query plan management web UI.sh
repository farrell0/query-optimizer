#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_dir="$project_dir/.local-runtime"
pid_file="$runtime_dir/web-ui.pid"
log_file="$runtime_dir/web-ui.log"

mkdir -p "$runtime_dir"
if [[ -f "$pid_file" ]] && kill -0 "$(<"$pid_file")" 2>/dev/null; then
   echo "Query plan management web UI is already running (PID $(<"$pid_file"))."
   exit 0
fi

cd "$project_dir"
nohup python3 60_index.py >>"$log_file" 2>&1 &
pid=$!
printf '%s\n' "$pid" >"$pid_file"

for _ in {1..30}; do
   if curl -fsS http://127.0.0.1:5048/api/state >/dev/null 2>&1; then
      echo "Query plan management web UI started: http://$(hostname -f):5048"
      echo "PID: $pid"
      exit 0
   fi
   sleep 1
done

echo "The web UI did not become ready. Review $log_file" >&2
exit 1
