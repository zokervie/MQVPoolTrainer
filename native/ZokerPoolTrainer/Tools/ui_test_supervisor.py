#!/usr/bin/env python3
"""Supervisor for the XCTest UI shards (ZB-035).

Why: CI run 45927685914 shard 2 sat 58 minutes inside ONE test (testChapterOneLadderAndExam, XCTest kept polling
"Alert (First Match)") although xcodebuild was given a 900 s per-test allowance - the allowance did not fire, so the
job died at its 100-minute limit with 2 of 38 tests done and no evidence. A supervisor outside xcodebuild fixes that:

 1. one xcodebuild invocation per attempt, watched by a watchdog: a test running longer than --test-max, no output for
    --stall seconds, or the shard budget exhausted -> the process group is killed;
 2. the test that was running at the kill is marked HUNG, the Simulator is rebooted, and the REMAINING tests continue
    in a new attempt (nothing is lost);
 3. every failed or hung test is re-run once, alone, on a clean Simulator. Pass on re-run = FLAKY (reported as a
    warning with its evidence, counted, capped by --max-flaky); fail again = FAILED (red). Tests are never loosened;
 4. a summary (JSON + GitHub step summary + annotations) lists passed / flaky / failed / hung / not run with times.

Exit code 0 only when nothing failed, hung or was left unrun and flaky <= --max-flaky.
"""
import argparse, json, os, re, signal, subprocess, sys, threading, time
from pathlib import Path

START = re.compile(r"Test Case '-\[\S+\.InteractionTests (test\w+)\]' started")
END = re.compile(r"Test Case '-\[\S+\.InteractionTests (test\w+)\]' (passed|failed) \(([\d.]+) seconds\)")
FUNC = re.compile(r"func (test[A-Za-z0-9_]+)\(")


def list_tests(swift_path, k=None, n=None):
    names = FUNC.findall(Path(swift_path).read_text(encoding="utf-8"))
    if k is None:
        return names
    return [t for i, t in enumerate(names) if i % n == k - 1]


def kill_group(proc):
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    for _ in range(20):
        if proc.poll() is not None:
            return
        time.sleep(0.5)
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


class Attempt:
    def __init__(self):
        self.results = {}      # name -> (status, seconds)
        self.hung = None       # test running when the watchdog fired
        self.reason = ""
        self.exit_code = None


