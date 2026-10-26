# Zoker Pool Trainer 0.12 — build 21

This release adds a persistent training catalog and improves presentation controls while keeping the native physics coefficients and fixed-step solver unchanged.

## Included

- 46 practice layouts, grouped by kick / bank rail count, shot control and measurement. New 1–3 rail kick and bank tracks each have three staged levels.
- A lesson page for every drill with a drawn ball layout, goal, geometric mirror/unfolding reference and a 10-shot coaching routine. The angles are explicitly starting estimates, not real-table calibration.
- Five optional cloth tints plus the original selected-table cloth, persistent across launches.
- Top-camera orbit now responds to two-finger drag; pinch can zoom farther out. Both gestures remain available while balls are moving.
- Antialiased cue-ball spots, stronger close-contact shadows, and eased inward/downward pocket capture with scale reduction.
- Event-impulse metadata from the native simulator drives synthesized, spatially panned cue/ball/cushion/pocket audio. Audio can be disabled in the menu. No third-party recording is bundled.
- CI screenshots cover orbit/zoom, the training list and a lesson detail page.

## Physics and accuracy boundaries

The 1/960 s simulation step, collision response, restitution, friction, spin loss, cushion geometry and coupled contact model are unchanged. Interpolation, shadow, pocket animation and audio do not feed back into ball state. The training formula cards teach geometric constructions and controlled practice; they do not claim that mirror-angle layouts are calibrated answers for a specific table.

## Build result

Pending Codemagic workflow completion for this commit. Record workflow ID, source commit, simulator/device compile results, screenshot review, IPA size and SHA-256 here before delivery.
