import Foundation

/// Máy trạng thái điều khiển (docs/02-controls.md). Thuần logic, không phụ thuộc UIKit.
public enum InteractionState: Equatable, Sendable {
    case aiming
    case locked
    case shotRunning
    case reviewing
}

public enum InteractionEvent: Equatable, Sendable {
    case lockTap          // chạm nhanh vào vùng khóa
    case strokeCompleted  // cú vuốt vượt vạch chạm bi
    case strokeCancelled  // nhấc tay trước vạch
    case ballsStopped
    case reviewDismissed
}

public enum Haptic: Equatable, Sendable {
    case lock, unlock, none
}

public struct InteractionMachine: Sendable {
    public private(set) var state: InteractionState = .aiming
    public init() {}

    /// Trả về haptic cần phát (nếu có).
    @discardableResult
    public mutating func handle(_ e: InteractionEvent) -> Haptic {
        switch (state, e) {
        case (.aiming, .lockTap):           state = .locked; return .lock
        case (.locked, .lockTap):           state = .aiming; return .unlock
        case (.locked, .strokeCompleted):   state = .shotRunning
        case (.locked, .strokeCancelled):   break
        case (.shotRunning, .ballsStopped): state = .reviewing
        case (.reviewing, .reviewDismissed): state = .aiming
        default: break
        }
        return .none
    }

    /// Bi effect chỉ hiện khi đang ngắm.
    public var showsEffectBall: Bool { state == .aiming }
    /// Vuốt = xoay hướng ngắm khi chưa khóa; = ra cơ khi đã khóa.
    public var swipeAims: Bool { state == .aiming }
    public var swipeStrokes: Bool { state == .locked }
}
