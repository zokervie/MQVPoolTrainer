import Foundation

/// 0.59 A1/A2: the foul card and the turn pill (BankLab/UI/MatchNotice059.swift). Built by Tools/run_lan_checks.sh.
@main struct MatchNoticeMain {
    static func main() {
        var failures = 0
        func check(_ ok: Bool, _ what: String) { if !ok { failures += 1; print("FAIL \(what)") } }
        let text: (String) -> String = { ["scratch": "Lỗi bi cái vào lỗ", "wrong_ball_first": "Lỗi chạm sai bi đầu tiên"][$0] ?? $0 }
        func s(_ shot: Int, _ reason: String, _ player: Int, hand: Bool = false, choice: Bool = false, warn: Bool = false,
               winner: Int = -1, net: Bool = false, local: Int = 0, cpu: Bool = false) -> MatchNoticeInput {
            MatchNoticeInput(shotCount: shot, reason: reason, currentPlayer: player, ballInHand: hand, warnedCurrent: warn,
                             pendingChoice: choice, winner: winner, localPlayer: local, networked: net, vsComputer: cpu, names: ["An", "Bình"])
        }
        func d(_ a: MatchNoticeInput?, _ b: MatchNoticeInput, foul: Bool = true, pill: Bool = true) -> MatchNotice? {
            MatchNotice.decide(previous: a, now: b, reasonText: text, foulCard: foul, turnPill: pill)
        }

        // A1: a scratch on the guest's own shot, seen by the guest (Wi-Fi): "Cú của bạn · Đối thủ được bi cái trong tay"
        let scratch = d(s(4, "legal_pot", 1, net: true, local: 1), s(5, "scratch", 0, hand: true, net: true, local: 1))
        check(scratch == .foul(title: "Lỗi bi cái vào lỗ", detail: "Cú của bạn · Đối thủ được bi cái trong tay", warning: nil, seat: 1),
              "own scratch, guest view: \(String(describing: scratch))")
        // the same shot on the host: the host gets ball in hand
        let host = d(s(4, "legal_pot", 1, net: true, local: 0), s(5, "scratch", 0, hand: true, net: true, local: 0))
        check(host == .foul(title: "Lỗi bi cái vào lỗ", detail: "Cú của đối thủ · Bạn được bi cái trong tay", warning: nil, seat: 1),
              "opponent scratch, host view: \(String(describing: host))")
        // two players on one device: names
        let local = d(s(2, "legal_pot", 0), s(3, "wrong_ball_first", 1, hand: true))
        check(local == .foul(title: "Lỗi chạm sai bi đầu tiên", detail: "Cú của An · Bình được bi cái trong tay", warning: nil, seat: 0),
              "names: \(String(describing: local))")
        // vs computer, a choice for the incoming player, and the three-foul warning
        let choice = d(s(0, "break", 0, cpu: true), s(1, "three_ball_break_not_met", 1, choice: true, warn: true, cpu: true))
        check(choice == .foul(title: "three_ball_break_not_met", detail: "Cú của bạn · Máy được chọn nhận bàn hoặc trả lượt",
                              warning: "Đã 2 lỗi liên tiếp · thêm một lỗi nữa là thua ván", seat: 0), "choice + warning: \(String(describing: choice))")
        // a foul without ball in hand (8-ball rules variant): "Mất lượt"
        let lost = d(s(6, "legal_pot", 0), s(7, "no_rail_after_contact", 1))
        if case .foul(_, let detail, _, _)? = lost { check(detail.hasSuffix("Mất lượt"), "lost turn: \(detail)") } else { check(false, "no-rail foul shows a card") }

        // A2: the pill after a plain miss, never together with a foul card
        check(d(s(2, "legal_pot", 0, net: true), s(3, "turn_passed", 1, net: true)) == .turn(text: "Lượt đối thủ", seat: 1), "pill: opponent")
        check(d(s(3, "turn_passed", 1, net: true), s(4, "turn_passed", 0, net: true)) == .turn(text: "Lượt của bạn", seat: 0), "pill: own")
        check(d(s(3, "turn_passed", 1, cpu: true), s(4, "turn_passed", 0, cpu: true)) == .turn(text: "Lượt của bạn", seat: 0), "pill: vs computer")
        check(d(s(3, "turn_passed", 0), s(4, "turn_passed", 1)) == .turn(text: "Lượt Bình", seat: 1), "pill: two players, names")
        if case .turn? = scratch { check(false, "a foul never shows the pill") }
        // a push-out answered with "pass": no new shot but the turn changed
        check(d(s(5, "push_out_choice", 1), s(5, "choice_pass", 0)) == .turn(text: "Lượt An", seat: 0), "pill after a choice")

        // silence
        check(d(nil, s(1, "scratch", 0, hand: true)) == nil, "no previous state (first sync): nothing")
        check(d(s(3, "legal_pot", 0), s(4, "legal_pot", 0)) == nil, "potted and stays: nothing")
        check(d(s(5, "scratch", 0, hand: true), s(5, "scratch", 0, hand: true)) == nil, "same state again: nothing (no repeats)")
        check(d(s(9, "turn_passed", 1), s(0, "break", 0)) == nil, "new rack: nothing")
        check(d(s(8, "legal_pot", 0), s(9, "nine_ball_win", 0, winner: 0)) == nil, "rack won: nothing")
        check(d(s(4, "legal_pot", 1), s(5, "scratch", 0, hand: true), foul: false) == .turn(text: "Lượt An", seat: 0), "foul card off: the pill still says whose turn")
        check(d(s(4, "legal_pot", 1), s(5, "scratch", 0, hand: true), foul: false, pill: false) == nil, "both off: nothing")
        check(d(s(2, "legal_pot", 0), s(3, "turn_passed", 1), pill: false) == nil, "pill off")

        // A4: taps while calling (pockets in solver order, 9-ft table)
        let x = 0.635, y = 1.27, holes = [(-x, -y), (x, -y), (-x, 0.0), (x, 0.0), (-x, y), (x, y)]
        let near = [(id: 9, x: 0.56, y: 1.19)]   // ball 9 sitting 11 cm from the foot-right pocket (the owner's screenshot)
        check(CallTap.target(0.565, 1.195, balls: near, holes: holes) == (9, -1), "a tap on a ball beside the pocket picks the ball")
        check(CallTap.target(0.63, 1.265, balls: near, holes: holes) == (0, 5), "a tap in the pocket mouth still calls the pocket")
        check(CallTap.target(0.45, 1.10, balls: near, holes: holes) == (0, 5), "a tap 25 cm away still reaches the pocket")
        check(CallTap.target(0.0, 0.6, balls: near, holes: holes) == (0, -1), "mid-table: nothing")
        check(CallTap.target(0.62, 0.02, balls: [], holes: holes) == (0, 3), "side pocket")
        print(failures == 0 ? "PASS MatchNoticeTests: foul card + turn pill + call taps (22 checks)" : "FAIL MatchNoticeTests (\(failures))")
        exit(failures == 0 ? 0 : 1)
    }
}
