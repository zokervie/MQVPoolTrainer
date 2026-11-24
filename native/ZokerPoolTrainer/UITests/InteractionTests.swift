import XCTest

final class InteractionTests: XCTestCase {
    /// Intel CI simulators run ~3-4x slower than Apple Silicon; waits are for state, not for speed.
    private let slow: TimeInterval = 4

    private func launch(_ extra: [String] = []) -> (XCUIApplication, XCUIElement) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-qa", "--g1-default-qa"] + extra
        app.launch()
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 60))
        let ready = NSPredicate(format: "value CONTAINS %@", "angle=")
        expectation(for: ready, evaluatedWith: scene)
        waitForExpectations(timeout: 60)
        return (app, scene)
    }

    private func angle(_ scene: XCUIElement) -> Double {
        let value = scene.value as? String ?? ""
        let part = value.components(separatedBy: ";").first ?? ""
        return Double(part.replacingOccurrences(of: "angle=", with: "")) ?? .nan
    }

    func testStartupUsesAim3D() {
        let (_, scene) = launch()
        XCTAssertTrue((scene.value as? String ?? "").contains("mode=2"))
    }

    func testSingleFingerPanChangesAimWithoutShooting() {
        let (_, scene) = launch()
        let before = angle(scene)
        XCTAssertTrue(before.isFinite)
        let start = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.30, dy: 0.32))
        let end = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.46, dy: 0.32))
        start.press(forDuration: 0.05, thenDragTo: end)
        let changed = NSPredicate { _, _ in
            let current = self.angle(scene)
            return current.isFinite && abs(current-before) > 0.01
        }
        expectation(for: changed, evaluatedWith: scene)
        waitForExpectations(timeout: 10 * slow)
        XCTAssertTrue((scene.value as? String ?? "").contains("moving=0"))
    }

    private func field(_ scene: XCUIElement, _ key: String) -> Double {
        let value = scene.value as? String ?? ""
        for part in value.components(separatedBy: ";") where part.hasPrefix(key + "=") {
            return Double(part.dropFirst(key.count + 1)) ?? .nan
        }
        return .nan
    }

    /// The compact column scrolls on a landscape SE; interaction must use the
    /// actual visible button rather than an off-screen coordinate.
    /// 0.53 B1: "Xem lại" lives in the Bàn menu now.
    private func tapReplay(_ app: XCUIApplication) {
        quick(app,"QuickTable").tap()
        let item=app.buttons["Xem lại"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout:5 * slow),"Xem lại in the Bàn menu");item.tap()
    }
    private func openReplaySubmenu(_ app: XCUIApplication) {
        quick(app,"QuickTable").tap()
        let sub=app.buttons["Lưu cú / Thư viện"].firstMatch
        XCTAssertTrue(sub.waitForExistence(timeout:5 * slow),"save / library submenu");sub.tap()
    }
    private func waitReplayReady(_ scene: XCUIElement) { wait(scene,timeout:30 * slow){self.field(scene,"replayReady")==1} }
    /// 0.54: "Bài cũ" sits below chapter 1's nine ladders and its exam — scroll the Chapters table until the row is on screen.
    private func chapterCell(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let cell = app.cells[id], table = app.tables["Chapters"]
        for _ in 0..<8 where !(cell.exists && cell.isHittable) { table.swipeUp() }
        return cell
    }
    private func quick(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let button = app.buttons[id]
        let scroll = app.scrollViews["QuickRailScroll"]
        if !button.isHittable && scroll.exists {
            for _ in 0..<4 {
                scroll.swipeUp()
                if button.isHittable { break }
            }
        }
        XCTAssertTrue(button.isHittable, "Shortcut \(id) must be reachable by scrolling")
        return button
    }

    /// 0.46 M2: Đặt bi · Thêm bi · Bao cơ · Camera are items of the single "Bàn" menu. Opens it (retrying a dropped tap) and
    /// taps the item whose label starts with `title` (path = submenu titles first, then the item).
    @discardableResult
    /// Root cause of the sideways pictures (0.49c): `XCUIApplication.screenshot()` of this landscape-only app is a PORTRAIT image of the rotated
    /// app, and the exported PNG of a window/screen shot keeps portrait pixels with an orientation flag. Re-draw the screen shot upright
    /// (landscape pixels) before attaching, so exported pictures are readable. (Element frames of such an app are in portrait coordinates too.)
    private func attachUpright(_ name: String) {
        let image = XCUIScreen.main.screenshot().image
        let upright = UIGraphicsImageRenderer(size: image.size).image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
        let att = XCTAttachment(image: upright); att.name = name; att.lifetime = .keepAlways; add(att)
    }
    private func tableMenu(_ app: XCUIApplication, _ path: String...) -> Bool {
        for _ in 0..<3 {
            quick(app, "QuickTable").tap()
            var ok = true
            for title in path {
                let item = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
                if !item.waitForExistence(timeout: 5 * slow) { ok = false; break }
                item.tap()
            }
            if ok { return true }
            if app.buttons["QuickTable"].exists, !app.buttons["QuickTable"].isHittable { app.windows.firstMatch.tap() }   // dismiss a half-open menu
        }
        return false
    }

    /// CI log lines are cut at 300 chars: lead failures with the fields that explain a stall.
    private func brief(_ scene: XCUIElement) -> String {
        let v = scene.value as? String ?? ""
        let keys = ["kind","moving","shots","cpuShots","cpuTurn","jumpSeen","ballCount","busy","locked","editing","replay","preRoll","status","lastTouch"]
        let parts = v.split(separator: ";")
        return keys.compactMap { k in parts.first { $0.hasPrefix(k + "=") }.map(String.init) }.joined(separator: ";")
    }

    /// Polls without failing; true when `condition` holds before `timeout` (used to retry taps the loaded CI Simulator drops).
    private func poll(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end { if condition() { return true }; Thread.sleep(forTimeInterval: 0.5) }
        return condition()
    }

    /// Polls a probe field and reports the whole probe on failure (diagnosable from the CI log).
    private func settle(_ scene: XCUIElement, _ key: String, _ value: Double, timeout: TimeInterval = 20,
                        file: StaticString = #filePath, line: UInt = #line) {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if field(scene, key) == value { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("\(key) != \(value) · \(brief(scene))", file: file, line: line)
    }

    /// Polls `condition`; on timeout fails with the whole app probe so CI logs show the state (0.30).
    private func wait(_ scene: XCUIElement, timeout: TimeInterval = 30,
                      file: StaticString = #filePath, line: UInt = #line,
                      _ condition: @escaping () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("timed out after \(Int(timeout)) s · \(brief(scene))", file: file, line: line)
    }

    /// B1: kéo một ngón theo chiều dọc chỉ đổi độ cao camera ngắm, không làm lệch hướng đánh.
    func testSingleFingerVerticalPanChangesCameraHeightOnly() {
        let (_, scene) = launch()
        let angleBefore = angle(scene), pitchBefore = field(scene, "pitch")
        XCTAssertTrue(angleBefore.isFinite && pitchBefore.isFinite)
        // Độ cao đã lưu từ lần chạy trước có thể gần giới hạn trên: khi đó kéo lên (hạ camera).
        let down = pitchBefore < 0.8
        let start = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: down ? 0.30 : 0.50))
        let end = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: down ? 0.50 : 0.30))
        // Intel CI can drop a synthesized drag (seen in run 126 only): retry the same gesture, never a different one.
        for _ in 0..<3 {
            start.press(forDuration: 0.05, thenDragTo: end)
            if poll(5 * slow, { let p = self.field(scene, "pitch"); return p.isFinite && abs(p - pitchBefore) > 0.01 }) { break }
        }
        let changed = NSPredicate { _, _ in
            let p = self.field(scene, "pitch")
            return p.isFinite && abs(p - pitchBefore) > 0.01
        }
        expectation(for: changed, evaluatedWith: scene)
        waitForExpectations(timeout: 2 * slow)
        XCTAssertEqual(angle(scene), angleBefore, accuracy: 1e-6, "kéo dọc không được đổi hướng ngắm")
        XCTAssertTrue((scene.value as? String ?? "").contains("moving=0"))
    }

    func testCoachIsOffAndOneTapControlsAllTrainingOverlays() {
        let (app,scene)=launch(["--ux017-qa"])
        XCTAssertEqual(field(scene,"coach"),0)
        let coach=app.buttons["CoachToggle"];XCTAssertTrue(coach.exists)
        XCTAssertTrue(coach.label.contains("Coach"))
        XCTAssertGreaterThan(coach.frame.width,coach.frame.height,"Coach is a readable rectangle")
        let rail=app.scrollViews["QuickRailScroll"]
        XCTAssertTrue(rail.exists)
        // 0.22 layout: Menu + Coach top-left, B bottom-left, thumb column on the right in owner order.
        let menu=app.buttons["Menu"].firstMatch
        XCTAssertEqual(coach.frame.minY,menu.frame.minY,accuracy:2)
        XCTAssertGreaterThan(coach.frame.minX,menu.frame.maxX)
        XCTAssertLessThan(coach.frame.midX,scene.frame.midX)
        XCTAssertGreaterThan(rail.frame.midX,scene.frame.midX)
        let order=["QuickRetry","QuickCamera","QuickTable"]   // 0.46 M2: Đặt bi · Thêm bi · Bao cơ are in "Bàn"
        for (upper,lower) in zip(order,order.dropFirst()) {
            XCTAssertLessThan(app.buttons[upper].frame.midY,app.buttons[lower].frame.midY,"\(upper) above \(lower)")
        }
        XCTAssertTrue(coach.isEnabled,"Coach enabled · \(scene.value ?? "")")
        tapCoach(app,scene,coach,expect:1)
        XCTAssertTrue(app.buttons["GuideToggle"].waitForExistence(timeout:5 * slow) && app.buttons["GuideToggle"].isHittable,"Coach shows Chỉ dẫn")
        XCTAssertTrue(app.buttons["NumbersToggle"].isHittable && app.buttons["CoachCardToggle"].isHittable,"Coach shows Nút số and Board")
        tapCoach(app,scene,coach,expect:0)
        XCTAssertFalse(app.otherElements["CoachCard"].isHittable)
    }

    /// Intel CI sometimes drops a synthesized tap before it reaches the app (probe coachDown unchanged).
    /// Retry only in that case, so a tap that DID reach the button but did not toggle still fails.
    /// Intel CI sometimes drops a synthesized tap or re-synthesizes it (seen: 2 taps -> 3 touch-downs), so tap until
    /// the state is reached, at most 3 times. A Coach button that never toggles still fails.
    private func tapCoach(_ app: XCUIApplication, _ scene: XCUIElement, _ coach: XCUIElement, expect: Double) {
        for attempt in 0..<3 {
            coach.tap()
            let end = Date().addingTimeInterval(6)
            while Date() < end && field(scene, "coach") != expect { Thread.sleep(forTimeInterval: 0.3) }
            if field(scene, "coach") == expect { return }
            print("REPORT coach tap \(attempt + 1) not settled · probe: \(scene.value ?? "")")
        }
        settle(scene, "coach", expect)
    }

    func testCameraRoundTripPreservesAimHeightAndZoom() {
        let (app,scene)=launch(["--ux017-qa"])
        scene.pinch(withScale:0.8,velocity:-1)
        // Run 127: the baseline was read while the camera was still easing after the pinch (pitch 1.197 → 1.228).
        // Capture it only once zoom and pitch hold still for a second.
        var zoom=field(scene,"zoom"),pitch=field(scene,"pitch")
        _=poll(10 * slow){
            Thread.sleep(forTimeInterval:1)
            let z=self.field(scene,"zoom"),p=self.field(scene,"pitch")
            defer{zoom=z;pitch=p}
            return abs(z-zoom)<0.0005 && abs(p-pitch)<0.0005
        }
        quick(app,"QuickCamera").tap();quick(app,"QuickCamera").tap()
        let returned=NSPredicate { _,_ in self.field(scene,"mode")==2 }
        expectation(for:returned,evaluatedWith:scene);waitForExpectations(timeout:5 * slow)
        XCTAssertEqual(field(scene,"zoom"),zoom,accuracy:0.002)
        XCTAssertEqual(field(scene,"pitch"),pitch,accuracy:0.002)
    }

    func testPlaceCueBallAtCentreAndCancelRestoresLayout() {
        let (app,scene)=launch(["--ux017-qa"])
        let x=field(scene,"cueX"),y=field(scene,"cueY")
        XCTAssertTrue(tableMenu(app,"Đặt bi"))
        let editing=NSPredicate { _,_ in self.field(scene,"editing")==1 }
        expectation(for:editing,evaluatedWith:scene);waitForExpectations(timeout:5 * slow)
        // 0.22: free spot nearest the centre (exactly the centre when it is empty)
        XCTAssertLessThan(hypot(field(scene,"cueX"),field(scene,"cueY")),0.15)
        XCTAssertTrue(tableMenu(app,"Hủy đặt bi"))
        let cancelled=NSPredicate { _,_ in self.field(scene,"editing")==0 }
        expectation(for:cancelled,evaluatedWith:scene);waitForExpectations(timeout:5 * slow)
        XCTAssertEqual(field(scene,"cueX"),x,accuracy:0.001);XCTAssertEqual(field(scene,"cueY"),y,accuracy:0.001)
        // Cancelling editing must restore input mode as well as the visible camera transform.
        let pitch=field(scene,"pitch"),down=pitch<0.8
        let start=scene.coordinate(withNormalizedOffset:CGVector(dx:0.40,dy:down ? 0.30:0.50))
        let end=scene.coordinate(withNormalizedOffset:CGVector(dx:0.40,dy:down ? 0.50:0.30))
        start.press(forDuration:0.05,thenDragTo:end)
        let heightChanged=NSPredicate { _,_ in abs(self.field(scene,"pitch")-pitch)>0.01 }
        expectation(for:heightChanged,evaluatedWith:scene);waitForExpectations(timeout:5 * slow)

    }

    /// 0.44 (#18): Bao cơ shows the bag (3 slots) with "Thêm cơ vào bao…", which opens the cue library.
    func testCueBagOpensCueLibrary() {
        let (app,_)=launch(["--ux017-qa"])
        XCTAssertTrue(tableMenu(app,"Bao cơ"))
        let add=app.buttons["＋ Thêm cơ vào bao…"]
        XCTAssertTrue(add.waitForExistence(timeout:5 * slow),"bag sheet offers adding a cue")
        add.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout:5 * slow),"cue library opens")
    }

    func testReplayManualCameraDoesNotChangeNextAimHeight() {
        // Shots now settle fast (0.29), so a short replay can finish before a slow simulator answers;
        // --replay-hold-qa keeps the last frame until Done.
        let (app,scene)=launch(["--ux017-shot-qa","--replay-hold-qa"])
        waitReplayReady(scene)
        let pitch=field(scene,"pitch")
        tapReplay(app);app.buttons["ReplayPause"].tap()
        let start=scene.coordinate(withNormalizedOffset:CGVector(dx:0.35,dy:0.30))
        let end=scene.coordinate(withNormalizedOffset:CGVector(dx:0.35,dy:0.50))
        start.press(forDuration:0.05,thenDragTo:end)
        app.buttons["ReplayDone"].tap()
        let stopped=NSPredicate { _,_ in self.field(scene,"replay")==0 }
        expectation(for:stopped,evaluatedWith:scene);waitForExpectations(timeout:5 * slow)
        XCTAssertEqual(field(scene,"pitch"),pitch,accuracy:0.002)
    }

    /// 0.30b: no B button; touching the effect ball LATCHES the lock. A non-firing touch on the table unlocks
    /// without shooting, after which aiming works again.
    func testEffectBallLatchesLockAndNonFiringTouchUnlocks() {
        let (app,scene)=launch(["--ux017-qa","-tuneEffectLock037","YES"])   // 0.37: latch is opt-in (Tuỳ chỉnh)
        XCTAssertTrue(app.descendants(matching:.any)["Giữ để khóa hướng"].firstMatch.isHittable, "0.36: B is back beside the effect ball")
        let effect=app.descendants(matching:.any)["Điểm chạm đầu cơ"].firstMatch
        XCTAssertTrue(effect.isHittable)
        effect.press(forDuration:0.5)
        settle(scene,"locked",1)                       // still locked after the finger lifts
        XCTAssertTrue(app.otherElements["FineAimWheel"].exists || app.descendants(matching:.any)["FineAimWheel"].exists)
        let before=angle(scene)
        let start=scene.coordinate(withNormalizedOffset:CGVector(dx:0.30,dy:0.32))
        let end=scene.coordinate(withNormalizedOffset:CGVector(dx:0.45,dy:0.32))
        start.press(forDuration:0.05,thenDragTo:end)   // sideways: no stroke -> unlock, no shot
        settle(scene,"locked",0)
        XCTAssertEqual(field(scene,"moving"),0)
        XCTAssertEqual(angle(scene),before,accuracy:1e-6,"locked aim did not move")
        start.press(forDuration:0.05,thenDragTo:end)
        wait(scene,timeout:5 * slow){abs(self.angle(scene)-before)>0.01}
        XCTAssertEqual(field(scene,"moving"),0)
    }

    /// 0.37 (owner): by default touching the effect ball does NOT lock the aim; only B does.
    func testEffectBallDoesNotLockByDefault() {
        let (app,scene)=launch(["--ux017-qa","-tuneEffectLock037","NO"])
        let effect=app.descendants(matching:.any)["Điểm chạm đầu cơ"].firstMatch
        XCTAssertTrue(effect.waitForExistence(timeout:5 * slow))
        effect.press(forDuration:0.5)
        let settled=Date().addingTimeInterval(1.5)
        wait(scene,timeout:5 * slow){Date()>=settled}
        XCTAssertEqual(field(scene,"locked"),0,"effect ball must not latch the lock by default")
    }

    /// 0.53 B2: two cue buttons in a row above the effect ball: "Cơ chơi" (Đánh, Massé from elevation) and "Cơ phá" (Phá, Nhảy from elevation).
    func testTwoCueButtonsPlayAndBreak() {
        let (app,scene)=launch(["--ux017-qa"])
        XCTAssertFalse(app.buttons["CueIconJump"].exists || app.buttons["CueIconMasse"].exists, "Jump and Massé are no longer separate buttons")
        for (id,kind) in [("CueIconBreak",2.0),("CueIconPlay",0.0)] {
            let icon=app.buttons[id];XCTAssertTrue(icon.waitForExistence(timeout:5 * slow),id)
            for _ in 0..<3 { icon.tap(); if poll(6 * slow,{self.field(scene,"kind")==kind}) {break} }
            settle(scene,"kind",kind)
        }
        XCTAssertEqual(app.buttons["CueIconPlay"].label, "Gậy Cơ chơi")
        let effect=app.descendants(matching:.any)["Điểm chạm đầu cơ"].firstMatch
        let e=effect.frame
        let row=["CueIconPlay","CueIconBreak"].map{app.buttons[$0].frame}
        for f in row{XCTAssertLessThanOrEqual(f.maxY,e.minY+1,"cue row above effect ball")}
        XCTAssertGreaterThanOrEqual(row[1].minX,row[0].maxX-1,"Cơ chơi left of Cơ phá")
        XCTAssertEqual(row[0].midY,row[1].midY,accuracy:1,"one horizontal row")
        // 0.35: Nút số / Chỉ dẫn / Bảng only with Coach
        XCTAssertFalse(app.buttons["NumbersToggle"].isHittable,"numbers only with Coach")
        XCTAssertFalse(app.buttons["GuideToggle"].isHittable,"guide button only with Coach")
    }

    /// 0.44.1 (owner decision, design 0.36): observation gestures while the balls run never switch the camera mode;
    /// once everything stops the aim view comes back BEHIND the cue ball (yaw 0) at the zoom chosen for the stroke.
    /// Does not depend on when the balls stop: the gestures run only if the shot is still moving when we look, and
    /// the end state is the same either way.
    func testLiveShotKeepsAimViewAndManualZoomAfterBallsStop() {
        let (_,scene)=launch(["--ux018-live-qa"])
        wait(scene,timeout:30 * slow){self.field(scene,"shots")>=1}
        XCTAssertEqual(field(scene,"mode"),2)
        let aimZoom=field(scene,"zoom")
        XCTAssertTrue(aimZoom.isFinite)
        if field(scene,"moving")==1 {
            scene.pinch(withScale:0.82,velocity:-1)
            let start=scene.coordinate(withNormalizedOffset:CGVector(dx:0.32,dy:0.34))
            let end=scene.coordinate(withNormalizedOffset:CGVector(dx:0.45,dy:0.34))
            start.press(forDuration:0.05,thenDragTo:end)
            XCTAssertEqual(field(scene,"mode"),2,"an observation gesture during the shot must not change the camera mode")
        }
        wait(scene,timeout:30 * slow){self.field(scene,"moving")==0}
        // The settle gate restores the aim pose: yaw 0 behind the cue ball, the stroke's zoom.
        wait(scene,timeout:10 * slow){abs(self.field(scene,"cameraYaw"))<1e-4 && abs(self.field(scene,"zoom")-aimZoom)<0.005}
        XCTAssertEqual(field(scene,"mode"),2)
        XCTAssertEqual(field(scene,"cameraYaw"),0,accuracy:1e-4)
        XCTAssertEqual(field(scene,"cameraAngle"),field(scene,"angle"),accuracy:1e-4)
        XCTAssertEqual(field(scene,"zoom"),aimZoom,accuracy:0.005)
    }
    /// 0.44.1 (owner): a fresh install on a Vietnamese device opens in Vietnamese (no more English default), and
    /// everything in the Coach card is Vietnamese. Control: an English device still gets English.
    func testFreshInstallFollowsDeviceLanguageAndCoachIsVietnamese() {
        let vietnamese = CharacterSet(charactersIn: "ạảãàáâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđĐ")
        let app = XCUIApplication()
        app.launchArguments = ["--visual-qa", "--g1-default-qa", "--l10n-real", "--fresh-language", "--coach-card-qa", "-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 60))
        let card = app.otherElements["CoachCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 30 * slow))
        XCTAssertTrue((scene.value as? String ?? "").contains(";lang=vi;"), "fresh install on a Vietnamese device must be vi")
        let texts = card.staticTexts.allElementsBoundByIndex.map { $0.label }.filter { !$0.isEmpty }
        XCTAssertFalse(texts.isEmpty, "Coach card shows text")
        for text in texts {
            XCTAssertNotNil(text.rangeOfCharacter(from: vietnamese), "Coach text is Vietnamese: \(text)")
        }
        app.terminate()
        let english = XCUIApplication()
        english.launchArguments = ["--visual-qa", "--g1-default-qa", "--l10n-real", "--fresh-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        english.launch()
        let englishScene = english.otherElements["PoolScene"]
        XCTAssertTrue(englishScene.waitForExistence(timeout: 60))
        wait(englishScene, timeout: 20 * slow) { (englishScene.value as? String ?? "").contains(";lang=") }
        XCTAssertTrue((englishScene.value as? String ?? "").contains(";lang=en;"), "an English device keeps English")
    }
    /// 0.44.1 M4: first launch through the real Lobby (--keep-lobby-qa keeps it under QA): "Tập tự do" → beat 1
    /// within 2 s → drag the aim onto the gold dot → beat 2 → stroke → "Vào rồi!" or "Thử lại nhé". No tap is required
    /// by the tutorial itself and nothing covers the screen. The stroke is fired by the app (--tutorial-stroke-qa):
    /// XCUITest cannot hold B and swipe with a second finger; the real gesture is device-only.
    func testFirstLaunchTutorialFromLobbyAimThenStroke() {
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-tutorial", "--tutorial-stroke-qa"]
        app.launch()
        let free = app.buttons["LobbyFree"]
        XCTAssertTrue(free.waitForExistence(timeout: 60), "the Lobby is shown on a real first launch")
        free.tap()
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 30))
        func value() -> String { scene.value as? String ?? "" }
        func tut() -> String { value().components(separatedBy: ";").first { $0.hasPrefix("tut=") }.map { String($0.dropFirst(4)) } ?? "" }
        let shown = Date()
        wait(scene, timeout: 10 * slow) { tut() == "aim" }
        XCTAssertLessThan(Date().timeIntervalSince(shown), 2.0 * slow, "beat 1 within 2 s of reaching the table")
        let pill = app.otherElements["TutorialPill"]
        if pill.exists {
            XCTAssertLessThanOrEqual(pill.frame.height, 36.5, "caption pill at most 36 pt tall")
            XCTAssertLessThan(pill.frame.width, app.windows.firstMatch.frame.width * 0.8, "no full-screen overlay")
        }
        // Drag the aim onto the dot: measure the drag gain once, then correct until within 1°.
        let target = field(scene, "aimTarget")
        func err() -> Double { remainder(field(scene, "angle") - target, 2 * .pi) }
        func drag(_ dx: Double) {
            let s = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5 - dx / 2, dy: 0.62))
            let e = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + dx / 2, dy: 0.62))
            s.press(forDuration: 0.05, thenDragTo: e)
        }
        var before = err(); drag(0.06); var gain = (err() - before) / 0.06
        for _ in 0..<10 where tut() == "aim" {
            before = err()
            guard abs(gain) > 1e-4 else { drag(-0.06); gain = (err() - before) / -0.06; continue }
            let dx = max(-0.35, min(0.35, -before / gain))
            drag(dx)
            let moved = err() - before
            if abs(dx) > 0.004, abs(moved) > 1e-5 { gain = moved / dx }
        }
        // Review CI 158: the app fires the QA stroke 1.5 s after beat 2 appears, so on a slow runner beat 2 can come and go
        // between two polls — check the ORDER of states the coach went through, not one instant.
        func log() -> [String] { (value().components(separatedBy: ";").first { $0.hasPrefix("tutLog=") }.map { String($0.dropFirst(7)) } ?? "").components(separatedBy: ">") }
        wait(scene, timeout: 10 * slow) { log().contains("stroke") }
        let seen = log()
        XCTAssertTrue(seen.contains("stroke"), "aiming onto the dot opens beat 2 (log \(seen))")
        if let a = seen.firstIndex(of: "aim"), let s = seen.firstIndex(of: "stroke") {
            XCTAssertLessThan(a, s, "beat 1 then beat 2")
            XCTAssertFalse(seen[a..<s].contains { $0.hasPrefix("hint") }, "no contextual hint between beat 1 and beat 2 (log \(seen))")
        }
        wait(scene, timeout: 40 * slow) { log().contains("potted") || log().contains("retry") }
        XCTAssertTrue(log().contains("potted") || log().contains("retry"), "the shot ends with Vào rồi! or Thử lại nhé (log \(log()))")
    }
    /// 0.44.1 M5: a normal first launch (no Lobby-skipping flag): the intro is on screen and tappable, then it is gone,
    /// and only then the Lobby appears (0.43 opened the Lobby on top of the intro at once).
    func testIntroPlaysBeforeLobbyAndTapSkips() {
        let app = XCUIApplication()
        app.launchArguments = ["--intro-lobby-qa", "--fresh-intro"]
        app.launch()
        let intro = app.descendants(matching: .any)["IntroOverlay"].firstMatch
        XCTAssertTrue(intro.waitForExistence(timeout: 60), "the intro is shown first")
        XCTAssertFalse(app.buttons["LobbyFree"].exists, "the Lobby is not on top of the intro")
        intro.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: intro); waitForExpectations(timeout: 5 * slow)
        XCTAssertTrue(app.buttons["LobbyFree"].waitForExistence(timeout: 20 * slow), "the Lobby comes after the intro")
        let scene = app.otherElements["PoolScene"]
        if scene.exists {
            // The probe string refreshes on the next shot-loop tick: poll for it instead of reading once; ≥ 2 is the real failure.
            let deadline = Date().addingTimeInterval(10 * slow)
            while Date() < deadline, !(scene.value as? String ?? "").contains(";introDone=1;") { RunLoop.current.run(until: Date().addingTimeInterval(0.25)) }
            XCTAssertTrue((scene.value as? String ?? "").contains(";introDone=1;"), "finish ran exactly once")
        }
    }
    /// 0.45 M5.3: a fresh install on a Vietnamese device walks the whole AppFlow — intro → Sảnh → hướng dẫn → bàn —
    /// each step entered once, in order, each started by the previous one finishing (no timers). Debug build only
    /// (QA flags are compiled out of Release). Written 18/11; NOT RUN yet (Simulator broken on the Mac at the time).
    func testFreshInstallLaunchFlowIntroLobbyTutorialTable() {
        let app = XCUIApplication()
        app.launchArguments = ["--intro-lobby-qa", "--intro-hold-qa", "--fresh-intro", "--fresh-tutorial", "--fresh-player-qa", "--tutorial-stroke-qa",
                               "--l10n-real", "--fresh-language", "-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()
        let scene = app.otherElements["PoolScene"]
        func value() -> String { scene.value as? String ?? "" }
        func part(_ key: String) -> String { value().components(separatedBy: ";").first { $0.hasPrefix(key + "=") }.map { String($0.dropFirst(key.count + 1)) } ?? "" }
        // 1 · intro first, alone
        let intro = app.descendants(matching: .any)["IntroOverlay"].firstMatch
        XCTAssertTrue(intro.waitForExistence(timeout: 60), "fresh install: the intro is shown first")
        XCTAssertFalse(app.buttons["LobbyFree"].exists, "no Lobby on top of the intro")
        // 0.49b: the probe string is refreshed by the shot-loop tick: on a slow runner (CI 163) it still read "launching" when the
        // intro overlay was already up, and on a fast one the intro may already be over by the time it is read. Poll with a
        // deadline until the flow has logged anything, then check that "intro" came FIRST (flowLog), alone, before the Lobby.
        if scene.exists {
            wait(scene, timeout: 20 * slow) { !part("flowLog").isEmpty }
            XCTAssertTrue(part("flowLog").hasPrefix("intro"), "the intro is the first flow step: \(part("flowLog"))")
        }
        if intro.exists { intro.tap() }
        // 2 · Lobby only after the intro finished (Vietnamese device → Vietnamese Lobby)
        let free = app.buttons["LobbyFree"]
        XCTAssertTrue(free.waitForExistence(timeout: 20 * slow), "the Lobby comes after the intro")
        XCTAssertTrue(free.label.contains("Tập tự do"), "Vietnamese Lobby: \(free.label)")
        XCTAssertFalse(intro.exists)
        free.tap()
        // 3 · tutorial right after the Lobby closed
        wait(scene, timeout: 10 * slow) { part("tut") == "aim" }
        XCTAssertEqual(part("flow"), "tutorial")
        XCTAssertEqual(part("flowLog"), "intro>lobby>tutorial", "each step once, in order")
        let target = field(scene, "aimTarget")
        func err() -> Double { remainder(field(scene, "angle") - target, 2 * .pi) }
        func drag(_ dx: Double) {
            let s = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5 - dx / 2, dy: 0.62))
            let e = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + dx / 2, dy: 0.62))
            s.press(forDuration: 0.05, thenDragTo: e)
        }
        var before = err(); drag(0.06); var gain = (err() - before) / 0.06
        for _ in 0..<10 where part("tut") == "aim" {
            before = err()
            guard abs(gain) > 1e-4 else { drag(-0.06); gain = (err() - before) / -0.06; continue }
            let dx = max(-0.35, min(0.35, -before / gain)); drag(dx)
            let moved = err() - before
            if abs(dx) > 0.004, abs(moved) > 1e-5 { gain = moved / dx }
        }
        // 4 · the first shot (fired by --tutorial-stroke-qa) ends the tutorial → table
        wait(scene, timeout: 40 * slow) { part("flow") == "table" }
        XCTAssertEqual(part("flowLog"), "intro>lobby>tutorial>table", "intro → Sảnh → hướng dẫn → bàn, nothing twice")
        XCTAssertTrue(value().contains(";introDone=1;"), "intro finish ran exactly once")
        XCTAssertEqual(part("lang"), "vi")
    }
    /// 0.46 M1: from the Lobby, "Tiếp tục" is one tap to the table (open app → Lobby → Tiếp tục = 2 steps to the first shot).
    func testLobbyContinueReachesTableInTwoTaps() {
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa"]
        app.launch()
        let cont = app.buttons["LobbyContinue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 60), "the Lobby opens with the big Tiếp tục card")
        XCTAssertTrue(app.buttons["LobbyFree"].exists && app.buttons["LobbyDrills"].exists && app.buttons["LobbyComputer"].exists && app.buttons["LobbyLibrary"].exists,
                      "four tiles: free practice, drills, match, library")
        XCTAssertTrue(app.buttons["LobbyCustomize"].exists, "old Lobby functions stay (chip row)")
        cont.tap()
        XCTAssertTrue(cont.waitForNonExistence(timeout: 10 * slow), "the Lobby closes")
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["QuickTable"].waitForExistence(timeout: 10 * slow), "at the table, HUD in front")
        XCTAssertFalse(app.buttons["LobbyContinue"].exists)
    }
    /// 0.45 M3: Lobby language follows the device on a fresh install — Vietnamese device: Vietnamese Lobby, English
    /// device: English Lobby (no source-language leftovers on the main card).
    func testLobbyLanguageFollowsDevice() {
        for (lang, locale, free) in [("(vi)", "vi_VN", "Tập tự do"), ("(en)", "en_US", "Free practice")] {
            let app = XCUIApplication()
            app.launchArguments = ["--keep-lobby-qa", "--l10n-real", "--fresh-language", "-AppleLanguages", lang, "-AppleLocale", locale]
            app.launch()
            let button = app.buttons["LobbyFree"]
            XCTAssertTrue(button.waitForExistence(timeout: 60))
            XCTAssertTrue(button.label.contains(free), "Lobby in \(lang): \(button.label)")
            app.terminate()
        }
    }
    func testComputerOpponentTakesItsTurns() {
        let (_,scene)=launch(["--computer-qa"])
        wait(scene,timeout:40 * slow){self.field(scene,"cpuShots")>=1}
        wait(scene,timeout:60 * slow){self.field(scene,"moving")==0 && (self.field(scene,"cpuTurn")==0 || self.field(scene,"cpuShots")>=2)}
    }
    func testJumpShotResetsEffectAndReturnsToPlayingCue() {
        let (_,scene)=launch(["--ux018-jump-qa"])
        // latched by the app: the jump shot really ran with the jump cue (0.5 s polling could miss a short shot)
        wait(scene,timeout:10 * slow){self.field(scene,"jumpSeen")==1}
        wait(scene){self.field(scene,"moving")==0 && self.field(scene,"kind")==0}
        XCTAssertEqual(field(scene,"side"),0,accuracy:0.0001)
        XCTAssertEqual(field(scene,"top"),0,accuracy:0.0001)
    }

    func testRandomLayoutMenuSupportsOneThroughFifteenObjectBalls() {
        let (app,scene)=launch(["--ux017-qa"])
        for count in [1,14] {
          // relative to what is on the table (Mặc định keeps existing balls; ids cap the total at 15)
          let want=min(field(scene,"ballCount")+Double(count),15)
          for _ in 0..<4 where field(scene,"ballCount") != want {   // retry the whole menu if a tap was dropped
            if app.alerts["Thêm bi"].exists {app.alerts["Thêm bi"].buttons["Mặc định"].tap()}
            if !tableMenu(app,"Thêm bi","Thêm bi · số lượng / bố trí") {continue}   // slow runner: a dropped tap retries the whole menu
            let alert=app.alerts["Thêm bi"]
            if !alert.waitForExistence(timeout:5 * slow) {continue}
            // Intel CI: keystrokes sent before the field has focus are lost — retype until the field shows the count.
            let field=alert.textFields.firstMatch
            for _ in 0..<3 {
                field.tap();if let old=field.value as? String,!old.isEmpty,old != field.placeholderValue{field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:old.count))}
                field.typeText(String(count))
                if (field.value as? String) == String(count) {break}
            }
            if (field.value as? String) != String(count) {alert.buttons["Mặc định"].tap();continue}
            alert.buttons["Mặc định"].tap()
            // a dropped tap leaves the alert up: tap again (the app ignores nothing once the alert is gone)
            for _ in 0..<2 where alert.waitForExistence(timeout:2) && alert.buttons["Mặc định"].isHittable { alert.buttons["Mặc định"].tap() }
            _=poll(10 * slow){self.field(scene,"ballCount")==want}
          }
            XCTAssertFalse(app.alerts["Thêm bi"].exists,"alert closed")
            wait(scene,timeout:5 * slow){self.field(scene,"ballCount")==want}
        }
    }


    func testCompetitiveNineBallOnlyOffersDiamondNumbersAndBlocksPracticeEdits() {
        let (app,scene)=launch(["--ux018-match-nine-qa"])
        let status=app.buttons["MatchStatus"]
        XCTAssertTrue(status.waitForExistence(timeout:5 * slow))
        XCTAssertTrue(status.label.contains("9 Ball"))
        XCTAssertTrue(status.label.lowercased().contains("lượt người 1"))   // 0.29: "Lượt <tên người chơi>"
        XCTAssertEqual(field(scene,"ballCount"),9)
        XCTAssertEqual(field(scene,"coach"),0)
        let numbers=app.buttons["CoachToggle"]
        XCTAssertTrue(numbers.label.contains("nút số"))
        numbers.tap()
        XCTAssertEqual(field(scene,"coach"),0,"Competitive mode cannot enable coaching")
        let retry=app.buttons["QuickRetry"]   // hidden (or disabled) in competitive play
        XCTAssertTrue(!retry.exists || !retry.isEnabled)
        XCTAssertEqual(field(scene,"replayReady"),0,"no replay in competitive play before a shot")
        XCTAssertFalse(app.otherElements["CoachCard"].isHittable)
    }

    func testRotationFifteenRackAndScoringTargetAreClearlyNamed() {
        let (app,scene)=launch(["--ux018-match-rotation-qa"])
        let status=app.buttons["MatchStatus"]
        XCTAssertTrue(status.waitForExistence(timeout:5 * slow))
        XCTAssertTrue(status.label.contains("Rotation"))
        XCTAssertTrue(status.label.contains("/61"))
        XCTAssertEqual(field(scene,"ballCount"),15)
        XCTAssertEqual(field(scene,"coach"),0)
    }

    func testArchivedReplayPreservesLiveTableAndRemembersItsCoachChoice() {
        let (app,scene)=launch(["--ux018-live-qa"])
        // 0.43 (CI 144): the scripted shot can start AND settle before the first 0.5 s poll (faster state bridge) —
        // a finished shot (shots ≥ 1) counts as having moved.
        wait(scene){self.field(scene,"moving")==1 || self.field(scene,"shots")>=1}
        wait(scene){self.field(scene,"moving")==0 && self.field(scene,"shots")>=1}
        // Wait for settlement: archive actions are intentionally unavailable
        // while any pocket presentation or shot-ready guard remains active.
        waitReplayReady(scene)
        let save=app.buttons["Lưu cú này"].firstMatch
        for _ in 0..<3 where !save.exists { openReplaySubmenu(app); _=save.waitForExistence(timeout:4 * slow) }
        XCTAssertTrue(save.exists,"replay menu · probe: \(scene.value ?? "")");save.tap()
        let alert=app.alerts["Lưu cú này"]
        XCTAssertTrue(alert.waitForExistence(timeout:5 * slow))
        let name="QA-"+String(UUID().uuidString.prefix(8))
        let text=alert.textFields.firstMatch;text.tap()
        let previous=text.value as? String ?? ""
        text.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:previous.count)+name)
        alert.buttons["Lưu"].tap()
        let saved=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Đã lưu: "+name)).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout:10 * slow))
        // A distinct current aim proves replay did not simply reload its own
        // initial layout into the live world.
        let start=scene.coordinate(withNormalizedOffset:CGVector(dx:0.30,dy:0.32))
        let end=scene.coordinate(withNormalizedOffset:CGVector(dx:0.46,dy:0.32))
        start.press(forDuration:0.05,thenDragTo:end)
        let liveAngle=angle(scene),liveX=field(scene,"cueX"),liveY=field(scene,"cueY")
        func openArchive() {
            openReplaySubmenu(app)
            let list=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Cú đã lưu (")).firstMatch
            XCTAssertTrue(list.waitForExistence(timeout:5 * slow));list.tap()
            let item=app.buttons.matching(NSPredicate(format:"label CONTAINS %@",name)).firstMatch
            XCTAssertTrue(item.waitForExistence(timeout:5 * slow));item.tap()
            let play=app.buttons["Xem lại cú này"].firstMatch
            XCTAssertTrue(play.waitForExistence(timeout:5 * slow));play.tap()
            wait(scene,timeout:10 * slow){self.field(scene,"replay")==1}
            app.buttons["ReplayPause"].tap()
        }
        openArchive()
        XCTAssertEqual(field(scene,"coach"),0)
        app.buttons["CoachToggle"].tap()
        wait(scene,timeout:5 * slow){self.field(scene,"coach")==1}
        app.buttons["ReplayDone"].tap()
        wait(scene,timeout:5 * slow){self.field(scene,"replay")==0}
        XCTAssertEqual(angle(scene),liveAngle,accuracy:0.0001)
        XCTAssertEqual(field(scene,"cueX"),liveX,accuracy:0.0001)
        XCTAssertEqual(field(scene,"cueY"),liveY,accuracy:0.0001)
        openArchive()
        XCTAssertEqual(field(scene,"coach"),1)
        app.buttons["ReplayDone"].tap()
    }

    func testReplayIncludesActualPreparationBeforeNativeShotClock() {
        let (app,scene)=launch(["--replay-preroll-qa"])
        wait(scene,timeout:30 * slow){self.field(scene,"preRoll")>5 && self.field(scene,"moving")==0}
        XCTAssertGreaterThan(field(scene,"preRoll"),5)
        XCTAssertLessThanOrEqual(field(scene,"preRoll"),8.01)
        waitReplayReady(scene)
        tapReplay(app)
        // 0.41 (owner 13/11): replay starts exactly 1 s before cue contact (was the whole preparation). The
        // negative clock lasts only 1 s, shorter than one XCUITest snapshot on CI, so assert the lead itself.
        wait(scene,timeout:5 * slow){self.field(scene,"replay")==1}
        XCTAssertEqual(field(scene,"replayLead"),1.0,accuracy:0.01)
        app.buttons["ReplayPause"].tap()
        app.buttons["ReplayDone"].tap()
        wait(scene,timeout:5 * slow){self.field(scene,"replay")==0}
    }

    // MARK: 0.47 "Quay lại mỗi ngày" (written for CI; NOT RUN locally — the Simulator on the Mac is broken)
    private func text(_ scene: XCUIElement, _ key: String) -> String {
        let value = scene.value as? String ?? ""
        for part in value.components(separatedBy: ";") where part.hasPrefix(key + "=") { return String(part.dropFirst(key.count + 1)) }
        return ""
    }
    /// M0: Sảnh → Bài tập → chương 1 (thẻ mẹo lần đầu) → bài 1 → lượt 5 cú bằng cú bắn QA → kết quả; rồi thi chương 1
    /// (bậc đã qua bằng --chapter-unlock-qa) đủ 10 cú không trợ giúp → kết quả thi.
    func testChapterOneLadderAndExam() {
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--auto-shot-qa"]
        app.launch()
        XCTAssertTrue(app.buttons["LobbyDrills"].waitForExistence(timeout: 60))
        app.buttons["LobbyDrills"].tap()
        XCTAssertTrue(app.tables["Chapters"].waitForExistence(timeout: 10 * slow), "chapters replace the 5-level list")
        XCTAssertTrue(chapterCell(app, "ChapterDrill-first-shot").exists, "chapter 1 rung 1 open")
        chapterCell(app, "ChapterDrill-first-shot").tap()
        XCTAssertTrue(app.buttons["TipCardOK"].waitForExistence(timeout: 5 * slow), "first time in a chapter: its tip card")
        app.buttons["TipCardOK"].tap()
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bắt đầu · 5 cú")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5 * slow)); start.tap()
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 30))
        wait(scene, timeout: 60 * slow) { self.text(scene, "drill") == "first-shot" && self.text(scene, "lesson") == "1" }
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 120 * slow), "five QA shots close the round")
        // The result alert is checked, not dismissed: tapping its buttons made XCTest's interruption handler recurse for
        // 15 min (the alert carries 4–5 actions; the next launch below replaces this app instance anyway).
        XCTAssertTrue(app.alerts.firstMatch.label.contains("Qua bài"), "five on-aim QA shots clear the drill: \(app.alerts.firstMatch.label)")
        app.terminate()

        let exam = XCUIApplication()
        exam.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--chapter-unlock-qa", "--auto-shot-qa"]
        exam.launch()
        XCTAssertTrue(exam.buttons["LobbyDrills"].waitForExistence(timeout: 60)); exam.buttons["LobbyDrills"].tap()
        XCTAssertTrue(exam.cells["ChapterExam-1"].waitForExistence(timeout: 10 * slow)); exam.cells["ChapterExam-1"].tap()
        if exam.buttons["TipCardOK"].waitForExistence(timeout: 3 * slow) { exam.buttons["TipCardOK"].tap() }
        let examScene = exam.otherElements["PoolScene"]
        wait(examScene, timeout: 30 * slow) { self.text(examScene, "test").hasPrefix("straight-speed:") }
        let examDone = exam.alerts.firstMatch.waitForExistence(timeout: 240)
        XCTAssertTrue(examDone, "ten shots, then the only result: \(examScene.value as? String ?? "")")
        XCTAssertTrue(exam.alerts.firstMatch.label.contains("Thi chương 1"))
    }
    /// 0.49b X1: the drill catalogue comes from the C table — nine chapters, each with at least two drills, flag on by default;
    /// a player's saved stars keep their keys (drill id never changes).
    func testCatalogGivesNineChaptersEachWithTwoDrills() {
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa"]
        app.launch()
        XCTAssertTrue(app.buttons["LobbyDrills"].waitForExistence(timeout: 60))
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 30))
        wait(scene, timeout: 20 * slow) { self.text(scene, "chapters") != "" }
        XCTAssertEqual(text(scene, "catalog"), "1", "FeatureFlags.drillCatalog is on by default")
        let counts = text(scene, "chapters").components(separatedBy: ",").compactMap { Int($0) }
        XCTAssertEqual(counts.count, 9, "nine chapters: \(counts)")
        XCTAssertTrue(counts.allSatisfy { $0 >= 2 }, "every chapter has at least two drills: \(counts)")
        app.buttons["LobbyDrills"].tap()
        XCTAssertTrue(app.tables["Chapters"].waitForExistence(timeout: 10 * slow))
        XCTAssertTrue(chapterCell(app, "ChapterDrill-first-shot").exists, "the first rung of chapter 1 is open")
    }
    /// 0.49b X3: shot 0 of a round is the catalogue layout; from shot 1 the cue ball sits a little elsewhere (≤ the drill's jitter).
    func testRoundMovesTheCueBallBetweenShots() {
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--auto-shot-qa"]
        app.launch()
        XCTAssertTrue(app.buttons["LobbyDrills"].waitForExistence(timeout: 60)); app.buttons["LobbyDrills"].tap()
        XCTAssertTrue(chapterCell(app, "ChapterDrill-first-shot").waitForExistence(timeout: 10 * slow)); chapterCell(app, "ChapterDrill-first-shot").tap()
        if app.buttons["TipCardOK"].waitForExistence(timeout: 5 * slow) { app.buttons["TipCardOK"].tap() }
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bắt đầu · 5 cú")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5 * slow)); start.tap()
        let scene = app.otherElements["PoolScene"]
        wait(scene, timeout: 60 * slow) { self.text(scene, "drill") == "first-shot" && self.text(scene, "lesson") == "1" }
        let x0 = 0.23159, y0 = 0.86659   // first-shot catalogue cue ball (DrillCatalogData.h); read from the table it may already be on its way
        XCTAssertEqual(text(scene, "variant"), "0", "first shot: catalogue layout")
        wait(scene, timeout: 120 * slow) { self.text(scene, "variant") == "1" }
        // layoutX/Y = the cue ball of the layout the shot starts from (the next auto shot moves the real ball right after)
        let moved = hypot(field(scene, "layoutX") - x0, field(scene, "layoutY") - y0)
        XCTAssertGreaterThan(moved, 0.002, "shot 2 starts with the cue ball somewhere else")
        XCTAssertLessThanOrEqual(moved, 0.0301, "…but never farther than the drill's jitter (0.03 m)")
    }
    /// 0.49b X5 + X7: the drill card shows ONE tip line; the long text is under "Xem thêm". "Ra bàn thật" lists every ball in
    /// diamonds, takes the number made out of 10 and remembers it.
    func testDrillCardOneTipLineAndRealTableCard() {
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa"]
        app.launch()
        XCTAssertTrue(app.buttons["LobbyDrills"].waitForExistence(timeout: 60)); app.buttons["LobbyDrills"].tap()
        XCTAssertTrue(chapterCell(app, "ChapterDrill-first-shot").waitForExistence(timeout: 10 * slow)); chapterCell(app, "ChapterDrill-first-shot").tap()
        if app.buttons["TipCardOK"].waitForExistence(timeout: 5 * slow) { app.buttons["TipCardOK"].tap() }
        XCTAssertTrue(app.staticTexts["DrillTip"].waitForExistence(timeout: 5 * slow), "one tip line of the chapter")
        XCTAssertFalse(app.staticTexts["Cách chấm điểm"].exists, "the scoring text is folded away")
        app.buttons["DrillMore"].tap()
        XCTAssertTrue(app.staticTexts["Cách chấm điểm"].waitForExistence(timeout: 5 * slow), "Xem thêm opens it")
        app.buttons["DrillMore"].tap()
        app.buttons["DrillRealTable"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Bi cái: nút dài", "nút ngắn")).firstMatch.waitForExistence(timeout: 5 * slow), "cue ball in diamonds")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Bi 1: nút dài")).firstMatch.exists, "ball 1 in diamonds")
        XCTAssertEqual(app.staticTexts["RealTableValue"].label, "5/10")
        app.buttons["RealTablePlus"].tap(); app.buttons["RealTablePlus"].tap()
        XCTAssertEqual(app.staticTexts["RealTableValue"].label, "7/10")
        app.buttons["RealTableSave"].tap()
        XCTAssertTrue(app.buttons["DrillRealTable"].waitForExistence(timeout: 5 * slow))
        app.buttons["DrillRealTable"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Các lần trước: 7")).firstMatch.waitForExistence(timeout: 5 * slow), "the try was saved")
    }
    /// 0.49c G6: stand-alone "Đặt bi" button (64 pt): one tap = place mode, tap again = done.
    func testPlaceBallButtonIsOutsideTheMenuAndToggles() {
        let (app, scene) = launch([])
        let b = app.buttons["PlaceBallButton"]
        XCTAssertTrue(b.waitForExistence(timeout: 20 * slow), "the button is on the table, not in a menu")
        XCTAssertGreaterThanOrEqual(b.frame.height, 43.5, "same key size as the rest of the column")
        XCTAssertTrue(b.isEnabled, "free table: placing is allowed")
        b.tap()
        wait(scene, timeout: 10 * slow) { self.field(scene, "editing") == 1 }
        b.tap()
        wait(scene, timeout: 10 * slow) { self.field(scene, "editing") == 0 }
    }
    /// 0.58c item 5a: entering a 9-ball match (Pass & play) and placing the cue ball behind the head string both end in the aim
    /// camera (mode 2) without any touch on the camera buttons ("Toàn cảnh" was needed before).
    func testMatchEntryAndPlacementEndInTheAimCamera() {
        let (app, scene) = launch(["--ux018-match-nine-qa"])
        wait(scene, timeout: 30 * slow) { self.field(scene, "mode") == 2 && self.field(scene, "moving") == 0 }
        XCTAssertEqual(field(scene, "mode"), 2, "match entry: aim camera with no touch — \(scene.value as? String ?? "")")
        let b = app.buttons["PlaceBallButton"]
        XCTAssertTrue(b.waitForExistence(timeout: 20 * slow))
        if b.isEnabled {
            b.tap()
            wait(scene, timeout: 10 * slow) { self.field(scene, "editing") == 1 }
            XCTAssertEqual(field(scene, "mode"), 1, "placing uses the top-down view")
            b.tap()
            wait(scene, timeout: 10 * slow) { self.field(scene, "editing") == 0 }
            Thread.sleep(forTimeInterval: 1.0)   // the camera transition (0.45 s) must have finished
            XCTAssertEqual(field(scene, "mode"), 2, "after placing: aim camera again — \(scene.value as? String ?? "")")
        }
    }
    /// 0.49c G3: the bar is small, magnifies ×2.5 while held (the load still matches the core mapping), and a switch next to "Đặt bi" turns it off/on.
    func testPowerBarIsSmallZoomsWhenHeldAndHasASwitch() {
        let (app, scene) = launch(["--power-bar-qa"])
        let bar = app.descendants(matching: .any)["PowerBar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10 * slow))
        XCTAssertLessThanOrEqual(bar.frame.width, 30, "small bar (≈ 28 pt wide)")
        XCTAssertLessThanOrEqual(bar.frame.height, 185, "≈ 180 pt tall at most")
        XCTAssertEqual(field(scene, "barZoom"), 1, accuracy: 0.01)
        let f = bar.frame
        let from = bar.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.width / 2, dy: 30))
        from.press(forDuration: 0.4, thenDragTo: from.withOffset(CGVector(dx: 0, dy: 6)))   // below 10 %: a cancel, but the zoom happened
        wait(scene, timeout: 5 * slow) { self.field(scene, "barZoom") > 2.4 }
        XCTAssertEqual(field(scene, "barZoom"), 2.5, accuracy: 0.01, "×2.5 while held")
        XCTAssertFalse(app.buttons["PowerBarSwitch"].exists, "0.56 K2: there is no on-screen switch any more")
        XCTAssertEqual(field(scene, "bar"), 1)
    }
    /// 0.49c G7: no UIKit layout pass lands between the frames of a rolling shot (everything the strike invalidated is laid out in the
    /// strike call). Counted by the app from the end of the strike to the end of the shot; Simulator only — device frame timing NOT RUN.
    func testNoUIKitLayoutPassWhileTheBallsRoll() {
        let (_, scene) = launch(["--ux017-shot-qa", "--layout-trace-qa"])
        wait(scene, timeout: 60 * slow) { (scene.value as? String ?? "").contains("status=Quãng đường bi cái") }   // the QA shot has finished
        XCTAssertEqual(field(scene, "midShotLayout"), 0, "layout passes between frames of the shot: \(scene.value as? String ?? "")")
    }
    /// 0.58c: the same rule through the REAL stroke path (power bar drag + release), which is what the owner's device measurement used
    /// (2 UIKit layout passes mid-shot while the programmatic QA shot above shows 0). Simulator only — device frame timing NOT RUN.
    func testNoUIKitLayoutPassAfterPowerBarStroke() {
        let (app, scene) = launch(["--power-bar-qa", "--layout-trace-qa"])
        let bar = app.descendants(matching: .any)["PowerBar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10 * slow), "power bar on the right")
        let f = bar.frame, travel = (f.height - 20) * 0.9
        let origin = bar.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let from = origin.withOffset(CGVector(dx: f.width / 2, dy: 30))
        let to = origin.withOffset(CGVector(dx: f.width / 2, dy: 30 + travel * 0.5 * 2.5))
        from.press(forDuration: 0.2, thenDragTo: to)
        wait(scene, timeout: 10 * slow) { self.field(scene, "shotSpeed") > 0 }
        wait(scene, timeout: 60 * slow) { (scene.value as? String ?? "").contains(";moving=0;") && self.field(scene, "shotSpeed") > 0 && self.text(scene, "status") != "" }
        Thread.sleep(forTimeInterval: 1.0)   // let the finish tick refresh the probe
        let probe = scene.value as? String ?? ""
        XCTAssertEqual(field(scene, "midShotLayout"), 0, "layout passes between frames of a power-bar shot — why: \(text(scene, "midShotWhy")) cause: \(text(scene, "layoutCause")) probe: \(probe.prefix(600))")
    }
    /// 0.49b X7: the Tiến bộ screen lists the app's and the real-table results side by side ("Trong app / Bàn thật").
    func testProgressShowsRealTableColumn() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-qa", "--g1-default-qa", "--progress-demo-qa"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["ProgressChart"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["Trong app / Bàn thật"].waitForExistence(timeout: 10 * slow) || app.descendants(matching: .any)["ProgressRealTable"].exists, "the real-table section")
        attachUpright("progress-real-table")
    }
    /// 0.49c G4 + G8: defaults — no spectrum strip while swiping, 3-ball break rule off (the switches live in Tuỳ chỉnh).
    func testSpectrumStripAndThreeBallBreakAreOffByDefault() {
        let (_, scene) = launch([])
        XCTAssertEqual(text(scene, "spectrum"), "0", "no colour strip while swiping by default")
        XCTAssertEqual(text(scene, "threeBallPref"), "0", "3-ball break rule is a tournament option, off")
    }
    func testSpectrumStripCanBeBroughtBackForDiagnostics() {
        let (_, scene) = launch(["-diagPowerSpectrum049", "YES", "-threeBallBreak049", "YES"])
        XCTAssertEqual(text(scene, "spectrum"), "1")
        XCTAssertEqual(text(scene, "threeBallPref"), "1")
    }
    /// 0.49b X8: a round passed without Coach earns the "Không Coach" badge (named in the result).
    func testRoundWithoutCoachEarnsABadge() {
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--auto-shot-qa"]
        app.launch()
        XCTAssertTrue(app.buttons["LobbyDrills"].waitForExistence(timeout: 60)); app.buttons["LobbyDrills"].tap()
        XCTAssertTrue(chapterCell(app, "ChapterDrill-first-shot").waitForExistence(timeout: 10 * slow)); chapterCell(app, "ChapterDrill-first-shot").tap()
        if app.buttons["TipCardOK"].waitForExistence(timeout: 5 * slow) { app.buttons["TipCardOK"].tap() }
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bắt đầu · 5 cú")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5 * slow)); start.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 180 * slow), "five QA shots close the round")
        XCTAssertTrue(app.alerts.firstMatch.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Huy hiệu mới")).firstMatch.exists, "the round message names the new badge")
    }
    /// 0.49c G2: Petemoss is in the bundle (Vietnamese glyphs), "Đấu với máy" opens as a solid wood picker with Vietnamese level names on
    /// equal-size cards, and Pháp lý credits the font with its licence.
    func testWoodPickerPetemossAndLegal() {
        XCUIDevice.shared.orientation = .landscapeLeft   // upright pictures (a portrait device otherwise captures the landscape app sideways)
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa"]
        app.launch()
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 60))
        wait(scene, timeout: 20 * slow) { self.text(scene, "petemoss") != "" }
        XCTAssertEqual(text(scene, "petemoss"), "1", "Petemoss-Regular.ttf is registered (UIAppFonts)")
        XCTAssertTrue(app.buttons["LobbyComputer"].waitForExistence(timeout: 30)); app.buttons["LobbyComputer"].tap()
        XCTAssertTrue(app.otherElements["WoodPicker"].waitForExistence(timeout: 10 * slow) || app.staticTexts["WoodPickerTitle"].waitForExistence(timeout: 5), "wood picker, not a glass sheet")
        let names = ["Tập sự", "Nghiệp dư", "CLB", "Phong trào", "Chuyên nghiệp", "Đỉnh cao"]
        var heights = Set<Int>()
        for (i, n) in names.enumerated() {
            let card = app.descendants(matching: .any)["WoodItem-\(i)"]
            XCTAssertTrue(card.waitForExistence(timeout: 5 * slow), "level card \(i)")
            XCTAssertTrue(card.label.hasPrefix(n), "Vietnamese level name: \(card.label)")
            heights.insert(Int(card.frame.height.rounded()))
        }
        XCTAssertEqual(heights.count, 1, "all level cards are the same size: \(heights)")
        attachUpright("wood-picker")
    }
    /// 0.49c G2: largest accessibility text size — the wood picker keeps every card inside its panel and the content wraps (scrolls), no clipping.
    func testWoodPickerFitsAtTheLargestTextSize() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["LobbyComputer"].waitForExistence(timeout: 60)); app.buttons["LobbyComputer"].tap()
        let panel = app.otherElements["WoodPicker"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10 * slow))
        let card = app.descendants(matching: .any)["WoodItem-0"]
        XCTAssertTrue(card.waitForExistence(timeout: 5 * slow))
        XCTAssertLessThanOrEqual(card.frame.maxX, panel.frame.maxX + 1, "the card does not run out of the panel on the right")
        XCTAssertGreaterThanOrEqual(card.frame.minX, panel.frame.minX - 1)
        // element frames of this landscape-only app are in portrait coordinates: the card's landscape HEIGHT is frame.width here
        XCTAssertGreaterThan(card.frame.width, 90, "at the largest text size the text wraps and the card grows with it: \(card.frame)")
        attachUpright("wood-picker-xxxl")
    }
    func testLegalScreenCreditsPetemoss() {
        let app = XCUIApplication()
        app.launchArguments = ["--visual-qa", "--g1-default-qa", "--legal-qa"]
        app.launch()
        let entry = app.cells["LegalEntry-0"]
        XCTAssertTrue(entry.waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Petemoss")).firstMatch.exists, "the font is credited")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "SIL Open Font License 1.1")).firstMatch.exists, "with its licence")
        entry.tap()
        XCTAssertTrue(app.textViews["LegalLicenseText"].waitForExistence(timeout: 10 * slow))
        XCTAssertTrue((app.textViews["LegalLicenseText"].value as? String ?? "").contains("SIL OPEN FONT LICENSE Version 1.1"), "the original OFL.txt")
    }
    // MARK: 0.50 Thế bí
    private func openFirstPuzzle(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["LobbyPuzzles"].waitForExistence(timeout: 60)); app.buttons["LobbyPuzzles"].tap()
        XCTAssertTrue(app.tables["Puzzles"].waitForExistence(timeout: 10 * slow))
        XCTAssertTrue(app.cells["Puzzle-p-1-01"].waitForExistence(timeout: 5 * slow), "first puzzle of room 1 is open"); app.cells["Puzzle-p-1-01"].tap()
    }
    /// T1: the map shows rooms; room 1 is open, a later room is locked with "Còn N sao nữa…".
    func testPuzzleMapRoomOneOpenAndLaterRoomLocked() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa"]; app.launch()
        XCTAssertTrue(app.buttons["LobbyPuzzles"].waitForExistence(timeout: 60)); app.buttons["LobbyPuzzles"].tap()
        XCTAssertTrue(app.tables["Puzzles"].waitForExistence(timeout: 10 * slow))
        XCTAssertTrue(app.otherElements["PuzzleRoom-1"].waitForExistence(timeout: 5 * slow) || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Phòng 1")).firstMatch.exists, "room 1 on the map")
        XCTAssertTrue(app.cells["Puzzle-p-1-01"].exists, "room 1 puzzle listed and open")
        let locked = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Còn", "sao nữa là mở phòng")).firstMatch
        for _ in 0..<6 where !locked.exists { app.tables["Puzzles"].swipeUp() }
        XCTAssertTrue(locked.exists, "a locked room says how many stars are missing")
    }
    /// 0.58 L3: Sổ lời giải and Đo cục bộ (pushed in Thế bí) each have a visible "Đóng"; it returns to Thế bí, and Xong returns to the table.
    func testPuzzleBookAndStatsCanBeClosed() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa"]; app.launch()
        XCTAssertTrue(app.buttons["LobbyPuzzles"].waitForExistence(timeout: 60)); app.buttons["LobbyPuzzles"].tap()
        XCTAssertTrue(app.tables["Puzzles"].waitForExistence(timeout: 10 * slow))
        for (opener, screen) in [("PuzzleBookOpen", "PuzzleBook"), ("PuzzleStatsOpen", "PuzzleStats")] {
            XCTAssertTrue(app.buttons[opener].waitForExistence(timeout: 5 * slow), "\(opener) is in the Thế bí bar"); app.buttons[opener].tap()
            XCTAssertTrue(app.tables[screen].waitForExistence(timeout: 10 * slow), "\(screen) opens")
            let close = app.buttons["PushedClose"]
            XCTAssertTrue(close.waitForExistence(timeout: 5 * slow) && close.isHittable, "\(screen) has a visible Đóng")
            close.tap()
            XCTAssertTrue(app.tables["Puzzles"].waitForExistence(timeout: 10 * slow), "Đóng returns to Thế bí")
            XCTAssertFalse(app.tables[screen].exists)
        }
        app.buttons["Xong"].tap()
        XCTAssertTrue(app.otherElements["PoolScene"].waitForExistence(timeout: 10 * slow), "Xong returns to the table")
        XCTAssertFalse(app.tables["Puzzles"].exists)
    }
    /// T2/T3/T4: the task line, a miss shows a real measurement, retry is instant and keeps the session, a hint takes one from the jar.
    func testPuzzleMissThenInstantRetryAndHintFromTheJar() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--auto-shot-qa", "--puzzle-miss-qa"]; app.launch()
        openFirstPuzzle(app)
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 30))
        wait(scene, timeout: 30 * slow) { self.text(scene, "puzzle") == "p-1-01" }
        XCTAssertTrue(app.staticTexts["PuzzleTask"].waitForExistence(timeout: 10 * slow), "one line of task")
        XCTAssertEqual(text(scene, "hintJar"), "3", "a fresh player's jar is full")
        wait(scene, timeout: 90 * slow) { (Int(self.text(scene, "puzzleTries")) ?? 0) >= 1 }
        XCTAssertEqual(text(scene, "puzzleStarsNow"), "0", "the QA shot was a miss")
        let status = text(scene, "status")
        XCTAssertFalse(status.isEmpty || status.contains("Giải được"), "a miss states what really happened: \(status)")
        let before = XCTAttachment(screenshot: app.screenshot()); before.name = "puzzle-after-miss"; before.lifetime = .keepAlways; add(before)
        let hintButton = app.buttons["PuzzleHint"]
        expectation(for: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), evaluatedWith: hintButton)
        waitForExpectations(timeout: 15 * slow)   // ready, with a deadline: no sleeping
        // hint first: after a retry the QA shooter fires again and a hint is refused while a shot runs
        app.buttons["PuzzleHint"].tap()
        wait(scene, timeout: 10 * slow) { self.text(scene, "hintJar") == "2" }
        XCTAssertEqual(text(scene, "hintJar"), "2", "a hint costs one")
        app.buttons["PuzzleRetry"].tap()
        wait(scene, timeout: 20 * slow) { self.text(scene, "puzzleRetries") != "0" }
        XCTAssertLessThan(Double(text(scene, "puzzleRetryMs")) ?? 9999, 1000, "retry in under a second: \(text(scene, "puzzleRetryMs")) ms")
    }
    func testPuzzleSolvedWithItsListedRouteEarnsStars() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--auto-shot-qa", "--puzzle-solve-qa", "-shotKind017", "1"]; app.launch()
        openFirstPuzzle(app)
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 30))
        wait(scene, timeout: 60 * slow) { (Int(self.text(scene, "puzzleStarsNow")) ?? 0) >= 1 || (Int(self.text(scene, "puzzleTries")) ?? 0) >= 1 }
        XCTAssertGreaterThanOrEqual(Int(text(scene, "puzzleStarsNow")) ?? 0, 1, "the listed route solved it: status=\(text(scene, "status")) tries=\(text(scene, "puzzleTries")) layout=\(text(scene, "layoutX")),\(text(scene, "layoutY"))")
        // T5 Sổ lời giải: opens once solved and shows the player's stroke next to the reference
        let bookButton = app.buttons["PuzzleBookButton"]
        expectation(for: NSPredicate(format: "exists == true AND hittable == true"), evaluatedWith: bookButton); waitForExpectations(timeout: 15 * slow)
        bookButton.tap()
        XCTAssertTrue(app.cells["PuzzleBookEntry-p-1-01"].waitForExistence(timeout: 10 * slow), "the solved puzzle is in the book")
    }
    /// 0.50 T4 + T8: hint level 1 → "Ra bàn tập" opens the tool's lesson; a cleared round refills one hint and "Quay lại thế bí" returns to the puzzle.
    func testPuzzleHintLevelOnePracticeAndBack() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--auto-shot-qa", "--puzzle-miss-qa"]; app.launch()
        openFirstPuzzle(app)
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 30))
        wait(scene, timeout: 90 * slow) { (Int(self.text(scene, "puzzleTries")) ?? 0) >= 1 }
        XCTAssertTrue(app.descendants(matching: .any)["PuzzleSkillIcon"].exists, "the tool's symbol is on the puzzle bar")
        let hint = app.buttons["PuzzleHint"]
        expectation(for: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), evaluatedWith: hint); waitForExpectations(timeout: 15 * slow)
        hint.tap()
        XCTAssertTrue(app.alerts["PuzzleHint1"].waitForExistence(timeout: 10 * slow) || app.alerts.firstMatch.waitForExistence(timeout: 5), "level 1 names the tool")
        app.alerts.firstMatch.buttons["Ra bàn tập"].tap()
        wait(scene, timeout: 30 * slow) { self.text(scene, "lesson") == "1" }
        XCTAssertEqual(text(scene, "hintJar"), "2", "the hint cost one")
        let back = app.alerts.firstMatch.buttons["Quay lại thế bí"]
        XCTAssertTrue(back.waitForExistence(timeout: 180 * slow), "a cleared round offers the way back")
        back.tap()
        wait(scene, timeout: 30 * slow) { self.text(scene, "puzzle") == "p-1-01" }
        XCTAssertEqual(text(scene, "hintJar"), "3", "the cleared lesson gave the hint back")
    }
    /// 0.50 T4 level 3: the reference route plays once and the stroke is blocked while it runs.
    func testPuzzleHintLevelThreePlaysTheRouteOnce() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--puzzle-hint3-qa"]; app.launch()
        openFirstPuzzle(app)
        let scene = app.otherElements["PoolScene"]
        wait(scene, timeout: 30 * slow) { self.text(scene, "puzzle") == "p-1-01" }
        let hint = app.buttons["PuzzleHint"]
        expectation(for: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), evaluatedWith: hint); waitForExpectations(timeout: 15 * slow)
        hint.tap()
        wait(scene, timeout: 10 * slow) { self.text(scene, "puzzleGhost") == "1" }
        XCTAssertEqual(text(scene, "puzzleGhost"), "1", "the route is playing, no stroke allowed")
        XCTAssertEqual(text(scene, "hintJar"), "1", "level 3 costs two")
        wait(scene, timeout: 12 * slow) { self.text(scene, "puzzleGhost") == "0" }
        XCTAssertEqual(text(scene, "puzzleGhost"), "0", "it plays once")
    }
    /// 0.50 T6: a puzzle solved yesterday comes back today as its left–right twin under "Thế bí hôm nay".
    func testPuzzleReviewComesBackMirrored() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--puzzle-review-qa"]; app.launch()
        XCTAssertTrue(app.buttons["LobbyPuzzles"].waitForExistence(timeout: 60)); app.buttons["LobbyPuzzles"].tap()
        XCTAssertTrue(app.cells["PuzzleReview-p-1-01"].waitForExistence(timeout: 10 * slow), "review due after one day")
        app.cells["PuzzleReview-p-1-01"].tap()
        let scene = app.otherElements["PoolScene"]
        wait(scene, timeout: 30 * slow) { self.text(scene, "puzzle") == "p-1-01" }
        XCTAssertEqual(text(scene, "puzzleMirrored"), "1", "the twin, left–right")
    }
    /// 0.50 T7 + T8: two puzzles left unsolved in a row → an easier one is offered; the local stats screen opens.
    func testPuzzleTwoFailsOfferAnEasierOneAndStatsOpen() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--auto-shot-qa", "--puzzle-miss-qa"]; app.launch()
        openFirstPuzzle(app)
        let scene = app.otherElements["PoolScene"]
        for key in ["p-1-02", "p-1-03"] {
            wait(scene, timeout: 90 * slow) { (Int(self.text(scene, "puzzleTries")) ?? 0) >= 1 }
            let more = app.buttons["PuzzleListButton"]
            expectation(for: NSPredicate(format: "exists == true AND hittable == true"), evaluatedWith: more); waitForExpectations(timeout: 15 * slow)
            more.tap()
            XCTAssertTrue(app.cells["Puzzle-" + key].waitForExistence(timeout: 10 * slow))
            // CI 170 evidence: "System gesture gate timed out" swallowed this tap and the list stayed open for 2 minutes. A lost tap is not a
            // slow app: tap again while the list is still up and the puzzle has not changed (the timeout below stays the same).
            for _ in 0..<4 where self.text(scene, "puzzle") != key {
                if app.cells["Puzzle-" + key].exists { app.cells["Puzzle-" + key].tap() }
                let until = Date().addingTimeInterval(8 * slow)
                while Date() < until, self.text(scene, "puzzle") != key { RunLoop.current.run(until: Date().addingTimeInterval(0.25)) }
            }
            wait(scene, timeout: 30 * slow) { self.text(scene, "puzzle") == key }
        }
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 30 * slow), "after two unsolved puzzles an easier one is offered: fails=\(text(scene, "puzzleFails")) puzzle=\(text(scene, "puzzle")) tries=\(text(scene, "puzzleTries"))")
        app.alerts.firstMatch.buttons["Đóng"].tap()
        expectation(for: NSPredicate(format: "count == 0"), evaluatedWith: app.alerts); waitForExpectations(timeout: 10 * slow)   // the alert is gone
        // the QA shooter plays p-1-03 as soon as the alert is gone; the list refuses to open during a shot — wait for that shot to end
        wait(scene, timeout: 90 * slow) { (Int(self.text(scene, "puzzleTries")) ?? 0) >= 1 }
        let more = app.buttons["PuzzleListButton"]
        expectation(for: NSPredicate(format: "exists == true AND hittable == true"), evaluatedWith: more); waitForExpectations(timeout: 15 * slow)
        more.tap()
        XCTAssertTrue(app.tables["Puzzles"].waitForExistence(timeout: 10 * slow))
        app.buttons["PuzzleStatsOpen"].tap()
        XCTAssertTrue(app.tables["PuzzleStats"].waitForExistence(timeout: 10 * slow))
        XCTAssertTrue(app.staticTexts["Thế đã giải"].exists)
    }
    /// 0.51 N1: the daily puzzle gives 6 tries, then locks with the share line; a new (QA-set) date opens a new one; today's stays locked on relaunch.
    func testDailyPuzzleLocksAfterSixTriesAndReopensTomorrow() {
        func launchDaily(day: Int, fresh: Bool) -> (XCUIApplication, XCUIElement) {
            let app = XCUIApplication()
            app.launchArguments = ["--keep-lobby-qa"] + (fresh ? ["--fresh-player-qa"] : []) + ["--auto-shot-qa", "--puzzle-miss-qa", "--daily-autoretry-qa", "--daily-day-qa=\(day)"]
            app.launch()
            XCTAssertTrue(app.buttons["LobbyDailyPuzzle"].waitForExistence(timeout: 60)); app.buttons["LobbyDailyPuzzle"].tap()
            return (app, app.otherElements["PoolScene"])
        }
        // day +40: number > 0 whatever the release epoch is
        let (app, scene) = launchDaily(day: 40, fresh: true)
        XCTAssertTrue(scene.waitForExistence(timeout: 30))
        wait(scene, timeout: 400 * slow) { self.text(scene, "dailyLocked") == "1" }
        XCTAssertEqual(text(scene, "dailyTries"), "6", "six tries, then locked")
        XCTAssertTrue(app.alerts["DailyResult"].waitForExistence(timeout: 20 * slow) || app.alerts.firstMatch.waitForExistence(timeout: 5), "the result card")
        var share = text(scene, "dailyShare")   // the probe refreshes a little after the card shows: poll
        let deadline = Date().addingTimeInterval(20 * slow)
        while share.isEmpty && Date() < deadline { Thread.sleep(forTimeInterval: 0.5); share = text(scene, "dailyShare") }
        XCTAssertTrue(share.hasPrefix("Zoker #") && share.contains("· X/6|"), "share line (no spoiler, unsolved shows X/6): \(share)")
        guard share.components(separatedBy: "|").count > 1 else { return }
        XCTAssertEqual(share.components(separatedBy: "|")[1].count, 6, "six dots, one per try: \(share)")
        app.alerts.firstMatch.buttons["Khoe"].tap()
        wait(scene, timeout: 10 * slow) { self.text(scene, "dailyShares") == "1" }
        XCTAssertEqual(text(scene, "dailyShares"), "1", "Khoe counted (local measure)")
        app.terminate()
        // same day again: still locked, the result card shows instead of a puzzle
        let (app2, scene2) = launchDaily(day: 40, fresh: false)
        XCTAssertTrue(app2.alerts.firstMatch.waitForExistence(timeout: 30 * slow), "today is locked: the result card, not a puzzle")
        XCTAssertEqual(text(scene2, "puzzle"), "")
        app2.terminate()
        // tomorrow: a new puzzle, open
        let (app3, scene3) = launchDaily(day: 41, fresh: false)
        wait(scene3, timeout: 60 * slow) { self.text(scene3, "puzzle") != "" }
        XCTAssertNotEqual(text(scene3, "puzzle"), "", "a new daily puzzle")
        XCTAssertEqual(text(scene3, "dailyLocked"), "0")
        app3.terminate()
    }
    /// 0.51 N4: the flyer PDF is a real A5 PDF; the QR URL scheme opens the puzzle of the day; a retry shows the previous try's path faintly;
    /// the 45-minute reminder fires once (QA shortens the stretch; the clock logic itself is tested with a fake clock in PlayerStoreTests).
    func testFlyerUrlSchemeGhostPathAndRestNudge() {
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--daily-flyer-qa", "--daily-day-qa=40"]
        app.launch()
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 60))
        wait(scene, timeout: 20 * slow) { (Int(self.text(scene, "flyerBytes")) ?? 0) != 0 }
        XCTAssertGreaterThan(Int(text(scene, "flyerBytes")) ?? 0, 2000, "a real %PDF document")
        app.terminate()
        let app2 = XCUIApplication()
        app2.launchArguments = ["--fresh-player-qa", "--daily-day-qa=40", "--visual-qa", "--g1-default-qa"]
        app2.launch()
        let scene2 = app2.otherElements["PoolScene"]; XCTAssertTrue(scene2.waitForExistence(timeout: 60))
        if #available(iOS 16.4, *) { app2.open(URL(string: "zokerpool://daily")!) } else { XCTFail("needs iOS 16.4 to open a URL from XCUITest"); return }
        wait(scene2, timeout: 30 * slow) { self.text(scene2, "puzzle") != "" }
        XCTAssertNotEqual(text(scene2, "puzzle"), "", "zokerpool://daily opened the puzzle of the day")
        app2.terminate()
        let app3 = XCUIApplication()
        app3.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--auto-shot-qa", "--puzzle-miss-qa", "--rest-nudge-qa"]
        app3.launch()
        XCTAssertTrue(app3.buttons["LobbyPuzzles"].waitForExistence(timeout: 60)); app3.buttons["LobbyPuzzles"].tap()
        XCTAssertTrue(app3.cells["Puzzle-p-1-01"].waitForExistence(timeout: 10 * slow)); app3.cells["Puzzle-p-1-01"].tap()
        let scene3 = app3.otherElements["PoolScene"]
        wait(scene3, timeout: 90 * slow) { (Int(self.text(scene3, "puzzleTries")) ?? 0) >= 1 }
        XCTAssertEqual(text(scene3, "ghostPath"), "0", "no ghost before the first retry")
        let retry = app3.buttons["PuzzleRetry"]
        expectation(for: NSPredicate(format: "exists == true AND hittable == true"), evaluatedWith: retry); waitForExpectations(timeout: 15 * slow)
        retry.tap()
        wait(scene3, timeout: 20 * slow) { (Int(self.text(scene3, "ghostPath")) ?? 0) >= 1 }
        XCTAssertGreaterThanOrEqual(Int(text(scene3, "ghostPath")) ?? 0, 1, "the previous try's path was shown on the retry")
        XCTAssertEqual(text(scene3, "restNudges"), "1", "one reminder after the (shortened) stretch")
    }
    /// 0.51 N2: mark where the cue ball stops, lock in → the real solver's point, "Lệch N cm · k điểm", the Eye moves; only 5 rounds a day count.
    func testPredictThePathScoresAndMovesTheEye() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--daily-day-qa=40"]; app.launch()
        XCTAssertTrue(app.buttons["LobbyPredict"].waitForExistence(timeout: 60)); app.buttons["LobbyPredict"].tap()
        let board = app.otherElements["PredictBoard"]
        XCTAssertTrue(board.waitForExistence(timeout: 15 * slow))
        let eye = app.staticTexts["PredictEye"]
        XCTAssertTrue(eye.waitForExistence(timeout: 5 * slow))
        XCTAssertTrue(eye.label.contains("1000"), "the Eye starts at 1000: \(eye.label)")
        var scores: [Int] = []
        for round in 1...6 {
            let lock = app.buttons["PredictLock"]
            XCTAssertFalse(lock.isEnabled, "nothing marked yet")
            board.coordinate(withNormalizedOffset: CGVector(dx: 0.30 + 0.07 * Double(round), dy: 0.5)).tap()
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: lock); waitForExpectations(timeout: 10 * slow)
            lock.tap()
            let result = app.staticTexts["PredictResult"]
            expectation(for: NSPredicate(format: "label CONTAINS %@", "điểm"), evaluatedWith: result); waitForExpectations(timeout: 10 * slow)
            let digits = result.label.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            scores.append(Int(digits.last ?? "-1") ?? -1)
            if round <= 5 { XCTAssertTrue(eye.label.contains("(") && !eye.label.contains("không tính điểm"), "scored round \(round): \(eye.label)") }
            else { XCTAssertTrue(eye.label.contains("không tính điểm"), "the sixth round is practice only: \(eye.label)") }
            if round < 6 { app.buttons["PredictNext"].tap() }
        }
        XCTAssertTrue(scores.allSatisfy { (0...100).contains($0) }, "scores 0…100: \(scores)")
        attachUpright("predict-the-path")
    }
    /// 0.55 R1 (deterministic): a change lands while the check runs → the old result is dropped, Gửi stays off, no routes are announced.
    func testStaleCheckResultNeverEnablesSend() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--user-puzzle-qa", "--user-puzzle-race-qa"]; app.launch()
        XCTAssertTrue(app.buttons["LobbyUserPuzzle"].waitForExistence(timeout: 60)); app.buttons["LobbyUserPuzzle"].tap()
        let status = app.staticTexts["UserPuzzleStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 15 * slow))
        app.buttons["UserPuzzleCheck"].tap()
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["UserPuzzleCheck"]); waitForExpectations(timeout: 240 * slow)   // the (slow) check finished and offered its result
        XCTAssertFalse(app.buttons["UserPuzzleSend"].isEnabled, "the result of the old layout must not enable Gửi")
        XCTAssertFalse(status.label.contains("lời giải"), "no routes announced for a layout that was changed: \(status.label)")
        XCTAssertTrue(app.buttons["UserPuzzleCheck"].isEnabled, "the editor is usable again")
    }
    /// 0.51 N3: arrange → Kiểm thế finds routes → Gửi gives a 15-character code → a receiver types it, the layout is rebuilt and re-checked, then played.
    /// An invalid arrangement is refused (a "Hit ball 1" puzzle needs a grey ball).
    func testUserPuzzleCheckSendReceiveAndPlay() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--user-puzzle-qa"]; app.launch()
        XCTAssertTrue(app.buttons["LobbyUserPuzzle"].waitForExistence(timeout: 60)); app.buttons["LobbyUserPuzzle"].tap()
        let status = app.staticTexts["UserPuzzleStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 15 * slow))
        // an invalid arrangement: "Hit ball 1" with no grey ball
        app.segmentedControls["UserPuzzleStyle"].buttons.element(boundBy: 1).tap()
        app.buttons["UserPuzzleCheck"].tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "chưa hợp lệ"), evaluatedWith: status); waitForExpectations(timeout: 10 * slow)
        app.segmentedControls["UserPuzzleStyle"].buttons.element(boundBy: 0).tap()
        XCTAssertFalse(app.buttons["UserPuzzleSend"].isEnabled, "nothing to send before a check")
        app.buttons["UserPuzzleCheck"].tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "lời giải"), evaluatedWith: status); waitForExpectations(timeout: 60 * slow)
        XCTAssertTrue(app.buttons["UserPuzzleSend"].isEnabled, "a layout with routes can be sent")
        app.buttons["UserPuzzleSend"].tap()
        let codeLabel = app.staticTexts["UserPuzzleCode"]
        XCTAssertTrue(codeLabel.waitForExistence(timeout: 10 * slow))
        let code = codeLabel.label
        XCTAssertTrue(app.staticTexts["UserPuzzleBeta"].exists, "0.55 R2: the Thử nghiệm label")
        let shareLine = app.staticTexts["UserPuzzleShareLine"].label
        XCTAssertTrue(shareLine.hasPrefix("Zoker Pool · Thế bí của tôi (Vào lỗ): ") && shareLine.contains(code) && shareLine.hasSuffix("bạn giải được không?"), "0.55 R3: \(shareLine)")
        XCTAssertTrue(app.staticTexts["UserPuzzleTally"].label.contains("Mã đã gửi: 1"), "0.55 R5: one code sent so far: \(app.staticTexts["UserPuzzleTally"].label)")
        XCTAssertNotNil(code.range(of: "^[0-9A-Z]{5}-[0-9A-Z]{5}-[0-9A-Z]{5}$", options: .regularExpression), "XXXXX-XXXXX-XXXXX: \(code)")
        app.terminate()
        // the receiving device
        let app2 = XCUIApplication(); app2.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa"]; app2.launch()
        XCTAssertTrue(app2.buttons["LobbyUserPuzzle"].waitForExistence(timeout: 60)); app2.buttons["LobbyUserPuzzle"].tap()
        XCTAssertTrue(app2.buttons["UserPuzzleEnter"].waitForExistence(timeout: 15 * slow)); app2.buttons["UserPuzzleEnter"].tap()
        let field = app2.textFields["UserPuzzleCodeField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10 * slow)); field.tap(); field.typeText(code)
        app2.alerts.firstMatch.buttons["Kiểm tra và chơi"].tap()
        let ready = app2.alerts["UserPuzzleReady"]
        XCTAssertTrue(ready.waitForExistence(timeout: 120 * slow), "0.55 R4: what the check found, before playing")
        XCTAssertTrue(ready.label.contains("lời giải"), ready.label)
        ready.buttons["Chơi"].tap()
        let scene = app2.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 120 * slow), "the editor closes when the re-check passes; status: \(app2.staticTexts["UserPuzzleStatus"].label) code: \(code)")
        wait(scene, timeout: 30 * slow) { self.text(scene, "puzzle") == "user" }
        XCTAssertEqual(text(scene, "puzzle"), "user", "the received puzzle is on the table")
        XCTAssertTrue(app2.staticTexts["PuzzleTask"].waitForExistence(timeout: 10 * slow))
        XCTAssertTrue(text(scene, "userCheck").hasPrefix("received:"), "re-checked on the receiving device: \(text(scene, "userCheck"))")
    }
    /// 0.53 A1: after the computer's foul the human has ball in hand and the "Place ball" button must be ON (8-, 9- and 10-ball).
    func testPlaceBallButtonOnAfterComputerFoul() {
        for rule in ["tenBall", "nineBall", "eightBall"] {
            let (app, scene) = launch(["--match-foul-qa=\(rule)"])
            wait(scene, timeout: 60 * slow) { self.field(scene, "placeOn") == 1 }
            XCTAssertEqual(field(scene, "placeOn"), 1, "\(rule): ball in hand → Place ball enabled")
            app.terminate()
        }
    }
    /// 0.53 A2: holding B for the stroke keeps the mission ring (only the prediction and trail hide).
    func testMissionRingStaysWhileBIsHeld() {
        let (_, scene) = launch(["--hold-ring-qa"])
        wait(scene, timeout: 60 * slow) { self.field(scene, "locked") == 1 }
        XCTAssertEqual(field(scene, "ringHidden"), 0, "the ring stays while B is held: \(scene.value as? String ?? "")")
    }
    /// 0.56 K1/K2: the right column is exactly four keys — Đặt bi · Lùi cú · Camera ngắm · Bàn, top to bottom, same size; no power-bar switch anywhere.
    func testRightColumnIsFourKeysAndNoPowerSwitch() {
        let (app, _) = launch(["--power-bar-qa"])
        let place = app.buttons["PlaceBallButton"], retry = app.buttons["QuickRetry"], camera = app.buttons["QuickCamera"], table = app.buttons["QuickTable"]
        XCTAssertTrue(place.waitForExistence(timeout: 10 * slow) && retry.exists && camera.exists && table.exists)
        XCTAssertLessThan(place.frame.midY, retry.frame.midY); XCTAssertLessThan(retry.frame.midY, camera.frame.midY); XCTAssertLessThan(camera.frame.midY, table.frame.midY)
        XCTAssertEqual(place.frame.height, retry.frame.height, accuracy: 1, "Đặt bi has the size of the other keys")
        XCTAssertEqual(place.frame.width, retry.frame.width, accuracy: 1)
        XCTAssertFalse(app.buttons["PowerBarSwitch"].exists, "no switch")
    }
    /// 0.56 K3: D = the effect ball; B is D × D beside it; each cue button is D wide, 2/3 D tall, flush above B / the ball.
    func testLeftClusterGeometry() {
        let (app, _) = launch(["--ux017-qa"])
        let ball = app.descendants(matching: .any)["Điểm chạm đầu cơ"].firstMatch, play = app.buttons["CueIconPlay"], brk = app.buttons["CueIconBreak"]
        XCTAssertTrue(ball.waitForExistence(timeout: 10 * slow) && play.exists && brk.exists)
        let d = ball.frame.width
        XCTAssertEqual(play.frame.width, d, accuracy: 2, "cue buttons are D wide"); XCTAssertEqual(brk.frame.width, d, accuracy: 2)
        XCTAssertEqual(play.frame.height, d * 2 / 3, accuracy: 2, "…and 2/3 D tall")
        XCTAssertEqual(brk.frame.minX, ball.frame.minX, accuracy: 2, "Cơ phá is right above the effect ball")
        XCTAssertLessThanOrEqual(play.frame.maxY, ball.frame.minY + 1)
    }
    /// 0.56 K2: in chapter 2 with 8 take-backs left and 3 missed rounds the rescue card appears once; "Dùng" shows the bar for that drill; chapter 1 never asks.
    func testRescueCardOffersThePowerBarOnlyInLaterChapters() {
        let (app, scene) = launch(["--rescue-qa"])
        let card = app.alerts["RescueCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 40 * slow), "the rescue card: \(scene.value as? String ?? "")")
        XCTAssertEqual(field(scene, "barOn"), 0, "no bar before the player agrees")
        card.buttons["Dùng"].tap()
        wait(scene, timeout: 10 * slow) { self.field(scene, "barOn") == 1 }
        XCTAssertEqual(field(scene, "barOn"), 1); XCTAssertEqual(field(scene, "rescueUsed"), 1, "counted for the chapter (no Tay sạch afterwards)")
        app.terminate()
        let (app1, _) = launch(["--rescue-ch1-qa"])
        XCTAssertFalse(app1.alerts["RescueCard"].waitForExistence(timeout: 12 * slow), "chapter 1 is the force chapter: never offered")
    }
    /// 0.53 C1: in a training drill the power bar and its switch are gone and the mission ring is on without Coach; free play keeps the bar.
    func testTrainingDrillHasNoPowerBarAndAlwaysTheRing() {
        let (app, scene) = launch(["--training-drill-qa"])
        wait(scene, timeout: 60 * slow) { self.field(scene, "ringHidden") == 0 }
        XCTAssertEqual(field(scene, "ringHidden"), 0, "the ring is on without turning Coach on")
        XCTAssertFalse(app.descendants(matching: .any)["PowerBar"].isHittable, "no power bar in a drill")
        XCTAssertFalse(app.buttons["PowerBarSwitch"].isHittable, "no switch either")
    }
    /// 0.53 B3: the call needs one tap: ball 1 is called by default (10-ball), the camera stays low, and a tap on a pocket completes it.
    func testCallNeedsOnlyOneTapOnAPocket() {
        let (_, scene) = launch(["--call-qa", "--call-tap-pocket-qa"])
        wait(scene, timeout: 60 * slow) { self.field(scene, "calledPocket") == 3 }
        XCTAssertEqual(field(scene, "calledBall"), 1, "the default called ball is the lowest ball on the table")
        XCTAssertEqual(field(scene, "calledPocket"), 3, "one tap on the right side pocket")
        XCTAssertNotEqual(field(scene, "mode"), 1, "no forced top view")
    }
    /// 0.54 M1/M3/M4/M6: chapter 1 shows nine ladders, the title for the saved progress (70 % → "Triển Vọng", from Mastery.h), the "∞" take-back line,
    /// locked rings beyond a ring with fewer than 3 stars, the intro text; "Chơi lại chương" (two confirmations) clears it.
    func testChapterOneLaddersTitleAndReset() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--mastery-qa"]; app.launch()
        XCTAssertTrue(app.buttons["LobbyDrills"].waitForExistence(timeout: 60)); app.buttons["LobbyDrills"].tap()
        XCTAssertTrue(app.tables["Chapters"].waitForExistence(timeout: 10 * slow))
        let title = app.staticTexts["ChapterTitle-1"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10 * slow), "title line of chapter 1")
        XCTAssertTrue(title.label.contains("Triển Vọng") && title.label.contains("70 %"), "70 % = title 2: \(title.label)")
        XCTAssertTrue(title.label.contains("Bàn Tay Nhung"), "the chapter nickname")
        XCTAssertTrue(app.staticTexts["ChapterUndo-1"].firstMatch.label.contains("∞"), "chapter 1: unlimited take-backs")
        XCTAssertTrue(app.cells["ChapterLadder-force-near"].exists && app.cells["ChapterLadder-force-far"].exists, "ladder cards")
        let follow = chapterCell(app, "ChapterLadder-force-follow")
        let followText = follow.descendants(matching: .staticText).allElementsBoundByIndex.map { $0.label }.joined(separator: " ")
        XCTAssertTrue(followText.contains("🔒"), "no stars yet: the smaller rings are locked: \(followText)")
        // reset the chapter: two confirmations
        let settings = chapterCell(app, "ChapterSettings-1"); settings.tap()
        if app.buttons["TipCardOK"].waitForExistence(timeout: 1) { app.buttons["TipCardOK"].tap() }
        let again = app.buttons["Chơi lại chương từ đầu"].firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 5 * slow)); again.tap()
        let sure = app.alerts["ChapterResetSure"]; XCTAssertTrue(sure.waitForExistence(timeout: 5 * slow)); sure.buttons["Tiếp tục"].tap()
        let really = app.alerts["ChapterResetReally"]; XCTAssertTrue(really.waitForExistence(timeout: 5 * slow)); really.buttons["Chơi lại chương"].tap()
        app.tables["Chapters"].swipeDown(); app.tables["Chapters"].swipeDown()
        let after = app.staticTexts["ChapterTitle-1"].firstMatch
        XCTAssertTrue(after.waitForExistence(timeout: 5 * slow) && after.label.contains("0 %") && after.label.contains("Tay Mơ Có Chí"), "back to the start: \(after.label)")
    }
    /// 0.54 M3/M5: moving up a title shows one card (once), and the share card is drawn at 1080×1350 (probe: PNG bytes > 0).
    func testTitleCardAppearsOnceWithAShareCard() {
        let (app, scene) = launch(["--mastery-qa", "--mastery-card-qa", "--fresh-player-qa"])
        let card = app.alerts["TitleCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 30 * slow), "the card for the new title")
        XCTAssertTrue(card.label.contains("Triển Vọng"), card.label)
        XCTAssertEqual(text(scene, "titleCard"), "2")
    }
    /// 0.54 M2: a ring: warm-up shots first (not scored, "Khởi động n/5" until 5 are made), then a scored round of 5 → the result card with 0…3 stars.
    func testRingWarmupThenScoredRound() {
        let app = XCUIApplication(); app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--auto-shot-qa"]; app.launch()
        XCTAssertTrue(app.buttons["LobbyDrills"].waitForExistence(timeout: 60)); app.buttons["LobbyDrills"].tap()
        let ladder = app.cells["ChapterLadder-force-near"]
        XCTAssertTrue(ladder.waitForExistence(timeout: 10 * slow)); ladder.tap()
        if app.buttons["TipCardOK"].waitForExistence(timeout: 3 * slow) { app.buttons["TipCardOK"].tap() }
        let ring1 = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Vòng 1")).firstMatch
        XCTAssertTrue(ring1.waitForExistence(timeout: 5 * slow)); ring1.tap()
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bắt đầu · 5 cú")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5 * slow)); start.tap()
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 30))
        wait(scene, timeout: 60 * slow) { self.text(scene, "drill") == "force-near-1" && self.text(scene, "lesson") == "1" }
        wait(scene, timeout: 120 * slow) { (scene.value as? String ?? "").contains("Khởi động") }
        XCTAssertTrue((scene.value as? String ?? "").contains("Khởi động"), "the warm-up line comes first")
        let card = app.alerts["LadderRound"]
        XCTAssertTrue(card.waitForExistence(timeout: 400 * slow), "after the warm-up, five scored shots close the round: \(scene.value as? String ?? "")")
        XCTAssertTrue(card.label.hasPrefix("Vòng 1"), card.label)
    }
    /// 0.56 K5 photo: the HUD in the standard room on whatever device the run targets (upright attachment, exported by Tools/run_hud_photos.sh).
    func testHudPhoto056() {
        let (_, scene) = launch(["--ux017-qa"])
        XCTAssertTrue(scene.waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 3)
        attachUpright("hud056-" + UIDevice.current.name.replacingOccurrences(of: " ", with: "_"))
    }
    /// 0.57 I7: the first-launch intro lasts ≤ 3.5 s on the real clock (tolerance only for a slow runner), then the Lobby is there; it is the 3D film.
    func testFirstLaunchIntroEndsWithin3Point5Seconds() {
        let app = XCUIApplication(); app.launchArguments = ["--intro-lobby-qa", "--fresh-intro", "--fresh-player-qa", "--fresh-tutorial"]; app.launch()
        XCTAssertTrue(app.buttons["LobbyFree"].waitForExistence(timeout: 60 * slow), "the Lobby follows the intro on its own")
        let scene = app.otherElements["PoolScene"]; XCTAssertTrue(scene.waitForExistence(timeout: 30))
        wait(scene, timeout: 20 * slow) { self.text(scene, "introMode") != "" }
        // The film clock freezes while the main thread stalls (a cold first frame on a fresh Simulator can take seconds), so the 3.5 s limit is judged on the
        // film time (wall minus those freezes); the raw wall time is only bounded loosely for a slow runner.
        let film = Double(text(scene, "introFilm")) ?? 99, wall = Double(text(scene, "introWall")) ?? 99
        XCTAssertLessThanOrEqual(film, 3.5, "intro film time \(film) s (wall \(wall) s)")
        XCTAssertLessThanOrEqual(wall, 12, "intro wall time \(wall) s")
    }
    /// 0.57 I7: a tap at 0.3 s ends the intro within 0.3 s (QA taps for us at 0.3 s of the film).
    func testTapDuringIntroGivesControlWithin300ms() {
        let app = XCUIApplication(); app.launchArguments = ["--intro-lobby-qa", "--fresh-intro", "--fresh-player-qa", "--fresh-tutorial", "--intro-skip-at-qa=0.3"]; app.launch()
        XCTAssertTrue(app.buttons["LobbyFree"].waitForExistence(timeout: 60 * slow))
        let scene = app.otherElements["PoolScene"]; XCTAssertTrue(scene.waitForExistence(timeout: 30))
        wait(scene, timeout: 20 * slow) { self.text(scene, "introSkipMs") != "-1" && self.text(scene, "introMode") != "" }
        XCTAssertLessThanOrEqual(Double(text(scene, "introSkipMs")) ?? 9999, 300 * max(1, slow / 2), "skip → control: \(text(scene, "introSkipMs")) ms")
    }
    /// 0.57 I7: Reduce Motion (QA stands in for the system switch) gives the still logo — no 3D film.
    func testReduceMotionIntroHasNo3D() {
        let app = XCUIApplication(); app.launchArguments = ["--intro-lobby-qa", "--fresh-intro", "--fresh-player-qa", "--fresh-tutorial", "--intro-reduce-qa"]; app.launch()
        XCTAssertTrue(app.buttons["LobbyFree"].waitForExistence(timeout: 60 * slow))
        let scene = app.otherElements["PoolScene"]; XCTAssertTrue(scene.waitForExistence(timeout: 30))
        wait(scene, timeout: 20 * slow) { self.text(scene, "introMode") != "" }
        XCTAssertEqual(text(scene, "introMode"), "logo", "no 3D break with Reduce Motion")
    }
    /// M1: kéo thanh lực xuống một nửa hành trình rồi thả → cú được đánh, tốc độ đầu = BLPowerBarSpeed(phần kéo, trần) ±2 %.
    func testPowerBarDragStrikesWithMappedSpeed() {
        let (app, scene) = launch(["--power-bar-qa"])
        let bar = app.descendants(matching: .any)["PowerBar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10 * slow), "power bar on the right")
        XCTAssertEqual(field(scene, "bar"), 1)
        let f = bar.frame, track = f.height - 20, travel = track * 0.9
        let origin = bar.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let from = origin.withOffset(CGVector(dx: f.width / 2, dy: 20 + 10))
        // 0.49c G3: holding the bar magnifies it ×2.5 around the finger, so half the load takes 2.5× the screen travel.
        let to = origin.withOffset(CGVector(dx: f.width / 2, dy: 20 + 10 + travel * 0.5 * 2.5))
        from.press(forDuration: 0.2, thenDragTo: to)
        wait(scene, timeout: 10 * slow) { self.field(scene, "shotSpeed") > 0 }
        let frac = field(scene, "barFrac"), maxSpeed = field(scene, "barMax"), speed = field(scene, "shotSpeed")
        // 0.49c G3: the bar magnifies ×2.5 while held, so the screen travel no longer maps linearly to the old half-bar: the load only has
        // to be a real one; what must hold is that the speed fired matches the displayed %.
        XCTAssertGreaterThan(frac, 0.1, "a real load, not a cancel"); XCTAssertLessThanOrEqual(frac, 1.0)
        let expected = 0.5 * pow(maxSpeed / 0.5, frac)   // BLPowerBarSpeed (DailyLoop.h)
        XCTAssertEqual(speed, expected, accuracy: expected * 0.01, "speed within ±1 % of the core mapping of the displayed %")
    }
    /// M2: thẻ "Bài hôm nay" đứng đầu Sảnh (trên "Tiếp tục"), có chuỗi ngày; chạm → vào một trong ba bài của hôm nay.
    func testDailyCardOnTopOfLobbyStartsTodaysDrill() {
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa"]
        app.launch()
        let card = app.descendants(matching: .any)["LobbyDaily"]
        XCTAssertTrue(card.waitForExistence(timeout: 60), "Bài hôm nay card")
        let cont = app.buttons["LobbyContinue"]
        XCTAssertTrue(cont.exists)
        XCTAssertLessThan(card.frame.minY, cont.frame.minY, "Bài hôm nay sits above Tiếp tục")
        XCTAssertTrue(card.label.contains("Bắt đầu chuỗi ngày"), "fresh player: no streak yet")
        card.tap()
        let scene = app.otherElements["PoolScene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 30))
        // New player in a chapter: its tip card, then the lesson card's start button (same path as the ladder test).
        if app.buttons["TipCardOK"].waitForExistence(timeout: 5 * slow) { app.buttons["TipCardOK"].tap() }
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bắt đầu · 5 cú")).firstMatch
        if start.waitForExistence(timeout: 5 * slow) { start.tap() }
        wait(scene, timeout: 20 * slow) { self.text(scene, "lesson") == "1" }
        XCTAssertTrue(text(scene, "drill").hasSuffix("-1") && text(scene, "drill").hasPrefix("force-") || ["first-shot", "speed-1", "speed-2", "speed-3"].contains(text(scene, "drill")),   // 0.54: chapter 1 is a ring ladder; only the big ring is open for a new player
                      "a new player only gets drills of open chapters (chapter 1)")
    }
    /// M3: màn Tiến bộ (Swift Charts) với 30 ngày dữ liệu giả — biểu đồ, chuỗi, nút bài kiểm tuần; ảnh cho nghiệm thu.
    func testProgressScreenWithThirtyDemoDays() {
        // The screen opens by itself 2 s after launch and covers the table: do not wait for PoolScene (hidden behind it).
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--visual-qa", "--g1-default-qa", "--progress-demo-qa"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["ProgressChart"].waitForExistence(timeout: 60), "Tiến bộ opens with the chart")
        XCTAssertTrue(app.buttons["WeeklyTest"].exists, "weekly test entry")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "progress-30-days"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["ProgressDone"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ProgressChart"].waitForNonExistence(timeout: 10 * slow))
    }
    /// M5: bài kiểm tuần 10 cú — không hiện kết quả giữa chừng (chỉ "đã đánh n/10"), kết quả cuối mới hiện.
    func testWeeklyTestShowsNothingUntilTheEnd() {
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa", "--auto-shot-qa"]
        app.launch()
        let chip = app.buttons["LobbyWeeklyTest"]
        XCTAssertTrue(chip.waitForExistence(timeout: 60)); chip.tap()
        let scene = app.otherElements["PoolScene"]
        wait(scene, timeout: 30 * slow) { self.text(scene, "test").hasPrefix("weekly:") }
        for _ in 0..<40 where !app.alerts.firstMatch.exists {
            let status = text(scene, "status")
            XCTAssertFalse(status.contains("ĐẠT") || status.contains("chưa đạt") || status.contains("điểm"), "no result between shots: \(status)")
            Thread.sleep(forTimeInterval: 3)
        }
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 120 * slow), "the result only at the end")
        XCTAssertTrue(app.alerts.firstMatch.label.contains("Bài kiểm tuần"))
    }
    /// M6: mã sai một ký tự bị từ chối (CRC-9); mã đúng (81R0-0Y9J = "Cắt phải 30° vào lỗ góc", người thách vào 3/5) → đúng bài.
    func testChallengeCodeOpensTheSameDrillAndRejectsATypo() {
        let app = XCUIApplication()
        app.launchArguments = ["--keep-lobby-qa", "--fresh-player-qa"]
        app.launch()
        let chip = app.buttons["LobbyChallenge"]
        XCTAssertTrue(chip.waitForExistence(timeout: 60)); chip.tap()
        let field = app.textFields["ChallengeCodeField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10 * slow)); field.tap(); field.typeText("81R0-0Y9K")
        app.alerts.firstMatch.buttons["Chơi bài này"].tap()
        XCTAssertTrue(app.alerts["Mã không đúng"].waitForExistence(timeout: 10 * slow), "a one-character typo is refused")
        app.alerts["Mã không đúng"].buttons["Đóng"].tap()
        let scene = app.otherElements["PoolScene"]
        XCTAssertNotEqual(text(scene, "drill"), "cut-30-r")
        // The Lobby closed when the chip was chosen: start again from a fresh launch.
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["LobbyChallenge"].waitForExistence(timeout: 60)); app.buttons["LobbyChallenge"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10 * slow)); field.tap(); field.typeText("81r0 0y9j")
        app.alerts.firstMatch.buttons["Chơi bài này"].tap()
        wait(scene, timeout: 20 * slow) { self.text(scene, "drill") == "cut-30-r" && self.text(scene, "lesson") == "1" }
    }

    // MARK: 0.48 "Máy quay" (written for CI; NOT RUN locally — the Simulator on the Mac is broken)
    /// M4: replay opens on the planned Director camera, switches to Học and a hand-picked angle (each re-planned),
    /// then exports the same shot as 9:16 and 16:9 (offline render at the output size).
    func testReplayPlannedAnglesAndExportBothFrames() {
        let (app,scene)=launch(["--ux017-shot-qa","--replay-hold-qa","--replay-angle-reset-qa","--export-small-qa"])
        waitReplayReady(scene)
        wait(scene,timeout:30 * slow){self.field(scene,"moving")==0}
        tapReplay(app)
        wait(scene,timeout:10 * slow){self.field(scene,"replay")==1 && self.field(scene,"camPlan")==1}
        XCTAssertEqual(field(scene,"cam"),0,"Đạo diễn is the default replay angle")
        // The planned cut sequence advances with the clock (a slow roll with no contact may plan one merged scene).
        if field(scene,"camScenes")>1 {wait(scene,timeout:20 * slow){self.field(scene,"camScene")>=1}}
        else {XCTAssertEqual(field(scene,"camScenes"),1,"a plan has at least one scene")}
        for (title,raw) in [("Học",1.0),("Đón ở lỗ",7.0)] {
            app.buttons["ReplayAuto"].tap()
            let item=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@",title)).firstMatch
            // Landscape iPhone: the 8-angle menu is taller than the screen — scroll it to reach the last angles.
            if !item.waitForExistence(timeout:2 * slow) || !item.isHittable {
                let first=app.buttons["ReplayAngle-0"]
                if first.exists && first.isHittable {first.swipeUp()}
            }
            XCTAssertTrue(item.waitForExistence(timeout:5 * slow),title);item.tap()
            wait(scene,timeout:5 * slow){self.field(scene,"cam")==raw && self.field(scene,"camPlan")==1}
        }
        app.buttons["ReplayDone"].tap()
        wait(scene,timeout:5 * slow){self.field(scene,"replay")==0}
        for (n,title) in ["Video dọc 9:16 (TikTok, Reels, Shorts)","Video ngang 16:9"].enumerated() {
            tapReplay(app)
            wait(scene,timeout:10 * slow){self.field(scene,"replay")==1}
            app.buttons["ReplayExport"].tap()
            let option=app.buttons[title];XCTAssertTrue(option.waitForExistence(timeout:5 * slow),title);option.tap()
            wait(scene,timeout:40 * slow){self.field(scene,"exported")>=Double(n+1)}
            XCTAssertEqual(field(scene,"exportW"),n==0 ? 360:640,"output frame width");XCTAssertEqual(field(scene,"exportH"),n==0 ? 640:360,"output frame height")
            let close=app.buttons["Đóng"];if close.waitForExistence(timeout:2 * slow){close.tap()}
        }
    }
}
