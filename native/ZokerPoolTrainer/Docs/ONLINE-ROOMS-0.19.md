# Online rooms — accepted requirements

Status: design recorded; Internet service and client are NOT implemented or deployed.

Confirmed by the user:
- Internet play across different networks.
- Singles: two seats. Doubles: two teams, alternate teammates after EVERY shot.
- One entry: Chơi Cùng Bạn. Create/join a chosen six-digit ASCII code; room name; atomic conflict rejection.
- Persist room bookmark and device membership token securely. Opening a bookmark reconnects and resynchronizes; it cannot guarantee an always-live connection while iOS suspends the app.
- A room code grants a request to join/watch, never host privileges. Seat changes and doubles participation require host/involved-player approval.
- Spectators are read-only and cannot send strike/placement/rules commands.

## Required service

MultipeerConnectivity cannot satisfy different-network Internet play. A persistent room registry, authenticated membership, atomic code reservation and durable reconnect identity are required. Never advertise a local process or temporary workspace tunnel as a deployed production service.

Keep one authoritative physics host initially. Service authenticates membership, seats/teams, command revisions and forwards state. On host loss pause, preserve last confirmed state and reconnect; do not silently simulate on two peers. Resume requires authoritative full sync. Spectator fanout must use the service rather than extra direct streams from the phone.

Six-digit codes are discoverable; rate-limit lookup/join attempts and require admission for seating. Persist membership secrets in Keychain, room labels/bookmarks in local storage; never put secrets in source or logs.

## Doubles turn mapping

Team A seats [A1,A2], team B [B1,B2]. Maintain next shooter index separately for EACH team. A legal shot retaining team turn advances to the other teammate; a turn change selects the opponent team's next index. A submitted foul still consumes that shooter's shot. Rejected commands and placement/call actions do not rotate teammates. Snapshot includes team turn and exact shooter seat. Rules engine continues to adjudicate two teams rather than four independent players.

## Spectator limit

Do not claim an unmeasured maximum. Measure server outbound throughput, host upload rate, guest p95 rendering/audio delay and concurrent spectator fanout before setting a shipping cap. Drop/coalesce superseded visual snapshots under load; retain ordered commands/results. Spectators cannot delay match simulation. Report free-tier quotas and suspension behavior honestly.

## Other accepted changes pending

- Auto pocket inference plus optional on-screen Call for 8/10, top camera and six tappable lit pockets; restore exact prior camera. Explicitly label inferred-call/accidental-pot foul as custom rules, distinct from WPA.
- Replay pre-roll of aim/stroke with recorded camera/input timing, bounded rolling buffer; cinematic default and last-three-seconds slowdown with manual override. Preserve live world and aim.
- B-only bridge control, adaptive tablet hit targets. Keep hold-to-lock.
- Ball count text input with random/default placement and overlap checks.
- Physics/swipe sensitivity menu and Markdown before/after calibration export, measured notes, configuration provenance.
- Assisted straight initial cue-ball direction except massé, with explicit physical/assisted mode recorded in archives/calibration. Preserve spin, collision throw and cushion response; do not change friction to mask squirt.

Acceptance: meaningful room-claim races, admission/seat authority, reconnect and four-player rotation tests; two-network device session; measured spectator load; native Swift/ObjC++ build and UI tests; signed device installation. No new IPA yet.

## Latest scope correction

User has deferred Internet hosting. This build retains same-Wi-Fi MultipeerConnectivity. Internet room service, spectators and four-player doubles are NOT implemented. Do not describe this build as containing those features.

Current implementation adds B-only bridge presentation, 72pt phone/92pt tablet bridge target, count-input random/default ball addition, and Markdown calibration export. Call-map auto-inference, replay pre-roll, assisted straight shots and simplified saved-room flow remain pending. Native acceptance is not yet complete; prior run46 had four UI failures.
