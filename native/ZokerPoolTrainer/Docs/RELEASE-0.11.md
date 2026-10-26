# 0.11 candidate scope / acceptance

Implemented in native target:
- Optional 3D C++ solver; per-ball vertical position/velocity, gravity and a sequential cue then slate contact approximation.
- Ground friction couples three-axis angular velocity to sliding motion; elevated side english can curve the ground path. No predefined massé arc is drawn.
- Height-aware sphere-sphere and raised cushion-nose impulses; adaptive bounded displacement substeps (not a general continuous 3D TOI solver).
- Three illustrative Zoker cues change scene geometry and physical cue effective mass/efficiency. Preview rotates; elevation 0–80° is sent to physics and visible cue.
- Rendering/replay show simulated height, interpolated quaternion and distance-varying contact shadow. Original 4K cloth / original table mesh remain; exposure default -0.95.
- Hold B hides spin/menu/fine slider. Coalesced real touches, timestamp-window linear velocity fit, forward contact crossing; no lift-to-shoot and no artificial minimum launch boost. Seven UI speed bins remain separate from continuous force.
- Existing ZUPE research Lab remains available, with separate research box-model calibration.

Not validated / limitations:
- Slate contact is sequential, not coupled/compliant. No compliant nose/body shape, general continuous simultaneous 3D multi-contact solver, realistic miscue/chalk model or measured cue brand calibration.
- Existing 2D pocket capture basins act after landing. 3D pocket shelf/well entry is visual, not a complete rigid-body pocket model.
- Native 3D predictor/replay use the same solver; original stable 2D solver is still default.
- Real iPhone two-finger acceptance, left-handed layout, measured Golden Shots, stable 60fps/30min and memory targets still require device validation.
- Full 8/9-ball modes and entire GitHub curriculum are not imported into the native 0.9 codebase.
- Do not label the candidate Remastered Complete. Unit tests and CI do not prove real-table fidelity.

See workflow artifacts for actual compile/install screenshots and unsigned IPA status.
