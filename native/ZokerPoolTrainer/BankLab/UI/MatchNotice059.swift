import Foundation

/// 0.59 A1/A2 (owner 28/11, học từ game tham khảo): after a shot is ruled, one short notice under the scoreboard.
/// A1 = a foul card (what the foul was + what it means: who has ball in hand, who chooses, a lost turn) — the reason
/// already came from the rules core but only reached the small status strip. A2 = a small pill when the turn changes.
/// A foul card already says who plays next, so a foul never shows the pill too. Nothing at a new rack (shot count back
/// to 0), nothing once the rack is won. Foundation only: Tests/MatchNoticeTests.swift.
struct MatchNoticeInput: Equatable {
    var shotCount = 0
    var reason = ""
    var currentPlayer = 0
    var ballInHand = false
    var warnedCurrent = false      // the incoming player is on two fouls (three-foul rule)
    var pendingChoice = false
    var winner = -1
    var localPlayer = 0
    var networked = false
    var vsComputer = false
    var names = ["", ""]
}

enum MatchNotice: Equatable {
    case foul(title: String, detail: String, warning: String?, seat: Int)   // seat = the player who fouled
    case turn(text: String, seat: Int)                                      // seat = the player who plays now

    /// Rules-core reasons (MatchRules.hpp) that end a turn by a foul or hand the incoming player a choice.
    static let foulReasons: Set<String> = ["scratch", "ball_off_table", "wrong_ball_first", "no_rail_after_contact",
                                           "bad_cue_ball_placement", "illegal_break_four_rails", "three_ball_break_not_met",
                                           "eight_on_foul_break"]

    static func decide(previous: MatchNoticeInput?, now: MatchNoticeInput, reasonText: (String) -> String,
                       foulCard: Bool, turnPill: Bool) -> MatchNotice? {
        guard let p = previous, now.winner < 0 else { return nil }
        let seat = min(1, max(0, now.currentPlayer)), names = now.names.count == 2 ? now.names : ["", ""]
        let shot = now.shotCount > p.shotCount && p.shotCount >= 0
        let choiceMade = now.shotCount == p.shotCount && now.reason.hasPrefix("choice_") && p.reason != now.reason
        if shot, foulCard, foulReasons.contains(now.reason) {
            let shooter = 1 - seat
            let who: String
            if now.networked { who = shooter == now.localPlayer ? "Cú của bạn" : "Cú của đối thủ" }
            else if now.vsComputer { who = shooter == 0 ? "Cú của bạn" : "Cú của máy" }
            else { who = "Cú của " + names[shooter] }
            let next = player(seat, now)
            let what: String
            if now.pendingChoice { what = next.isEmpty ? "Bạn được chọn nhận bàn hoặc trả lượt" : next + " được chọn nhận bàn hoặc trả lượt" }
            else if now.ballInHand { what = next.isEmpty ? "Bạn được bi cái trong tay" : next + " được bi cái trong tay" }
            else { what = "Mất lượt" }
            let warning = now.warnedCurrent ? "Đã 2 lỗi liên tiếp · thêm một lỗi nữa là thua ván" : nil
            return .foul(title: reasonText(now.reason), detail: who + " · " + what, warning: warning, seat: shooter)
        }
        guard turnPill, shot || choiceMade, now.currentPlayer != p.currentPlayer else { return nil }
        if now.networked { return .turn(text: seat == now.localPlayer ? "Lượt của bạn" : "Lượt đối thủ", seat: seat) }
        if now.vsComputer { return .turn(text: seat == 0 ? "Lượt của bạn" : "Lượt của máy", seat: seat) }
        return .turn(text: "Lượt " + names[seat], seat: seat)
    }

    /// "" = the reader of this device ("Bạn …"); otherwise the name the sentence starts with.
    private static func player(_ seat: Int, _ s: MatchNoticeInput) -> String {
        if s.networked { return seat == s.localPlayer ? "" : "Đối thủ" }
        if s.vsComputer { return seat == 0 ? "" : "Máy" }
        return s.names.indices.contains(seat) ? s.names[seat] : ""
    }
}

/// 0.59 A4 (owner, ảnh 28/11: "phím gọi bi ở những vị trí ngay lỗ không được"): what a tap during the call picks.
/// A ball within 6 cm of the tap wins over a pocket unless the tap is closer to the pocket centre than to that ball;
/// otherwise the nearest pocket within 30 cm; otherwise nothing. Before, any tap within 35 cm of a pocket called it.
enum CallTap {
    static func target(_ x: Double, _ y: Double, balls: [(id: Int, x: Double, y: Double)], holes: [(Double, Double)]) -> (ball: Int, pocket: Int) {
        guard !holes.isEmpty else { return (0, -1) }
        let pocket = holes.indices.min(by: { hypot(holes[$0].0 - x, holes[$0].1 - y) < hypot(holes[$1].0 - x, holes[$1].1 - y) }) ?? 0
        let dp = hypot(holes[pocket].0 - x, holes[pocket].1 - y)
        if let ball = balls.min(by: { hypot($0.x - x, $0.y - y) < hypot($1.x - x, $1.y - y) }) {
            let db = hypot(ball.x - x, ball.y - y)
            if db < 0.06 && db <= dp { return (ball.id, -1) }
        }
        return dp < 0.30 ? (0, pocket) : (0, -1)
    }
}
