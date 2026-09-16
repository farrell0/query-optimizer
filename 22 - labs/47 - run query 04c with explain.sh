#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
properties="$project_dir/properties.ini"

value() {
   sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" "$properties" | tail -1
}

host="$(value DATABASE_HOST)"
port="$(value DATABASE_PORT)"
database="$(value DATABASE_NAME)"
user="$(value DATABASE_USER)"
password="$(value DATABASE_PASSWORD)"

export PGPASSWORD="$password"
ysqlsh -X -v ON_ERROR_STOP=1 -h "$host" -p "$port" -U "$user" \
   -d "$database" -f "$script_dir/46 - run query 04c with explain.sql"
