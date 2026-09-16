#!/usr/bin/env python3
"""YugabyteDB query plan management demonstration web application."""

from __future__ import annotations

import configparser
import json
import random
import threading
import time
from dataclasses import dataclass
from glob import glob
from pathlib import Path
from typing import Any

import psycopg2
from psycopg2 import sql
from flask import Flask, jsonify, render_template, request, send_from_directory


BASE_DIR = Path(__file__).resolve().parent
APPLICATION_NAME = "YugabyteDB query plan management demo"

TYPICAL_CUSTOMER_IDS = list(range(1, 501))
MEGA_CUSTOMER_IDS = [9001, 9002, 9003]
ALLOWED_PLAN_CACHE_MODES = {"auto", "force_custom_plan", "force_generic_plan"}
PAYLOAD_DISPLAY_LENGTH = 40


def parse_execution_time_ms(plan_text: str) -> float | None:
    """Pull the plan's own "Execution Time: X ms" line -- the pure,
    server-side, plan-driven cost -- distinct from the client-observed
    elapsed_ms, which for a large result set is dominated by shipping rows
    to Python rather than by which plan the server chose."""
    for line in plan_text.splitlines():
        line = line.strip()
        if line.startswith("Execution Time:"):
            try:
                return float(line.split(":", 1)[1].strip().split()[0])
            except (IndexError, ValueError):
                return None
    return None


def parse_labeled_int(plan_text: str, label: str) -> int | None:
    """Pull a "Label: <int>" line out of an EXPLAIN plan, e.g.
    "Query Identifier: 6498551768429791526" or "Plan Identifier: -515...".
    """
    prefix = f"{label}:"
    for line in plan_text.splitlines():
        line = line.strip()
        if line.startswith(prefix):
            try:
                return int(line[len(prefix):].strip())
            except ValueError:
                return None
    return None


def summarize_plan_json(plan_text: str) -> str:
    """yb_pg_stat_plans stores the plan as JSON (yb_pg_stat_plans_plan_format
    default). Reduce it to a short "Node Type on Relation" label for display
    rather than showing the raw JSON blob in a table cell."""
    try:
        parsed = json.loads(plan_text)
        node = parsed[0]["Plan"] if isinstance(parsed, list) else parsed["Plan"]
        node_type = node.get("Node Type", "?")
        relation = node.get("Relation Name")
        return f"{node_type} on {relation}" if relation else node_type
    except Exception:
        return (plan_text or "")[:60]


def list_slides(slides_dir: Path) -> list[str]:
    files: list[str] = []
    for extension in ("*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"):
        files.extend(glob(str(slides_dir / extension)))
    return [Path(item).name for item in sorted(set(files))]


@dataclass(frozen=True)
class Config:
    database_host: str
    database_port: int
    database_name: str
    database_user: str
    database_password: str
    web_host: str
    web_port: int

    @classmethod
    def load(cls, filename: Path) -> "Config":
        parser = configparser.ConfigParser()
        if not parser.read(filename):
            raise FileNotFoundError(f"Configuration file not found: {filename}")

        db = parser["database"]
        web = parser["web"]
        return cls(
            database_host=db["DATABASE_HOST"].strip(),
            database_port=db.getint("DATABASE_PORT", 5433),
            database_name=db.get("DATABASE_NAME", "my_db48").strip(),
            database_user=db.get("DATABASE_USER", "yugabyte").strip(),
            database_password=db.get("DATABASE_PASSWORD", ""),
            web_host=web.get("WEB_HOST", "0.0.0.0").strip(),
            web_port=web.getint("WEB_PORT", 5048),
        )


