# 0.12 build 22 — source changes for the next acceptance

## Implemented
- Effect pad beside B at the lower left, with a separate right-edge camera, cue-role, selected-cue, bag and practice toolbar. Elevation remains beside the right toolbar. Expanded effect does not hide the toolbar; retry stays external.
- Post-shot observation mode with a whole-table camera, smooth perspective transition from aim, two-finger yaw/pitch and pinch zoom. Manual camera gestures are not recentered during the shot. Camera menu restores the saved aiming view or a full-table top view.
- Cue geometry now consumes effect X/Y and elevation, chooses the corresponding spherical contact point and rotates the shaft around a fixed rear-hand pivot. The same geometric yaw is used by native strike, prediction and inverse kick-search display. Visual QA checks that the rendered tip reaches the selected surface point.
- Standard pool reference mouths: 114.3 mm corner, 127 mm side; ball diameter stays 57.15 mm and bed stays 1.27 × 2.54 m. Branded table looks remain illustrative, not measured manufacturer CAD/cushion profiles.
- Full-resolution cloth albedo, aperiodic directional fibres, stronger micro-normal/roughness detail and equal physical texture density in both table directions. Contact shadows are darker; high-quality shadow workload is reduced from 4096/32 samples to 2048/16 samples.
- Event sound PCM is cached and generated off the main/UI thread, with bounded playback voices and stale-sound dropping. A per-shot CADisplayLink interval summary is available under graphics diagnostics (not a GPU benchmark).
- Pocket fall heads toward the actual nearest pocket center and keeps regulation ball size while geometry occludes it; no fake 40% ball shrink.
- Bank/kick lesson formulas now describe unfolded reflections, finite-radius contact boundaries, ghost-ball targeting, and spin/throw corrections as dynamic effects.
- Regression suite adds gearing cancellation, under/over-gearing sign changes, mirror symmetry, passive ball impacts and spin carried across two opposite cushions. Existing 3D rail/slate and ball-ball solvers are retained; no arbitrary fixed angle correction is added.

## Validation record
- Local resource, JS research/integration and all C++ physics suites passed, including the new SpinTransfer suite.
- Xcode Simulator and unsigned iPhone Release compilation succeeded in Codemagic run #24, source commit 2dd1a55e51a55c4e2d0c5d697b79fcdd4df3f1bd. All screenshot visibility gates passed; cue-contact and post-shot observation captures were inspected. Touch reach, transition feel and sustained device performance remain on-device acceptance items.
- Real iPhone 14 Pro Max frame time, thermal behaviour and touch reach still require on-device acceptance. Simulator screenshots do not establish these.
- Physics coefficients are estimates until real-table measured velocity/spin/path data is supplied. This release does not claim measured real-world calibration.
- IPA is unsigned under the existing workflow. Deliver inside an outer ZIP for iPhone download; signing is a separate installation step.

## Sources and test boundaries
- WPA equipment reference: https://wpapool.com/wp-content/uploads/2024/01/RECOMMENDED-EQUIPMENT-SPECIFICATIONS.pdf
- Mathavan, Jackson & Parkin, cushion impact analysis (2010): https://doi.org/10.1243/09544062JMES1964
- Kim, collision of spinning billiard balls and role of table: https://arxiv.org/abs/2402.13258
- These references support the mechanisms and dimensional checks; their coefficients are not substituted as a universal calibration for every table.

## Delivered artifact verification
- Codemagic run: https://codemagic.io/app/6ad8240a50a68ff0a344a214/build/6adc7d5e4a72334e32e4ab8b
- Result: finished; duration 5m 39s; Mac mini M2.
- IPA marketing version 0.12, build 22, bundle com.maiquocviet.BankLabS; ZIP integrity passed, no embedded provisioning profile or signature directory.
- IPA SHA-256: eb8dc207b5b94aecb325bc86701b61f80517ec5b902e989cd89eddbc3b109d70.
- Outer delivery ZIP SHA-256: 69418a556448edaded310931e388f9e1515e40d469add6aba6e33d20f063aa02.
- Final source additionally isolates visual probe physics state, fixes the retry title to Lùi cú and updates in-app instructions to the left effect pad/right toolbar.
