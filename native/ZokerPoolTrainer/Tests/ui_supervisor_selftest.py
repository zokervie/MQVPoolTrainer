#!/usr/bin/env python3
"""Self-test of Tools/ui_test_supervisor.py with a fake xcodebuild (no Simulator, no Xcode).
Scenarios: pass, fail-then-pass (flaky), always fail, hang-forever (the CI 45927685914 case, output keeps flowing),
hang-once (flaky), silent stall, budget exhaustion, shard selection. Run: python3 Tests/ui_supervisor_selftest.py"""
import json, os, stat, subprocess, sys, tempfile, textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUP = ROOT / "Tools" / "ui_test_supervisor.py"
sys.path.insert(0, str(ROOT / "Tools"))
import ui_test_supervisor as sup  # noqa: E402

FAKE = textwrap.dedent('''\
    #!/usr/bin/env python3
    import json, os, sys, time
    plan = json.load(open(os.environ["FAKE_PLAN"])); counts_path = os.environ["FAKE_COUNTS"]
    counts = json.load(open(counts_path)) if os.path.exists(counts_path) else {}
    tests = [a.split("/")[-1] for a in sys.argv if a.startswith("-only-testing:")]
    if "build-for-testing" in sys.argv:
        how = plan.get("__build", "ok")
        if how == "fail": print("error: Swift compile failed", flush=True); sys.exit(65)
        if how == "quiet": time.sleep(6)   # a long silent compile: must not be taken for a hang
        print("** TEST BUILD SUCCEEDED **", flush=True); sys.exit(0)
    def mark(t):
        counts[t] = counts.get(t, 0) + 1; json.dump(counts, open(counts_path, "w")); return counts[t]
    for t in tests:
        n = mark(t); how = plan.get(t, "pass")
        print("Test Case '-[ZokerPoolTrainerUITests.InteractionTests %s]' started." % t, flush=True)
        if how == "hang" or (how == "hang_once" and n == 1):
            while True:
                print("    t = 1.0s Checking existence of `Alert (First Match)`", flush=True); time.sleep(0.2)
        if how == "silent" or (how == "silent_once" and n == 1):
            time.sleep(600)
        ok = how in ("pass",) or (how == "fail_once" and n > 1) or (how == "hang_once" and n > 1) or (how == "silent_once" and n > 1)
        print("Test Case '-[ZokerPoolTrainerUITests.InteractionTests %s]' %s (0.5 seconds)." % (t, "passed" if ok else "failed"), flush=True)
    sys.exit(0)
''')

SWIFT = "\n".join(f"    func test{n}() {{}}" for n in ("A", "B", "C", "D", "E", "F", "G"))


def run(plan, extra=(), shard="", swift=SWIFT):
    with tempfile.TemporaryDirectory() as d:
        d = Path(d); (d / "T.swift").write_text(swift)
        fake = d / "fakexcb"; fake.write_text(FAKE); fake.chmod(fake.stat().st_mode | stat.S_IEXEC)
        (d / "plan.json").write_text(json.dumps({(k if k.startswith("__") else "test" + k): v for k, v in plan.items()}))
        env = dict(os.environ, FAKE_PLAN=str(d / "plan.json"), FAKE_COUNTS=str(d / "counts.json"))
        cmd = [sys.executable, str(SUP), "--swift", str(d / "T.swift"), "--xcodebuild", str(fake), "--out", str(d / "out"),
               "--derived", str(d / "dd"), "--no-device", "--quiet", "--test-max", "3", "--stall", "4", "--build-stall", "30", "--budget", "60", *extra]
        if shard: cmd += ["--shard", shard]
        p = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=200)
        tag = "-shard" + shard.split("/")[0] if shard else ""
        summary = json.loads((d / "out" / f"ui-summary{tag}.json").read_text()) if (d / "out" / f"ui-summary{tag}.json").exists() else None
        return p.returncode, summary, p.stdout