class DemoState:
    def __init__(self, config: Config):
        self.config = config
        self.lock = threading.RLock()
        self.conn = None
        self.setup_ready = False
        self.setup_message = "Database setup has not run"
        self.qpm_available = False
        self.server_version = ""
        self.last_results: dict[str, dict] = {}
        self.last_query_id: int | None = None

    def db_connect(self, database: str | None = None):
        return psycopg2.connect(
            host=self.config.database_host,
            port=self.config.database_port,
            dbname=database or self.config.database_name,
            user=self.config.database_user,
            password=self.config.database_password,
            connect_timeout=5,
            application_name=APPLICATION_NAME,
        )

    def setup_database(self) -> None:
        try:
            connection = self.db_connect("yugabyte")
            connection.autocommit = True
            try:
                with connection.cursor() as cursor:
                    cursor.execute(
                        "SELECT 1 FROM pg_database WHERE datname = %s",
                        (self.config.database_name,),
                    )
                    if cursor.fetchone() is None:
                        cursor.execute(
                            sql.SQL("CREATE DATABASE {}").format(
                                sql.Identifier(self.config.database_name)
                            )
                        )
            finally:
                connection.close()

            connection = self.db_connect()
            connection.autocommit = True
            try:
                with connection.cursor() as cursor:
                    cursor.execute(
                        "SELECT to_regclass('public.t1') IS NOT NULL"
                    )
                    (table_exists,) = cursor.fetchone()
                    if not table_exists:
                        schema = (
                            BASE_DIR / "20 - sql" / "10 - Create all SQL and data.sql"
                        ).read_text()
                        cursor.execute(schema)
                    else:
                        cursor.execute("ANALYZE t1")
                    cursor.execute(
                        "SELECT to_regclass('yb_pg_stat_plans') IS NOT NULL"
                    )
                    (qpm_available,) = cursor.fetchone()
                    cursor.execute("SELECT version()")
                    (server_version,) = cursor.fetchone()
            finally:
                connection.close()

            with self.lock:
                self.setup_ready = True
                self.setup_message = "Demo database and table are ready"
                self.qpm_available = bool(qpm_available)
                self.server_version = server_version

            self._open_persistent_connection()
        except Exception as exc:
            with self.lock:
                self.setup_ready = False
                self.setup_message = f"Database setup incomplete: {exc}"

    def _open_persistent_connection(self) -> None:
        """One long-lived connection/session, so plan_cache_mode's
        custom-vs-generic decision (which is per-session) actually
        accumulates across button clicks the way a pooled app connection
        would, instead of resetting on every request."""
        with self.lock:
            if self.conn is not None:
                try:
                    self.conn.close()
                except Exception:
                    pass
            self.conn = self.db_connect()
            self.conn.autocommit = True
            with self.conn.cursor() as cursor:
                cursor.execute(
                    "PREPARE find_by_customer(int) AS "
                    "SELECT id, customer_id, payload FROM t1 WHERE customer_id = $1;"
                )

    def _ensure_connection(self):
        with self.lock:
            if self.conn is None or self.conn.closed:
                self._open_persistent_connection()
            return self.conn

    def run_query(self, customer_type: str) -> dict:
        if customer_type == "typical":
            customer_id = random.choice(TYPICAL_CUSTOMER_IDS)
        elif customer_type == "mega":
            customer_id = random.choice(MEGA_CUSTOMER_IDS)
        else:
            raise ValueError("customer_type must be 'typical' or 'mega'")

        with self.lock:
            connection = self._ensure_connection()
            try:
                cursor = connection.cursor()
                started = time.perf_counter()
                cursor.execute("EXECUTE find_by_customer(%s);", (customer_id,))
                rows = cursor.fetchall()
                elapsed_ms = (time.perf_counter() - started) * 1000

                # ANALYZE actually re-runs the query (a real second execution,
                # doubling cost for the mega customers) in exchange for real
                # per-stage timing, buffer usage, and the settings that were
                # in effect (e.g. the current plan_cache_mode) rather than
                # just the plan shape.
                cursor.execute(
                    "EXPLAIN (ANALYZE, DIST, BUFFERS, VERBOSE, SETTINGS, SUMMARY, "
                    "QUERYID ON, PLANID ON) EXECUTE find_by_customer(%s);",
                    (customer_id,),
                )
                plan_text = "\n".join(row[0] for row in cursor.fetchall())

                cursor.execute("SHOW plan_cache_mode;")
                (plan_cache_mode,) = cursor.fetchone()
                cursor.close()
            except psycopg2.Error:
                # Connection dropped mid-request; reopen and let the user retry.
                self._open_persistent_connection()
                raise

        sample = []
        for row_id, row_customer_id, payload in rows[:5]:
            text = payload or ""
            if len(text) > PAYLOAD_DISPLAY_LENGTH:
                text = text[:PAYLOAD_DISPLAY_LENGTH] + "…"
            sample.append({"id": row_id, "customer_id": row_customer_id, "payload": text})

        execution_time_ms = parse_execution_time_ms(plan_text)
        query_id = parse_labeled_int(plan_text, "Query Identifier")
        plan_id = parse_labeled_int(plan_text, "Plan Identifier")

        result = {
            "customer_type": customer_type,
            "customer_id": customer_id,
            "total_rows": len(rows),
            "elapsed_ms": round(elapsed_ms, 2),
            "execution_time_ms": execution_time_ms,
            "sample_rows": sample,
            "plan_cache_mode": plan_cache_mode,
            "plan_text": plan_text,
            "query_id": query_id,
            "plan_id": plan_id,
        }
        with self.lock:
            if query_id is not None:
                self.last_query_id = query_id
            self.last_results.setdefault(customer_type, {})[plan_cache_mode] = {
                "elapsed_ms": result["elapsed_ms"],
                "execution_time_ms": execution_time_ms,
            }
        return result

    def set_plan_cache_mode(self, mode: str) -> str:
        if mode not in ALLOWED_PLAN_CACHE_MODES:
            raise ValueError(f"Unsupported plan_cache_mode: {mode}")
        with self.lock:
            connection = self._ensure_connection()
            cursor = connection.cursor()
            # mode is validated against a fixed allow-list above, so this
            # interpolation cannot carry injected SQL.
            cursor.execute(f"SET plan_cache_mode = {mode};")
            cursor.execute("SHOW plan_cache_mode;")
            (current,) = cursor.fetchone()
            cursor.close()
        return current

    def current_plan_cache_mode(self) -> str:
        with self.lock:
            connection = self._ensure_connection()
            cursor = connection.cursor()
            cursor.execute("SHOW plan_cache_mode;")
            (current,) = cursor.fetchone()
            cursor.close()
        return current

    def qpm_snapshot(self) -> dict:
        """Live QPM data for the demo query, using its own short-lived
        connection -- deliberately separate from the persistent one, so
        this read-only monitoring query can never perturb the persistent
        connection's own custom-vs-generic plan cache state."""
        with self.lock:
            query_id = self.last_query_id

        connection = self.db_connect()
        try:
            connection.autocommit = True
            cursor = connection.cursor()
            cursor.execute("SELECT to_regclass('yb_pg_stat_plans') IS NOT NULL")
            (available,) = cursor.fetchone()
            if not available or query_id is None:
                cursor.close()
                return {"available": bool(available), "query_id": None, "plans": []}

            cursor.execute(
                """
                SELECT p.planid, p.calls, p.avg_exec_time, p.max_exec_time,
                       p.avg_est_cost, p.first_used, p.last_used, p.plan,
                       i.min_avg_exec_time, i.min_avg_est_cost,
                       i.plan_require_evaluation, i.plan_min_exec_time
                FROM yb_pg_stat_plans p
                LEFT JOIN yb_pg_stat_plans_insights i
                  ON i.queryid = p.queryid AND i.planid = p.planid
                WHERE p.queryid = %s
                ORDER BY p.last_used DESC
                """,
                (query_id,),
            )
            rows = cursor.fetchall()
            cursor.close()
        finally:
            connection.close()

        plans = []
        for (planid, calls, avg_exec_time, max_exec_time, avg_est_cost,
                first_used, last_used, plan_text, min_avg_exec_time,
                min_avg_est_cost, plan_require_evaluation,
                plan_min_exec_time) in rows:
            plans.append({
                "planid": str(planid),
                "calls": calls,
                "avg_exec_time": round(avg_exec_time, 3) if avg_exec_time is not None else None,
                "max_exec_time": round(max_exec_time, 3) if max_exec_time is not None else None,
                "avg_est_cost": round(avg_est_cost, 2) if avg_est_cost is not None else None,
                "first_used": first_used.isoformat() if first_used else None,
                "last_used": last_used.isoformat() if last_used else None,
                "plan_summary": summarize_plan_json(plan_text),
                "min_avg_exec_time": round(min_avg_exec_time, 3) if min_avg_exec_time is not None else None,
                "min_avg_est_cost": round(min_avg_est_cost, 2) if min_avg_est_cost is not None else None,
                "plan_require_evaluation": plan_require_evaluation,
                "plan_min_exec_time": plan_min_exec_time,
            })
        return {"available": True, "query_id": str(query_id), "plans": plans}

    def snapshot(self) -> dict:
        with self.lock:
            setup_ready = self.setup_ready
            setup_message = self.setup_message
            qpm_available = self.qpm_available
            server_version = self.server_version
            last_results = dict(self.last_results)
        plan_cache_mode = None
        if setup_ready:
            try:
                plan_cache_mode = self.current_plan_cache_mode()
            except Exception:
                plan_cache_mode = None
        return {
            "setup": {"ready": setup_ready, "message": setup_message},
            "plan_cache_mode": plan_cache_mode,
            "last_results": last_results,
            "qpm": {
                "available": qpm_available,
                "server_version": server_version,
            },
        }


