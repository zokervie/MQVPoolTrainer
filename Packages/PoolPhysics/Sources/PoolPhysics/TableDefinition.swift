import Foundation

// MARK: - Nguồn gốc tham số (UPGRADE.md, quyết định D5; REVIEW.md mục E)

/// Mọi tham số phải cho biết nó đến từ đâu.
public enum Provenance: Codable, Equatable, Sendable {
    /// Giá trị lấy từ tài liệu đã công bố (ghi rõ tài liệu và vị trí).
    case published(source: String)
    /// Giá trị đo trên bàn thật (phương pháp, số mẫu, sai số dư trên tập kiểm chứng).
    case measured(method: String, samples: Int, residual: Double)
    /// Giá trị giả định phục vụ thử nghiệm. Shot Lab hiển thị cảnh báo cho các tham số này.
    case assumed(note: String)

    public var isAssumed: Bool {
        if case .assumed = self { return true }
        return false
    }
}

public struct Measured<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var value: Value
    public var provenance: Provenance
    public init(_ value: Value, _ provenance: Provenance) {
        self.value = value
        self.provenance = provenance
    }
}

/// Các tham số của bàn có thể hiệu chỉnh. Khóa ổn định để lưu file.
public enum ParameterKey: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case slidingFriction
    case rollingResistance
    case spinFriction
    case ballBallFriction
    case ballBallRestitution
    case cushionRestitution
    case cushionFriction

    var keyPath: WritableKeyPath<PhysicsParameters, Double> {
        switch self {
        case .slidingFriction: \.slidingFriction
        case .rollingResistance: \.rollingResistance
        case .spinFriction: \.spinFriction
        case .ballBallFriction: \.ballBallFriction
        case .ballBallRestitution: \.ballBallRestitution
        case .cushionRestitution: \.cushionRestitution
        case .cushionFriction: \.cushionFriction
        }
    }

    /// Khoảng vật lý hợp lý để chặn dữ liệu sai (không phải khoảng "đúng").
    public var plausibleRange: ClosedRange<Double> {
        switch self {
        case .slidingFriction: 0.05...0.5
        case .rollingResistance: 0.001...0.05
        case .spinFriction: 0.005...0.2
        case .ballBallFriction: 0.0...0.2
        case .ballBallRestitution: 0.8...1.0
        case .cushionRestitution: 0.5...1.0
        case .cushionFriction: 0.0...0.5
        }
    }
}

public enum DefinitionError: Error, Equatable {
    case unsupportedSchema(found: Int, supported: Int)
    case outOfRange(field: String, value: Double, range: ClosedRange<Double>)
    case missingProvenance(ParameterKey)
    case tableMismatch(expected: String, found: String)
}

// MARK: - Định nghĩa bàn

