> Integration note (21/10/2026): this README describes the historical coder kit. The updated app now embeds these modules in an offline research Lab; read ../../START-HERE-VI.md and Docs/INTEGRATION-0.10.md at the project root for current scope. Native iOS compilation has not been run.

# Zoker Pool Trainer — code review kit: table, touch, 2–4 cushion physics
Date: 2026-10-20

## What is in this zip
1. `original_reference/SOURCE_MAP.md` gives **pinned links to the exact original** 3D table geometry/render code, iOS controls, JS/Swift physics, tests.
2. `original_reference/*-extract.js` contain **short genuine verified source excerpts**, not complete upstream copies.
3. `enhancements/bank-physics.mjs` NEW self-contained candidate code: rail impulse with speed-dependent restitution and vertical-spin coupling, cloth sliding/rolling, collision record, up to four rail events and diamond coordinates.
4. `enhancements/stroke-control.mjs` NEW self-contained touch sampling and impact gate.
5. `tests/test.mjs` initial automated regression checks.

**Important:** Source version 0.9 has NOT been confirmed. This kit uses a pinned snapshot of `MQVPoolTrainer` with verified files and distinguishes newly-authored code from original code. The enhancement is an engineering prototype; it has not been calibrated against real tables, has not been compiled into the iOS app, and is not a production-accurate 2/3/4-rail solver.

## How to run the tests
Requires Node.js 20+ (18+ with `Array.at` works):

```bash
node tests/test.mjs
```

## Integration procedure (for coder)
- Retrieve each full original from SOURCE_MAP first. Pin revision; **do not replace** existing `Simulation` with this standalone reference prototype.
- Keep single truth in physics; geometry defines actual rail segments, cushions interrupted by pockets and jaws, pockets captured separately.
- For exercises that explicitly call 2 / 3 / 4 cushions, simulate full shot and inspect the `cushion` events in order. Count **actual contacts** (deduplicate repeated substeps); verify legal contacts, ball position, and shot objective.
- Treat diamond/Corner-5 and other systems as approximate AIMING hypotheses, not exact collision laws. Refine aim through actual physics output with spin, speed, cloth and rail parameters. The current `searchBankRoute()` is an illustrative coarse candidate search only; its final-target score is *not* yet a validated route solver. Replace with segment-wise closest approach on the FINAL leg, using event times or adaptive root finding.
- A proper rail strike needs **3D contact geometry** (cushion nose height, possible bounce/hop), contact patch, variable coefficient of restitution, friction limiting; this demo only resolves planar translation + vertical-axis spin.
- Calibrate muRoll/muSlide/eRail/muRail from measurements and estimate uncertainty. Manufacturer brand alone is insufficient to determine physics profile.
- Run slow, medium, hard × center/top/bottom/left/right spin × 2/3/4 rail, at least 100 reproducible trajectories, and compare with measurement; reserve a separate validation set.
- Rerun existing upstream `test/physics.test.js`; match native Swift against JS before merging.
- Render uses fixed simulation timestamps and position/rotation interpolation; do not derive ball movement from display FPS. Sync rolling quaternion to angular velocity (not to distance alone if ball is sliding).

## Physics context
Ball kinetic friction: sliding accelerations proportional to `-muSlide*g*unit(contact slip)`; rotational coupling uses the sphere inertia 2/5 mr². For rolling resistance: `dv/dt = -muRoll*g` (simplified). For a rail with inward/outward normal, resolve normal and tangential impulses with finite Coulomb friction. Side spin changes tangential contact speed and hence rebound angle; faster approaches change impulse and effective restitution. Rail nose height also induces vertical torque/hop, which planar formulas cannot reproduce. Diamond systems are training approximations conditional on standard reference conditions.

## Explicit limitations/known TODOs
- `simulateRails` models continuous position interpolation during each *fixed time-step*, not full simultaneous multiple contacts or rail-jaw junctions.
- Rail collision at corners is approximate. No ball-ball collisions, pockets, jump, 3D cushion, swerve or cloth anisotropy in the new module.
- Rolling and sliding transition uses an approximate switching rule; validate energy/momentum, corner cases and contact impulse sign.
- No claims of real-world precision. No app build produced.

## NEW: Elevated cue / jump equipment review (2026-10-20)
- `enhancements/elevated-cue-3d.mjs`: NEW standalone 3D impact-and-slate demonstration with 3 **fictional Zoker** equipment presets, off-center cue contact, inertia, gravity, slate restitution, tangential friction, flight sampling, reference loss. This module does **not** modify the GitHub repo or existing native Swift app.
- `tests/elevated-cue.test.mjs` checks direction of cue impulse, impact-generated vertical rebound, determinism, and invalid contact offsets.
- Source audit: `Zoker-Pool-Trainer` v0.2.1 `CueStrike.swift` has aimAngle, cueSpeed, tipVertical, tipHorizontal and explicitly says cue elevation is planned for stage 2. No complete branded equipment library or physically verified jump/massé module was found in the reviewed core files. Other repository snapshots may contain different features.
- **Important limitation**: `masse-candidate` is a UI classification only. Full massé curved ground path, rigid 3D cue–ball–slate simultaneous collision, squirt, cushion nose impulses, legal jump verification, and jump clearance over a particular obstacle are NOT implemented or validated. Never advertise this prototype as realistic massé or real manufacturer performance.
- The current simple slate rebound is an approximate 2-stage model (downward impulse then floor rebound); replace with coupled contact solving and high-speed video calibration before production.
- Named manufacturer models / logos / paint schemes have NOT been imported. Fictional Zoker presets avoid unsupported performance data and branding permission issues.
- For rail exercises use actual shot trajectory and ordered contact events. The same nominal diamond coordinates do not guarantee identical 2/3/4-cushion outcomes with varying power, cloth, rail friction or side spin.
- Recommendation: calibrate at fixed shot references (known speed, contact offset, cue elevation, humidity/cloth/table profile) and fit continuous bounded parameters; keep training measurements distinct from validation; never mutate physics just to force formula geometry.

## ZUPE 2.0 research additions (2026-10-20)
- `enhancements/golden-calibration.mjs`: strict sample input and measured-reference train/validation evaluator, constrained prototype fitting.
- `enhancements/cue-equipment-library.mjs`: original fictional cue catalog; no licensed brand models or assets.
- `enhancements/simulation-recorder.mjs`: one-way, read-only trajectory-to-display interpolation.
- `golden/golden-shot-schema.json`: sample schema only; NO measured Golden Shots are supplied.
- `tests/golden-calibration.test.mjs`: synthetic-only deterministic regression test.
- `docs/IMPLEMENTATION_PLAN.md`: precise gaps, architecture and native port instructions.

**Not merged to repo; not a compiled iOS source patch.** See explicit limitations in the plan.
