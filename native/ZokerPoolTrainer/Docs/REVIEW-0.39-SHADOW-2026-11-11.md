# Zoker Pool / Trainer 0.39 — code and UI review

## Exact baseline and acceptance status

- Repository: `zokervie/MQVPoolTrainer`.
- Owner's candidate: `ci/native-0.39`, Actions run **120 / 43007731406**, source **849ead72456e93cd32f35090d654ea94f8546240**.
- `zoker-ipa-candidate-120`: artifact **13850120025**, confirmed present and unexpired on 11 November 2026.
- Working base: **9e86c9b94c50648702e570ce6ae53f76484a9fa9**. Compared directly with candidate SHA: only `CLAUDE.md` and the acceptance form changed; native code is identical.
- Run 120 report: `PASSED_SIMULATOR_UNSIGNED`, `physical_device: NOT_RUN`, `signing: UNSIGNED_ONLY`. A green build does not establish smooth motion on an iPhone.
- This patch is on `ci/native-0.39-shadow-pacing`; main and the owner's candidate branch are preserved.

## Findings, ordered by impact

| Priority | Finding / evidence | Consequence | Action |
|---|---|---|---|
| P1 | `FramePacer.fraction` rounds to an integer within 0.35 of a sample boundary; renderer adds an assumed future refresh and extrapolates up to 2.0 | Continuous motion becomes plateaus and jumps as callback phase varies. Around collisions the guessed path can overshoot and then correct. These are demonstrable code defects; whether they account for all device stutter is unverified. | Replace with continuous buffered interpolation and no extrapolation. |
| P1 | Pacer retains only the newest two poses, even though producer/render callback order can change | Merely clamping the fraction would still hold frames when the producer runs ahead. | Retain eight timestamped poses and bracket the requested render time. |
| P1 | Existing smoothness report samples only CADisplayLink target intervals | Cannot separate producer stalls from irregular SceneKit callbacks or establish actual GPU presentation time. | Record render callback intervals, starvation and sample age during the live shot. |
| P2 | Replay sampler converts all balls into Objective-C dictionaries/Swift values at 240 Hz just to choose a recording interval | Unnecessary main-thread allocation at medium/low speed; potential contributor to stalls, no device CPU profile yet. | Native scalar `maximumSpeed`; allocate full states only when recording a sample. Fast 240 Hz recording is retained. |
| P2 | Live audio reads/boxes the complete event history each frame | Work grows with collision count, especially after a break. | `events(since:)` retrieves only the new tail. Existing full-event consumers remain compatible. |
| P2 | `TrainingController.swift` is ~2,800 lines and owns input, physics scheduling, rendering, network, replay and menus | Timing changes have a wide regression surface. | Follow-up: separate shot scheduling/recording and HUD state from the controller, with native regression gates. Avoid a broad rewrite during a motion fix. |
| P2 | `TableScene.swift` mixes mesh/material generation, ball presentation, pockets and camera (~1,800 lines) | Hard to profile individual presentation costs or establish one owner for scene mutations. | Follow-up: split immutable resources from ball/camera presenters. |

## Patch behavior

- Render at a fixed one-refresh presentation delay, initialized for the selected frame rate at live-shot start: 16.7 ms at 60 Hz, 8.3 ms at 120 Hz. The delay is presentation latency, not a change to physics time. It stays fixed during the motion segment; changing it on a missed refresh would move the sampling clock backwards.
- Store the pre-strike pose and up to eight samples per ball. Interpolate position, height, orientation and contact-shadow position on the same clock. No quantization window, guessed forward velocity or extrapolated rail/jump position.
- If the producer truly stalls beyond the buffer, hold at the latest known pose and count the missing sample. Interpolation cannot recreate absent frames or repair a GPU stall.
- Clear tracks on layout/replay discontinuities. Preserve serialized reset/removal versus render writes so a completed reset is not overwritten by an in-flight old pose.
- Capture diagnostics only during live shots; idle rendering cannot inflate the report. Available through Hình ảnh → Nhịp hiển thị cú vừa đánh.
- C++ solver, fixed 1/960 s step, friction, restitution, spin, cue policy and shot outcome are unchanged. CPU allocation reductions affect bridge/recording work only.

## UI review from actual run-120 artifacts

