# Extended replay 0.19

New local recordings retain up to eight seconds of actual aim, camera, effect and stroke-pull samples before impact. The bounded buffer stores at most 241 samples and clears on layout changes, simulation and interruptions. Starting immediately after a layout captures only the available preparation, never invented waiting time.

The native ball frames and impact times still start at zero. Preparation playback uses negative replay time; physical simulation, scoring, saved layouts and CSV times are unchanged. Cue-strike audio plays when playback crosses zero. Archived metadata optionally stores preparation; old archives without it remain readable.

Playback defaults to the recorded preparation view followed by the cinematic director. The final three seconds of native motion play at 0.48 speed, including when the viewer manually rotates or zooms. Manual view control suppresses automatic camera cuts. Preparation is normal speed. Stopping replay restores live cue equipment and current table.

Validation: Tools/run_replay_checks.sh compiles the production archive/director and extracted production BallState with swiftc on Mac. It checks legacy decoding, camera/stroke roundtrip, invalid data rejection, native-clock preservation and final slowdown. One additional XCUITest checks real controller capture and negative playback time. Local Bash/Python/whitespace checks are not native Swift or physical-device acceptance.
