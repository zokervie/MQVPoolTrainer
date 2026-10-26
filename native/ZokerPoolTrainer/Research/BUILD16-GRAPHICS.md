# Build 16 — graphics and compact equipment controls

## Changes

- Aperiodic cloth microfibres replace the periodic weave that produced stripes at grazing angles. Cloth tint is baked into the albedo before lighting.
- Lower key-light intensity, front fill, softer environment cards and a small diffuse emission floor reduce crushed ball shading. This is an artistic ambient approximation, not measured room illumination.
- Ball contact shadows use a 512 px feathered texture. High-detail shadow maps are 4096 px with 32 samples. The cue also has a soft projected shadow, clipped to the rectangular playing surface.
- A translucent elevation control sits immediately left of the effect pad. Its range is 0–80 degrees. Nonzero elevation enables the existing experimental 3D model; selecting a jump cue presets 45 degrees.
- A compact landscape rail offers three cameras, play/jump/break roles, cues in the active bag, three saved bags and the equipment library. It compresses on shorter screens and hides while the effect pad is expanded.
- The library contains 20 table reference looks, 12 cue reference looks and three persistent bags. Preview scenes can be rotated.

## Scope

The table catalog uses six original procedural base families and different finishes. These are reference reconstructions, not official meshes or dimensionally exact replicas. Manufacturer links are recorded in EquipmentLibrary.swift. Historical Rasson OX and Victory II Plus are included as reference looks. All variants retain the same 9 ft training geometry. Choosing a brand does not load measured brand-specific physics.

The cue catalog uses original procedural geometry with reference finishes and three generic role configurations. It does not reproduce branded cue mass distributions or shaft deflection measurements. The underlying jump/masse/kick physics remains experimental and uncalibrated against captured real-world shot datasets.

The 27-second user screen recording was visually sampled to confirm compact elevation/effect placement and the desired softer lighting. It is a visual reference, not a source of measured physical parameters.

## Validation

The existing C++ physics and offline ZUPE checks remain in CI. Simulator and device Xcode builds are followed by screenshots of overview, top, aim, expanded effect, jump, alternate tables, table library and cue library. Screenshot color checks are only smoke tests; visual review is required before delivery.
