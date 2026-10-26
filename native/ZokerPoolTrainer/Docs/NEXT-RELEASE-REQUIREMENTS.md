# Zoker Pool Trainer — saved product requirements

Current precedence: MASTER-PATCH-0.13-0.14.md. G1 code and portable policy tests exist; Xcode/UIKit/device acceptance remains pending.

Updated after the 0.12 / build 21 review. This file is the persistent acceptance checklist for the next app review.

## Training library

- Organize practice into cue-ball kick (1, 2, 3 rails), object-ball bank (1, 2, 3 rails), and control / table-measurement groups.
- Provide beginner, intermediate, and advanced sample layouts for each 1–3 rail kick and bank family.
- Each lesson shows its ball layout, rail-count objective, an initial geometric aiming construction, and a repeatable 10-shot practice routine with a 7/10 target.
- Describe mirror-image / unfolded-table methods as starting estimates. Rebound loss, speed, cloth/cushion friction, spin, throw, and cut angle can shift the real result; do not label the preset angle as a calibrated solution.

## Table, camera, ball and pocket visuals

- Keep the full-screen landscape table, matte cloth, brand/model names, standard cushion diamond references and the no-label playing surface.
- Preserve the distinct 20 table looks and allow a player to choose a cloth tint or return to the selected table's material color.
- Keep fine non-periodic cloth texture and add detail at material edges without drawing guide lines across the playable bed.
- Make cue-ball spots round and even at their edges. Preserve soft, dark contact shadows that broaden and weaken as a ball jumps.
- Allow pinch zoom over the current wide range and two-finger camera orbit during live ball motion so players can inspect a path.
- Animate pocket capture inward and down, with easing and scale, while the native solver remains the authority for whether a ball is sunk.

## Sound and motion

- Play a distinct cue, ball-to-ball, cushion, and pocket sound from native physics events. Scale transient level with event impulse/speed and pan by event position. Keep the sound toggle and avoid clipping.
- Ball motion should remain interpolated for display and 60 fps; never alter physical coefficients to smooth the render.
- Use original synthesized or explicitly licensed/attributed audio. Do not extract arbitrary YouTube recordings without the rights holder's permission.

## Acceptance and remaining validation

- Run resource, research, native physics and presentation regression checks, then compile iOS Simulator and unsigned iPhone Release in Codemagic.
- Capture table, camera, training-catalogue and lesson-detail screenshots and inspect for legible controls, visible playing surface, texture and shadows.
- Verify IPA ZIP integrity, bundle identifier, marketing/build versions and artifact digest before delivery.
- Real-table accuracy still requires measured shot data at multiple speeds, spins and rail incidences. Simulator QA cannot replace touch, frame-rate and thermal evaluation on a physical iPhone/iPad.


## New review findings — dimensions, gear effect, cue alignment and motion

