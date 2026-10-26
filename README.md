# ZokerPoolTrainer 0.11 — Native Jump / Masse

Private build repository, prepared 2026-10-21 08:58 Asia/Ho_Chi_Minh.

Native project: `native/ZokerPoolTrainer/ZokerPoolTrainer.xcodeproj`.
Workflow: `.github/workflows/xcode-build.yml` on push to `main` or manual dispatch.
Outputs: unsigned iPhone IPA, Simulator screenshots and build logs.
Research physics; physical-device accuracy and performance are not yet validated.

## Active 0.13 candidate

Branch `feature/0.13-hud-camera` adds G1 HUD/camera changes. Read `native/ZokerPoolTrainer/Docs/G0-BASELINE.md`, `G1-IMPLEMENTATION.md` and `QA-MATRIX-G1.md`. Portable regressions have local evidence; Xcode, Simulator and physical-device gates are open. `MASTER-PATCH-0.13-0.14.md` takes precedence over earlier control requirements.

## Council integration — 26 October 2026

Read `native/ZokerPoolTrainer/Docs/COUNCIL-INTEGRATION-2026-10-26.md`, `AI-COACH-SPEC.md` and `COUNCIL-BACKLOG.json` for accepted/revised review decisions, calibration and Coach requirements. These additions are specifications with PLANNED tasks; they do not close native/device gates or claim a Coach implementation. Keep B hold as default and verify branches before merging.