Examined `shots/native` SOURCE.txt (`ci/native-0.39 849ead7 run 120`), `aim.png` and `g1-hud-expanded.png`, plus layout/hit-test source. These are Simulator images, not owner-device screenshots.

| Area | Assessment | Proposed next change |
|---|---|---|
| B hold and effect pad | Clear paired thumb targets; expanded effect pad is usable. Keep hold-to-lock default. | Preserve current placement for this patch; verify thumb reach on device. |
| Six-item right rail | Undo and camera are useful; replay/place/add/equipment occupy persistent space and compete with the table. | Keep Undo/Camera visible; group lower-frequency tools into one expandable button. Native hit-test and gesture tests required before moving controls. |
| Cue-type row | Four visible modes add clutter and can accidentally switch technique. | Consider one active cue selector opening the four choices, while preserving direct access in training mode. |
| Visual hierarchy | Gold theme is consistent; small text and translucent controls reduce legibility over cloth. | Improve contrast and labels for key actions; test on small iPhone and left-handed layout. |
| Camera/aim view | Cue and cue-ball dominate the near view. Existing occlusion fading and manual pitch help, but a static screenshot cannot verify their behavior in motion. | Device QA: target visibility with cue ball near a rail, at normal and raised cue angles. |
| Settings | Five task-based groups are more understandable than technical categories. | Keep advanced physics and render diagnostics secondary. |
| Touch/safe area | Runtime probes check rectangles and hit paths; code deliberately gives back 35% of horizontal safe-area inset. | Confirm notch/home-indicator clearance on real devices; a rectangle test alone does not verify comfort or visibility. |

The UI is functional but not yet a polished professional trainer. No wholesale layout changes are mixed into this motion patch.

## Validation and remaining gates

Local Linux command:

```sh
python3 native/ZokerPoolTrainer/Tools/run_acceptance.py --portable
```

Result: **PASSED_PORTABLE**, report `ACCEPTANCE-9e86c9b94c50-20261111T145812Z.json`; 29 C++ suites plus JS, resources and gesture checks passed. This confirms portable regressions on the unchanged solver; it does **not** compile Swift/UIKit/Objective-C++ or prove device smoothness. The final patch also requires the native CI below.

Added real native `FramePacerTests.swift`, compiled with production `FramePacer.swift` and real SCNNodes by `Tools/run_replay_checks.sh`. Only the preference provider is stubbed. Cases: fractional phase, 60/120 Hz alternating callback order, shadows, rebound, jump height, rotation, producer stall, duplicate timestamp, removal, clear, backward seek and node replacement. The old pacer must fail the continuous-phase test.

Native verification command (Mac / Xcode):

```sh
python3 native/ZokerPoolTrainer/Tools/run_acceptance.py
```

At review authoring: native patch tests/build are **PENDING CI**, not declared passed. IPA signing remains **UNSIGNED_ONLY** under the existing build pipeline. No physical device is attached to this Linux executor.

Device acceptance still required on the owner's iPhone/iPad:

1. Same saved layout/input in old and new build; 0.5 m/s straight roll, 15-ball break, three-rail shot with side spin, jump, pocket and replay. Test 60 Hz first, then 120 Hz if enabled.
2. Cold start and 10-minute warm session, balanced/high graphics separately. Check normal play and camera orbit/pinch while moving.
3. Capture the app-update and render p50/p95/max, starvation count/sample age and screen recording. A 30/60 fps recording alone cannot resolve all 120 Hz frame pacing.
4. Undo while moving, reset, replay seek/pause, background/resume, Wi-Fi host/guest, turn controls and audio-event sequence must not regress.
5. Remaining limitation: ball pacing is render-clock based; camera and pocket animations still update on the main display link. If device evidence isolates them, move their presentation into the same render-time packet rather than adjust friction or add more FPS switches.

## Timing references

- Apple: [SCNSceneRendererDelegate.renderer(_:updateAtTime:)](https://developer.apple.com/documentation/scenekit/scnscenerendererdelegate/renderer(_:updateattime:)) — per-render updates and system-time parameter.
- Apple: [CADisplayLink.targetTimestamp](https://developer.apple.com/documentation/quartzcore/cadisplaylink/targettimestamp) — intended next display time; requested FPS alone is not a measurement of displayed frames.

Code patch SHA-256 (excluding this review): `7e83c8de686b99dd873c32c82a16bec2d8bd3b39b8860a905c28cd959d657af5`.
