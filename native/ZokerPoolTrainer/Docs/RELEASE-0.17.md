# 0.17 — integrated UX/audio candidate

Base source: b3ecd09b1965ccb7d7bc8594e84f5d3d7fd8eb8e, ci/native-ux-luc-co-dinh. Candidate branch: ci/native-0.17-ux-audio. This file describes implementation; native acceptance remains pending until CI produces a report for the candidate SHA.

## Changes

- Removed the fixed power bar. Hold B, pull back, then push forward; timestamp-based swipe speed is normalised by the short screen edge. Releasing B cancels an uncompleted stroke.
- C is off at launch and controls Coach, training target/diamond overlays, prediction and analysis paths. Core ball/table visuals remain visible.
- Bottom-right shortcuts: eye, replay, retry, cue preset, ball placement and add ball beside spin/elevation. B and C remain bottom-left. A centre-reset button is available when spin is expanded.
- Cue presets: playing 0, jump 1, break 2 preserve legacy physics IDs; massé 3 is a UI technique preset using playing cue physics. Each preset remembers elevation/spin. No new calibrated equipment model is claimed.
- Camera modes retain independent poses. Hold eye while balls move to peek at the full table; release restores the prior pose. Automatic observation frames moving balls after contact and returns to the stored aim after rest. Manual orbit/pinch temporarily overrides automatic observation.
- Replay has pause, seek, 0.25/0.5/1x, automatic/manual view, event audio, and restoration of the pre-replay camera. Playback does not add attempts or mutate the live world.
- Placement starts with the cue ball at the centre; an occupied centre is translucent until moved to a valid position. Finish rejects overlap. Cancel restores the snapshot. Tap + Ball adds one; hold opens seeded random add/new-layout options.
- Replaced synthesized tones with seven edited field-recording samples: four ball impacts plus cue/rail/pocket. Original source URLs, HQ-preview encoding, hashes, trims, licences and credits are in Tools/AudioSources. In-app attribution is under Help. Cue, rail and pocket each currently have one source recording, with continuous gain, rather than claiming multiple recorded force layers.

## Verification and evidence

- Linux: bash Run-All-Checks.command (18 C++ suites, JS/lab, gesture/source checks); includes production swipe-response monotonicity/screen normalisation and updated HUD geometry.
- Audio: python3 Tools/check_audio.py verifies encoded/bundled bytes, PCM headers, lengths, source and license manifest.
- Mac: python3 Tools/run_acceptance.py must pass Simulator build, fresh runtime probes/screenshots, XCUITest and unsigned iPhone build. Added UI scenarios cover Coach default/toggle, camera pose, placement cancellation, cue selection and replay camera isolation.
- The source can be built with existing unsigned CI. Physical-device signing, real multi-touch feel, audio fidelity/latency, thermal/frame pacing and real-table accuracy are NOT VERIFIED by portable checks.
- A headless audio engine may be unavailable; sample loading is still required. Sound scheduling is not acoustic-latency evidence.

## Device acceptance on the same candidate

Try soft/medium/hard and cancelled swipes; test B with a second finger; Coach on/off; camera peek/automatic/manual, scratch and retry; all four cues; placement on an occupied centre; add/random/replay; audio on speakers/headphones; 10-minute break/jump/replay stress. Record device/OS, build/SHA and findings. CI artifact is unsigned unless a signing environment is explicitly provided.
