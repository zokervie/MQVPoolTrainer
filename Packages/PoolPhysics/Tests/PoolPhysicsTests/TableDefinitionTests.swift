import XCTest
import simd
@testable import PoolPhysics

final class TableDefinitionTests: XCTestCase {

    func testDefaultTableIsValidAndFullySourced() throws {
        let t = TableDefinition.zoker9ft
        XCTAssertNoThrow(try t.validate())
        XCTAssertEqual(Set(t.physicsProvenance.keys), Set(ParameterKey.allCases))
    }

    func testRejectsUnknownSchemaVersion() {
        var t = TableDefinition.zoker9ft
        t.schemaVersion = 99
        XCTAssertThrowsError(try t.validate()) { e in
            XCTAssertEqual(e as? DefinitionError, .unsupportedSchema(found: 99, supported: 1))
        }
    }

    func testRejectsImplausibleParameter() {
        var t = TableDefinition.zoker9ft
        t.physics.rollingResistance = 0.5
        XCTAssertThrowsError(try t.validate())
    }

    func testRejectsMissingProvenance() {
        var t = TableDefinition.zoker9ft
        t.physicsProvenance[.cushionFriction] = nil
        XCTAssertThrowsError(try t.validate()) { e in
            XCTAssertEqual(e as? DefinitionError, .missingProvenance(.cushionFriction))
        }
    }

    func testCalibrationOverridesValueAndProvenance() throws {
        let t = TableDefinition.zoker9ft
        let cal = CalibrationProfile(
            tableId: t.id, measuredAt: Date(timeIntervalSince1970: 0), conditions: "test",
            overrides: [.rollingResistance: Measured(0.008, .measured(method: "máng lăn", samples: 20, residual: 0.05))]
        )
        let (p, prov) = try cal.applied(to: t)
        XCTAssertEqual(p.rollingResistance, 0.008)
        XCTAssertEqual(p.slidingFriction, t.physics.slidingFriction)
        XCTAssertEqual(prov[.rollingResistance], .measured(method: "máng lăn", samples: 20, residual: 0.05))
    }

    func testCalibrationForOtherTableIsRejected() {
        let cal = CalibrationProfile(tableId: "khac", measuredAt: Date(), conditions: "", overrides: [:])
        XCTAssertThrowsError(try cal.validate(for: .zoker9ft))
    }

    func testCodableRoundTrip() throws {
        let t = TableDefinition.zoker9ft
        let data = try JSONEncoder().encode(t)
        XCTAssertEqual(try JSONDecoder().decode(TableDefinition.self, from: data), t)
    }
}

final class RenderMappingTests: XCTestCase {
    let m = RenderMapping(table: .nineFoot)

    func testTableCenterMapsToOrigin() {
        let c = m.toRender(SIMD3(TableSpec.nineFoot.length / 2, TableSpec.nineFoot.width / 2, 0))
        XCTAssertEqual(simd_length(c), 0, accuracy: 1e-6)
    }

    func testUpIsUp() {
        XCTAssertEqual(m.directionToRender(SIMD3(0, 0, 1)), SIMD3<Float>(0, 1, 0))
    }

    func testRoundTrip() {
        let p = SIMD3<Double>(0.7, 0.3, 0.028575)
        let back = m.toPhysics(m.toRender(p))
        XCTAssertEqual(simd_distance(p, back), 0, accuracy: 1e-6)
    }

    /// Phép đổi phải giữ chiều tay phải: x̂ × ŷ = ẑ ở cả hai hệ.
    func testPreservesHandedness() {
        let x = m.directionToRender(SIMD3(1, 0, 0))
        let y = m.directionToRender(SIMD3(0, 1, 0))
        let z = m.directionToRender(SIMD3(0, 0, 1))
        XCTAssertEqual(simd_distance(simd_cross(x, y), z), 0, accuracy: 1e-6)
    }
}