- Recheck the rendered table-to-ball-to-pocket scale against the selected discipline's standard physical dimensions. For WPA pool, use a 57.15 mm nominal ball diameter and the table's playing-surface dimensions measured cushion-nose to cushion-nose; verify corner and side pocket mouth widths from the selected table profile. Apply one world-to-render scale and use the same ball radius in collision, pocket capture, cue contact and mesh geometry. Add a top-camera calibration scene with a known 2-ball-diameter spacing and near/far perspective comparison.
- Improve cloth detail with non-periodic fine albedo plus subtle directional nap in normal/roughness maps and mipmapping; avoid broad repeating stripes. Judge on-device at both wide and close camera distances.
- Diagnose motion judder on iPhone 14 Pro Max with frame-time and dropped-frame capture while balls roll. Preserve the fixed-step physics state; improve only presentation timing/interpolation and render workload. Verify smooth 60 Hz motion on-device rather than inferring it from Simulator screenshots.
- Rework cue/effect alignment in one shared 3D coordinate frame. The spin-pad selection defines a point on the cue-ball surface; the rendered tip must meet that point, while the cue shaft and rear-hand pivot follow the same shot axis. The orbit/aim camera and UI spin indicator must use the same basis and sign convention. Add tests/screenshots for center, left/right, top/bottom and combined offsets at three camera modes.
- Model object-ball throw and spin transfer from relative contact-point slip, not a fixed “opposite spin” rule. At ball-ball impact, compute normal and tangential impulses with the current angular velocities and Coulomb friction, apply equal/opposite impulse and the resulting torques to both balls, and preserve the planar table constraint. The sign and magnitude of object-ball side spin depend on cut direction, cue-ball spin, impact speed and friction.
- At each cushion impact, compute contact-point velocity from translation plus angular velocity, solve normal restitution and tangential Coulomb friction, then apply the impulse to translation and angular velocity. The resulting cushion exit angle can narrow or widen depending on side spin, incidence, speed, cushion profile and table friction; it must emerge from the model rather than an unconditional angle correction. Carry the spin into the next rail collision.
- Validate with isolated ball-ball tests (head-on, both cut directions, gearing outside spin, over/under-geared spin, follow/draw), followed by one-rail and two-rail object-ball tests. Assert momentum/energy bounds and symmetry where applicable. Record high-speed video/track-mark measurements from a real table across multiple speeds and offsets before claiming calibrated accuracy.
- Keep mirror/unfolded-table constructions as geometry-only initial guesses for lessons. The final predicted route must use the coupled collision solver and label unmeasured table parameters as estimates.



## Consolidated repair plan for the next acceptance build

Use this section as the ordered implementation and sign-off list. Do not mark a physics item calibrated from simulator screenshots alone.

### P0 — Correct scale and aim/effect geometry

- [ ] Keep the WPA 9-foot playing bed at 1.27 × 2.54 m and nominal pool-ball diameter at 57.15 mm unless a different table/game profile is selected. Audit rendered mesh radius, pocket mouths, rail noses, cue-tip contact, shadows, and collision radius against the same world scale.
- [ ] Match pocket-mouth geometry to the chosen table profile; use WPA reference ranges for a standard pool table and test corner versus side pockets separately.
- [ ] Fix cue/effect synchronization using one documented table-local coordinate basis. The effect-pad point, visible cue-tip contact point, cue shaft axis, rear-hand pivot and aim vector must agree for center, left/right, top/bottom, and combined offsets.
- [ ] Keep the rear-hand pivot fixed while moving the cue contact point as the selected strike point changes. Verify camera projection does not change the logical spin sign or displace the contact point.

### P1 — Validate coupled ball-ball and ball-cushion physics

- [ ] Trace object-ball translational velocity and 3D angular velocity through oblique ball-ball impacts. Compute contact-point relative slip, normal restitution impulse, and tangential Coulomb-limited impulse; apply equal/opposite linear impulses and corresponding torques to both balls.
- [ ] Verify sign convention with mirrored left/right cuts and mirrored cue sidespin. Do not encode an unconditional opposite-spin rule: gearing, under-gearing and over-gearing must arise from relative slip and may yield different object-ball spin.
- [ ] At every cushion hit, include translation and angular velocity at the elevated cushion contact point; solve normal and tangential impulses with the selected rail restitution/friction, update angular velocity, then carry the result into subsequent rail contacts.
- [ ] Reproduce the illustrated object-ball route: ball-ball impact transfers spin; first cushion changes tangential velocity/spin; the outgoing route toward the next/opposite cushion is computed from that new state. Treat the hand-drawn route as an observation to compare, not proof of an exact curve.
- [ ] Add deterministic regression cases for head-on, shallow/steep cuts, left/right gearing outside english, under/over-geared english, follow/draw, one-rail and two-rail object-ball routes, mirrored geometry, and multiple impact speeds.
- [ ] Assert non-penetration, finite state, bounded energy loss, mirrored symmetry, correct rail count, and prediction/live solver consistency.
- [ ] Keep coefficients marked as estimates until matched to measured real-table trajectories. Gather high-speed video or measured before/after velocities and spins on known table/cloth/cushion profiles before claiming real-world calibration.

