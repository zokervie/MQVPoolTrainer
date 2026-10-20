# ZokerPoolTrainer 0.9 Remastered — Locked product specification
Date: 2026-10-20. Source of truth: user's screenshots of Zoker v0.9 and ShootersPool lighting references, and explicit conversation requirements. This supersedes the short prior handoff. Do not label a build Remastered Complete unless all gates pass.

## Mandatory R1 — 0.9 bridge & input (block release until all pass)
- 0.9 input layout, not a reskin of new HUD. B at bottom left, ball effect lower right, fine-angle translucent slim line bottom center, menu top right; cue library and elevation next to effect, not large panels.
- Press AND HOLD B locks cue direction, hides all HUD except B/table/balls/cue and optionally almost invisible guide. Finger 2 can drag anywhere on unobstructed table. Releasing B returns the HUD without firing a shot. Ensure multitouch gesture delegates do not cancel each other.
- Continuous stroke: pull backward; one/multiple feather cycles; push forward crossing contact plane causes strike. Tap/release never fires. Distinguish camera pan, zoom, ball-in-hand placement, and spin adjustment. Train 7 visible strength bands with continuous input; precise soft shots require no minimum jump in power.
- Capture timestamped/coalesced touch points, calibrate contact velocity using window fitting; not event cadence. Must be deterministic in replay. Maintain former .9 input feel without modifying working Physics.swift.
- Test on real iPhone: 2-finger B hold + other finger stroke, cancellation, sub-10% soft touch, force-repeatability, touch anywhere, left-hand configuration.

## Mandatory R2 — 0.9 table geometry and lighting
- Reuse .9 table silhouette, camera and calm atmosphere. Repair bulging wood rail, physically coherent cushion nose, jaw mouth, pocket shelf, leather/rubber liner and dark well. Never fix visible jaw without updating matching collision geometry; verify ball radius and realistic pocket entry.
- ShootersPool pictures are artistic lighting/material references only. Use licensed or original art. Bright table and distinct vivid glossy numbered balls; realistic broad highlights, rougher wood, soft layered contact and cast shadows; stable exposure and legible rails.
- Multiscale, tiled cloth microfibers: base color, fine normal, roughness and direction-dependent nap, mipmapping/aniso, no moiré/texture blur at zoom. Cheap quality fallback for iPhone. Cloth hue never changes rolling friction.
- Visual regression screenshots from same camera & cue-ball poses, close-zoom, exposure and near-pocket shadow.

## Mandatory R3 — cue library & elevation
- In menu/tool drawer: real 3D geometry + rotating preview; playing/break/jump cue types, color/type/mass/tip/shaft configurations. Brand logos only with permission and substantiated measurements; fictional Zoker cue presets must be labeled simulated.
- Changing cue must swap scene cue mesh and selected profile (not metadata-only). Pair jump cue with usable elevation/dart + pendulum controls; playing cue with high elevation/side effect can masse. Outcomes must come from simulation, not selection labels.
- Full jump/masse contact physics and measured calibration still research-gated: do not claim true physical fidelity until validated on independent shots. Keep existing working solver as default with feature-flagged experimental solver.

## R4 — physics preservation & quality
- Preserve current ball-ball/bank/kick/drill results, test golden shots 1–4 rails; separate visual changes from simulation. Add 7-level force labels as UI-only bins over continuous curve. Full-power reference is measured typical player cue-tip speed, NOT universal bounce constant. Use held-out data to validate spin/energy/swerve.
- Add renderer replay decoupled from physics timestep, proper rolling quaternion rotation, contact shadow distance, pin-quality debug mode.

## Build gates
1. Unit & integration tests PASS; iOS compile PASS, no conflicting gestures.
2. Simulator screenshot comparison for old/new R1 + table/pocket close-ups, and stable 60fps.
3. Physical iPhone multitouch acceptance PASS (manual result logged).
4. IPA signed/unsigned status explicitly labeled. Non-main branch artifact must never overwrite stable Release.
5. CI success != product completion; display detailed implemented / not-yet-implemented checklist per build.

## Current verified branch status
As of 2026-10-20 compare(main, feature/zoker-09-remaster-build): 6 commits modifying only Settings.swift (2 additions), PoolScene.swift (4 replacements), GameView.swift (R1 interim), TableView.swift (R1 interim), and short previous doc. NOT full Remastered. Need complete native gesture state machine; interim pan recognizer crosses zero before lift and uses per-sample velocity only; must improve to prevent false triggers.