/// Bốn phần tách biệt: hình học (TableSpec), hồ sơ vật lý (physics + nguồn gốc),
/// tài nguyên hiển thị (tên, nằm trong App), hiệu chỉnh (CalibrationProfile, lưu riêng).
public struct TableDefinition: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var geometry: TableSpec
    public var physics: PhysicsParameters
    public var physicsProvenance: [ParameterKey: Provenance]
    public var visualAssetName: String

    public init(schemaVersion: Int = TableDefinition.currentSchemaVersion,
                id: String, name: String, geometry: TableSpec,
                physics: PhysicsParameters, physicsProvenance: [ParameterKey: Provenance],
                visualAssetName: String) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.geometry = geometry
        self.physics = physics
        self.physicsProvenance = physicsProvenance
        self.visualAssetName = visualAssetName
    }

    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DefinitionError.unsupportedSchema(found: schemaVersion, supported: Self.currentSchemaVersion)
        }
        try check("length", geometry.length, 1.5...3.0)
        try check("width", geometry.width, 0.7...1.5)
        try check("ballRadius", geometry.ballRadius, 0.025...0.035)
        try check("ballMass", geometry.ballMass, 0.14...0.20)
        try check("cushionHeightRatio", geometry.cushionHeightRatio, 0.55...0.70)
        try check("cornerPocketMouth", geometry.cornerPocketMouth, 0.09...0.15)
        try check("sidePocketMouth", geometry.sidePocketMouth, 0.10...0.16)
        for key in ParameterKey.allCases {
            try check(key.rawValue, physics[keyPath: key.keyPath], key.plausibleRange)
            guard physicsProvenance[key] != nil else { throw DefinitionError.missingProvenance(key) }
        }
    }

    /// Bàn 9 ft thiết kế riêng của dự án, theo kích thước chuẩn WPA (không theo hãng nào).
    /// Hình học: WPA Equipment Specifications — mặt chơi 100" × 50", bi 2,25",
    /// miệng lỗ góc 4,5–4,625", lỗ giữa 5–5,125", mũi băng 62,5–64,5% đường kính bi.
    /// Tham số vật lý là giá trị khởi đầu từ tài liệu; sẽ thay bằng số đo ở R4.
    public static let zoker9ft = TableDefinition(
        id: "zoker-9ft-v1",
        name: "Zoker 9ft",
        geometry: .nineFoot,
        physics: PhysicsParameters(),
        physicsProvenance: [
            .slidingFriction: .published(source: "Alciatore, Pool and Billiards Physics Resources (~0,2)"),
            .rollingResistance: .published(source: "Alciatore (0,005–0,015 tùy nỉ)"),
            .spinFriction: .assumed(note: "Từ Marlow, chưa đối chiếu trực tiếp; cần đo ở R4"),
            .ballBallFriction: .published(source: "Alciatore TP A.14 (~0,06, phụ thuộc tốc độ)"),
            .ballBallRestitution: .published(source: "Alciatore (0,92–0,98)"),
            .cushionRestitution: .published(source: "Mathavan et al. 2010 (0,75–0,85)"),
            .cushionFriction: .published(source: "Mathavan et al. 2010 (~0,2)")
        ],
        visualAssetName: "ZokerTable9ft"
    )
}

// MARK: - Hiệu chỉnh theo bàn thật

public struct CalibrationProfile: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var tableId: String
    public var measuredAt: Date
    /// Điều kiện đo: loại nỉ, độ mới, bi, nhiệt độ, độ ẩm.
    public var conditions: String
    public var overrides: [ParameterKey: Measured<Double>]

    public init(schemaVersion: Int = CalibrationProfile.currentSchemaVersion,
                tableId: String, measuredAt: Date, conditions: String,
                overrides: [ParameterKey: Measured<Double>]) {
        self.schemaVersion = schemaVersion
        self.tableId = tableId
        self.measuredAt = measuredAt
        self.conditions = conditions
        self.overrides = overrides
    }

    public func validate(for table: TableDefinition) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DefinitionError.unsupportedSchema(found: schemaVersion, supported: Self.currentSchemaVersion)
        }
        guard tableId == table.id else {
            throw DefinitionError.tableMismatch(expected: table.id, found: tableId)
        }
        for (key, m) in overrides {
            try check(key.rawValue, m.value, key.plausibleRange)
        }
    }

    /// Tham số sau khi áp hiệu chỉnh lên hồ sơ gốc của bàn.
    public func applied(to table: TableDefinition) throws -> (PhysicsParameters, [ParameterKey: Provenance]) {
        try validate(for: table)
        var p = table.physics
        var prov = table.physicsProvenance
        for (key, m) in overrides {
            p[keyPath: key.keyPath] = m.value
            prov[key] = m.provenance
        }
        return (p, prov)
    }
}

private func check(_ field: String, _ value: Double, _ range: ClosedRange<Double>) throws {
    guard value.isFinite, range.contains(value) else {
        throw DefinitionError.outOfRange(field: field, value: value, range: range)
    }
}
