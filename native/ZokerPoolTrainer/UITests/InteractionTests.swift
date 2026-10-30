import XCTest

final class InteractionTests: XCTestCase {
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
        waitForExpectations(timeout: 10)
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

    private func wait(_ scene: XCUIElement, timeout: TimeInterval = 30,
                      _ condition: @escaping () -> Bool) {
        expectation(for: NSPredicate { _, _ in condition() }, evaluatedWith: scene)
        waitForExpectations(timeout: timeout)
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
        waitForExpectations(timeout: 10)
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
        XCTAssertEqual(coach.frame.midX,rail.frame.midX,accuracy:1)
        XCTAssertLessThan(coach.frame.maxY,rail.frame.minY)
        XCTAssertGreaterThan(coach.frame.midX,scene.frame.midX)
        coach.tap()
        let enabled=NSPredicate { _,_ in self.field(scene,"coach")==1 }
        expectation(for:enabled,evaluatedWith:scene);waitForExpectations(timeout:5)
        coach.tap()
        let disabled=NSPredicate { _,_ in self.field(scene,"coach")==0 }
        expectation(for:disabled,evaluatedWith:scene);waitForExpectations(timeout:5)
        XCTAssertFalse(app.otherElements["CoachCard"].isHittable)
    }

    func testCameraRoundTripPreservesAimHeightAndZoom() {
        let (app,scene)=launch(["--ux017-qa"])
        scene.pinch(withScale:0.8,velocity:-1)
        let zoom=field(scene,"zoom"),pitch=field(scene,"pitch")
        quick(app,"QuickCamera").tap();quick(app,"QuickCamera").tap()
        let returned=NSPredicate { _,_ in self.field(scene,"mode")==2 }
        expectation(for:returned,evaluatedWith:scene);waitForExpectations(timeout:5)
        XCTAssertEqual(field(scene,"zoom"),zoom,accuracy:0.002)
        XCTAssertEqual(field(scene,"pitch"),pitch,accuracy:0.002)
    }

    func testPlaceCueBallAtCentreAndCancelRestoresLayout() {
        let (app,scene)=launch(["--ux017-qa"])
        let x=field(scene,"cueX"),y=field(scene,"cueY")
        quick(app,"QuickPlace").tap()
        let editing=NSPredicate { _,_ in self.field(scene,"editing")==1 }
        expectation(for:editing,evaluatedWith:scene);waitForExpectations(timeout:5)
        XCTAssertEqual(field(scene,"cueX"),0,accuracy:0.001);XCTAssertEqual(field(scene,"cueY"),0,accuracy:0.001)
        quick(app,"QuickAdd").tap()
        let cancelled=NSPredicate { _,_ in self.field(scene,"editing")==0 }
        expectation(for:cancelled,evaluatedWith:scene);waitForExpectations(timeout:5)
        XCTAssertEqual(field(scene,"cueX"),x,accuracy:0.001);XCTAssertEqual(field(scene,"cueY"),y,accuracy:0.001)
        // Cancelling editing must restore input mode as well as the visible camera transform.
        let pitch=field(scene,"pitch"),down=pitch<0.8
        let start=scene.coordinate(withNormalizedOffset:CGVector(dx:0.40,dy:down ? 0.30:0.50))
        let end=scene.coordinate(withNormalizedOffset:CGVector(dx:0.40,dy:down ? 0.50:0.30))
        start.press(forDuration:0.05,thenDragTo:end)
        let heightChanged=NSPredicate { _,_ in abs(self.field(scene,"pitch")-pitch)>0.01 }
        expectation(for:heightChanged,evaluatedWith:scene);waitForExpectations(timeout:5)

    }

    func testFourCueChoicesKeepMasséAndBreakDistinct() {
        let (app,scene)=launch(["--ux017-qa"])
        for (name,kind) in [("Massé",3.0),("Jump",1.0),("Break",2.0),("Đánh",0.0)] {
            quick(app,"QuickCue").tap()
            let option=app.buttons[name].firstMatch;XCTAssertTrue(option.waitForExistence(timeout:5));option.tap()
            let selected=NSPredicate { _,_ in self.field(scene,"kind")==kind }
            expectation(for:selected,evaluatedWith:scene);waitForExpectations(timeout:5)
        }
    }