fails = []
def check(name, cond, info=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  {info}"))
    if not cond: fails.append(name)

# shard selection: every n-th func in source order, starting at k
check("shard 1/3 picks A D G", sup.list_tests("/dev/stdin" if False else str(ROOT / "UITests/InteractionTests.swift"), 1, 3) == sup.list_tests(str(ROOT / "UITests/InteractionTests.swift"))[0::3])
check("shards 1..3 cover every test once", sorted(sum((sup.list_tests(str(ROOT / "UITests/InteractionTests.swift"), k, 3) for k in (1, 2, 3)), [])) == sorted(sup.list_tests(str(ROOT / "UITests/InteractionTests.swift"))))

code, s, _ = run({})
check("all pass -> exit 0", code == 0 and s and s["passed"] == 7, (code, s and s["passed"]))

code, s, _ = run({"B": "fail_once"})
check("fail once then pass alone -> FLAKY, exit 0", code == 0 and s["flaky"] == 1 and s["results"]["testB"]["status"] == "flaky", (code, s))

code, s, _ = run({"E": "fail"})
check("always fails -> FAILED, exit 1", code == 1 and s["failed"] == 1 and s["results"]["testE"]["status"] == "failed", (code, s))

code, s, _ = run({"C": "hang"})
r = s["results"]
check("hang forever (output keeps flowing) -> HUNG, later tests still run, exit 1",
      code == 1 and r["testC"]["status"] == "hung" and all(r[t]["status"] == "passed" for t in ("testD", "testE", "testF", "testG")), (code, {t: r[t]["status"] for t in r}))

code, s, _ = run({"F": "hang_once"})
check("hang once -> killed, retried alone, FLAKY, exit 0", code == 0 and s["results"]["testF"]["status"] == "flaky" and s["results"]["testG"]["status"] == "passed", (code, s["results"]))

code, s, _ = run({"D": "silent_once"})
check("silent stall once -> killed by stall rule, FLAKY", code == 0 and s["results"]["testD"]["status"] == "flaky", (code, s["results"]))

code, s, _ = run({"B": "fail_once", "C": "fail_once", "D": "fail_once"}, extra=["--max-flaky", "2"])
check("flaky cap exceeded -> exit 1", code == 1 and s["flaky"] == 3, (code, s["flaky"]))

code, s, _ = run({}, extra=["--budget", "0"])
check("no budget -> NOT RUN, exit 1", code == 1 and s["notrun"] == 7, (code, s["notrun"]))

code, s, _ = run({"__build": "quiet"})
check("silent 6 s build (longer than --stall 4) is not killed", code == 0 and s["passed"] == 7, (code, s and s["passed"]))

code, s, _ = run({"__build": "fail"})
check("build fails twice -> every test NOT RUN, exit 1", code == 1 and s["notrun"] == 7 and len(s["notes"]) == 2, (code, s and (s["notrun"], s["notes"])))

code, s, _ = run({"A": "fail", "B": "fail", "C": "fail", "D": "fail", "E": "fail", "F": "fail"}, extra=["--unhealthy-after", "4"])
check("first 4 tests all fail -> unhealthy runner, exit 75, no retries, rest NOT RUN",
      code == 75 and s["unhealthy"] and s["notrun"] >= 3 and "flaky" in s and s["flaky"] == 0, (code, s and (s["unhealthy"], s["notrun"], s["flaky"])))

code, s, _ = run({"C": "fail", "D": "fail", "E": "fail", "F": "fail"}, extra=["--unhealthy-after", "4"])
check("a streak of failures after passes is NOT a sick runner (normal retry path)", code == 1 and not s["unhealthy"] and s["failed"] == 4, (code, s and (s["unhealthy"], s["failed"])))

code, s, out = run({"A": "pass"}, shard="2/3")
check("shard 2/3 runs only B E", s and sorted(s["results"]) == ["testB", "testE"], s and sorted(s["results"]))

print("ui supervisor self-test:", "PASS" if not fails else "FAIL " + ", ".join(fails))
sys.exit(1 if fails else 0)
