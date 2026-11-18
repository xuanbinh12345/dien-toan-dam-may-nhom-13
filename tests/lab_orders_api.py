"""Local lab HTTP API. Database access uses docker exec + psql in the restore container."""
import json
import re
import subprocess
from decimal import Decimal, InvalidOperation
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

HOST = "127.0.0.1"
PORT = 8099
CONTAINER = "lab13-host-copy-restore-restore-1"
ORDER_ID = re.compile(r"APP-PITR-[A-Za-z0-9-]{1,64}\Z")


def query(sql):
    result = subprocess.run(
        ["docker", "exec", CONTAINER, "psql", "-X", "-w", "-q", "-A", "-t",
         "-v", "ON_ERROR_STOP=1", "-U", "postgres", "-d", "ha_lab", "-c", sql],
        capture_output=True, text=True, timeout=15, check=True,
    )
    return result.stdout.strip()


class Handler(BaseHTTPRequestHandler):
    def respond(self, status, value):
        data = json.dumps(value, ensure_ascii=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urlsplit(self.path).path
        try:
            if path == "/health":
                role = query("SELECT pg_is_in_recovery();")
                if role not in ("t", "f"):
                    raise ValueError("unexpected recovery state")
                self.respond(200, {"container": CONTAINER, "in_recovery": role == "t"})
                return
            prefix = "/orders/"
            order_id = path[len(prefix):] if path.startswith(prefix) else ""
            if not ORDER_ID.fullmatch(order_id):
                self.respond(400, {"error": "invalid order id"})
                return
            row = query("SELECT row_to_json(t)::text FROM (SELECT order_id, amount::text AS amount "
                        "FROM public.orders WHERE order_id = '" + order_id + "') t;")
            if not row:
                self.respond(404, {"error": "order not found"})
                return
            self.respond(200, json.loads(row))
        except (subprocess.SubprocessError, OSError, ValueError):
            self.respond(503, {"error": "database query failed"})

    def do_POST(self):
        if urlsplit(self.path).path != "/orders":
            self.respond(404, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length < 1 or length > 4096:
                raise ValueError("invalid length")
            payload = json.loads(self.rfile.read(length))
            order_id = payload["order_id"]
            amount_text = str(payload["amount"])
            if not isinstance(order_id, str) or not ORDER_ID.fullmatch(order_id):
                raise ValueError("invalid order id")
            if not re.fullmatch(r"[0-9]{1,10}(?:\.[0-9]{1,2})?", amount_text):
                raise ValueError("invalid amount")
            amount = Decimal(amount_text)
            if amount <= 0:
                raise ValueError("amount must be positive")
            result = query("INSERT INTO public.orders(order_id, amount) VALUES ('" +
                           order_id + "', " + amount_text + ") RETURNING order_id;")
            if result != order_id:
                raise ValueError("insert not confirmed")
            self.respond(201, {"order_id": order_id, "amount": f"{amount:.2f}"})
        except (KeyError, TypeError, ValueError, InvalidOperation, json.JSONDecodeError):
            self.respond(400, {"error": "invalid request"})
        except (subprocess.SubprocessError, OSError):
            self.respond(503, {"error": "database write failed"})


if __name__ == "__main__":
    print(f"Lab API http://{HOST}:{PORT} -> {CONTAINER}", flush=True)
    print("Press Ctrl+C to stop.", flush=True)
    try:
        ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        print("Stopped.", flush=True)
