# A1: coupled cushion/slate impulses, build 19

## Verified build-18 distinction
Native Config::railHeight is a dimensionless offset of the nose above the ball centre, divided by R; it is used in both planar and elevated contact code. Default R=.028575 m, offset=.27 R=.00771525 m, absolute nose height=.03629025 m and tilt asin(.27)=15.6643 degrees. The .0365 m value is in the independent ZUPE Lab and must not be substituted into the dimensionless field. Absolute native height now has one derived accessor railNoseHeightMeters(), used in the 3D detection/response path.

## Mechanics
CushionContact3D.hpp is original code. XY is cloth, +Z upward. For a cushion inward unit normal N and centre-to-contact vector r=-R N, u=v+omega cross r. At a raised nose N has a downward component. An isolated radial normal impulse produces no torque; tangential impulses produce the angular change.

Free flight: solve the full 3D Newton restitution impulse and project the cancelling tangential impulse onto a circular Coulomb disk. Preserve vz and all angular components.

Ground contact: projected Gauss-Seidel solves two simultaneous unilateral normal constraints and two circular tangential Coulomb disks, one at the cushion nose and one at the slate contact. Rail restitution target is -e*u_n_before. Slate target is zero, not a bounce from an artificial sequential landing. Accumulated impulses are projected as vectors; friction axes are not clamped independently. Mass-normalized impulses are m/s, multiply by mass for N*s. I/m=2 R^2/5. Iteration residual/tolerance, iteration count and convergence status are available in the result.

Passivity guard: simultaneous Newton restitution with Coulomb friction can create energy in high-spin cases. If total kinetic energy increases, the solver bisects the effective restitution target and re-solves all impulses; it does not scale output velocities. The result reports passivityLimited and effectiveRestitution. This is an admissibility safeguard, not a measured rubber law or an implementation of energetic Stronge restitution. Nominal normal restitution is therefore exact only when this guard is inactive.

Native app enables coupledCushions by default and exposes an A1 switch for comparison. Core Config defaults to the legacy option to retain explicit baseline regressions. The same response drives measured-state fitting and 3D simulation. With A1 on, flat shots also use 3D evolution so vertical state is not discarded. Turning A1 off restores the preceding contact/evolution choices.

## Limits and validation
This is an instantaneous rigid-contact model, not Mathavan ODE integration or a compliant rubber model. A convergence/passivity test is not a claim of measured real-world accuracy. Pocket-jaw simultaneous contacts and ball-ball/slate coupling remain sequential; 3D detection uses bounded substeps rather than exact swept time-of-impact. Old fitted parameters require remeasurement for the new model.

An additional 10,000 deterministic boundary-range cases check convergence, passivity, Coulomb disks and the effective restitution target, including cases that exercise the passivity guard.

Tests cover dimensional geometry, free versus grounded impulses, circular Coulomb bounds, nonnegative normal impulses, zero normal torque, normal restitution, passivity over 578 spin/velocity cases, mirror symmetry, and multi-rail evolution. Calibration recovery is checked against both legacy and coupled models. Existing regression suites remain required.

Primary references: Mathavan/Jackson/Parkin (2010), DOI 10.1243/09544062JMES1964; https://drdavepoolinfo.com/physics_articles/Mathavan_IMechE_2010.pdf . Pooltool model taxonomy for distinction between instantaneous 3D and compliant models: https://pooltool.readthedocs.io/en/latest/autoapi/pooltool/physics/index.html . No pooltool code is copied.

Requested app target for build 19: com.maiquocviet.BankLabS. This differs from the unsigned build-18 source identifier com.maiquocviet.BankLab. CI launch identifiers are updated together.

Fitting up to 500 observations runs on a private worker world off the UI thread; only the result UI returns to the main queue. Selecting the first independent-rail candidate seeds the other rails from the active global coefficients.
