# Z-Trainer 0.18 — integrated training and matches

Source starts at `ci/native-ux-luc-co-dinh`, commit
`b3ecd09b1965ccb7d7bc8594e84f5d3d7fd8eb8e`, on the new branch
`feature/native-0.18-integrated-play`. The uploaded 0.17 source patch is merged.
The six authoritative native physics files already match the supplied
`PoolSpinPhysics-3Bang-Masse-eda19ed2e3ba.zip`; there is one solver, with its
existing three-cushion spin and elevated massé implementation. The uploaded
`build.zip` contains older CI logs, not another source revision.

## User-visible changes

- Live shots retain the chosen camera. Zoom/orbit remain available during
  motion; settling does not restore or switch a viewpoint. Next aim follows
  the lowest legal object ball, with own-group selection for 8 Ball.
- Spin returns to centre after each shot; Jump returns to the playing cue.
- Compact vertical right shortcuts retain 44-point touch targets and scroll
  on short landscape screens. The rectangular Coach switch is above them.
  A translucent vertical wheel replaces the fine-aim slider.
- Random practice layouts support every count from 1 to 15 object balls.
- Replay alone uses cinematic framing and pocket-approach slow motion.
  Archived snapshots play without changing the live table; each saved shot
  remembers its Coach setting. Archive data is bounded to 20 recordings and
  200 MiB; legacy input-only recordings can be reconstructed on a worker.
- Pocketed balls spiral into a bounded basket and stay there until restored
  or the layout changes. This is rendering; pocket decisions remain native.
- Balanced graphics, thermal quality changes, cached geometry/textures,
  idle rendering and background prediction reduce avoidable work. Native
  physics step size and calibrated friction are unchanged.
- Audio uses the attributed CC0 and CC BY field recordings in
  `Tools/AudioSources/manifest.json`. Warm voices, removal of sample pre-roll
  and impact dispatch immediately after simulation address scheduling delay.
  Speaker/route latency and perceived realism still require device listening.
- New opaque app artwork reads **Z-Trainer** and includes a yellow 9-ball.
  The encoded master, checksum and rendition pipeline are checked in.

## Matches

Menu offers virtual WPA 8/9/10 Ball, and the explicitly named **15 Ball
Rotation, first to 61** variant selected by the user. A legal final-ball
60–60 tie awards the shooter one tiebreak point (61–60), following
[Celeris Rotation scoring](https://vponline.celeris.com/support/rules/id/11). Rules consume actual
ordered solver events: first contact, subsequent rail/pot, scratch, ball off
table, break choices, called ball/pocket, push-out and warned three-foul loss.
8/10 Ball require a call after the break; 10 Ball does not offer a safety call.
The 2025 WPA change requires the 10-ball to be the last object ball to win.

Two players can pass one device, or create/join a six-digit nearby room over
Wi-Fi using Apple Multipeer Connectivity, with no server or paid service.
One host owns the solver and rules. Guests submit bounded, revision-checked
commands and draw interpolated snapshots; they never run another simulation.
Reliable encrypted transport, reconnect/full sync and pause on disconnect or
backgrounding are included. Spectators control their own camera. All coaching
and predicted paths are disabled in matches; the optional **123** switch
only shows the physical diamond numbers.

Rules references: [WPA Rules, 2 Jan 2026](https://www.wpapool.com/wp-content/uploads/2026/01/2026.01.02-WPA-Rules.pdf)
and [WPA Regulations, 15 Sep 2025](https://wpapool.com/wp-content/uploads/2025/10/2025.09.15-WPA-Regs-NP.pdf).
Virtual event adjudication does not observe physical referee conditions such
as hand contact, a foot on the floor or template interference. Synthetic rule
tests are separate from measured-table accuracy and tournament certification.

## Acceptance evidence

Portable command: `bash Run-All-Checks.command`; all native C++ suites pass,
including 456 rules assertions, plus resource, audio, ZUPE and gesture checks.
Local log: `build/portable-0.18-integration.log`.

The Mac command is `python3 Tools/run_acceptance.py`, including the Foundation
LAN wire harness, actual Swift/ClangImporter builds, UIKit runtime probes,
XCTest interactions and an unsigned arm64 IPA. The workflow records the exact
commit, dirty patch hash, commands, logs and artifact SHA-256. Until a matching
acceptance report says `PASSED_SIMULATOR_UNSIGNED`, this revision is a build
candidate. Physical-device heat, sustained frame pacing, audio listening and
a two-device Wi-Fi session remain `NOT_RUN` in automated reports.

Bundle identifier remains `com.maiquocviet.BankLabS`. The generated IPA is
**unsigned**, requires valid signing before installation, and is not a signed
distribution. Main and the requested source branch are preserved.
