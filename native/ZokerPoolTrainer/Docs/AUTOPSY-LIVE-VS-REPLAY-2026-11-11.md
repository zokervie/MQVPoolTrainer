# Live shot versus slow replay — video autopsy, 11 November 2026

## Evidence and limits

Owner supplied `ScreenRecording_11-11-2026 22-36-23_1.mp4`: 28.8667 s, 866 frames, 682×512, encoded at 30 fps. This file includes live play and in-app replay, making it a better comparison than separately transcoded clips. Installed source/build is not visible in the recording and is not inferred from its filename.

Frame inspection and a pixel-difference check over the table region x=100…659, y=60…399 found a periodic near-repeat in live play (11.6–16.0 s) that is absent as a fixed six-frame pattern in replay (22.5–26.5 s). Median mean absolute RGB difference by frame index modulo six:

| Phase | Live (132 frames) | Replay (120 frames) |
|---|---:|---:|
| 0 | 0.0089 | 0.1070 |
| 1 | 0.1757 | 0.1188 |
| 2 | 0.1125 | 0.1035 |
| 3 | 0.1293 | 0.1206 |
| 4 | 0.1187 | 0.1050 |
| 5 | 0.0435 | 0.1115 |

These values measure encoded image change, not true FPS, CPU time, ball speed or GPU presentation. Camera, replay rate and visible ball size differ; the table is not a performance benchmark. It supports a live-only cadence problem and weakens a whole-file fixed-frame-conversion explanation. It does not isolate one function as the cause.

## Code findings

1. Live simulation, replay recording, Objective-C dictionary conversion, audio/event dispatch and scene publication share `TrainingController.tick` on the main thread. Replay reads immutable recorded states and skips the solver/recorder. It can therefore look smooth even when the original computation missed display deadlines. Native physics time in `frameTimes` does not preserve UI/render callback stalls.
2. A particularly relevant live-only path changes the multiline `statusLabel` every >0.2 seconds, including when its menu is hidden. The label is part of the menu Auto Layout stack. Layout invalidation can reach `viewDidLayoutSubviews`, which calls `layoutRightHUD()` and `wakeRendering()`. This is a concrete frequency match to the video, not measured proof of a layout stall.
3. Both modes call the SceneKit pacer. Previous rounding/extrapolation defects still warrant the existing patch, but cannot alone explain why one mode consistently fares better. Different input sample streams and workload matter.
4. Live pacing interpolates orientations with shortest-path quaternion slerp. Replay additionally integrates recorded angular velocity and distributes the endpoint residual (`TableScene.replay`). At fast spin, angular motion can exceed 180 degrees per display interval, so these paths can display different rolling direction/smoothness. This can explain rotational wobble; it does not explain every translational hold/jump. A shared spin-aware interpolator is a separate required follow-up.
5. Even the replay's 1× button can be multiplied by automatic cinematic/ending slow motion (`endingRate`, `slowMotion`). A decisive A/B must disable automatic slowdowns and use the same camera and viewport; the present clip is not that controlled A/B.

## Narrow corrective patch

Based on source `9de1cc48d8417aa63663a5a1ec63d0ed909e3cec`, update the live status label only when `menuOpen` is true. The hidden menu no longer causes 5 Hz text/intrinsic-size invalidation during normal play. `finishShot` still writes the final result; opening the menu during a shot resumes visible live status. No solver parameter, shot state, replay sample or network permission is changed.

This is a low-impact correction and a targeted test of the 5 Hz hypothesis. It is not declared a confirmed cure. Native build/device verification remains pending for this follow-up; run 122 is for the parent source and must not be attributed to this patch.

## Next verification and architecture decision

- A/B the parent and this patch on the same device/layout/camera at 1×, then replay with cinematic slowdown disabled. Track actual layout callback count, render intervals and producer starvation. If the periodic stalls disappear with hidden status updates gated, retain the patch and confirm no menu-status regression.
- Instrument simulation, replay capture/bridging, event/audio work, HUD/layout and scene publication separately. Measure CPU duration rather than only CADisplayLink timestamps. One 60 Hz frame has a 16.7 ms budget.
- If simulation/recording exceeds budget, move the authoritative solver and recorder to one serial worker with ordered strike/reset commands; publish immutable timestamped typed snapshots in a bounded presentation buffer. SceneKit consumes snapshots without waiting for the solver. Preserve all authoritative collision/shot events and determinism; only redundant presentation samples may be discarded. UIKit stays on main; live world must not gain a second writer.
- Use one timestamp-based presentation sampler for live and replay, including spin-aware orientation, height, shadows and collision boundaries. Do not interpolate blindly across an impact or change friction to conceal timing issues.
- Verify Undo while moving, background/resume, layout/reset, replay seek/pause, jump, fast spin, pockets and online authority before adopting that larger threading change.

## Build state at this review

Parent run 121 failed Swift import (`Int` to `UInt` event index). Fixed by `9de1cc4`. Run 122 passed both Linux compiler jobs and exported/uploaded an unsigned candidate IPA; full Simulator/SceneKit/UI acceptance was still running when checked. The physical-device smoothness gate remains open.
