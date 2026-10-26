# Zoker 0.12 / build 20 — practice controls and table presentation

Bundle: com.maiquocviet.BankLabS. Physics coefficients, rail geometry and A1 coupled contact solver are unchanged from build 19.

## Practice controls

- External 44 pt Retry button above B, with a 16 pt gap. Restores pre-shot layout and ball orientation, including during a shot or replay. Aim, effect, elevation and equipment remain available for the next attempt.
- Right rail: camera, cue role and cue bag. Bag menu contains three selected cues, bag switching and equipment library. Expanded Effect hides that rail.
- Fine aim is opt-in with a 44 pt control area. Research and calibration are grouped under Advanced.
- Presentation interpolates position and quaternion without mutating simulation. A collision in the final fixed step disables interpolation across that discontinuity. Maximum lag is one 1/960 s step; actual-device frame pacing remains to be evaluated.

## Table and ball presentation

Every cosmetic table retains the same 9 ft surface, 2.54 × 1.27 m. Primary reference: WPA Recommended Equipment Specifications, sections 5–6:
https://wpapool.com/wp-content/uploads/2024/01/RECOMMENDED-EQUIPMENT-SPECIFICATIONS.pdf

- 17 diamond sights plus a nameplate at the positive-Z short-rail centre, as permitted by the specification.
- Station interval 0.3175 m; centre offset from cushion nose 0.0936625 m.
- Diamond dimensions 28 × 13 mm, within specified 25.4 × 11.11 to 31.75 × 15.875 mm range.
- Flat sights lie 0.15 mm above the cap to avoid depth fighting. Brand and model name update on table selection.
- Metallic perimeter trim, apron panel seams, narrow trim details and existing walnut normal/roughness maps on wood cabinets. These are original reference graphics, not manufacturer-approved models, logos, dimensions or certified tables.
- Six equal angular-radius cue-ball spots, stronger soft contact shadow and stronger existing cloth micro-normal map; no new periodic cloth overlay.

## Validation

Linux native/JS/resource checks include presentation nonmutation at irregular display intervals. Xcode simulator and iPhone compilation are required in Codemagic. Simulator QA asserts actual sight count and centre offsets, and retry restoration. Screenshots cover table families, cameras, expanded Effect and equipment.

Unsigned IPA requires personal signing before installation. Measured cushion validation and actual-device smoothness evaluation remain separate from this visual/control update.

## Verified build result

Codemagic workflow index 16 finished in 4m 55s on Xcode 16.4 / Mac mini M2. App source commit: d201ec2fcf707ffa8e5f7ac2e2904ffdcee53184.

https://codemagic.io/app/6ad8240a50a68ff0a344a214/build/6adc40fc4a72334e32e49f57

- Simulator and iPhone Release: BUILD SUCCEEDED.
- Eleven simulator screenshots passed visibility checks; actual node count/offset assertions and rotated-ball retry restoration passed.
- Reviewed top, aim and classic-table renders: sights, nameplate, external retry, compact rail and equal cue-ball spots are visible.
- Runtime/build logs have no compiler errors, failed preconditions, failed assertions or conflicting Auto Layout constraints.
- IPA ZIP integrity passed; bundle com.maiquocviet.BankLabS, version 0.12, build 20.
- IPA: 55,744,849 bytes; SHA-256 fee9346c3a6a37f7829b9d40d7d80dc6c8d86fa9f639af87be9d1c88aaa0dc04.

This documentation result is recorded after the app build; it does not change the compiled app.
