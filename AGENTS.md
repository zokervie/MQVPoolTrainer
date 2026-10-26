# Zoker Pool Trainer — Codex execution contract

Work only in this repository. Read Docs/MASTER-PATCH-0.13-0.14.md,
Docs/COUNCIL-INTEGRATION-2026-10-26.md and Docs/AI-COACH-SPEC.md under
native/ZokerPoolTrainer before changing requirements.

Continue feature/0.13-hud-camera. Inspect remote SHA and changes before writes;
preserve main and user data. UIKit/SceneKit renders the authoritative native
C++ world; never replace the solver with SceneKit physics or tune friction to
hide rendering errors. B remains hold-to-lock by default.

First close G1: actual Swift/ClangImporter build, single-finger aim gesture,
runtime camera/HUD probes, XCTest UI gestures, then physical-device QA.
Use Tools/run_acceptance.py on Mac; --portable runs only portable checks.
Automatic Mac acceptance requires ZOKER_ENABLE_MAC_RUNNER=true after a runner
is configured. Repository Settings reported no configured runners on 26/10/2026;
hosted Mac was blocked by billing. Use the root Codemagic workflow as fallback.
A queued job is not a running Mac. Do not claim remote control of a
machine without assigned-runner evidence. Avoid duplicate hosted/Mac builds.

After G1: implement cue clearance/contact clamps and seeded random, measurement
fixtures and immutable ShotRecord/offline Coach before online. Coach must label
uncalibrated solver advice; measured video and synthetic regression are separate.

Every report must name source SHA, dirty patch hash if applicable, test commands,
logs/artifacts, signing status and remaining gates. Never call portable tests
Swift/UIKit/device verification. No gate closes from documentation alone.
Unsigned IPA is an acceptance artifact, not an installable signed distribution.
