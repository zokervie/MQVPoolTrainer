# ZUPE 2.0 — Integration plan / limitations

## Current scope
This is an **isolated JavaScript coder review package** on top of the prior physics review. It **has not been merged into Swift or GitHub** and is **not an IPA**. File paths in `original_reference/SOURCE_MAP.md` point to original code. Do not treat snippets as a full source checkout.

## Major corrections needed before production
1. Establish a **single** SI world frame. Existing native PoolPhysics uses `z` up (`SIMD3`); prior web simulation uses `y` up. Never directly mix without a named transform.
2. Use measured tip position, relative velocity and coupled rigid-contact impulses (cue-ball-slate). Prototype `elevated-cue-3d.mjs` currently applies separate impact and bounce; this can misrepresent a real jump.
3. Integrate curved massé trajectory from dynamic 3-axis ball angular velocity and frictional point contact (not a UI classification). Add miscue limits based on tip material, chalk and impact geometry.
4. Replace test-only box rails with segmented jaws/pockets/table assets from original geometry. Resolve simultaneous rails/corners via a robust time-of-impact solver; ensure momentum/energy checks and no tunneling.
5. Validate all frame changes with an independent reference dataset. **Do not** alter simulated positions to force diamond-system paths or target points. Fit constrained physical parameters on training split only.
6. Verify `bank-physics.mjs` tangent sign and angular-velocity conventions against analytic cross-products before use; validate 2/3/4 rail route target on the entire final flight segment after last rail, not solely the last two samples.
7. Render from authoritative trajectory with interpolated positions and quaternion/sphere rotation, not guessed animation. Call physics with fixed/even-based stepping independent of display FPS.
8. Build real equipment/brands only from verified mass, length, tip hardness, deflection measurements, appearance licenses. `cue-equipment-library.mjs` contains **original fictional design data** only.

## Golden shot protocol
- Profile: measured cloth condition, humidity, cue/ball diameter/mass, true cushion nose height and table profile. Capture initial vector velocity and spin separately rather than assuming finger input equals ball launch.
- 5 speeds × 5 english offsets × 5 incident angles, with repeats; add one- to four-cushion scenarios, masse/jump arc, tip-elevation study. This is a sampling PLAN, not measured data.
- In each record: table geometry, camera transform, impact time, measured positions, time stamps, error bounds, provenance and train/validation split.
- Report mean/median/max radial error, rail-order success, height/landing errors, speed profile error, conservation and timestep convergence. Targets must be predeclared based on measurement uncertainty.
- `fitGolden` is a tiny deterministic coordinate-search **demonstration**. No measurements = no scientific calibration claim.

## Native port map
`CueStrike.swift` add `cueProfileId`, `elevationRad`, `contactOffset`. PhysicsParameters add explicit cloth, jaw, cushion and slate profiles. Introduce `CueBallContactSolver`, `BallSlateContactSolver`, `BallRailContactSolver`, `EventScheduler`, `GoldenShotEvaluator`, `TrajectoryRecorder`. PoolScene only maps coordinates and animates. `StrokeAnalyzer.swift` maps touch into approach velocity at contact but not directly into arbitrary launch speed. Preserve backwards-compatible decoder migration and regression tests.

## No promises without tests
This pack's tests prove internal invariants only; they do not establish realistic massé, certified brand-specific cue behavior, jump height, accurate 4-rail final positions or final iOS build.
