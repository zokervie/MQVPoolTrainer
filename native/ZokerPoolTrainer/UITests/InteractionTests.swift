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
        let coach=app.buttons["CoachToggle"];XCTAssertTrue(coach.exists);coach.tap()
        let enabled=NSPredicate { _,_ in self.field(scene,"coach")==1 }
        expectation(for:enabled,evaluatedWith:scene);waitForExpectations(timeout:5)
        coach.tap()
        let disabled=NSPredicate { _,_ in self.field(scene,"coach")==0 }
        expectation(for:disabled,evaluatedWith:scene);waitForExpectations(timeout:5)
        XCTAssertFalse(app.otherElements["CoachCard"].isHittable)
    }

    func testCameraRoundTripPreservesAimHeightAndZoom() {
        let (app,scene)=launch(["--ux017-qa"])
        scene.pinch(withScale:0.8,velocity:1)
        let zoom=field(scene,"zoom"),pitch=field(scene,"pitch")
        app.buttons["QuickCamera"].tap();app.buttons["QuickCamera"].tap()
        let returned=NSPredicate { _,_ in self.field(scene,"mode")==2 }
        expectation(for:returned,evaluatedWith:scene);waitForExpectations(timeout:5)
        XCTAssertEqual(field(scene,"zoom"),zoom,accuracy:0.002)
        XCTAssertEqual(field(scene,"pitch"),pitch,accuracy:0.002)
    }

    func testPlaceCueBallAtCentreAndCancelRestoresLayout() {
        let (app,scene)=launch(["--ux017-qa"])
        let x=field(scene,"cueX"),y=field(scene,"cueY")
        app.buttons["QuickPlace"].tap()
        let editing=NSPredicate { _,_ in self.field(scene,"editing")==1 }
        expectation(for:editing,evaluatedWith:scene);waitForExpectations(timeout:5)
        XCTAssertEqual(field(scene,"cueX"),0,accuracy:0.001);XCTAssertEqual(field(scene,"cueY"),0,accuracy:0.001)
        app.buttons["QuickAdd"].tap()
        let cancelled=NSPredicate { _,_ in self.field(scene,"editing")==0 }
        expectation(for:cancelled,evaluatedWith:scene);waitForExpectations(timeout:5)
        XCTAssertEqual(field(scene,"cueX"),x,accuracy:0.001);XCTAssertEqual(field(scene,"cueY"),y,accuracy:0.001)
    }

    func testFourCueChoicesKeepMasséAndBreakDistinct() {
        let (app,scene)=launch(["--ux017-qa"])
        for (name,kind) in [("Massé",3.0),("Jump",1.0),("Break",2.0),("Đánh",0.0)] {
            app.buttons["QuickCue"].tap()
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
        replay.tap();app.buttons["ReplayPause"].tap()
        let start=scene.coordinate(withNormalizedOffset:CGVector(dx:0.35,dy:0.30))
        let end=scene.coordinate(withNormalizedOffset:CGVector(dx:0.35,dy:0.50))
        start.press(forDuration:0.05,thenDragTo:end)
        app.buttons["Xong"].firstMatch.tap()
        let stopped=NSPredicate { _,_ in self.field(scene,"replay")==0 }
        expectation(for:stopped,evaluatedWith:scene);waitForExpectations(timeout:5)
        XCTAssertEqual(field(scene,"pitch"),pitch,accuracy:0.002)
    }
}