    func testReplayManualCameraDoesNotChangeNextAimHeight() {
        let (app,scene)=launch(["--ux017-shot-qa"])
        let replay=app.buttons["QuickReplay"]
        expectation(for:NSPredicate(format:"enabled == true"),evaluatedWith:replay);waitForExpectations(timeout:30)
        let pitch=field(scene,"pitch")
        quick(app,"QuickReplay").tap();app.buttons["ReplayPause"].tap()
        let start=scene.coordinate(withNormalizedOffset:CGVector(dx:0.35,dy:0.30))
        let end=scene.coordinate(withNormalizedOffset:CGVector(dx:0.35,dy:0.50))
        start.press(forDuration:0.05,thenDragTo:end)
        app.buttons["Xong"].firstMatch.tap()
        let stopped=NSPredicate { _,_ in self.field(scene,"replay")==0 }
        expectation(for:stopped,evaluatedWith:scene);waitForExpectations(timeout:5)
        XCTAssertEqual(field(scene,"pitch"),pitch,accuracy:0.002)
    }

    func testHoldingAndReleasingBridgeDoesNotFireOrLeaveAimLocked() {
        let (app,scene)=launch(["--ux017-qa"])
        let bridge=app.descendants(matching:.any)["Giữ để khóa hướng"].firstMatch
        XCTAssertTrue(bridge.isHittable)
        bridge.press(forDuration:0.5)
        XCTAssertEqual(field(scene,"moving"),0)
        let before=angle(scene)
        let start=scene.coordinate(withNormalizedOffset:CGVector(dx:0.30,dy:0.32))
        let end=scene.coordinate(withNormalizedOffset:CGVector(dx:0.45,dy:0.32))
        start.press(forDuration:0.05,thenDragTo:end)
        wait(scene,timeout:5){abs(self.angle(scene)-before)>0.01}
        XCTAssertEqual(field(scene,"moving"),0)
    }

    func testLiveShotKeepsAimViewAndManualZoomAfterBallsStop() {
        let (_,scene)=launch(["--ux018-live-qa"])
        wait(scene){self.field(scene,"moving")==1}
        XCTAssertEqual(field(scene,"mode"),2)
        let zoomBefore=field(scene,"zoom")
        scene.pinch(withScale:0.82,velocity:-1)
        wait(scene,timeout:5){abs(self.field(scene,"zoom")-zoomBefore)>0.02}
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
        wait(scene,timeout:5){Date()>=settled}
        XCTAssertEqual(field(scene,"mode"),2)
        XCTAssertEqual(field(scene,"cameraAngle"),observedAngle,accuracy:0.005)
        XCTAssertEqual(field(scene,"zoom"),observedZoom,accuracy:0.005)
    }

    func testJumpShotResetsEffectAndReturnsToPlayingCue() {
        let (_,scene)=launch(["--ux018-jump-qa"])
        wait(scene,timeout:10){self.field(scene,"kind")==1 && self.field(scene,"moving")==1}
        wait(scene){self.field(scene,"moving")==0 && self.field(scene,"kind")==0}
        XCTAssertEqual(field(scene,"side"),0,accuracy:0.0001)
        XCTAssertEqual(field(scene,"top"),0,accuracy:0.0001)
    }

    func testRandomLayoutMenuSupportsOneThroughFifteenObjectBalls() {
        let (app,scene)=launch(["--ux017-qa"])
        for count in [1,15] {
            quick(app,"QuickAdd").press(forDuration:1)
            let submenu=app.buttons["Tạo thế mới"].firstMatch
            XCTAssertTrue(submenu.waitForExistence(timeout:5));submenu.tap()
            let option=app.buttons["Tạo thế \(count) bi"].firstMatch
            XCTAssertTrue(option.waitForExistence(timeout:5))
            for _ in 0..<5 where !option.isHittable { app.swipeUp() }
            XCTAssertTrue(option.isHittable);option.tap()
            wait(scene,timeout:5){self.field(scene,"ballCount")==Double(count)}
        }
    }


