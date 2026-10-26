# Cushion calibration 0.12 build 18

Original native implementation, calibrated candidate parameters for the existing impulse-with-Coulomb-friction model. This is not a full Mathavan or Stronge compliant implementation, and no real-world measurements are bundled.

## References
- Mathavan, Jackson, Parkin (2010), DOI 10.1243/09544062JMES1964. Includes normal/tangential impulses, spin, cloth interaction; the rigid-cushion assumptions have a limited speed domain. https://repository.lboro.ac.uk/articles/journal_contribution/A_theoretical_analysis_of_billiard_ball_dynamics_under_cushion_impacts/9561458
- Pooltool model documentation: https://pooltool.readthedocs.io/en/latest/autoapi/pooltool/physics/index.html
- Dr Dave bank/kick effects: https://drdavepoolinfo.com/faq/bank-kick/effects/

## Current scope
Each of four rails has independent restitution and friction, shared by planar and elevated simulations. State remains continuous between collisions, and the cloth evolves translational and angular velocities between rails. Prediction uses the same world. The planar contact response retains its existing constrained approximation; fitting cannot repair missing model physics.

In Settings export the JSON template, collect 8–500 independent flat straight-rail impacts on a single rail, and import measured data. Velocities are SI, angular velocities rad/s, coordinates XY on the table and +Z up. Rail IDs: 0 left, 1 right, 2 negative Y end, 3 positive Y end. Include states immediately before and immediately after contact; do not use later rolling states. Avoid pocket jaws, flight and simultaneous ball contacts. Include varied speeds, approach angles and both sidespin signs, in randomized acquisition order. Every fourth row is withheld for validation. Input source must explicitly say measured. No synthetic data is shipped as measured.

The fit searches e in [.4,.98] and mu in [0,.35], with current speed sensitivity and other settings held fixed. Objective is RMS over vx,vy,R*wx,R*wy,R*spin residuals, expressed in m/s. Fit and validation errors are shown separately. A candidate can be selected only when it improves withheld error. Selection requires pressing Save before the app applies it. This criterion alone does not prove identifiability or match to all real tables.

## Acceptance
Synthetic parameter recovery tests verify the fitter and all four rail mappings; they do not establish real-world accuracy. After fitting, collect a separate dataset of two/three-rail shots and compare positions at each contact, outgoing angles/speeds, and final positions. Report measurement uncertainty and per-shot errors rather than claiming universal accuracy. Jump/Masse and compliant cushion behavior require separate model development and datasets.
