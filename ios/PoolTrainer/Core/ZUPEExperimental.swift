import Foundation

// ZUPE 2.0: experimental, testable equipment/contact reference models.
// This source is intentionally isolated from the production simulation until
// high-speed video and table-specific calibration become available.
// All numerical equipment profiles below are FICTIONAL, not manufacturer ratings.
struct ZUPECueProfile: Equatable {
    enum Kind { case playing, jump, breakCue }
    let id: String
    let kind: Kind
    let massKg: Double
    let tipHardness: Double
    let stiffness: Double
    let collisionEfficiency: Double
    static let playing = ZUPECueProfile(id: "zoker-playing", kind: .playing, massKg: 0.54, tipHardness: 0.55, stiffness: 0.62, collisionEfficiency: 0.78)
    static let jump = ZUPECueProfile(id: "zoker-jump", kind: .jump, massKg: 0.31, tipHardness: 0.92, stiffness: 0.94, collisionEfficiency: 0.88)
    static let breakCue = ZUPECueProfile(id: "zoker-break", kind: .breakCue, massKg: 0.56, tipHardness: 0.85, stiffness: 0.90, collisionEfficiency: 0.82)
}

struct ZUPEVector3: Equatable {
    var x: Double; var y: Double; var z: Double
    static func + (a: Self, b: Self) -> Self { .init(x: a.x+b.x, y: a.y+b.y, z: a.z+b.z) }
    static func * (a: Self, s: Double) -> Self { .init(x: a.x*s, y: a.y*s, z: a.z*s) }
    static func cross(_ a: Self, _ b: Self) -> Self {
        .init(x: a.y*b.z-a.z*b.y, y: a.z*b.x-a.x*b.z, z: a.x*b.y-a.y*b.x)
    }
}
struct ZUPEImpact: Equatable {
    let deltaVelocity: ZUPEVector3
    let angularVelocity: ZUPEVector3
    let impulseNs: Double
}
enum ZUPEExperimentalImpact {
    static let ballMass = 0.17
    static let ballRadius = 0.028575

    /// 3D cue contact model (Y is vertical). Negative vertical impulse is correct
    /// for an elevated stroke: the floor contact may cause upward rebound.
    /// NOT a validated simultaneous cue-ball-slate contact solver.
    static func calculate(cue: ZUPECueProfile, cueSpeed: Double, azimuth: Double,
                          elevationDegrees: Double, tipSide: Double, tipHeight: Double) -> ZUPEImpact? {
        guard cueSpeed.isFinite && cueSpeed >= 0 && elevationDegrees.isFinite &&
            (0...85).contains(elevationDegrees) && tipSide.isFinite && tipHeight.isFinite &&
            hypot(tipSide, tipHeight) <= 0.65 else { return nil }
        let el = elevationDegrees * .pi / 180
        let d = ZUPEVector3(x: cos(azimuth)*cos(el), y: -sin(el), z: sin(azimuth)*cos(el))
        let side = ZUPEVector3(x: -sin(azimuth), y: 0, z: cos(azimuth))
        let up = ZUPEVector3.cross(side, d)
        let axial = sqrt(1-tipSide*tipSide-tipHeight*tipHeight)
        let r = (d * -axial + side * tipSide + up * tipHeight) * ballRadius
        let effectiveMass = cue.massKg * (0.35+0.35*cue.stiffness)
        let J = cue.collisionEfficiency*1.35*cueSpeed / (1/effectiveMass+1/ballMass)
        let impulse = d * J
        let inertia = 0.4*ballMass*ballRadius*ballRadius
        return .init(deltaVelocity: impulse*(1/ballMass),
                     angularVelocity: ZUPEVector3.cross(r, impulse)*(1/inertia),
                     impulseNs: J)
    }
}