def create_app() -> Flask:
    config = Config.load(BASE_DIR / "properties.ini")
    app = Flask(
        __name__,
        static_folder=str(BASE_DIR / "44_static"),
        static_url_path="/static",
        template_folder=str(BASE_DIR / "45_views"),
    )
    state = DemoState(config)
    app.config["DEMO_STATE"] = state
    app.config["SLIDES_DIR"] = BASE_DIR / "48_slides"

    @app.get("/")
    def home():
        return render_template("60_index.html")

    @app.get("/slides/<path:filename>")
    def slides_file(filename):
        return send_from_directory(app.config["SLIDES_DIR"], filename)

    @app.get("/api/slides")
    def api_slides():
        files = list_slides(app.config["SLIDES_DIR"])
        return jsonify({"ok": True, "files": files, "count": len(files)})

    @app.get("/api/state")
    def api_state():
        return jsonify({"ok": True, **state.snapshot()})

    @app.get("/api/qpm")
    def api_qpm():
        try:
            return jsonify({"ok": True, **state.qpm_snapshot()})
        except Exception as exc:
            return jsonify({"ok": False, "message": str(exc)}), 409

    @app.post("/api/query")
    def api_query():
        try:
            payload = request.get_json(silent=True) or {}
            customer_type = payload.get("customer_type")
            result = state.run_query(customer_type)
            return jsonify({"ok": True, **result})
        except Exception as exc:
            return jsonify({"ok": False, "message": str(exc)}), 409

    @app.post("/api/plan_cache_mode")
    def api_plan_cache_mode():
        try:
            payload = request.get_json(silent=True) or {}
            mode = payload.get("mode")
            current = state.set_plan_cache_mode(mode)
            return jsonify({"ok": True, "plan_cache_mode": current})
        except Exception as exc:
            return jsonify({"ok": False, "message": str(exc)}), 409

    threading.Thread(target=state.setup_database, daemon=True).start()
    return app


if __name__ == "__main__":
    cfg = Config.load(BASE_DIR / "properties.ini")
    create_app().run(host=cfg.web_host, port=cfg.web_port, debug=False, threaded=True)