def run_attempt(cmd, log, cfg, deadline):
    a = Attempt()
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace",
                            bufsize=1, start_new_session=True)
    state = {"last": time.time(), "current": None, "since": None, "killed": ""}
    stop = threading.Event()

    def watchdog():
        while not stop.wait(1.0):
            now = time.time()
            why = ""
            if state["current"] and now - state["since"] > cfg.test_max:
                why = f"test {state['current']} ran over {cfg.test_max:.0f}s"
            elif now - state["last"] > cfg.stall:
                why = f"no output for {cfg.stall:.0f}s"
            elif now > deadline:
                why = "shard budget exhausted"
            if why:
                state["killed"] = why
                kill_group(proc)
                return

    threading.Thread(target=watchdog, daemon=True).start()
    for line in proc.stdout:
        state["last"] = time.time()
        log.write(line); log.flush()
        if cfg.echo:
            sys.stdout.write(line); sys.stdout.flush()
        m = START.search(line)
        if m:
            state["current"], state["since"] = m.group(1), time.time()
            continue
        m = END.search(line)
        if m:
            a.results[m.group(1)] = (m.group(2), float(m.group(3)))
            state["current"] = None
    proc.wait()
    stop.set()
    a.exit_code = proc.returncode
    if state["killed"]:
        a.reason = state["killed"]
        if state["current"] and state["current"] not in a.results:
            a.hung = state["current"]
    return a


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--swift", default="UITests/InteractionTests.swift")
    ap.add_argument("--shard", default="", help="k/n")
    ap.add_argument("--xcodebuild", default="xcodebuild")
    ap.add_argument("--project", default="ZokerPoolTrainer.xcodeproj")
    ap.add_argument("--scheme", default="ZokerPoolTrainer")
    ap.add_argument("--derived", default="build/Simulator")
    ap.add_argument("--out", default="build")
    ap.add_argument("--test-max", type=float, default=720, help="seconds one test may run before it is killed")
    ap.add_argument("--stall", type=float, default=600, help="seconds without any output before kill")
    ap.add_argument("--budget", type=float, default=4200, help="seconds for the whole shard (phase 1 + retries)")
    ap.add_argument("--max-flaky", type=int, default=6)
    ap.add_argument("--no-device", action="store_true", help="self-test: skip Simulator handling")
    ap.add_argument("--quiet", action="store_true")
    cfg = ap.parse_args()
    cfg.echo = not cfg.quiet

    k = n = None
    if cfg.shard:
        k, n = (int(x) for x in cfg.shard.split("/"))
    tests = list_tests(cfg.swift, k, n)
    if not tests:
        print(f"UI shard {cfg.shard or 'all'} selects no test"); return 1
    tag = f"-shard{k}" if k else ""
    out = Path(cfg.out); out.mkdir(parents=True, exist_ok=True)
    log = open(out / f"ui-tests{tag}.log", "a", encoding="utf-8")
    t0 = time.time(); deadline = t0 + cfg.budget

    device = None
    if not cfg.no_device:
        js = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True))
        cand = [d for g in js["devices"].values() for d in g if d.get("isAvailable") and "iPhone" in d["name"]]
        cand.sort(key=lambda d: d["state"] != "Booted")
        if not cand:
            print("No available iPhone Simulator"); return 1
        device = cand[0]["udid"]

    def fresh_simulator():
        if cfg.no_device:
            return
        subprocess.run(["xcrun", "simctl", "shutdown", device], stderr=subprocess.DEVNULL)
        subprocess.run(["xcrun", "simctl", "boot", device], stderr=subprocess.DEVNULL)
        subprocess.run(["xcrun", "simctl", "bootstatus", device, "-b"], stdout=subprocess.DEVNULL)

    attempt_no = [0]

    def command(batch):
        attempt_no[0] += 1
        result_path = Path(cfg.out).resolve() / f"ui-tests{tag}-a{attempt_no[0]}-{time.strftime('%H%M%S')}.xcresult"
        dest = "platform=iOS Simulator,id=%s" % device if device else "platform=iOS Simulator,name=fake"
        return ([cfg.xcodebuild, "test", "-project", cfg.project, "-scheme", cfg.scheme, "-configuration", "Debug",
                 "-destination", dest, "-derivedDataPath", str(Path(cfg.derived).resolve()),
                 "-resultBundlePath", str(result_path), "-parallel-testing-enabled", "NO",
                 "-maximum-concurrent-test-simulator-destinations", "1", "-destination-timeout", "120",
                 "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "900",
                 "-maximum-test-execution-time-allowance", "900"]
                + [f"-only-testing:ZokerPoolTrainerUITests/InteractionTests/{t}" for t in batch]
                + ["ONLY_ACTIVE_ARCH=YES", "CODE_SIGNING_ALLOWED=NO"])

    final = {}   # name -> {"status","seconds","note"}
    notes = []
    fresh_simulator()

    # Phase 1: everything, resuming after each kill.
    pending = list(tests); stuck = 0
    while pending and time.time() < deadline:
        log.write(f"\n=== attempt {attempt_no[0] + 1}: {len(pending)} tests ===\n")
        a = run_attempt(command(pending), log, cfg, deadline)
        progress = False
        for name, (st, sec) in a.results.items():
            final[name] = {"status": "passed" if st == "passed" else "failed", "seconds": sec}; progress = True
        if a.hung:
            final[a.hung] = {"status": "hung", "seconds": cfg.test_max, "note": a.reason}; progress = True
            notes.append(f"{a.hung}: killed ({a.reason})")
        pending = [t for t in pending if t not in final]
        if a.reason:
            fresh_simulator()
        if not progress:
            stuck += 1
            if stuck >= 2:
                notes.append("two attempts without a single finished test - stopping")
                break
        else:
            stuck = 0

    # Phase 2: one isolated re-run of every failed / hung test.
    for name in [t for t in tests if final.get(t, {}).get("status") in ("failed", "hung")]:
        if time.time() >= deadline:
            break
        first = final[name]["status"]
        fresh_simulator()
        log.write(f"\n=== retry (alone): {name} (first: {first}) ===\n")
        a = run_attempt(command([name]), log, cfg, deadline)
        res = a.results.get(name)
        if res and res[0] == "passed":
            final[name] = {"status": "flaky", "seconds": res[1], "note": f"first run {first}, passed alone"}
        else:
            final[name]["note"] = (final[name].get("note", "") + " · failed again alone").strip(" ·")

    for t in tests:
        final.setdefault(t, {"status": "notrun", "seconds": 0, "note": "budget exhausted before it ran"})

    count = lambda s: sum(1 for t in tests if final[t]["status"] == s)
    passed, flaky, failed, hung, notrun = (count(s) for s in ("passed", "flaky", "failed", "hung", "notrun"))
    elapsed = time.time() - t0
    summary = {"shard": cfg.shard or "all", "tests": len(tests), "passed": passed, "flaky": flaky, "failed": failed,
               "hung": hung, "notrun": notrun, "seconds": round(elapsed), "notes": notes,
               "results": {t: final[t] for t in tests}}
    (out / f"ui-summary{tag}.json").write_text(json.dumps(summary, indent=1, ensure_ascii=False), encoding="utf-8")

    lines = [f"### UI shard {summary['shard']}: {len(tests)} tests in {elapsed/60:.1f} min",
             f"passed {passed} · flaky {flaky} · failed {failed} · hung {hung} · not run {notrun}"]
    for t in tests:
        r = final[t]
        if r["status"] != "passed":
            lines.append(f"- {r['status'].upper()} `{t}` {r.get('note', '')}".rstrip())
    slow = sorted(((final[t]["seconds"], t) for t in tests if final[t]["status"] == "passed"), reverse=True)[:5]
    lines.append("slowest passed: " + ", ".join(f"{t} {s:.0f}s" for s, t in slow))
    text = "\n".join(lines)
    print("\n" + text)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write(text + "\n")
    for t in tests:
        r = final[t]
        if r["status"] == "flaky":
            print(f"::warning title=UI flaky (ZB-035)::{t} - {r['note']}")
        elif r["status"] in ("failed", "hung", "notrun"):
            print(f"::error title=UI {r['status']}::{t} - {r.get('note', '')}")
    bad = failed or hung or notrun or flaky > cfg.max_flaky
    if flaky > cfg.max_flaky:
        print(f"::error title=UI flaky cap::{flaky} flaky tests > cap {cfg.max_flaky}: the runner or the tests need work")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
