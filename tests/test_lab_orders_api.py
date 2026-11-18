"""Exercise the lab API via HTTP and save evidence without passwords or WAL."""
import json
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path

BASE = "http://127.0.0.1:8099"
CONTAINER = "lab13-host-copy-restore-restore-1"


def request(method, path, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as response:
        return response.status, json.load(response)


def main():
    run_id = "APP-PITR-" + datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6]
    record = {"run_id": run_id, "checked_utc": datetime.now(timezone.utc).isoformat(),
              "target_container": CONTAINER, "order_id": run_id, "amount": "123.45",
              "health_ok": False, "write_ok": False, "read_ok": False, "result": "FAIL"}
    try:
        status, health = request("GET", "/health")
        record["health_ok"] = status == 200 and health.get("container") == CONTAINER and health.get("in_recovery") is False
        if not record["health_ok"]:
            raise RuntimeError("Restore is not confirmed writable")
        status, written = request("POST", "/orders", {"order_id": run_id, "amount": "123.45"})
        record["write_ok"] = status == 201 and written.get("order_id") == run_id and written.get("amount") == "123.45"
        if not record["write_ok"]:
            raise RuntimeError("HTTP write did not match")
        status, read = request("GET", "/orders/" + run_id)
        record["read_ok"] = status == 200 and read.get("order_id") == run_id and read.get("amount") == "123.45"
        if not record["read_ok"]:
            raise RuntimeError("HTTP read did not match")
        record["result"] = "PASS"
    except (OSError, ValueError, RuntimeError, urllib.error.URLError) as exc:
        record["error"] = str(exc)
    output = Path(__file__).resolve().parent.parent / "results" / (run_id + ".json")
    output.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(record, indent=2, ensure_ascii=False))
    print("RESULT FILE:", output)
    return 0 if record["result"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
