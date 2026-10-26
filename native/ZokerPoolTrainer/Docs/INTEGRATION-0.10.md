# Integration boundary

- UIKit / SceneKit / BLWorld: original 0.9 application; menu launches a WKWebView
  research controller. New controller and Lab folder are in Xcode source/resource phases.
- Native C++: optional `railSpeedSensitivity` subtracts sensitivity × approach speed
  from rail restitution within [0.4,0.98]; default 0 keeps the old response.
- WKWebView: six namespaced modules compiled from `Research/ZUPE/enhancements`.
  Offline HTML has no CDN, network access or remote navigation. Only JSON export
  messages are accepted, with allowlisted names and a size limit.
- Lab can export results but does not mutate BLWorld or overwrite native calibration.
- Original JavaScript prototypes are retained under `Research/ZUPE/original_prototype`.
- The GitHub comparator is `zokervie/MQVPoolTrainer` at
  `555af3c76916607bddc931da68dff81f0ab47963`; it is a distinct Swift/JS codebase.
  No duplicate Simulation, Ball or renderer types were imported into the native target.
- Full GitHub table presets, 8/9-ball modes, curriculum and shot feedback are NOT
  ported by this research integration. The app's 28 original drills remain.
- All Lab material is experimental, not empirically calibrated. Its coarse box
  geometry and two-stage slate solver are not substitutes for real pocket/jaw,
  coupled cue-ball-slate, obstacle collision or massé solving.

## Device acceptance still required

Build Simulator and device with Xcode; launch all 4 tabs; verify local HTML loads,
sliders and multi-touch, JSON import and share sheet on iPhone/iPad; suspend/resume
and close Lab; verify Menu K/SpinPad still work; compare native bounces at sensitivity
0 and >0; inspect cloth at all three camera angles and measure FPS/memory.

## Axes

Native C++ uses 2D (x,y) for the tabletop and vertical angular spin. Lab uses SI
(x,y,z), y up. There is intentionally no implicit coordinate transform between
these models; they are separately tagged in exported JSON.
