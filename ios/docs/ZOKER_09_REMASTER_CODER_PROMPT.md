# ZokerPoolTrainer 0.9 Remastered — Coder integration instructions
Branch: feature/zoker-09-remaster-build. DO NOT alter main. Preserve the existing deterministic Physics.swift and drill golden fixtures unless separately validated.
Implemented in this branch: B-labeled lock button and subtler aiming strip; extra cloth color presets; softer shadows and brighter fill/key lighting. Verify on iPhone before tuning further.
REMAINING REQUIRED WORK (not implemented merely by this document):
1. Implement true bridge-hold interaction: while B is physically held, hide HUD except table/balls/cue and accept full-screen stroke; when released, restore HUD. Avoid view gesture conflicts with SpinPad, menu, placement, pinch and fine aim. Put gesture ownership in a shared state machine, use UITouch timestamps and coalescedTouches. Do not fire a shot merely on release; strike only when push crosses contact plane.
2. Cue library in SwiftUI with actual visual cues; categories playing, jump, break. Profiles are hypothetical unless physical measurements available; preserve original cue profile as default. Optional brand logos require licensed assets.
3. Cloth microfibers: create tiled diffuse, roughness, normal/detail microtexture, mipmapping/anisotropy/LOD and material preview with realistic fiber structure at zoom; keep friction unaffected by recoloring. Tune shadows with multiple device quality tiers.
4. Match appearance of the two provided ShootersPool images as visual reference ONLY; no copying licensed textures. Keep old 0.9 table geometry until pocket jaws rebuilt and validated against physics hit-test geometry.
5. Smooth multi-level stroke response (7 labels over continuous velocity), avoid frame-dependent speeds, test short soft strokes and strong strokes. Use calibration reference for cue speed, not arbitrary visual power.
6. Cue elevation + real jump/masse are separate physical validation tasks; do NOT claim they're ready because ZUPEExperimental.swift compiles.
Acceptance: Swift core tests, simulator screenshots, handheld gestures, 60 fps on target iPhone, clear close-up felt fibers, ray contact shadow consistency, no changes to golden physics trajectory within established tolerances.
CI: .github/workflows/ios.yml builds unsigned IPA for every iOS push to this branch, uploads an Artifacts ZIP; only main gets stable release. ESign required for install.