    func testCompetitiveNineBallOnlyOffersDiamondNumbersAndBlocksPracticeEdits() {
        let (app,scene)=launch(["--ux018-match-nine-qa"])
        let status=app.buttons["MatchStatus"]
        XCTAssertTrue(status.waitForExistence(timeout:5))
        XCTAssertTrue(status.label.contains("9 Ball"))
        XCTAssertTrue(status.label.contains("Lượt người 1"))
        XCTAssertEqual(field(scene,"ballCount"),9)
        XCTAssertEqual(field(scene,"coach"),0)
        let numbers=app.buttons["CoachToggle"]
        XCTAssertTrue(numbers.label.contains("nút số"))
        numbers.tap()
        XCTAssertEqual(field(scene,"coach"),0,"Competitive mode cannot enable coaching")
        XCTAssertFalse(app.buttons["QuickAdd"].isEnabled)
        XCTAssertFalse(app.buttons["QuickReplay"].isEnabled)
        XCTAssertFalse(app.otherElements["CoachCard"].isHittable)
    }

    func testRotationFifteenRackAndScoringTargetAreClearlyNamed() {
        let (app,scene)=launch(["--ux018-match-rotation-qa"])
        let status=app.buttons["MatchStatus"]
        XCTAssertTrue(status.waitForExistence(timeout:5))
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
        waitForExpectations(timeout:30)
        quick(app,"QuickReplay").press(forDuration:1)
        let save=app.buttons["Lưu cú này"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout:5));save.tap()
        let alert=app.alerts["Lưu cú này"]
        XCTAssertTrue(alert.waitForExistence(timeout:5))
        let name="QA-"+String(UUID().uuidString.prefix(8))
        let text=alert.textFields.firstMatch;text.tap()
        let previous=text.value as? String ?? ""
        text.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:previous.count)+name)
        alert.buttons["Lưu"].tap()
        let saved=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Đã lưu: "+name)).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout:10))
        // A distinct current aim proves replay did not simply reload its own
        // initial layout into the live world.
        let start=scene.coordinate(withNormalizedOffset:CGVector(dx:0.30,dy:0.32))
        let end=scene.coordinate(withNormalizedOffset:CGVector(dx:0.46,dy:0.32))
        start.press(forDuration:0.05,thenDragTo:end)
        let liveAngle=angle(scene),liveX=field(scene,"cueX"),liveY=field(scene,"cueY")
        func openArchive() {
            quick(app,"QuickReplay").press(forDuration:1)
            let list=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Cú đã lưu (")).firstMatch
            XCTAssertTrue(list.waitForExistence(timeout:5));list.tap()
            let item=app.buttons.matching(NSPredicate(format:"label CONTAINS %@",name)).firstMatch
            XCTAssertTrue(item.waitForExistence(timeout:5));item.tap()
            let play=app.buttons["Xem lại cú này"].firstMatch
            XCTAssertTrue(play.waitForExistence(timeout:5));play.tap()
            wait(scene,timeout:10){self.field(scene,"replay")==1}
            app.buttons["ReplayPause"].tap()
        }
        openArchive()
        XCTAssertEqual(field(scene,"coach"),0)
        app.buttons["CoachToggle"].tap()
        wait(scene,timeout:5){self.field(scene,"coach")==1}
        app.buttons["ReplayDone"].tap()
        wait(scene,timeout:5){self.field(scene,"replay")==0}
        XCTAssertEqual(angle(scene),liveAngle,accuracy:0.0001)
        XCTAssertEqual(field(scene,"cueX"),liveX,accuracy:0.0001)
        XCTAssertEqual(field(scene,"cueY"),liveY,accuracy:0.0001)
        openArchive()
        XCTAssertEqual(field(scene,"coach"),1)
        app.buttons["ReplayDone"].tap()
    }

}
