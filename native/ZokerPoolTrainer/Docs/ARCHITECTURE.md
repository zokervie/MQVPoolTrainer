# Architecture

0.6: Ball owns a physical quaternion, updated with mean angular velocity across each cloth step. Contact impulses change angular velocity for following time intervals. Bridge returns qx/qy/qz/qw; snapshots/replay include these optional fields. SceneKit applies the reflected-coordinate quaternion to a fixed initial texture pose, with no extra render-time integration.

0.6: bed/deck/trim meshes are prebuilt in TableMesh.dataset. Tools/generate_table_mesh.py (Shapely 2.1+) is only needed to regenerate them, not to build/run on Mac. Mesh normals and UVs are explicit. A connected polygon deck replaces separated rail-cap boxes. Cushion nose coordinates still come from the physics engine.

- `Core/Physics.hpp/.cpp`: deterministic SI-units C++17 world; 2D position and velocity, 3D angular velocity. All physics is independent of SceneKit.
- `Core/BLWorld.h/.mm`: Objective-C++ ownership bridge. No physics mutation is performed on render callbacks or background threads.
- `Rendering/TableScene.swift`: procedural table/balls/cue, PBR materials, lighting, cameras, ideal mirror overlay and recorded trails. SceneKit rigid-body simulation is not enabled.
- `UI/TrainingController.swift`: main-thread CADisplayLink, drill selection, scoring, saved layouts and timestamped replay with position, angular velocity and quaternion snapshots.
- `UI/TouchControls.swift`: spin disk and lock-gated pull/push stroke. Velocity estimate uses the last 90 ms of touch samples, normalized to the stroke pad height.
- `UI/SettingsController.swift`: on-device physics and gesture tuning.
- `Tests/PhysicsTests.cpp`: portable numerical regression and seeded stress checks.

## Deliberate limitations

Fixed stepping and overlap correction approximate impact times; this is not a continuous event-driven solver. Rail contacts use a tilted radial normal and 3D frictional impulse, then discard vertical translation; this is not a deformable rubber model. Pocket capture is a circular 2D basin beyond mouths. Optional ElevatedPhysics.cpp adds experimental vertical motion and elevated-cue mechanics; the original planar solver remains available. These are not measured real-table models. Do not claim real-table equivalence from unit tests.

Replay stores display-loop snapshots with simulation timestamps and physical quaternions; TableScene.replay interpolates positions and slerps orientations. Paths are sampled separately at about 30 Hz. Live display consumes native presentation states. Device pacing, adaptive quality, real-table calibration and measurement import still need validation.

## G1 presentation policy (0.13 candidate)

UI/PresentationPolicy.h is a small C-compatible, header-only policy exposed through BankLab-Bridging-Header.h. UIKit and portable C++ tests use the same settle clock, stroke authorization, smoothstep tween weights and right-HUD dimensions. It neither stores nor changes solver state. TrainingController drives it exclusively from CADisplayLink. TableScene reports outstanding pocket-fall animation. Actual ClangImporter/Swift/UIKit integration is pending Xcode validation; C/C++ test success alone does not establish that integration.