### P2 — Improve appearance and motion on device

- [ ] Compare top-down and perspective views against known ball-diameter spacing and rail/pocket dimensions. Correct mesh/camera/material mapping rather than changing correct physical units to make the screenshot look larger.
- [ ] Replace broad/striped-looking felt with subtle high-resolution, non-periodic cloth albedo and fine directional nap in normal/roughness maps. Check close zoom for texture repetition, aliasing and moire.
- [ ] Measure rolling smoothness on a physical iPhone 14 Pro Max at 60 Hz. Capture frame-time/drop data during long rolls and after impacts; improve display interpolation/render workload without changing fixed-step physics.
- [ ] Inspect contact shadows and ball spots at wide and close zoom; keep shadows soft, detailed and dark enough to ground rolling balls, with each spot round, even and attached to the rotating ball.
- [ ] Verify jump/flight rendering separates ball height from its table shadow and avoids visible position jumps on takeoff and landing.

### P3 — Research-backed training geometry and drills

- [ ] Review and cite geometry sources for bank/kick lessons: mirror/unfolded-table construction, ideal equal-angle reflection, diamond/diamond systems, and limits from pocket openings, finite ball radius, speed-dependent rebound, spin and friction.
- [ ] Keep ideal geometric construction separate from dynamic prediction. The lesson teaches a starting aim point; the native solver predicts the path under current settings.
- [ ] Include beginner/intermediate/advanced drills for 1-, 2-, and 3-rail object-ball banks and cue-ball kicks, with layouts, target zones, route diagrams, shot routines, and honest accuracy labels.
- [ ] Include table-profile and cloth/cushion calibration tasks so lessons do not imply one universal diamond formula is exact on every table.

### Required acceptance evidence

- [ ] All native physics, geometry, calibration, presentation and resource checks pass.
- [ ] Xcode simulator compile and unsigned iPhone IPA build succeed in Codemagic for the recorded commit.
- [ ] Inspect screenshots for overview, aim/effect combinations, close felt, rolling shadows, 1/2/3-rail bank/kick lessons, and the illustrated two-cushion object-ball route.
- [ ] On a physical iPhone 14 Pro Max, verify touch-to-cue alignment, 60 Hz roll smoothness, camera orbit/zoom and close-range cloth/spot quality.
- [ ] Archive the measured validation set and table profile. If real-table measurements are unavailable, label the build as a simulation estimate, not physically calibrated.
- [ ] Check IPA archive integrity, bundle ID com.maiquocviet.BankLabS, version/build number, and SHA-256 before delivery.


## Required camera and landscape control revision (24 October 2026)

- [ ] Place the effect pad immediately RIGHT of elevation, with B independent at the left. Effect expansion must block arming B/stroke; respect landscape safe areas.
- [ ] Use a right-side Tools flyout for cue role/bag/ball placement, with View and Undo accessible above elevation/effect. Exercises have one entry in Menu; keep the toolbar reachable during effect expansion.
- [ ] Keep external Undo/Retry accessible so an unsatisfactory shot can be replayed from its exact previous layout and ball orientations.
- [ ] After striking, allow the player to observe the whole shot: zoom out to show the table, orbit freely with two fingers, and switch top/overview/aim cameras while balls are moving.
- [ ] Default post-shot observation must keep the route readable without an abrupt camera snap, accidental re-aim, auto-recentering that fights a manual gesture, or unintended stroke input.
- [ ] Preserve manual observation while balls move; after uninterrupted 0.5-second rest and completed pocket falls, return smoothly to Aim3D in 0.45 seconds. Defer during replay, spectator turns and active camera gestures.
- [ ] Verify camera controls and interpolation during long rolls, bank/kick 1–3 rails, jumping, pocket drops and replay on a physical iPhone 14 Pro Max.

The detailed Vietnamese acceptance register is in NEXT-ACCEPTANCE-2026-10-24.md.
