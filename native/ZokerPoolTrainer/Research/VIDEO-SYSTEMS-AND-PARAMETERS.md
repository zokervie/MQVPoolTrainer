# Video systems and common shot parameters · build 14

## Evidence and scope
Visual frames inspected from the user-supplied videos. Narration has not been transcribed. Perspective, unknown speed/spin and cushion condition prevent unique estimation of physical parameters from these examples. These clips are aiming-system references, not a calibrated physical ground-truth dataset.

| Clip | Visible evidence | Integration |
| --- | --- | --- |
| Make the 8 with a One-Rail Kick - Midpoint Aiming Method | Find midpoint, shift aim, demonstrated shot | New lesson; numerical one-rail query |
| How to use this two rail bank system! | Numbered rails and a ball-face contact marker | New lesson; numerical two-rail query; radius-based contact display |
| 3 cushion kick system (Free Pool Lessons) and previously inspected preview | Parallel Shift; 1.5 + 5.5 = 7, forward tip / backward butt references | Separate lesson, explicitly not interchangeable with Corner-5 |
| The Plus Kicking System | 60+20=80, 50+20=70, 30+30=60, 30+50=80 on its own scales | Separate lesson; no unsupported universal extrapolation |

Numbered diamond overlays and calibrated reproductions of the video layouts are NOT yet implemented. The short clips do not identify a universal coefficient set. Additional visual inspection after the build was started: Pro level 3 rail kick shot (JP.Billiard) displays a ball-face marker on the right and a dotted reference path before the demonstration. The additional 52.18-second preview copy shows the same 0–8 scales and 1.5 + 5.5 = 7 example as the previously inspected preview. Neither adds known impact speed or a measured contact offset; no physical coefficients were fitted from either. These supplemental observations do not change the build-14 implementation.

## A common parameterization
Let state S contain all ball positions, velocities and angular velocities. Define

S(t) = F(S0, theta, v, a, b, alpha, q; T),

where theta is cue direction, v is the requested shot speed, a/b are horizontal/vertical offsets divided by ball radius, alpha is elevation and q is the cue profile. T contains table dimensions, ball radius/mass, sliding/rolling friction, spin decay, cushion normal restitution/friction/contact height, and ball restitution/friction. Direction conventions: viewed from behind the cue, a positive is right and b positive is above center. Normalized contact offset is not a percentage of output spin and is not a number of tip widths.

For the current planar solid-sphere impulse initialization, with direction d and radius R:

v0 = v*d; omega_xy = (5*b*v/(2*R))*perp(d); omega_z = -5*a*v/(2*R).

Both offsets are jointly clamped to the input disk. These are modeling assumptions. This update does not replace the cushion solver with a full compliant Mathavan model, does not add planar swerve/squirt, and does not calibrate the cue profiles. Elevated shots remain experimental.

Aiming systems give geometric starting estimates, whereas F propagates dynamics. Never merge unlike diamond scales into one arithmetic rule. One fixed offset or coefficient cannot stand in for speed-, spin-, angle- and equipment-dependent behavior.

## Inverse kick query implemented
At fixed speed, contact and T, evaluate candidate theta with the same World used for actual play. Stop at the first cue-ball/object contact. Accept only the chosen target after exactly N cushion events, N=1..3; earlier ball contacts reject the candidate. Pocketed cue balls are rejected before a target contact. This tool does not guarantee a legal final outcome or a successful bank/pot.

Search uses 360 angular seeds, then refines eight low-clearance candidates for seven passes. Horizon 10 seconds. Candidate distance is measured to a stationary target with a 2R center-contact allowance; this is an optimization score, not experimental error or a confidence interval. A reported hit is verified by collision events. A failure means no hit found within this finite search, not physical impossibility. The search runs on a separate world off the rendering thread.

## Effect display implemented
Hold the face control to expand. Rings at 25% and 50% of ball radius, orange dashed input boundary (70% planar / 60% experimental 3D), 12 angular ticks, center axes, red contact crosshair and X/Y values. Values are contact coordinates, not measured spin. Orange is a software limit, not a real-world miscue guarantee. Changing solver mode reclamps the displayed offset and updates the shot input together.

## Validation performed
C++ search checks: direct hit, wrong cushion count, absent target, zero speed, reachable one/two/three-rail fixtures, blocking ball and source-world nonmutation. Existing analytic, prediction and practice suites remain required. These are simulation checks, not empirical calibration.

Before claiming real-table accuracy: rectify footage using measured table/ball geometry, track ball centers/timestamps and contact markers, estimate parameters on one set, then evaluate separate held-out shots over different speeds/spins/angles. Report position and exit-angle residuals and uncertainty. Fit cloth and cushion parameters separately to reduce ambiguity. No numerical real-world accuracy is claimed in build 14.

## Primary model references
- Mathavan, Jackson, Parkin (2010), A theoretical analysis of billiard ball dynamics under cushion impacts: https://repository.lboro.ac.uk/articles/journal_contribution/A_theoretical_analysis_of_billiard_ball_dynamics_under_cushion_impacts/9561458
- Existing pooltool model taxonomy (comparison, not copied implementation): https://pooltool.readthedocs.io/en/latest/autoapi/pooltool/physics/index.html
