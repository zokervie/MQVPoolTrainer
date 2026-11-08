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

    /// Polls a probe field and reports the whole probe on failure (diagnosable from the CI log).
    private func settle(_ scene: XCUIElement, _ key: String, _ value: Double, timeout: TimeInterval = 20,
                        file: StaticString = #filePath, line: UInt = #line) {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if field(scene, key) == value { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("\(key) != \(value) · probe: \(scene.value ?? "")", file: file, line: line)
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
        XCTFail("timed out after \(Int(timeout)) s · probe: \(scene.value ?? "")", file: file, line: line)
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
        start.press(forDuration: 0.05, thenDragTo: end)
        let changed = NSPredicate { _, _ in
            let p = self.field(scene, "pitch")
            return p.isFinite && abs(p - pitchBefore) > 0.01
        }
        expectation(for: changed, evaluatedWith: scene)
        waitForExpectations(timeout: 10 * slow)
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
        let order=["QuickReplay","QuickRetry","QuickPlace","QuickAdd","QuickCue","QuickCamera"]
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
        let zoom=field(scene,"zoom"),pitch=field(scene,"pitch")
        quick(app,"QuickCamera").tap();quick(app,"QuickCamera").tap()
        let returned=NSPredicate { _,_ in self.field(scene,"mode")==2 }
        expectation(for:returned,evaluatedWith:scene);waitForExpectations(timeout:5 * slow)
        XCTAssertEqual(field(scene,"zoom"),zoom,accuracy:0.002)
        XCTAssertEqual(field(scene,"pitch"),pitch,accuracy:0.002)
    }

    func testPlaceCueBallAtCentreAndCancelRestoresLayout() {
        let (app,scene)=launch(["--ux017-qa"])
        let x=field(scene,"cueX"),y=field(scene,"cueY")
        quick(app,"QuickPlace").tap()
        let editing=NSPredicate { _,_ in self.field(scene,"editing")==1 }
        expectation(for:editing,evaluatedWith:scene);waitForExpectations(timeout:5 * slow)
        // 0.22: free spot nearest the centre (exactly the centre when it is empty)
        XCTAssertLessThan(hypot(field(scene,"cueX"),field(scene,"cueY")),0.15)
        quick(app,"QuickAdd").tap()   // "Hủy" while placing
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

    /// 0.30b: Bao cơ opens the cue library directly (looks are linked to the cue icons).
    func testCueBagOpensCueLibrary() {
        let (app,_)=launch(["--ux017-qa"])
        quick(app,"QuickCue").tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout:5 * slow),"cue library opens")
    }

    func testReplayManualCameraDoesNotChangeNextAimHeight() {
        // Shots now settle fast (0.29), so a short replay can finish before a slow simulator answers;
        // --replay-hold-qa keeps the last frame until Done.
        let (app,scene)=launch(["--ux017-shot-qa","--replay-hold-qa"])
        let replay=app.buttons["QuickReplay"]
        expectation(for:NSPredicate(format:"enabled == true"),evaluatedWith:replay);waitForExpectations(timeout:30 * slow)
        let pitch=field(scene,"pitch")
        quick(app,"QuickReplay").tap();app.buttons["ReplayPause"].tap()
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
        let (app,scene)=launch(["--ux017-qa"])
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

    /// 0.33: four cue icons around the effect ball; Jump 45°, Massé 70° (play cue raised), Break, back to Đánh.
    func testCueIconsSelectPlayJumpMasseBreak() {
        let (app,scene)=launch(["--ux017-qa"])
        for (id,kind) in [("CueIconJump",1.0),("CueIconMasse",3.0),("CueIconBreak",2.0),("CueIconPlay",0.0)] {
            let icon=app.buttons[id];XCTAssertTrue(icon.waitForExistence(timeout:5 * slow),id);icon.tap()
            settle(scene,"kind",kind)
        }
        let effect=app.descendants(matching:.any)["Điểm chạm đầu cơ"].firstMatch
        // 0.33: around the effect ball — Jump above, Đánh below, Massé left, Break right
        let e=effect.frame
        XCTAssertLessThanOrEqual(app.buttons["CueIconJump"].frame.maxY,e.minY+1,"Jump above")
        XCTAssertGreaterThanOrEqual(app.buttons["CueIconPlay"].frame.minY,e.maxY-1,"Đánh below")
        XCTAssertLessThanOrEqual(app.buttons["CueIconMasse"].frame.maxX,e.minX+1,"Massé left")
        XCTAssertGreaterThanOrEqual(app.buttons["CueIconBreak"].frame.minX,e.maxX-1,"Break right")
        // 0.35: Nút số / Chỉ dẫn / Bảng only with Coach
        XCTAssertFalse(app.buttons["NumbersToggle"].isHittable,"numbers only with Coach")
        XCTAssertFalse(app.buttons["GuideToggle"].isHittable,"guide button only with Coach")
    }

    func testLiveShotKeepsAimViewAndManualZoomAfterBallsStop() {
        let (_,scene)=launch(["--ux018-live-qa"])
        wait(scene){self.field(scene,"moving")==1}
        XCTAssertEqual(field(scene,"mode"),2)
        let zoomBefore=field(scene,"zoom")
        scene.pinch(withScale:0.82,velocity:-1)
        wait(scene,timeout:5 * slow){abs(self.field(scene,"zoom")-zoomBefore)>0.02}
        // An observation pan while balls run must orbit the same view rather
        // than selecting a different camera mode.
        let start=scene.coordinate(withNormalizedOffset:CGVector(dx:0.32,dy:0.34))
        let end=scene.coordinate(withNormalizedOffset:CGVector(dx:0.45,dy:0.34))
        start.press(forDuration:0.05,thenDragTo:end)
        XCTAssertEqual(field(scene,"mode"),2)
        let observedAngle=field(scene,"cameraAngle"),observedZoom=field(scene,"zoom")
        XCTAssertTrue(observedAngle.isFinite)
        wait(scene){self.field(scene,"moving")==0}
        // The shot-settle gate must not restore a saved viewpoint afterward.
        let settled=Date().addingTimeInterval(1.2)
        wait(scene,timeout:5 * slow){Date()>=settled}
        XCTAssertEqual(field(scene,"mode"),2)
        XCTAssertEqual(field(scene,"cameraAngle"),observedAngle,accuracy:0.005)
        XCTAssertEqual(field(scene,"zoom"),observedZoom,accuracy:0.005)
    }

    func testJumpShotResetsEffectAndReturnsToPlayingCue() {
        let (_,scene)=launch(["--ux018-jump-qa"])
        wait(scene,timeout:10 * slow){self.field(scene,"kind")==1 && self.field(scene,"moving")==1}
        wait(scene){self.field(scene,"moving")==0 && self.field(scene,"kind")==0}
        XCTAssertEqual(field(scene,"side"),0,accuracy:0.0001)
        XCTAssertEqual(field(scene,"top"),0,accuracy:0.0001)
    }

    func testRandomLayoutMenuSupportsOneThroughFifteenObjectBalls() {
        let (app,scene)=launch(["--ux017-qa"])
        for count in [1,14] {
            quick(app,"QuickAdd").tap()
            app.buttons["Thêm bi · số lượng / bố trí"].firstMatch.tap()
            let alert=app.alerts["Thêm bi"]
            XCTAssertTrue(alert.waitForExistence(timeout:5 * slow))
            // Intel CI: keystrokes sent before the field has focus are lost — retype until the field shows the count.
            let field=alert.textFields.firstMatch
            for _ in 0..<3 {
                field.tap();if let old=field.value as? String,!old.isEmpty,old != field.placeholderValue{field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:old.count))}
                field.typeText(String(count))
                if (field.value as? String) == String(count) {break}
            }
            XCTAssertEqual(field.value as? String,String(count),"typed count")
            alert.buttons["Mặc định"].tap()
            // a dropped tap leaves the alert up: tap again (the app ignores nothing once the alert is gone)
            for _ in 0..<2 where alert.waitForExistence(timeout:2) && alert.buttons["Mặc định"].isHittable { alert.buttons["Mặc định"].tap() }
            XCTAssertFalse(alert.exists,"alert closed")
            wait(scene,timeout:5 * slow){self.field(scene,"ballCount")==Double(count==1 ? 2:15)}
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
        XCTAssertFalse(app.buttons["QuickReplay"].isEnabled)
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
        wait(scene){self.field(scene,"moving")==1}
        wait(scene){self.field(scene,"moving")==0}
        // Wait for settlement: archive actions are intentionally unavailable
        // while any pocket presentation or shot-ready guard remains active.
        let replay=app.buttons["QuickReplay"]
        expectation(for:NSPredicate(format:"enabled == true"),evaluatedWith:replay)
        waitForExpectations(timeout:30 * slow)
        // Intel CI: a long press occasionally lands before the menu is ready — press again (max 3).
        let save=app.buttons["Lưu cú này"].firstMatch
        for _ in 0..<3 where !save.exists { quick(app,"QuickReplay").press(forDuration:1.2); _=save.waitForExistence(timeout:4 * slow) }
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
            quick(app,"QuickReplay").press(forDuration:1)
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
        let button=quick(app,"QuickReplay")
        expectation(for:NSPredicate(format:"enabled == true"),evaluatedWith:button)
        waitForExpectations(timeout:15 * slow);button.tap()
        wait(scene,timeout:5 * slow){self.field(scene,"replay")==1 && self.field(scene,"replayTime")<0}
        app.buttons["ReplayPause"].tap()
        app.buttons["ReplayDone"].tap()
        wait(scene,timeout:5 * slow){self.field(scene,"replay")==0}
    }

}
