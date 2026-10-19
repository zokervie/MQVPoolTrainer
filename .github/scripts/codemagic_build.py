#!/usr/bin/env python3
"""Chạy build trên Codemagic qua REST API (dùng từ GitHub Actions).

Biến môi trường:
  CODEMAGIC_API_TOKEN  bắt buộc (Codemagic → Settings → Integrations → Codemagic API → Show)
  CM_WORKFLOW          workflow trong codemagic.yaml (mặc định zoker-ipa-unsigned)
  CM_BRANCH            nhánh (mặc định feature/zoker-mvp)
  CM_REPO              URL repo (mặc định https://github.com/zokervie/MQVPoolTrainer.git)

Kết quả in thành annotation GitHub (::notice / ::error) để đọc được qua API check-runs.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = "https://api.codemagic.io"
TOKEN = os.environ.get("CODEMAGIC_API_TOKEN", "").strip()
WORKFLOW = os.environ.get("CM_WORKFLOW") or "zoker-ipa-unsigned"
BRANCH = os.environ.get("CM_BRANCH") or "feature/zoker-mvp"
REPO = os.environ.get("CM_REPO") or "https://github.com/zokervie/MQVPoolTrainer.git"
TERMINAL = {"finished", "failed", "canceled", "timeout", "skipped", "warning"}


def esc(s):
    return str(s).replace("%", "%25").replace("\r", "").replace("\n", "%0A")


def notice(title, msg):
    print(f"::notice title={title}::{esc(msg)}", flush=True)


def error(title, msg):
    print(f"::error title={title}::{esc(msg)}", flush=True)


def call(method, path, body=None, raw=False):
    url = path if path.startswith("http") else API + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"x-auth-token": TOKEN, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            text = r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {url} → HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:500]}")
    return text if raw else (json.loads(text) if text else {})


def find_or_add_app():
    apps = call("GET", "/apps").get("applications", [])
    key = "zokervie/mqvpooltrainer"
    for a in apps:
        if key in json.dumps(a).lower():
            return a["_id"], a.get("appName"), False
    created = call("POST", "/apps", {"repositoryUrl": REPO})
    return created["_id"], created.get("appName"), True


def main():
    if not TOKEN:
        error("codemagic", "Thiếu secret CODEMAGIC_API_TOKEN trong GitHub (Settings → Secrets and variables → Actions).")
        return 1
    app_id, name, created = find_or_add_app()
    notice("codemagic app", f"{'Đã thêm' if created else 'Dùng'} app {name} ({app_id})")
    build_id = call("POST", "/builds", {"appId": app_id, "workflowId": WORKFLOW, "branch": BRANCH})["buildId"]
    link = f"https://codemagic.io/app/{app_id}/build/{build_id}"
    notice("codemagic build", f"Bắt đầu {WORKFLOW} @ {BRANCH}: {link}")

    status, deadline, build = None, time.time() + 85 * 60, {}
    while time.time() < deadline:
        build = call("GET", f"/builds/{build_id}").get("build", {})
        if build.get("status") != status:
            status = build.get("status")
            print(f"[{time.strftime('%H:%M:%S')}] status: {status}", flush=True)
        if status in TERMINAL:
            break
        time.sleep(30)

    steps = build.get("buildActions") or []
    summary = "\n".join(f"{s.get('status', '?'):>9}  {s.get('name', '?')}" for s in steps)
    if status != "finished":
        error("codemagic status", f"Build {status}: {link}\n{summary}")
        for s in steps:
            if s.get("status") in ("failed", "timeout") and s.get("logUrl"):
                try:
                    log = call("GET", s["logUrl"], raw=True).splitlines()
                    keep = [l for l in log if "error" in l.lower() or "HỎNG" in l or "failed" in l.lower()][-25:] or log[-25:]
                    error(f"codemagic log: {s.get('name')}", "\n".join(keep))
                except Exception as e:  # noqa: BLE001
                    error("codemagic log", f"Không đọc được log bước {s.get('name')}: {e}")
        return 1

    notice("codemagic status", f"Build finished: {link}\n{summary}")
    lines = []
    for art in build.get("artefacts") or []:
        url = art.get("url")
        public = ""
        if url:
            try:
                public = call("POST", f"{url}/public-url", {"expiresAt": int(time.time()) + 7 * 24 * 3600}).get("url", "")
            except Exception as e:  # noqa: BLE001
                public = f"(không tạo được link công khai: {e})"
        lines.append(f"{art.get('name')} ({art.get('size', '?')} bytes): {public or url}")
    notice("codemagic artifacts", "\n".join(lines) if lines else "Không có artifact")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001
        error("codemagic", str(e))
        sys.exit(1)
