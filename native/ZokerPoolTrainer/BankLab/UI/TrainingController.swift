import UIKit
import SceneKit
import simd
import AVFoundation

final class TrainingController:UIViewController,UIGestureRecognizerDelegate {
    private let engine=BLWorld()
    private var table:TableScene!
    private var scn:SCNView!
    private var displayLink:CADisplayLink?
    private var lastTime:TimeInterval=0
    private var angle=Double.pi/2,side=0.0,top=0.0,pull=0.0
    private var locked=false,isPlacingBalls=false,guideOn=false,shotActive=false
    private var drillIndex=1,attempts=0,successes=0
    private var before:[BallState]=[],initial:[BallState]=[]
    private var shotCameraAnchor:BallState?
    private var savedAimCamera:CameraPose?
    private var observationCamera=false
    private var cameraTransition=0.0
    private var cameraTransitionDuration=0.45
    private var shotCameraState=BLShotCameraState()
    private var localTurn=true // Offline by default; future networking owns this value.
    private var qaAwaitingAimReturn=false
    private var frames:[[BallState]]=[],frameTimes:[Double]=[],replayIndex:Int?,replayClock=0.0
    private var paths:[Int:[SIMD3<Float>]]=[:]
    private var sampleClock=0.0,draggedBall:Int?
    private var displayDurations:[Double]=[]
    private var lastEventCount=0
    private let titleLabel=UILabel(),statusLabel=UILabel(),scoreLabel=UILabel(),hintLabel=UILabel()
    private let spinCenter=UIButton(type:.system)
    private let spin=SpinPad(frame:.zero),stroke=StrokePad(frame:.zero)
    private var testShotButton:UIButton!
    private var lastPassed=false,lastScratch=false
    private var lastShotSpeed=0.0
    private var testSpeed=2.0
    private var highGraphics=true
    private var focusMode=true
    private var menuOpen=false
    private var trailsOn=false
    private var spinWidth:NSLayoutConstraint!,spinHeight:NSLayoutConstraint!
    private var quickRailBottom:NSLayoutConstraint!
    private let menuButton=UIButton(type:.system)
    private let fineSlider=UISlider()
    private var fineAim=false
    private let retryButton=UIButton(type:.system)
    private var fineStartAngle=0.0
    private var aimRecognizers:[UIGestureRecognizer]=[]
    private var graphicsButton:UIButton!
    private let lockButton=HoldLockControl(frame:.zero)
    private let statusToast=UILabel()
    private let coachButton=UIButton(type:.system)
    private var coaching=false
    private var guidedCoachBefore:Bool?
    private var shotKind=0 // Stable legacy IDs: 0 playing, 1 jump, 2 break; 3 massé preset.
    private var quickPlace:UIButton!,quickAdd:UIButton!
    private let replayBar=UIStackView(),replaySlider=UISlider(),replayPause=UIButton(type:.system),replayRate=UIButton(type:.system),replayAutoButton=UIButton(type:.system)
    private var replayPaused=false,replaySpeed=1.0,replayAuto=true,replayAudioIndex=0
    private var lastShotEvents:[[String:NSNumber]]=[]
    private struct CameraPose {var mode:Int;var zoom:Float;var yaw:Float;var pitch:Float;var aimPitch:Float}
    private var cameraMemory:[Int:CameraPose]=[:]
    private var peekPose:CameraPose?,replayOrigin:CameraPose?,editingPose:CameraPose?
    private var editingSnapshot:[BallState]?
    private var cameraManual=false,lastDirectorTime = -10.0
    private var lastObservedMode=0
    private var autoCamera:Bool{UserDefaults.standard.object(forKey:"autoCamera017") as? Bool ?? true}
    private var referenceSpeed:Double{lastShotSpeed>0 ? lastShotSpeed:testSpeed}
    private var cameraButton:UIButton!,guideButton:UIButton!,editButton:UIButton!
    private var replayButton:UIButton!,undoButton:UIButton!,resetButton:UIButton!
    private var drillButton:UIButton!,layoutButton:UIButton!,settingsButton:UIButton!
    private let panel=UIView()
    private var spinExpanded=false
    private let quickRail=UIStackView(),elevationPad=ElevationPad(frame:.zero)
    private var quickReplay:UIButton!
    private let coachCard=UIView(),coachLabel=UILabel()
    private var lastShot:SavedShot?
    private var replayYaw=0.0
    private var quickCamera:UIButton!,quickTools:UIButton!,quickRole:UIButton!,quickCue:UIButton!,quickBag:UIButton!
    private var lastGuideAngle=Double.infinity,lastGuideVisible=false
    private var guideDirty=true
    private var lastPredictionTime:TimeInterval=0
    private let feedback=UIImpactFeedbackGenerator(style:.light)
    private let poolAudio=PoolAudio()
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override var prefersStatusBarHidden:Bool{true}
    override var prefersHomeIndicatorAutoHidden:Bool{true}
    override func viewDidLoad(){
        super.viewDidLoad();view.backgroundColor = UIColor(red:0.025,green:0.033,blue:0.044,alpha:1)
        // Visual probes must not inherit Jump/elevation from a previous scene.
        if !ProcessInfo.processInfo.arguments.contains("--visual-qa"),var config=UserDefaults.standard.dictionary(forKey:"physics") as? [String:NSNumber]{
            // 0.14: ma sát bi–bi đổi nghĩa (μ₀ của mô hình theo tốc độ). Bỏ giá trị cũ 0,035 đã lưu để dùng mặc định mới.
            if UserDefaults.standard.integer(forKey:"physicsModelVersion")<14 {
                config["ballFriction"]=nil;UserDefaults.standard.set(config,forKey:"physics");UserDefaults.standard.set(14,forKey:"physicsModelVersion")
            }
            engine.settings=config
        }
        table=TableScene(rails:engine.rails)
        if let color=UserDefaults.standard.object(forKey:"clothTintIndex") as? Int {table.setClothColor(color)}
        scn=SCNView(frame:.zero);scn.scene=table.scene;scn.pointOfView=table.camera
        scn.backgroundColor = .black;scn.antialiasingMode = .multisampling4X;scn.preferredFramesPerSecond=60
        scn.isPlaying=true;scn.rendersContinuously=true;scn.translatesAutoresizingMaskIntoConstraints=false
        view.addSubview(scn)
        scn.isMultipleTouchEnabled=true
        if ProcessInfo.processInfo.arguments.contains("--visual-qa"){scn.isAccessibilityElement=true;scn.accessibilityIdentifier="PoolScene"}
        NSLayoutConstraint.activate([
            scn.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            scn.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            scn.topAnchor.constraint(equalTo:view.topAnchor),
            scn.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
        buildHUD();buildQuickRail();buildCoachCard();buildStatusToast();configureGestures();loadDrill(drillIndex)
        let aimZoom=UserDefaults.standard.double(forKey:"aimCameraZoom013")
        table.zoom=Float(aimZoom>=0.45 && aimZoom<=2.6 ? aimZoom:1)
        let savedPitch=Float(UserDefaults.standard.double(forKey:"aimCameraPitch014"))
        table.aimPitch=TableScene.aimPitchRange.contains(savedPitch) ? savedPitch:TableScene.defaultAimPitch
        let configured=engine.settings
        spin.maximumOffset=(configured["experimental3D"]?.boolValue ?? false) ? 0.6:0.7
        table.selectCue(configured["cueType"]?.intValue ?? 0)
        table.cueElevation=(configured["experimental3D"]?.boolValue ?? false) ? (configured["cueElevationDegrees"]?.doubleValue ?? 0):0
        shotKind=ProcessInfo.processInfo.arguments.contains("--visual-qa") ? 0:(UserDefaults.standard.object(forKey:"shotKind017") as? Int ?? (configured["cueType"]?.intValue ?? 0))
        syncQuickRail()
        highGraphics=UserDefaults.standard.object(forKey:"highGraphics") as? Bool ?? true
        applyGraphics()
        table.camera.camera?.exposureOffset=CGFloat(UserDefaults.standard.object(forKey:"zokerExposure017") as? Double ?? -0.8)
        if ProcessInfo.processInfo.arguments.contains("--visual-qa") {
            let startupCameraMode=table.cameraMode
            loadShowcase()
            let args=ProcessInfo.processInfo.arguments
            if args.contains("--ux017-qa"){loadDrill(0)}
            if args.contains("--ux017-shot-qa") {
                DispatchQueue.main.asyncAfter(deadline:.now()+1){[weak self] in guard let self=self else{return};self.loadDrill(8);self.spin.select(side:0,top:0.4);self.locked=true;self.shoot(0.2)}
            }
            if args.contains("--g1-default-qa") {
                precondition(startupCameraMode==2,"G1: startup must use Aim3D")
                table.cameraMode=2;recordG1QA("default",["cameraMode":startupCameraMode,"coachDefaultOff":!coaching,"gesturePower":true])
            }
            if args.contains("--g1-audio-qa") {
                DispatchQueue.main.asyncAfter(deadline:.now()+0.8){[weak self] in
                    guard let self=self else{return}
                    for kind in 0...3 {self.poolAudio.play(kind:kind,impact:1.2,pan:0)}
                    // Máy CI có thể không có thiết bị âm thanh; khi engine chạy được thì cả 4 loại tiếng phải được phát.
                    if self.poolAudio.isRunning {precondition(self.poolAudio.scheduled==4,"All four impact kinds must be scheduled")}
                    precondition(self.poolAudio.sampleCount==7,"Seven real audio assets must load")
                    self.recordG1QA("audio",["engineRunning":self.poolAudio.isRunning,"scheduled":self.poolAudio.scheduled,"recordedSamples":self.poolAudio.sampleCount])
                }
            }
            if args.contains("--g1-hud-qa") {
                DispatchQueue.main.asyncAfter(deadline:.now()+1){[weak self] in self?.verifyRightHUD()}
            }
            if args.contains("--g1-return-qa") {
                DispatchQueue.main.asyncAfter(deadline:.now()+0.8){[weak self] in
                    guard let self=self else{return}
                    self.loadDrill(8);self.table.cameraMode=2;self.table.zoom=1.18
                    self.spin.select(side:0,top:0.4);self.locked=true;self.shoot(0.15)
                    precondition(self.shotActive,"G1 return probe must really strike")
                    self.qaAwaitingAimReturn=true
                }
            }
            if args.contains("--g1-spectator-qa") {
                localTurn=false;table.cameraMode=0;BLShotCameraStart(&shotCameraState)
                DispatchQueue.main.asyncAfter(deadline:.now()+1.5){[weak self] in
                    guard let self=self else{return};let before=self.balls.map{$0.dictionary}
                    self.setHold(true);self.shoot(2);self.undo();self.addBall()
                    precondition(!self.locked && !self.shotActive && !self.stroke.isEnabled)
                    precondition(NSArray(array:before).isEqual(to:self.balls.map{$0.dictionary}))
                    precondition(self.table.cameraMode==0,"G1 spectator must not be forced to aim")
                    self.recordG1QA("spectator",["cameraMode":self.table.cameraMode,"shotBlocked":true])
                }
            }
            if args.contains("--camera-top"){table.cameraMode=1;cameraButton.configuration?.title="Trên cao"}
            if args.contains("--camera-aim"){table.cameraMode=2;cameraButton.configuration?.title="Ngắm cơ"}
            if args.contains("--camera-orbit-qa"){table.cameraMode=0;table.orbit=0.62;table.zoom=1.35}
            if args.contains("--table-arc"){table.selectTable(TableLook.all[1]);table.cameraMode=0}
            if args.contains("--table-classic"){table.selectTable(TableLook.all[6]);table.cameraMode=0}
            if args.contains("--jump-qa"){chooseRole(1)}
            if args.contains("--cue-library-qa"){DispatchQueue.main.asyncAfter(deadline:.now()+1){[weak self]in self?.openLibrary(initialTab:1)}}
            if args.contains("--calibration-qa"){DispatchQueue.main.asyncAfter(deadline:.now()+1){[weak self]in self?.settings()}}
            if args.contains("--retry-qa"){DispatchQueue.main.asyncAfter(deadline:.now()+1){[weak self] in
                guard let self=self else{return}
                var layout=self.balls
                layout[0].qx=0.3;layout[0].qy=0.4;layout[0].qz=0;layout[0].qw=sqrt(0.75)
                self.engine.loadLayout(layout.map{$0.dictionary});precondition(abs((self.balls[0].qx ?? 0)-0.3)<1e-10);self.refresh();self.locked=true;self.shoot(2)
                DispatchQueue.main.asyncAfter(deadline:.now()+1){[weak self] in guard let self=self else{return};let expected=self.before;self.undo();assert(!self.shotActive && self.frames.isEmpty);precondition(self.balls.count==expected.count);precondition(zip(self.balls,expected).allSatisfy{a,b in abs(a.x-b.x)<1e-10 && abs(a.y-b.y)<1e-10 && abs((a.qw ?? 1)-(b.qw ?? 1))<1e-10 && abs((a.qx ?? 0)-(b.qx ?? 0))<1e-10})}
            }}
            if args.contains("--library-qa"){DispatchQueue.main.asyncAfter(deadline:.now()+1){[weak self]in self?.openLibrary()}}
            if args.contains("--drill-list-qa") || args.contains("--drill-detail-qa") {
                DispatchQueue.main.asyncAfter(deadline:.now()+0.8){[weak self] in
                    guard let self=self else{return}
                    let drills=DrillsController(style:.insetGrouped);drills.load={[weak self]index in self?.loadDrill(index)}
                    let nav=UINavigationController(rootViewController:drills);self.present(nav,animated:false)
                    if ProcessInfo.processInfo.arguments.contains("--drill-detail-qa") {
                        DispatchQueue.main.asyncAfter(deadline:.now()+0.5){drills.tableView(drills.tableView,didSelectRowAt:IndexPath(row:0,section:0))}
                    }
                }
            }
            if args.contains("--cue-contact-qa") {table.cameraMode=2}
            if args.contains("--observation-qa") {
                DispatchQueue.main.asyncAfter(deadline:.now()+0.8){[weak self] in
                    guard let self=self else{return};self.loadDrill(8);self.table.cameraMode=2;self.locked=true;self.shoot(1.8)
                }
            }
            setMenu(false)
        }
        applyCoachVisibility()

        stroke.sensitivity=UserDefaults.standard.double(forKey:"sensitivity");if stroke.sensitivity==0{stroke.sensitivity=1}
        spin.changed={[weak self]x,y in self?.side=x;self?.top=y;self?.guideDirty=true}
        if ProcessInfo.processInfo.arguments.contains("--cue-contact-qa") {spin.select(side:-0.5,top:0.49)}
        if ProcessInfo.processInfo.arguments.contains("--spin-detail") {
            spinWidth.constant=190;spinHeight.constant=190;spin.alpha=0.97
            spinExpanded=true;quickRail.isHidden=false
            spin.select(side:0.25,top:0.35)
        }
        stroke.shot={[weak self]v in guard let self=self else{return};self.shoot(v)}
        stroke.pullChanged={[weak self]p in self?.pull=p}
        displayLink=CADisplayLink(target:self,selector:#selector(tick(_:)));displayLink?.preferredFramesPerSecond=60
        displayLink?.add(to:.main,forMode:.common)
        NotificationCenter.default.addObserver(self,selector:#selector(resumed),name:UIApplication.willResignActiveNotification,object:nil)
    }
    deinit{displayLink?.invalidate();NotificationCenter.default.removeObserver(self)}
    @objc private func resumed(){lastTime=0;spin.collapse();lockButton.releaseHold();setHold(false)}
    override func viewWillAppear(_ animated:Bool){
        super.viewWillAppear(animated);lastTime=0;displayLink?.isPaused=false
        scn?.isPlaying=true;scn?.rendersContinuously=true
    }
    override func viewWillDisappear(_ animated:Bool){
        super.viewWillDisappear(animated);spin.collapse();lockButton.releaseHold();setHold(false)
        // Do not keep a second rendering loop running behind the research workspace.
        displayLink?.isPaused=true;scn?.isPlaying=false;scn?.rendersContinuously=false
    }
    override func viewDidLayoutSubviews(){
        super.viewDidLayoutSubviews();layoutRightHUD()
    }
    private func layoutRightHUD(){
        guard spinWidth != nil,quickRailBottom != nil else{return}
        let metrics=BLRightHUDLayout(Double(view.safeAreaLayoutGuide.layoutFrame.height),spinExpanded)
        let reserved:CGFloat = 188 + CGFloat(BL_HUD_RAIL_WIDTH) + CGFloat(BL_HUD_ELEVATION_WIDTH)
        let available:CGFloat = view.safeAreaLayoutGuide.layoutFrame.width - reserved
        let size=min(CGFloat(metrics.spinSize),max(78,available));spinWidth.constant=size;spinHeight.constant=size
    }
    private func recordG1QA(_ name:String,_ values:[String:Any]){
        let directory=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("g1-qa")
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            var record=values;record["result"]="PASS";record["probe"]=name
            let data=try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys])
            try data.write(to:directory.appendingPathComponent(name+".json"),options:.atomic)
        }catch{preconditionFailure("Cannot write G1 QA evidence: \(error)")}
    }
    private func verifyRightHUD(){
        view.layoutIfNeeded()
        let controls:[UIView]=[spin,elevationPad,quickRail,menuButton,lockButton,coachButton]
        let safe=view.safeAreaLayoutGuide.layoutFrame
        for (index,control) in controls.enumerated(){
            precondition(safe.contains(control.frame),"G1: control outside safe area")
            precondition(control.bounds.width>=44 && control.bounds.height>=44)
            for other in controls.dropFirst(index+1){precondition(!control.frame.intersects(other.frame),"G1: overlapping HUD controls")}
        }
        precondition(elevationPad.frame.minX>spin.frame.maxX,"G1: độ dốc cơ phải ở bên phải bi effect")
        precondition(quickRail.frame.minX>elevationPad.frame.maxX,"G1: thanh phím tắt sát mép phải")
        let interactive:[UIControl]=[spin,lockButton,coachButton,quickCamera!,retryButton,quickReplay!,quickRole!,quickPlace!,quickAdd!]
        for control in interactive{
            let point=control.convert(CGPoint(x:control.bounds.midX,y:control.bounds.midY),to:view)
            let hit=view.hitTest(point,with:nil)
            precondition(hit===control || hit?.isDescendant(of:control)==true,"G1: another view intercepts the HUD")
        }
        recordG1QA(spinExpanded ? "hud-expanded":"hud",["width":safe.width,"height":safe.height,"elevationRightOfEffect":true,"railOnRightEdge":true,"controlsDoNotOverlap":true])
    }
    private func text(_ label:UILabel,_ size:CGFloat,_ color:UIColor,_ weight:UIFont.Weight = .medium){label.font = .systemFont(ofSize:size,weight:weight);label.textColor=color}
    private func stack(_ axis:NSLayoutConstraint.Axis,_ spacing:CGFloat,_ views:[UIView])->UIStackView {
        let s=UIStackView(arrangedSubviews:views);s.axis=axis;s.spacing=spacing;s.alignment = .fill;return s
    }
    private func buildHUD(){
        // The SceneKit viewport never changes size when the menu opens.
        stroke.translatesAutoresizingMaskIntoConstraints=false
        stroke.isUserInteractionEnabled=false;view.addSubview(stroke)
        NSLayoutConstraint.activate([
            stroke.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            stroke.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            stroke.topAnchor.constraint(equalTo:view.topAnchor),
            stroke.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
        for overlay in [spin,lockButton] {
            overlay.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(overlay)
        }
        spinCenter.setTitle("Về tâm",for:.normal);spinCenter.titleLabel?.font = .systemFont(ofSize:12,weight:.semibold)
        spinCenter.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(spinCenter);spinCenter.isHidden=true
        spinCenter.addAction(UIAction{[weak self]_ in self?.spin.reset()},for:.touchUpInside)
        NSLayoutConstraint.activate([spinCenter.centerXAnchor.constraint(equalTo:spin.centerXAnchor),spinCenter.bottomAnchor.constraint(equalTo:spin.topAnchor,constant:-4),spinCenter.widthAnchor.constraint(equalToConstant:78),spinCenter.heightAnchor.constraint(equalToConstant:44)])
        spin.alpha=0.60
        spinWidth=spin.widthAnchor.constraint(equalToConstant:78)
        spinHeight=spin.heightAnchor.constraint(equalToConstant:78)
        spin.expandedChanged={[weak self] expanded in
            guard let self=self else{return}
            if expanded{self.lockButton.releaseHold();self.setHold(false)}
            self.spinExpanded=expanded
            self.spin.alpha=expanded ? 0.97:0.60
            self.layoutRightHUD();self.updateControls()
            self.fineSlider.isHidden=expanded || self.menuOpen || !self.fineAim
            self.coachButton.isEnabled = !expanded
            self.spinCenter.isHidden = !expanded
            self.view.layoutIfNeeded()
        }
        lockButton.heldChanged={[weak self] held in self?.setHold(held)}
        NSLayoutConstraint.activate([
            spin.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12),
            spinWidth,spinHeight,
            lockButton.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:12),
            lockButton.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12),
            lockButton.widthAnchor.constraint(equalToConstant:68),lockButton.heightAnchor.constraint(equalToConstant:68)])
        coachButton.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(coachButton)
        coachButton.setTitle("C",for:.normal);coachButton.titleLabel?.font = .systemFont(ofSize:22,weight:.bold)
        coachButton.layer.cornerRadius=24;coachButton.backgroundColor=UIColor(white:0.08,alpha:0.7)
        coachButton.accessibilityIdentifier="CoachToggle";coachButton.accessibilityLabel="C · Huấn luyện viên"
        coachButton.addAction(UIAction{[weak self]_ in self?.toggleCoach()},for:.touchUpInside)
        NSLayoutConstraint.activate([coachButton.leadingAnchor.constraint(equalTo:lockButton.trailingAnchor,constant:10),
            coachButton.centerYAnchor.constraint(equalTo:lockButton.centerYAnchor),coachButton.widthAnchor.constraint(equalToConstant:48),coachButton.heightAnchor.constraint(equalToConstant:48)])

        fineSlider.translatesAutoresizingMaskIntoConstraints=false
        fineSlider.minimumValue = -1;fineSlider.maximumValue=1;fineSlider.value=0
        fineSlider.tintColor=UIColor.white.withAlphaComponent(0.20);fineSlider.thumbTintColor=UIColor.white.withAlphaComponent(0.35)
        fineSlider.accessibilityLabel="Vi chỉnh góc ngắm"
        view.addSubview(fineSlider)
        NSLayoutConstraint.activate([fineSlider.centerXAnchor.constraint(equalTo:view.centerXAnchor),fineSlider.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-130),fineSlider.widthAnchor.constraint(equalToConstant:190),fineSlider.heightAnchor.constraint(equalToConstant:44)])
        fineSlider.addAction(UIAction{[weak self]_ in guard let self=self else{return};self.fineStartAngle=self.angle},for:.touchDown)
        fineSlider.addAction(UIAction{[weak self]_ in guard let self=self,!self.locked,!self.shotActive else{return};self.angle=self.fineStartAngle+Double(self.fineSlider.value)*0.018;self.refresh()},for:.valueChanged)
        fineSlider.addAction(UIAction{[weak self]_ in self?.fineSlider.value=0},for:[.touchUpInside,.touchUpOutside,.touchCancel])
        menuButton.setTitle("Menu",for:.normal)
        menuButton.titleLabel?.font = .systemFont(ofSize:13,weight:.semibold)
        menuButton.setTitleColor(UIColor.white.withAlphaComponent(0.8),for:.normal)
        menuButton.backgroundColor=UIColor(white:0.03,alpha:0.45);menuButton.layer.cornerRadius=18
        menuButton.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(menuButton)
        menuButton.addAction(UIAction{[weak self]_ in guard let self=self else{return};self.setMenu(!self.menuOpen)},for:.touchUpInside)
        NSLayoutConstraint.activate([
            menuButton.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-CGFloat(BL_HUD_EDGE)),
            menuButton.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:10),
            menuButton.widthAnchor.constraint(equalToConstant:78),menuButton.heightAnchor.constraint(equalToConstant:44)])

        panel.backgroundColor=UIColor(red:0.10,green:0.055,blue:0.025,alpha:0.98)
        panel.layer.cornerRadius=20;panel.layer.borderWidth=1.5;panel.layer.borderColor=MenuSkin.gold.withAlphaComponent(0.6).cgColor
        let wood=UIImageView(image:MenuSkin.wood);wood.contentMode = .scaleAspectFill;wood.alpha=0.25
        wood.translatesAutoresizingMaskIntoConstraints=false;wood.isUserInteractionEnabled=false;panel.addSubview(wood)
        panel.clipsToBounds=true
        NSLayoutConstraint.activate([wood.leadingAnchor.constraint(equalTo:panel.leadingAnchor),wood.trailingAnchor.constraint(equalTo:panel.trailingAnchor),wood.topAnchor.constraint(equalTo:panel.topAnchor),wood.bottomAnchor.constraint(equalTo:panel.bottomAnchor)])
        panel.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(panel)
        let scroll=UIScrollView();scroll.translatesAutoresizingMaskIntoConstraints=false;panel.addSubview(scroll)
        NSLayoutConstraint.activate([
            panel.trailingAnchor.constraint(equalTo:menuButton.trailingAnchor),
            panel.topAnchor.constraint(equalTo:menuButton.bottomAnchor,constant:8),
            panel.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12),
            panel.widthAnchor.constraint(equalToConstant:318),
            scroll.leadingAnchor.constraint(equalTo:panel.leadingAnchor),scroll.trailingAnchor.constraint(equalTo:panel.trailingAnchor),
            scroll.topAnchor.constraint(equalTo:panel.topAnchor),scroll.bottomAnchor.constraint(equalTo:panel.bottomAnchor)])
        let brand=UILabel();text(brand,17,.white,.bold);brand.text="Zoker Pool Trainer · 0.17 · Luyện tập";brand.textColor=MenuSkin.gold
        text(titleLabel,14,.white,.bold);text(statusLabel,12,.mint);text(scoreLabel,12,.white);text(hintLabel,12,.mint)
        for label in [titleLabel,statusLabel,scoreLabel,hintLabel]{label.numberOfLines=0}
        hintLabel.text=strokeHint
        drillButton = .lab("Bài tập"){[weak self]in self?.chooseDrill()}
        layoutButton = .lab("Thế bi / Nhật ký"){[weak self]in self?.layouts()}
        settingsButton = .lab("Hiệu chỉnh vật lý"){[weak self]in self?.settings()}
        graphicsButton = .lab("Hình ảnh"){[weak self]in self?.graphics()}
        cameraButton = .lab("Ngắm cơ"){[weak self]in self?.cycleCamera()}
        guideButton = .lab("Dự báo: tắt"){[weak self]in
            guard let self=self else{return};guard self.coachOn else{self.statusLabel.text="Bật C để xem trợ giúp";return};self.guideOn.toggle();self.guideDirty=true
            self.guideButton.configuration?.title=self.guideOn ? "Dự báo: bật":"Dự báo: tắt"
        }
        editButton = .lab("Đặt bi"){[weak self]in self?.toggleEdit()}
        undoButton = .lab("Lùi cú"){[weak self]in self?.undo()}
        resetButton = .lab("Làm lại"){[weak self]in self?.reset()}
        replayButton = .lab("Xem lại"){[weak self]in self?.replay()}
        testShotButton = .lab("Đánh thử · 2 m/s"){[weak self]in
            guard let self=self,!self.shotActive,self.replayIndex==nil,!self.isPlacingBalls,self.cue?.sunk==false else{return}
            self.setMenu(false);self.locked=true;self.shoot(self.testSpeed);self.locked=false;self.updateControls()
        }
        testShotButton.menu=UIMenu(title:"Tốc độ đầu",children:[0.3,0.5,1,1.5,2,3,4].map{value in
            UIAction(title:String(format:"%.1f m/s",value)){[weak self]_ in
                self?.testSpeed=value;self?.guideDirty=true
                self?.testShotButton.configuration?.title=String(format:"Đánh thử · %.1f m/s",value)
            }
        })
        let equipment=UIButton.lab("Cơ 3D · Jump / Massé"){[weak self]in self?.equipment()}
        let lessons=UIButton.lab("Bài học / Nguồn tham khảo"){[weak self]in self?.lessons()}
        let help=UIButton.lab("Cách điều khiển / Nguồn âm"){[weak self]in self?.help()}
        let trails=UIButton.lab("Vệt bi: bật / tắt"){[weak self]in
            guard let self=self else{return};guard self.coachOn else{return};self.trailsOn.toggle()
            self.table.trails(self.trailsOn ? self.paths:[:])
        }
        let felt=UIButton.lab("Màu nỉ bàn"){[weak self]in self?.chooseClothColor()}
        let sound=UIButton.lab("Âm thanh: bật / tắt"){[weak self]in
            let enabled = !(UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true)
            UserDefaults.standard.set(enabled,forKey:"poolAudioEnabled")
            self?.statusLabel.text=enabled ? "Âm thanh bi: bật":"Âm thanh bi: tắt"
        }
        let kick=UIButton.lab("Tìm góc kick · 1–3 băng"){[weak self]in self?.chooseKick()}
        let coachToggle=UIButton.lab("C · Bật / tắt toàn bộ trợ giúp"){[weak self] in self?.toggleCoach()}
        let cameraOptions=UIButton.lab("Camera tự động / Góc nhìn"){[weak self] in self?.cycleCamera()}
        let recordings=UIButton.lab("Lưu cú / Cú đã lưu"){[weak self] in
            guard let self=self else{return}
            let sheet=UIAlertController(title:"Thư viện cú đánh",message:nil,preferredStyle:.actionSheet)
            sheet.addAction(UIAlertAction(title:"Lưu cú vừa đánh",style:.default){[weak self]_ in self?.saveLastShot()})
            for shot in SavedShot.all().reversed(){sheet.addAction(UIAlertAction(title:shot.name,style:.default){[weak self]_ in self?.playSaved(shot)})}
            sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));self.presentSheet(sheet,source:self.menuButton)
        }
        let center=UIButton.lab("Ép phê về tâm"){[weak self]in self?.spin.reset()}
        let close=UIButton.lab("Đóng Menu"){[weak self]in self?.setMenu(false)}
        func row(_ buttons:[UIView])->UIStackView{let r=stack(.horizontal,8,buttons);r.distribution = .fillEqually;return r}
        let fine=UIButton.lab("Ngắm tinh: bật / tắt"){[weak self]in guard let self=self else{return};self.fineAim.toggle();self.setMenu(false)}
        let advanced=UIButton.lab("Nâng cao"){[weak self]in guard let self=self else{return};let a=UIAlertController(title:"Nâng cao",message:nil,preferredStyle:.actionSheet)
            a.addAction(UIAlertAction(title:"Hiệu chỉnh vật lý",style:.default){[weak self]_ in self?.settings()})
            a.addAction(UIAlertAction(title:"ZUPE Lab · nghiên cứu",style:.default){[weak self]_ in self?.setMenu(false);self?.present(UINavigationController(rootViewController:ZupeLabController()),animated:true)})
            a.addAction(UIAlertAction(title:"Đóng",style:.cancel));self.presentSheet(a,source:self.menuButton)
        }
        let controls=stack(.vertical,10,[brand,titleLabel,statusLabel,scoreLabel,hintLabel,
            row([drillButton,layoutButton]),guideButton,resetButton,
            row([center,trails]),
            row([graphicsButton,fine]),row([felt,sound]),coachToggle,cameraOptions,recordings,equipment,kick,advanced,lessons,help,close])
        controls.translatesAutoresizingMaskIntoConstraints=false;scroll.addSubview(controls)
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor,constant:16),
            controls.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor,constant:-16),
            controls.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor,constant:16),
            controls.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor,constant:-16),
            controls.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor,constant:-32)])
        for button in [drillButton,layoutButton,cameraButton,guideButton,editButton,undoButton,resetButton,
                       replayButton,testShotButton,graphicsButton,settingsButton] {
            button?.heightAnchor.constraint(greaterThanOrEqualToConstant:44).isActive=true
        }
        var retry=UIButton.Configuration.plain();retry.title="Lùi cú";retry.image=UIImage(systemName:"arrow.uturn.backward");retry.imagePadding=5;retry.baseForegroundColor=UIColor.white.withAlphaComponent(0.8);retry.background.backgroundColor=UIColor(white:0.03,alpha:0.3);retry.background.cornerRadius=18
        retry.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:11,weight:.medium);return a}
        retry.title="Tập lại";retryButton.configuration=retry;retryButton.translatesAutoresizingMaskIntoConstraints=false;retryButton.accessibilityLabel="Dừng và đánh lại cú vừa rồi";view.addSubview(retryButton)
        retryButton.addAction(UIAction{[weak self]_ in self?.undo()},for:.touchUpInside)
        panel.isHidden=true;table.cameraMode=2;table.showNumbers=false
    }
    private func setMenu(_ open:Bool){
        spin.collapse();lockButton.releaseHold();setHold(false)
        menuOpen=open;focusMode = !open;panel.isHidden = !open
        menuButton.setTitle(open ? "Đóng":"Menu",for:.normal)
        fineSlider.isHidden=open || !fineAim
        spinCenter.isHidden=true;spin.isHidden=open;lockButton.isHidden=open;coachButton.isHidden=open
        quickRail.isHidden=open;elevationPad.isHidden=open
        coachCard.isHidden=open || !coachOn || coachCard.alpha==0
        updateControls()
    }
    private func buildQuickRail(){
        quickRail.axis = .vertical;quickRail.spacing=6;quickRail.distribution = .fillEqually
        quickRail.translatesAutoresizingMaskIntoConstraints=false
        func button(_ symbol:String,_ name:String,_ id:String)->UIButton {
            let b=UIButton(type:.system);var c=UIButton.Configuration.plain()
            c.image=UIImage(systemName:symbol);c.title=name;c.imagePlacement = .top;c.imagePadding=3
            c.baseForegroundColor = .white;c.background.backgroundColor=UIColor(white:0.035,alpha:0.65);c.background.cornerRadius=12
            c.preferredSymbolConfigurationForImage=UIImage.SymbolConfiguration(pointSize:17,weight:.medium)
            c.contentInsets=NSDirectionalEdgeInsets(top:4,leading:2,bottom:4,trailing:2)
            c.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:11,weight:.medium);return a}
            b.configuration=c;b.accessibilityIdentifier=id;return b
        }
        quickCamera=button("eye","Mắt","QuickCamera")
        quickCamera.addAction(UIAction{[weak self]_ in self?.eyeDown()},for:.touchDown)
        quickCamera.addAction(UIAction{[weak self]_ in self?.eyeUp()},for:.touchUpInside)
        quickCamera.addAction(UIAction{[weak self]_ in self?.releasePeek()},for:[.touchUpOutside,.touchCancel])
        quickReplay=button("play.circle","Xem lại","QuickReplay")
        quickReplay.addAction(UIAction{[weak self]_ in self?.replay()},for:.touchUpInside)
        retryButton.configuration=button("arrow.uturn.backward","Tập lại","unused").configuration
        retryButton.accessibilityIdentifier="QuickRetry"
        quickRole=button("line.diagonal","Đánh","QuickCue");quickRole.showsMenuAsPrimaryAction=true
        quickPlace=button("hand.draw","Đặt bi","QuickPlace")
        quickPlace.addAction(UIAction{[weak self]_ in self?.toggleEdit()},for:.touchUpInside)
        quickAdd=button("plus.circle","+ Bi","QuickAdd")
        quickAdd.addAction(UIAction{[weak self]_ in guard let self=self else{return};if self.isPlacingBalls{self.cancelPlacement()}else{self.addBall()}},for:.touchUpInside)
        quickTools=UIButton(type:.system);quickCue=UIButton(type:.system);quickBag=UIButton(type:.system)
        for items in [[quickCamera!,quickReplay!,retryButton],[quickRole!,quickPlace!,quickAdd!]] {
            let row=UIStackView(arrangedSubviews:items);row.axis = .horizontal;row.spacing=6;row.distribution = .fillEqually;quickRail.addArrangedSubview(row)
        }
        view.addSubview(quickRail);elevationPad.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(elevationPad)
        quickRailBottom=quickRail.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12)
        NSLayoutConstraint.activate([
            quickRail.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-CGFloat(BL_HUD_EDGE)),
            quickRail.widthAnchor.constraint(equalToConstant:CGFloat(BL_HUD_RAIL_WIDTH)),quickRail.heightAnchor.constraint(equalToConstant:CGFloat(BLHUDRailHeight())),quickRailBottom,
            elevationPad.trailingAnchor.constraint(equalTo:quickRail.leadingAnchor,constant:-8),
            elevationPad.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12),
            elevationPad.widthAnchor.constraint(equalToConstant:CGFloat(BL_HUD_ELEVATION_WIDTH)),elevationPad.heightAnchor.constraint(equalToConstant:CGFloat(BL_HUD_ELEVATION_HEIGHT)),
            spin.trailingAnchor.constraint(equalTo:elevationPad.leadingAnchor,constant:-8)])
        elevationPad.changed={[weak self] value in self?.setElevation(value)}
        buildReplayBar();syncQuickRail();applyCoachVisibility()
    }
    private func syncQuickRail(){
        guard quickRole != nil else{return}
        let role=engine.settings["cueType"]?.intValue ?? 0
        elevationPad.degrees=table.cueElevation
        let names=[0:"Đánh",1:"Jump",2:"Break",3:"Massé"]
        quickRole.configuration?.title=names[shotKind] ?? "Đánh"
        quickRole.menu=UIMenu(title:"Kiểu cú / loại cơ",children:[0,3,1,2].map{kind in
            UIAction(title:names[kind]!,state:shotKind==kind ? .on:.off){[weak self]_ in self?.chooseShotKind(kind)}
        })
        quickPlace.configuration?.title=isPlacingBalls ? "Xong":"Đặt bi"
        quickAdd.configuration?.title=isPlacingBalls ? "Hủy":"+ Bi"
        quickAdd.menu=isPlacingBalls ? nil:UIMenu(title:"Xếp bi ngẫu nhiên",children:[
            UIMenu(title:"Thêm vào bàn",children:[3,6,9,15].map{n in UIAction(title:"Thêm \(n) bi"){[weak self]_ in self?.addRandomBalls(n)}}),
            UIMenu(title:"Tạo thế mới",children:[3,6,9,15].map{n in UIAction(title:"Tạo thế \(n) bi"){[weak self]_ in self?.addRandomBalls(n,replacing:true)}}),
            UIAction(title:"Chọn số bi / nhập seed"){[weak self]_ in self?.randomOptions()}])
        quickCamera.menu=shotActive ? nil:UIMenu(title:"Góc nhìn",children:[0,1,2].map{mode in
            UIAction(title:["Toàn bàn","Trên cao","Ngắm cơ"][mode],state:table.cameraMode==mode ? .on:.off){[weak self]_ in self?.selectCamera(mode)}
        }+[UIAction(title:"Camera tự động sau cú",state:autoCamera ? .on:.off){[weak self]_ in guard let self=self else{return};UserDefaults.standard.set(!self.autoCamera,forKey:"autoCamera017");self.syncQuickRail()}])
        quickCue.menu=UIMenu(title:"Cơ",children:(0...2).map{i in UIAction(title:CueBag.cue(i).title){[weak self]_ in self?.chooseRole(i)}})
        quickBag.menu=UIMenu(title:"Bao cơ",children:[quickCue.menu!,UIMenu(title:"Đổi bao",children:CueBag.names.enumerated().map{i,title in UIAction(title:title){[weak self]_ in CueBag.active=i;self?.chooseRole(role)}}),UIAction(title:"Thư viện bàn & cơ"){[weak self]_ in self?.openLibrary()}])
    }
    private func chooseShotKind(_ kind:Int){
        guard !presentationBusy,!locked,localTurn,(0...3).contains(kind) else{return}
        UserDefaults.standard.set(["elevation":table.cueElevation,"side":side,"top":top],forKey:"cuePreset017-\(shotKind)")
        shotKind=kind;UserDefaults.standard.set(kind,forKey:"shotKind017")
        let role=kind==3 ? 0:kind
        var values=engine.settings;values["cueType"]=NSNumber(value:role);engine.settings=values;table.selectCue(role)
        let preset=UserDefaults.standard.dictionary(forKey:"cuePreset017-\(kind)") as? [String:Double]
        setElevation(preset?["elevation"] ?? (kind==1 ? 45:(kind==3 ? 60:0)))
        spin.select(side:preset?["side"] ?? 0,top:preset?["top"] ?? 0)
        syncQuickRail()
    }
    private var toastGeneration=0
    private func buildStatusToast(){
        statusToast.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(statusToast)
        statusToast.textColor = .white;statusToast.backgroundColor=UIColor(white:0.035,alpha:0.9)
        statusToast.font = .systemFont(ofSize:13,weight:.medium);statusToast.textAlignment = .center;statusToast.numberOfLines=2
        statusToast.layer.cornerRadius=10;statusToast.clipsToBounds=true;statusToast.isHidden=true
        NSLayoutConstraint.activate([statusToast.centerXAnchor.constraint(equalTo:view.safeAreaLayoutGuide.centerXAnchor),statusToast.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),statusToast.widthAnchor.constraint(lessThanOrEqualToConstant:390),statusToast.widthAnchor.constraint(lessThanOrEqualTo:view.safeAreaLayoutGuide.widthAnchor,multiplier:0.7),statusToast.heightAnchor.constraint(greaterThanOrEqualToConstant:44)])
    }
    private func notifyStatus(_ text:String){
        statusLabel.text=text;statusToast.text="  "+text+"  ";statusToast.isHidden=false;view.bringSubviewToFront(statusToast)
        toastGeneration+=1;let generation=toastGeneration
        DispatchQueue.main.asyncAfter(deadline:.now()+3){[weak self] in guard let self=self,self.toastGeneration==generation else{return};self.statusToast.isHidden=true}
    }
    private func toggleCoach(){
        guard !locked,!spinExpanded else{return};coaching.toggle();applyCoachVisibility()
        if coaching {if lastShot != nil,!shotActive{showCoach(coachReport(drill:Drill.all[drillIndex],events:lastShotEvents,passed:lastPassed,scratch:lastScratch))}else{showCoach(drillBrief(Drill.all[drillIndex]))}}
    }
    private func applyCoachVisibility(){
        guard table != nil else{return}
        coachButton.setTitleColor(coaching ? .systemMint:.white,for:.normal)
        coachButton.accessibilityValue=coaching ? "Bật":"Tắt"
        table.showsDiamondNumbers=coaching
        table.target(coaching ? Drill.all[drillIndex].goal:nil)
        table.setTrainingOverlaysHidden(!coaching || locked)
        if !coaching {hideCoach();table.showRailContacts([]);table.trails([:]);table.prediction([],visible:false);guideOn=false;lastGuideVisible=false;guideButton?.configuration?.title="Dự báo: tắt"}
        hintLabel.isHidden = !coaching;scoreLabel.isHidden = !coaching
    }

    private func setElevation(_ degrees:Double){
        guard !presentationBusy,localTurn,!locked else{return}
        var values=engine.settings;values["cueElevationDegrees"]=NSNumber(value:degrees);values["experimental3D"]=NSNumber(value:degrees>0)
        engine.settings=values;table.cueElevation=degrees
        spin.maximumOffset=degrees>0 ? 0.6:0.7
        UserDefaults.standard.set(engine.settings,forKey:"physics");guideDirty=true;syncQuickRail()
    }
    private func chooseRole(_ role:Int){chooseShotKind(max(0,min(2,role)))}

    private func openLibrary(initialTab:Int=0){
        guard localTurn,!presentationBusy else{return};setMenu(false)
        let controller=EquipmentLibraryController(table:table);controller.initialTab=initialTab
        controller.changed={[weak self] role in if let role=role{self?.chooseRole(role)};self?.syncQuickRail()}
        let navigation=UINavigationController(rootViewController:controller);navigation.modalPresentationStyle = .fullScreen;present(navigation,animated:true)
    }
    private func equipment(){
        guard localTurn,!presentationBusy else{return}
        setMenu(false)
        let controller=CueEquipmentController(settings:engine.settings,table:table)
        controller.apply={[weak self] values in
            guard let self=self else{return}
            self.engine.settings=values
            self.spin.maximumOffset=(values["experimental3D"]?.boolValue ?? false) ? 0.6:0.7
            self.spin.select(side:self.side,top:self.top)
            UserDefaults.standard.set(self.engine.settings,forKey:"physics")
            self.table.selectCue(values["cueType"]?.intValue ?? 0)
            self.table.cueElevation=(values["experimental3D"]?.boolValue ?? false) ? (values["cueElevationDegrees"]?.doubleValue ?? 0):0
            self.guideDirty=true;self.syncQuickRail()
        }
        let navigation=UINavigationController(rootViewController:controller)
        navigation.modalPresentationStyle = .fullScreen
        present(navigation,animated:true)
    }
    private func setHold(_ held:Bool){
        locked=held && strokeAllowed
        table.setTrainingOverlaysHidden(locked);coachCard.isHidden=locked || coachCard.alpha==0
        for recognizer in aimRecognizers{recognizer.isEnabled = !locked}
        stroke.isUserInteractionEnabled=locked;stroke.isEnabled=locked
        menuButton.isHidden=locked
        fineSlider.isHidden=locked || menuOpen || !fineAim
        spin.isHidden=locked || menuOpen
        quickRail.isHidden=locked || menuOpen;elevationPad.isHidden=locked || menuOpen
        coachButton.isHidden=locked || menuOpen
        table.setTrainingOverlaysHidden(!coachOn || locked)
        if !locked{stroke.cancelStroke();pull=0}
    }
    /// Trục của lần kéo một ngón hiện tại: 0 chưa quyết, 1 ngang (hướng ngắm), 2 dọc (độ cao camera).
    private var aimPanAxis=0
    private var presentationBusy:Bool{shotActive || replayIndex != nil || BLShotCameraBusy(shotCameraState)}
    private var strokeHint:String{
        "Giữ B để khóa hướng. Ngón khác kéo lùi rồi đẩy tới: đẩy nhanh hơn là mạnh hơn. Buông B để hủy/ngắm lại. C bật/tắt trợ giúp."
    }

    private var strokeAllowed:Bool{
        BLStrokeAllowed(localTurn,presentationBusy,menuOpen,spinExpanded,isPlacingBalls,cue?.sunk==false)
    }
    private var balls:[BallState]{engine.states.map{BallState($0)}}
    private var cue:BallState?{balls.first{$0.id==0}}
    private func loadDrill(_ index:Int){
        guard !presentationBusy,localTurn else{return}
        drillIndex=index;attempts=0;successes=0;let drill=Drill.all[index]
        table.target(coachOn ? drill.goal:nil)
        initial=drill.balls;before=initial;angle=drill.angle
        engine.loadLayout(initial.map{$0.dictionary});clearShot();locked=false;isPlacingBalls=false;spin.reset()
        titleLabel.text=drill.title;hintLabel.text=strokeHint
        statusLabel.text="Trắng: bi cái · Vàng: bi 1";updateControls();refresh()
        table.showRailContacts([])
        table.showsDiamondNumbers=diamondNumbersOn && (drill.goal != nil || drill.rails>0)
        if coachOn && (drill.goal != nil || drill.rails>0) {showCoach(drillBrief(drill))}else{hideCoach()}
    }
    private func clearShot(){
        if replayIndex != nil{stopReplay()};releasePeek();replayBar.isHidden=true
        frames=[];frameTimes=[];paths=[:];shotActive=false;replayIndex=nil;lastEventCount=0
        BLShotCameraReset(&shotCameraState);table.trails([:]);guideDirty=true
        if observationCamera{restoreAimCamera()};shotCameraAnchor=nil
    }
    // MARK: Cơ tránh băng (BankLab/UI/CueClearance.h, Tests/CueClearanceTests.cpp)
    private struct TableGeometry {var width=1.27,length=2.54,radius=0.028575,nose=0.27}
    private var geometry=TableGeometry()
    /// Góc nghiêng tối đa cho cú thường (không bật cơ nâng 3D): 35° — giả định, cần đối chiếu trên bàn thật.
    private var maxStrokeElevation:Double{(engine.settings["experimental3D"]?.boolValue ?? false) ? 80:35}
    private func cueClearance(side s:Double,top t:Double)->Double{
        guard let c=cue,!c.sunk else{return 0}
        return BLCueMinimumElevation(c.x,c.y,angle,s,t,geometry.width,geometry.length,geometry.radius,geometry.nose)
    }
    private func updateCueClearance(){
        let g=engine.settings
        geometry=TableGeometry(width:g["tableWidth"]?.doubleValue ?? 1.27,length:g["tableLength"]?.doubleValue ?? 2.54,
                               radius:g["ballRadius"]?.doubleValue ?? 0.028575,nose:g["railHeight"]?.doubleValue ?? 0.27)
        let limit=maxStrokeElevation
        if spin.reachable==nil {
            spin.reachable={[weak self] x,y in guard let self=self else{return true};return self.cueClearance(side:x,top:y)<=self.maxStrokeElevation}
            spin.clampTop={[weak self] x,y in
                guard let self=self,let c=self.cue else{return y}
                return BLCueClampTop(c.x,c.y,self.angle,x,y,self.geometry.width,self.geometry.length,self.geometry.radius,self.geometry.nose,self.maxStrokeElevation,self.spin.maximumOffset)
            }
        }
        if cueClearance(side:side,top:top)>limit {spin.select(side:side,top:top)} // select() kẹp lên vùng với tới
        table.clearanceElevation=cueClearance(side:side,top:top)
        spin.setNeedsDisplay()
    }
    private func refresh(){updateCueClearance();table.update(balls,dt:0);guideDirty=true;scoreLabel.text="\(successes) / \(attempts) đạt · góc \(String(format:"%.1f",angle*180/Double.pi))°"}
    private func updateControls(){
        let busy=presentationBusy
        fineSlider.isEnabled = !busy && localTurn && !isPlacingBalls && !spinExpanded
        lockButton.isEnabled = strokeAllowed
        stroke.isEnabled=locked && strokeAllowed
        stroke.isUserInteractionEnabled=stroke.isEnabled
        testShotButton.isEnabled = !busy && localTurn && !isPlacingBalls && cue?.sunk == false
        elevationPad.isEnabled = !busy && localTurn && !isPlacingBalls && !spinExpanded
        quickTools?.isEnabled = !busy && localTurn && !spinExpanded
        quickRole?.isEnabled = !busy && localTurn && !spinExpanded && !isPlacingBalls
        quickPlace?.isEnabled = !busy && localTurn && !spinExpanded
        quickAdd?.isEnabled = !busy && localTurn && !spinExpanded
        quickReplay?.isEnabled = !shotActive && !frames.isEmpty && !isPlacingBalls
        coachButton.isEnabled = !locked && !spinExpanded
        syncQuickRail()
        spin.isEnabled = !busy && localTurn && !isPlacingBalls;editButton.configuration?.title=isPlacingBalls ? "Xong đặt bi":"Đặt bi"
        for b in [drillButton,layoutButton,settingsButton,editButton] {b?.isEnabled = !busy && localTurn}
        replayButton.isEnabled = !shotActive && !frames.isEmpty && localTurn
        replayButton.configuration?.title=replayIndex == nil ? "Xem lại":"Dừng xem"
        undoButton.isEnabled = !before.isEmpty && localTurn
        retryButton.isEnabled = !before.isEmpty && !isPlacingBalls && localTurn && !spinExpanded
    }
    private func nudge(_ amount:Double){guard !locked,!isPlacingBalls,!shotActive,replayIndex==nil else{return};angle+=amount;refresh()}
    private func captureCamera()->CameraPose{CameraPose(mode:table.cameraMode,zoom:table.zoom,yaw:table.orbit,pitch:table.orbitPitch,aimPitch:table.aimPitch)}
    private func applyCamera(_ pose:CameraPose){
        table.cameraMode=pose.mode;table.zoom=pose.zoom;table.orbit=pose.yaw;table.orbitPitch=pose.pitch;table.aimPitch=pose.aimPitch
        table.focusBounds=nil;beginCameraTransition(0.35)
    }
    private func selectCamera(_ mode:Int){
        guard (0...2).contains(mode),!locked else{return}
        cameraMemory[table.cameraMode]=captureCamera()
        let pose=cameraMemory[mode] ?? CameraPose(mode:mode,zoom:1,yaw:0,pitch:0.85,aimPitch:table.aimPitch)
        applyCamera(pose);observationCamera=mode != 2
        if mode != 2{lastObservedMode=mode}
        if shotActive{cameraManual=true}
        cameraButton.configuration?.title=["Toàn bàn","Trên cao","Ngắm cơ"][mode];syncQuickRail()
    }
    private func beginCameraTransition(_ duration:Double){cameraTransitionDuration=duration;cameraTransition=duration}
    private func restoreAimCamera(){
        guard localTurn,replayIndex==nil else{return}
        releasePeek()
        let saved=savedAimCamera ?? cameraMemory[2] ?? CameraPose(mode:2,zoom:1,yaw:0,pitch:0.57,aimPitch:table.aimPitch)
        applyCamera(saved);table.cameraMode=2;observationCamera=false;table.focusBounds=nil
        beginCameraTransition(0.45);cameraButton.configuration?.title="Ngắm cơ";syncQuickRail()
    }
    private func eyeDown(){
        guard !locked,!spinExpanded else{return}
        if shotActive {peekPose=captureCamera();table.cameraMode=0;table.zoom=1;table.orbitPitch=0.95;table.focusBounds=nil;beginCameraTransition(0.18)}
    }
    private func releasePeek(){
        guard let pose=peekPose else{return};peekPose=nil;applyCamera(pose)
    }
    private func eyeUp(){
        if peekPose != nil{releasePeek();return}
        guard !shotActive,replayIndex==nil,!isPlacingBalls,!locked else{return}
        selectCamera(table.cameraMode==2 ? lastObservedMode:2)
    }
    private func directCamera(time:Double,state:[BallState],replay:Bool){
        guard peekPose==nil,!cameraManual,(!replay || replayAuto),time>0.25,time-lastDirectorTime>1.5 else{return}
        let events=replay ? lastShotEvents:engine.events
        // Avoid switching viewpoint in the middle of an impact.
        if events.contains(where:{abs(($0["time"]?.doubleValue ?? -10)-time)<0.12}){return}
        lastDirectorTime=time;observationCamera=true
        let aerial=(lastShot?.elevation ?? 0)>15
        table.cameraMode=0;table.zoom=1;table.orbitPitch=aerial ? 0.4:0.95
        let moving=state.filter{!$0.sunk && ($0.id==0 || hypot($0.vx ?? 0,$0.vy ?? 0)>0.03)}
        if moving.count>0 && moving.count<5 {
            let xs=moving.map{Float($0.x)},ys=moving.map{Float($0.y)}
            table.focusBounds=SIMD4(max(-0.78,(xs.min() ?? 0)-0.35),min(0.78,(xs.max() ?? 0)+0.35),max(-1.43,(ys.min() ?? 0)-0.45),min(1.43,(ys.max() ?? 0)+0.45))
        }else{table.focusBounds=nil}
        beginCameraTransition(0.45)
    }

    private func cycleCamera(){
        let sheet=UIAlertController(title:"Góc nhìn",message:nil,preferredStyle:.actionSheet)
        for (index,title) in ["Toàn bàn · quan sát cú đánh","Trên cao · luyện thế bi","Ngắm cơ · sát bi"].enumerated(){
            sheet.addAction(UIAlertAction(title:title,style:.default){[weak self]_ in
                self?.selectCamera(index)
                self?.cameraButton.configuration?.title=["Toàn bàn","Trên cao","Ngắm cơ"][index]
                self?.setMenu(false);self?.syncQuickRail()
            })
        }
        sheet.addAction(UIAlertAction(title:autoCamera ? "Tắt tự động sau cú":"Bật tự động sau cú",style:.default){[weak self]_ in guard let self=self else{return};UserDefaults.standard.set(!self.autoCamera,forKey:"autoCamera017");self.syncQuickRail()})
        sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(sheet,source:menuButton)
    }
    private func placementValid()->Bool{
        let state=balls.filter{!$0.sunk}
        for (i,a) in state.enumerated(){for b in state.dropFirst(i+1){if hypot(a.x-b.x,a.y-b.y)<geometry.radius*2+0.0001{return false}}}
        return state.contains{$0.id==0}
    }
    private func toggleEdit(){
        guard !presentationBusy,localTurn,!locked else{return}
        if isPlacingBalls {
            guard placementValid() else{notifyStatus("Vị trí đang vướng bi khác — kéo bi cái ra vùng trống");return}
            isPlacingBalls=false;table.placementBlocked=false;editingSnapshot=nil
            initial=balls;before=balls;clearShot();if let pose=editingPose{applyCamera(pose)};editingPose=nil
        }else{
            hideCoach();editingSnapshot=balls;editingPose=captureCamera();isPlacingBalls=true
            var state=balls
            if let i=state.firstIndex(where:{$0.id==0}){state[i].x=0;state[i].y=0;state[i].sunk=false}else{state.append(BallState(id:0,x:0,y:0))}
            engine.loadLayout(state.map{$0.dictionary});selectCamera(1)
            table.placementBlocked = !placementValid();notifyStatus("Kéo bi cái từ giữa bàn · Xong để nhận · Hủy để phục hồi")
        }
        refresh();updateControls();syncQuickRail()
    }
    private func cancelPlacement(){
        guard isPlacingBalls,let snapshot=editingSnapshot else{return}
        engine.loadLayout(snapshot.map{$0.dictionary});isPlacingBalls=false;table.placementBlocked=false;editingSnapshot=nil
        if let pose=editingPose{applyCamera(pose)};editingPose=nil;refresh();updateControls()
    }

    private func shoot(_ speed:Double){
        guard locked,strokeAllowed,speed.isFinite,speed>0 else{return}
        lastShotSpeed=speed
        displayDurations=[]
        testSpeed=speed
        hintLabel.text=String(format:"Cú vuốt vừa rồi · %.2f m/s · %@",speed,CueLook.roles[engine.settings["cueType"]?.intValue ?? 0])
        shotCameraAnchor=cue
        if table.cameraMode==2 {savedAimCamera=captureCamera()}
        BLShotCameraStart(&shotCameraState)
        cameraManual=false;lastDirectorTime = -10;peekPose=nil;lastShotEvents=[]
        before=balls;frames=[before];frameTimes=[0];paths=[:];sampleClock=0;lastEventCount=0
        let strikeAngle=table.shotAngle(cue,angle:angle,side:side,top:top)
        lastShot=SavedShot(name:"",date:Date(),balls:balls,aimAngle:angle,speed:speed,side:side,top:top,
                           elevation:table.cueElevation,cueType:engine.settings["cueType"]?.intValue ?? 0,strikeAngle:strikeAngle,shotKind:shotKind)
        hideCoach()
        engine.strike(angle:strikeAngle,speed:speed,side:side,top:top)
        if UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true {poolAudio.play(kind:3,impact:speed,pan:audioPan(cue?.x ?? 0,cue?.y ?? 0))}
        shotActive=true;attempts+=1;statusLabel.text=String(format:"Đang chạy · tốc độ đầu %.2f m/s",speed)
        feedback.impactOccurred();guideDirty=true;table.trails([:]);setMenu(false);updateControls()
    }
    @objc private func tick(_ link:CADisplayLink){
        let dt=lastTime==0 ? 0:min(0.1,max(0,link.timestamp-lastTime));lastTime=link.timestamp
        let wasSimulating=shotActive,wasReplaying=replayIndex != nil
        if let index=replayIndex {
            replayClock += replayPaused ? 0:dt*replaySpeed
            var i=index
            while i+1<frames.count && replayClock>=frameTimes[i+1] {i+=1}
            if replayClock>=(frameTimes.last ?? 0)+0.25 {stopReplay()}
            else{
                replayIndex=i
                let j=min(i+1,frames.count-1)
                let span=frameTimes[j]-frameTimes[i]
                table.replay(frames[i],to:frames[j],fraction:span>0 ? (replayClock-frameTimes[i])/span:0)
                replaySlider.value=Float(replayClock);directCamera(time:replayClock,state:frames[i],replay:true)
                if !replayPaused {playReplayAudio()}
            }
        }else if shotActive {
            if dt>0 {displayDurations.append(dt)}
            engine.advance(dt);let state=balls;table.update(engine.presentationStates.map{BallState($0)},dt:dt)
            if let cb=state.first(where:{$0.id==0}),!cb.sunk {
                let vx=cb.vx ?? 0,vy=cb.vy ?? 0
                let slipX=vx-cb.wy*0.028575,slipY=vy+cb.wx*0.028575
                let speed=hypot(vx,vy)
                let phase=speed<0.005 ? "ĐỨNG":(hypot(slipX,slipY)>0.02 ? "TRƯỢT":"LĂN")
                statusLabel.text=String(format:"%@ · %.2f m/s · %.1f s",phase,speed,engine.elapsed)
            }
            frames.append(state);frameTimes.append(engine.elapsed)
            sampleClock+=dt
            if sampleClock>=1.0/30.0 {
                sampleClock-=1.0/30.0
                for b in state where !b.sunk {paths[b.id,default:[]].append(SIMD3<Float>(Float(b.x),Float((b.height ?? 0)+0.004),Float(b.y)))}
            }
            let events=engine.events
            if events.count>lastEventCount {
                let fresh=events.suffix(events.count-lastEventCount)
                if fresh.contains(where:{$0["kind"]?.intValue==0}){feedback.impactOccurred(intensity:0.25)}
                if UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true {
                    for event in fresh {poolAudio.play(kind:event["kind"]?.intValue ?? 1,impact:event["impact"]?.doubleValue ?? 0.3,pan:audioPan(event["x"]?.doubleValue ?? 0,event["y"]?.doubleValue ?? 0))}
                }
                lastEventCount=events.count
            }
            if !engine.moving || engine.elapsed>60 {finishShot(timedOut:engine.moving)}
        }
        if shotActive,autoCamera {directCamera(time:engine.elapsed,state:balls,replay:false)}
        table.animatePockets(dt)
        let wasBusy=BLShotCameraBusy(shotCameraState)
        let cameraGestureActive=aimRecognizers.contains{recognizer in
            (recognizer is UIPinchGestureRecognizer || (recognizer as? UIPanGestureRecognizer)?.minimumNumberOfTouches==2) && (recognizer.state == .began || recognizer.state == .changed)
        }
        if BLShotCameraTick(&shotCameraState,dt,wasSimulating || shotActive || engine.moving,table.hasActivePocketAnimations,wasReplaying || replayIndex != nil,localTurn,isPlacingBalls,cameraGestureActive) {
            restoreAimCamera()
        }
        if wasBusy != BLShotCameraBusy(shotCameraState){updateControls()}
        if qaAwaitingAimReturn && !presentationBusy {
            precondition(table.cameraMode==2 && !observationCamera)
            precondition(abs(table.zoom-1.18)<0.001,"G1: saved aim zoom was lost")
            precondition(!table.hasActivePocketAnimations && !engine.moving)
            qaAwaitingAimReturn=false;recordG1QA("return",["cameraMode":table.cameraMode,"zoom":table.zoom,"settleSeconds":0.5,"transitionSeconds":0.45])
        }
        let displayCue:BallState? = replayIndex.flatMap{frames[$0].first{$0.id==0}} ?? cue
        var cameraCue=displayCue
        if shotActive,let anchor=shotCameraAnchor {cameraCue=anchor}
        if displayCue?.sunk==true,let anchor=shotCameraAnchor {cameraCue=anchor}
        var cameraAngle=angle
        if replayIndex != nil {cameraCue=frames.first?.first(where:{$0.id==0});cameraAngle=(lastShot?.aimAngle ?? angle)+replayYaw}
        let blend=BLCameraTweenBlend(cameraTransition,dt,cameraTransitionDuration)
        table.placeCamera(cue:cameraCue,angle:cameraAngle,aspect:scn.bounds.width/max(1,scn.bounds.height),blend:Float(blend))
        cameraTransition=max(0,cameraTransition-dt)
        if ProcessInfo.processInfo.arguments.contains("--visual-qa"){scn.accessibilityValue=String(format:"angle=%.6f;mode=%d;moving=%d;pitch=%.4f;coach=%d;kind=%d;zoom=%.4f;replay=%d;editing=%d;cueX=%.4f;cueY=%.4f",angle,table.cameraMode,shotActive ? 1:0,table.aimPitch,coaching ? 1:0,shotKind,table.zoom,replayIndex == nil ? 0:1,isPlacingBalls ? 1:0,cue?.x ?? 0,cue?.y ?? 0)}
        table.showCue(displayCue,angle:angle,visible:!presentationBusy && localTurn && !isPlacingBalls,pull:pull,side:side,top:top)
        let show=coachOn && guideOn && !presentationBusy && localTurn && !isPlacingBalls
        if !show && lastGuideVisible {
            table.prediction([],visible:false);lastGuideVisible=false
        }
        let changed=guideDirty || abs(angle-lastGuideAngle)>0.00001 || !lastGuideVisible
        if show && changed && link.timestamp-lastPredictionTime>=0.18 {
            let samples=engine.prediction(angle:table.shotAngle(cue,angle:angle,side:side,top:top),speed:referenceSpeed,side:side,top:top)
            table.prediction(samples,visible:true)
            lastGuideAngle=angle;lastGuideVisible=true;guideDirty=false;lastPredictionTime=link.timestamp
            if !focusMode {scoreLabel.text=String(format:"%d/%d đạt · Tham chiếu cú trước %.1f m/s",successes,attempts,referenceSpeed)}
        }
    }
    private func finishShot(timedOut:Bool){
        let d=Drill.all[drillIndex],events=engine.events
        lastShotEvents=events
        frames.append(balls);frameTimes.append(engine.elapsed)
        if timedOut {let stopped=balls;engine.loadLayout(stopped.map{$0.dictionary})}
        shotActive=false;locked=false;table.trails(coachOn && trailsOn ? paths:[:])
        let scratch=events.contains{$0["kind"]?.intValue==2 && $0["a"]?.intValue==0}
        var passed=false,railCount=0
        if let goal=d.goal {
            let potted=events.contains{$0["kind"]?.intValue==2 && $0["a"]?.intValue==1 && ($0["b"]?.intValue ?? -1)>=0}
            if let cb=balls.first(where:{$0.id==0}),!cb.sunk {
                passed=goal.potOnly ? potted:(hypot(cb.x-goal.x,cb.y-goal.y)<=goal.radius && (!goal.potRequired || potted))
            }
        }else if d.kick {
            for e in events {
                if e["kind"]?.intValue==0 && e["a"]?.intValue==0{railCount+=1}
                if e["kind"]?.intValue==1 && (e["a"]?.intValue==0 || e["b"]?.intValue==0) {
                    let target=(e["a"]?.intValue==0 ? e["b"]:e["a"])?.intValue
                    passed=target==1 && railCount==d.rails;break
                }
            }
        }else if d.rails>0 {
            for e in events {
                if e["kind"]?.intValue==0 && e["a"]?.intValue==1{railCount+=1}
                if e["kind"]?.intValue==2 && e["a"]?.intValue==1 {passed=railCount==d.rails && (e["b"]?.intValue ?? -1)>=0;break}
            }
        }
        passed=passed && !scratch && !timedOut
        lastPassed=passed;lastScratch=scratch
        if passed{successes+=1}
        if d.goal != nil || d.rails>0 {
            var history=practiceRecords()
            history.append(PracticeRecord(date:Date(),drill:d.title,passed:passed,speed:lastShotSpeed,side:side,top:top))
            if let data=try? JSONEncoder().encode(Array(history.suffix(200))){UserDefaults.standard.set(data,forKey:"practiceHistory")}
        }
        let distance:Double = paths[0].map {p in zip(p,p.dropFirst()).reduce(0.0){$0+Double(simd_distance($1.0,$1.1))}} ?? 0
        if timedOut {statusLabel.text="Dừng sau 60 giây · cú không tính đạt"}
        else if scratch {statusLabel.text="Lỗi: bi cái vào lỗ"}
        else if d.goal != nil {statusLabel.text=passed ? "ĐẠT · đúng vùng / điều kiện":"Chưa đạt · xem vùng dừng và bi 1"}
        else if d.rails==0 {statusLabel.text=String(format:"Quãng đường bi cái ≈ %.2f m",distance)}
        else {statusLabel.text="\(passed ? "ĐẠT":"Chưa đạt") · \(railCount) băng / yêu cầu \(d.rails)"}
        hintLabel.text="Tập lại: trở về trước cú · Xem lại: phân tích đường bi"
        refresh();updateControls()
        if coachOn && !timedOut && (d.goal != nil || d.rails>0) {
            let tracked=d.kick || d.goal != nil ? 0:1
            table.showRailContacts(railContacts(events,ball:tracked,untilFirstHit:d.kick).map{($0.x,$0.y)})
            showCoach(coachReport(drill:d,events:events,passed:passed,scratch:scratch))
        }
    }
    private func undo(){guard localTurn,!before.isEmpty,!isPlacingBalls else{return};lockButton.releaseHold();setHold(false);engine.loadLayout(before.map{$0.dictionary});clearShot();restoreAimCamera();locked=false;statusLabel.text="Đã trở về trước cú đánh";refresh();updateControls()}
    private func reset(){
        guard localTurn else{return}
        if shotActive {shotActive=false}
        replayIndex=nil;engine.loadLayout(initial.map{$0.dictionary});before=initial;clearShot();locked=false;isPlacingBalls=false
        statusLabel.text="Đã khôi phục thế bi bài tập";refresh();updateControls()
    }
    private func replay(){
        guard localTurn,!shotActive,!frames.isEmpty,!isPlacingBalls else{return}
        lockButton.releaseHold();setHold(false)
        if replayIndex != nil{stopReplay();return}
        hideCoach();replayOrigin=captureCamera();replayIndex=0;replayClock=0;replayYaw=0;replayAudioIndex=0
        replayPaused=false;replayAuto=true;cameraManual=false;lastDirectorTime = -10
        if let pose=savedAimCamera{applyCamera(pose)}else{table.cameraMode=2}
        replaySlider.maximumValue=Float(frameTimes.last ?? 1);replaySlider.value=0
        replayBar.isHidden=false;menuButton.isHidden=true;replayPause.setTitle("Dừng",for:.normal)
        statusLabel.text="Xem lại · kéo để đổi góc · tua để xem điểm chạm"
        updateControls()
    }
    private func stopReplay(){
        replayIndex=nil;replayBar.isHidden=true;menuButton.isHidden=false;table.update(balls,dt:0)
        if let pose=replayOrigin{applyCamera(pose)};replayOrigin=nil;observationCamera=false
        statusLabel.text="Xem lại xong";updateControls();applyCoachVisibility()
    }
    private func buildReplayBar(){
        replayBar.axis = .horizontal;replayBar.spacing=8;replayBar.alignment = .fill
        replayBar.backgroundColor=UIColor(white:0.04,alpha:0.9);replayBar.layer.cornerRadius=12
        replayBar.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(replayBar)
        replayPause.setTitle("Dừng",for:.normal);replayRate.setTitle("1×",for:.normal);replayAutoButton.setTitle("Auto",for:.normal)
        let close=UIButton(type:.system);close.setTitle("Xong",for:.normal)
        for item in [replayPause,replayRate,replayAutoButton,close]{item.titleLabel?.font = .systemFont(ofSize:13,weight:.semibold);item.widthAnchor.constraint(equalToConstant:52).isActive=true}
        for item in [replayPause,replayRate,replaySlider,replayAutoButton,close] as [UIView]{replayBar.addArrangedSubview(item)}
        NSLayoutConstraint.activate([replayBar.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:12),replayBar.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-12),replayBar.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),replayBar.heightAnchor.constraint(equalToConstant:48)])
        replayPause.accessibilityIdentifier="ReplayPause";replaySlider.accessibilityIdentifier="ReplaySeek"
        replayPause.addAction(UIAction{[weak self]_ in guard let self=self else{return};self.replayPaused.toggle();self.replayPause.setTitle(self.replayPaused ? "Tiếp":"Dừng",for:.normal)},for:.touchUpInside)
        replayRate.showsMenuAsPrimaryAction=true;replayRate.menu=UIMenu(children:[0.25,0.5,1.0].map{rate in UIAction(title:"\(rate)×"){[weak self]_ in self?.replaySpeed=rate;self?.replayRate.setTitle("\(rate)×",for:.normal)}})
        replayAutoButton.addAction(UIAction{[weak self]_ in guard let self=self else{return};self.replayAuto.toggle();self.cameraManual = !self.replayAuto;self.lastDirectorTime = -10;self.replayAutoButton.setTitle(self.replayAuto ? "Auto":"Tay",for:.normal)},for:.touchUpInside)
        close.addAction(UIAction{[weak self]_ in self?.stopReplay()},for:.touchUpInside)
        replaySlider.addAction(UIAction{[weak self]_ in
            guard let self=self,self.replayIndex != nil else{return};self.replayClock=Double(self.replaySlider.value)
            self.replayIndex=self.frameTimes.lastIndex(where:{$0<=self.replayClock}) ?? 0
            self.replayAudioIndex=self.lastShotEvents.prefix(while:{($0["time"]?.doubleValue ?? 0)<=self.replayClock}).count
            self.lastDirectorTime = -10
        },for:.valueChanged)
        replayBar.isHidden=true
    }
    private func playReplayAudio(){
        while replayAudioIndex<lastShotEvents.count {
            let event=lastShotEvents[replayAudioIndex]
            guard (event["time"]?.doubleValue ?? 0)<=replayClock else{break}
            if UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true {poolAudio.play(kind:event["kind"]?.intValue ?? 1,impact:event["impact"]?.doubleValue ?? 0.3,pan:audioPan(event["x"]?.doubleValue ?? 0,event["y"]?.doubleValue ?? 0))}
            replayAudioIndex+=1
        }
    }
    private func audioPan(_ x:Double,_ y:Double)->Double{
        let point=scn.projectPoint(SCNVector3(Float(x),0.03,Float(y)))
        return max(-1,min(1,Double(point.x/max(1,Float(scn.bounds.width)))*2-1))
    }

    private func configureGestures(){
        let tap=UITapGestureRecognizer(target:self,action:#selector(tapTable(_:)));scn.addGestureRecognizer(tap);aimRecognizers.append(tap)
        let pan=UIPanGestureRecognizer(target:self,action:#selector(panTable(_:)));pan.maximumNumberOfTouches=1;scn.addGestureRecognizer(pan);aimRecognizers.append(pan)
        let orbit=UIPanGestureRecognizer(target:self,action:#selector(orbitTable(_:)));orbit.minimumNumberOfTouches=2;scn.addGestureRecognizer(orbit);aimRecognizers.append(orbit)
        let pinch=UIPinchGestureRecognizer(target:self,action:#selector(pinchTable(_:)));scn.addGestureRecognizer(pinch);aimRecognizers.append(pinch)
        for recognizer in aimRecognizers{recognizer.delegate=self}
        tap.require(toFail:pan);tap.require(toFail:orbit);tap.require(toFail:pinch)
        // One-finger aim must not wait for a two-finger recognizer to fail.
    }
    func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldReceive touch:UITouch)->Bool{
        guard !menuOpen,!spinExpanded,!locked else{return false}
        if gestureRecognizer is UIPinchGestureRecognizer || (gestureRecognizer as? UIPanGestureRecognizer)?.minimumNumberOfTouches==2{return true}
        return localTurn && (!presentationBusy || replayIndex != nil)
    }
    func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith other:UIGestureRecognizer)->Bool{
        let pair=[gestureRecognizer,other]
        return pair.contains{$0 is UIPinchGestureRecognizer} && pair.contains{($0 as? UIPanGestureRecognizer)?.minimumNumberOfTouches==2}
    }
    private func tablePoint(_ p:CGPoint)->SIMD2<Double>? {
        let a=scn.unprojectPoint(SCNVector3(Float(p.x),Float(p.y),0)),b=scn.unprojectPoint(SCNVector3(Float(p.x),Float(p.y),1))
        let dy=b.y-a.y;guard abs(dy)>0.00001 else{return nil};let t = -a.y/dy
        guard t>0,t<1 else{return nil}
        return SIMD2<Double>(Double(a.x+(b.x-a.x)*t),Double(a.z+(b.z-a.z)*t))
    }
    @objc private func tapTable(_ g:UITapGestureRecognizer){
        guard localTurn,!presentationBusy,!menuOpen,!spinExpanded,!locked,let p=tablePoint(g.location(in:scn)) else{return}
        if isPlacingBalls {moveBall(0,to:p)}else if let c=cue {angle=atan2(p.y-c.y,p.x-c.x);refresh()}
    }
    @objc private func panTable(_ g:UIPanGestureRecognizer){
        if replayIndex != nil,!menuOpen {
            cameraManual=true;replayAuto=false;replayAutoButton.setTitle("Tay",for:.normal)
            let delta=g.translation(in:scn)
            if table.cameraMode==2{replayYaw+=Double(delta.x)*0.004}else{table.orbit+=Float(delta.x)*0.006;table.orbitPitch=max(0.2,min(1.4,table.orbitPitch+Float(delta.y)*0.004))}
            table.aimPitch=min(max(table.aimPitch+Float(delta.y)*0.004,TableScene.aimPitchRange.lowerBound),TableScene.aimPitchRange.upperBound)
            cameraTransition=0;g.setTranslation(.zero,in:scn);return
        }
        guard localTurn,!presentationBusy,!menuOpen,!spinExpanded,!locked else{return}
        if isPlacingBalls {
            guard let p=tablePoint(g.location(in:scn)) else{return}
            if g.state == .began {
                draggedBall=balls.filter{!$0.sunk}.min{hypot($0.x-p.x,$0.y-p.y)<hypot($1.x-p.x,$1.y-p.y)}.flatMap{hypot($0.x-p.x,$0.y-p.y)<0.12 ? $0.id:nil}
            }
            if let id=draggedBall {moveBall(id,to:p)}
            if g.state == .ended || g.state == .cancelled {draggedBall=nil}
        }else{
            guard g.numberOfTouches<=1 else{return}
            // Một ngón: ngang = xoay hướng đánh; dọc = hạ/nâng camera ngắm (sát mặt bàn → nhìn từ trên).
            // Khoá trục theo mỗi lần kéo: chưa áp dụng gì cho tới khi đi đủ 6 pt, rồi chọn trục trội.
            // Rung tay dọc không làm lệch hướng ngắm và ngược lại; cú nhích ngắn < 6 pt vẫn tính là xoay ngang.
            if g.state == .began {aimPanAxis=0}
            let delta=g.translation(in:scn)
            let aimCamera=table.cameraMode==2 && !observationCamera && replayIndex==nil
            let finishing=g.state == .ended || g.state == .cancelled
            if aimPanAxis==0 {
                if hypot(delta.x,delta.y)>=6 {aimPanAxis = (aimCamera && abs(delta.y)>abs(delta.x)*1.3) ? 2:1}
                else if finishing {aimPanAxis=1}
                else {return}
            }
            if aimPanAxis==1 {angle+=Double(delta.x)*0.003}
            if aimCamera && aimPanAxis==2 {
                table.aimPitch=min(max(table.aimPitch+Float(delta.y)*0.004,TableScene.aimPitchRange.lowerBound),TableScene.aimPitchRange.upperBound)
                cameraTransition=0
            }
            if finishing{
                if aimPanAxis==2 {UserDefaults.standard.set(Double(table.aimPitch),forKey:"aimCameraPitch014")}
                aimPanAxis=0
            }
            g.setTranslation(.zero,in:scn);refresh()
        }
    }
    @objc private func orbitTable(_ g:UIPanGestureRecognizer){
        guard !menuOpen,!spinExpanded,!locked else{return}
        let delta=g.translation(in:scn)
        cameraManual=true;if replayIndex != nil{replayAuto=false;replayAutoButton.setTitle("Tay",for:.normal)};table.focusBounds=nil
        if table.cameraMode==2 {
            if !observationCamera{savedAimCamera=captureCamera()}
            table.cameraMode=0;table.zoom=1
        }
        table.orbit+=Float(delta.x)*0.006;table.orbitPitch=max(0.20,min(1.40,table.orbitPitch+Float(delta.y)*0.004))
        cameraTransition=0;g.setTranslation(.zero,in:scn)
    }
    @objc private func pinchTable(_ g:UIPinchGestureRecognizer){
        guard !menuOpen,!spinExpanded,!locked else{return}
        cameraManual=true;if replayIndex != nil{replayAuto=false;replayAutoButton.setTitle("Tay",for:.normal)};table.focusBounds=nil
        cameraTransition=0;table.zoom=max(0.45,min(2.6,table.zoom/Float(g.scale)));g.scale=1
        if table.cameraMode==2 && !observationCamera && replayIndex==nil{
            UserDefaults.standard.set(Double(table.zoom),forKey:"aimCameraZoom013")
        }
    }
    private func chooseClothColor(){
        let sheet=UIAlertController(title:"Màu nỉ",message:"Chọn màu bàn luyện. Vân nỉ matte và texture vẫn được giữ.",preferredStyle:.actionSheet)
        for (index,item) in TableScene.clothColors.enumerated(){sheet.addAction(UIAlertAction(title:item.0,style:.default){[weak self]_ in UserDefaults.standard.set(index,forKey:"clothTintIndex");self?.table.setClothColor(index)})}
        sheet.addAction(UIAlertAction(title:"Theo mẫu bàn đang chọn",style:.default){[weak self]_ in UserDefaults.standard.removeObject(forKey:"clothTintIndex");self?.table.setClothColor(nil)})
        sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(sheet,source:menuButton)
    }
    private func moveBall(_ id:Int,to p:SIMD2<Double>){
        guard localTurn,!presentationBusy,isPlacingBalls else{return}
        var state=balls;guard let i=state.firstIndex(where:{$0.id==id}) else{return}
        let x=max(-0.590,min(0.590,p.x)),y=max(-1.225,min(1.225,p.y))
        guard !state.contains(where:{$0.id != id && !$0.sunk && hypot($0.x-x,$0.y-y)<0.0573}) else{return}
        state[i].x=x;state[i].y=y;state[i].sunk=false;engine.loadLayout(state.map{$0.dictionary});table.placementBlocked = isPlacingBalls && !placementValid();refresh()
    }
    private func presentSheet(_ sheet:UIAlertController,source:UIView?=nil){
        sheet.popoverPresentationController?.sourceView=source ?? view
        sheet.popoverPresentationController?.sourceRect=source?.bounds ?? CGRect(x:view.bounds.midX,y:view.bounds.midY,width:1,height:1)
        present(sheet,animated:true)
    }
    private func beginDrill(_ index:Int,guided:Bool){
        if let previous=guidedCoachBefore{coaching=previous;guidedCoachBefore=nil}
        if guided{guidedCoachBefore=coaching;coaching=true}
        loadDrill(index);applyCoachVisibility()
    }
    private func chooseDrill(){
        guard !shotActive,replayIndex==nil else{return}
        let vc=DrillsController(style:.insetGrouped)
        vc.load={[weak self]index in self?.beginDrill(index,guided:false)}
        vc.guidedLoad={[weak self]index in self?.beginDrill(index,guided:true)}
        present(UINavigationController(rootViewController:vc),animated:true)
    }
    private func chooseKick(){
        guard !shotActive,replayIndex==nil,!engine.moving,!isPlacingBalls,cue?.sunk==false else{return}
        let sheet=UIAlertController(title:"Chọn bi đích",message:"Dùng tốc độ cú vuốt gần nhất (hoặc tốc độ tham chiếu của bài) và ép phê hiện tại. Chưa hiệu chuẩn bàn thật.",preferredStyle:.actionSheet)
        for ball in balls.filter({$0.id != 0 && !$0.sunk}).sorted(by:{$0.id<$1.id}) {
            sheet.addAction(UIAlertAction(title:"Bi \(ball.id)",style:.default){[weak self]_ in
                guard let self=self else{return}
                let count=UIAlertController(title:"Số lần chạm băng trước bi \(ball.id)",message:nil,preferredStyle:.actionSheet)
                for rails in 1...3 {count.addAction(UIAlertAction(title:"\(rails) băng",style:.default){[weak self]_ in self?.findKick(target:ball.id,rails:rails)})}
                count.addAction(UIAlertAction(title:"Hủy",style:.cancel));self.presentSheet(count)
            })
        }
        sheet.addAction(UIAlertAction(title:"Hủy",style:.cancel));presentSheet(sheet)
    }
    private func findKick(target:Int,rails:Int){
        let layout=engine.states,settings=engine.settings,speed=referenceSpeed,x=side,y=top
        let progress=UIAlertController(title:"Đang tìm góc kick",message:"Đối chiếu đường chạy, bi cản và số băng…",preferredStyle:.alert)
        presentSheet(progress)
        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
            // Worker owns a separate world; rendering never shares mutable physics.
            let model=BLWorld();model.settings=settings;model.loadLayout(layout)
            let result=model.kick(target:target,rails:rails,speed:speed,side:x,top:y)
            DispatchQueue.main.async {
                guard let self=self else{return}
                progress.dismiss(animated:true){
                    let hit=result["hit"]?.boolValue ?? false
                    if hit {
                        if let solved=result["angle"]?.doubleValue {self.angle=solved-self.table.shotAngle(self.cue,angle:0,side:x,top:y)}
                        self.guideOn=true;self.guideDirty=true
                        self.guideButton.configuration?.title="Dự báo: bật";self.refresh()
                    }
                    let message=hit ? String(format:"Đã tìm góc trong mô phỏng: %d băng → bi %d, %.1f m/s.\nX %+.0f / Y %+.0f %% bán kính.\n\nTốc độ tham chiếu từ cú trước; lực cú vuốt tiếp theo có thể khác. Kết quả phụ thuộc thông số bàn; chưa xác nhận độ chính xác ngoài thực tế.",rails,target,speed,x*100,y*100):"Chưa tìm được góc ở lực và ép phê hiện tại trong phạm vi tìm kiếm. Thử đổi lực hoặc điểm chạm; điều này không chứng minh cú đánh bất khả thi."
                    let alert=UIAlertController(title:hit ? "Đã cập nhật góc ngắm":"Chưa tìm được lời giải",message:message,preferredStyle:.alert)
                    alert.addAction(UIAlertAction(title:"Đã hiểu",style:.default));self.presentSheet(alert)
                }
            }
        }
    }
    private func help(){
        let message="Giữ B: khóa hướng. Ngón khác kéo lùi rồi đẩy tới: tốc độ vuốt quyết định lực. Buông B để hủy. C: bật/tắt toàn bộ trợ giúp. Ngang: ngắm, dọc: nâng mắt, hai ngón: quan sát. Giữ Mắt khi bi chạy để xem toàn bàn, buông về góc cũ. Chạm + Bi thêm từng bi, giữ để xếp ngẫu nhiên.\n\nÂm thanh thu thật: bsumusictech, Za-Games, mccarthy@bedmas.com, AmberdeMeillon (CC0). ‘Pool Ball in pocket.wav’ — jtroan, CC BY 3.0, freesound.org/people/jtroan/sounds/241373/ ; creativecommons.org/licenses/by/3.0/ . Đã cắt, đổi mono/PCM, chỉnh gain và fade. Bản dùng từ HQ MP3 preview."
        let alert=UIAlertController(title:"Điều khiển 0.17 & ghi công",message:message,preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"Xong",style:.cancel));present(alert,animated:true)
    }

    private func layouts(){
        let a=UIAlertController(title:"Thế bi cá nhân",message:"Lưu vị trí, góc ngắm và tên vào máy. Có thể thêm bi trong chế độ đặt bi.",preferredStyle:.actionSheet)
        a.addAction(UIAlertAction(title:"Nhật ký luyện tập",style:.default){[weak self]_ in self?.showPracticeHistory()})
        if !frames.isEmpty {a.addAction(UIAlertAction(title:"Xuất CSV cú đánh vừa rồi",style:.default){[weak self]_ in self?.exportShot()})}
        a.addAction(UIAlertAction(title:"Lưu thế bi hiện tại",style:.default){[weak self]_ in self?.saveLayout()})
        a.addAction(UIAlertAction(title:"Thêm bi mục tiêu",style:.default){[weak self]_ in self?.addBall()})
        a.addAction(UIAlertAction(title:"Chỉ giữ bi cái + bi 1",style:.default){[weak self]_ in guard let self=self else{return};self.engine.loadLayout(self.balls.filter{$0.id<2}.map{$0.dictionary});self.clearShot();self.initial=self.balls;self.before=self.balls;self.refresh();self.updateControls()})
        for (i,l) in savedLayouts().enumerated(){a.addAction(UIAlertAction(title:"Mở: \(l.name)",style:.default){[weak self]_ in self?.openLayout(i)})}
        if !savedLayouts().isEmpty {a.addAction(UIAlertAction(title:"Xóa một thế bi đã lưu…",style:.destructive){[weak self]_ in self?.deleteLayout()})}
        a.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(a,source:layoutButton)
    }
    private func savedLayouts()->[Layout]{guard let data=UserDefaults.standard.data(forKey:"layouts") else{return []};return (try? JSONDecoder().decode([Layout].self,from:data)) ?? []}
    private func saveLayout(){
        let a=UIAlertController(title:"Tên thế bi",message:nil,preferredStyle:.alert);a.addTextField{$0.placeholder="Ví dụ: Kick 3 băng góc dài"}
        a.addAction(UIAlertAction(title:"Lưu",style:.default){[weak self,weak a]_ in
            guard let self=self else{return};var list=self.savedLayouts();list.append(Layout(name:a?.textFields?.first?.text?.isEmpty==false ? a!.textFields!.first!.text!:"Thế bi \(list.count+1)",balls:self.balls,angle:self.angle))
            if let data=try? JSONEncoder().encode(list){UserDefaults.standard.set(data,forKey:"layouts")};self.statusLabel.text="Đã lưu thế bi"
        });a.addAction(UIAlertAction(title:"Hủy",style:.cancel));presentSheet(a)
    }
    private func openLayout(_ index:Int){
        guard localTurn,!presentationBusy else{return}
        let l=savedLayouts()[index];loadDrill(0);initial=l.balls;before=initial;engine.loadLayout(initial.map{$0.dictionary});angle=l.angle
        titleLabel.text=l.name;refresh();updateControls()
    }
    private func deleteLayout(){
        let a=UIAlertController(title:"Xóa thế bi",message:nil,preferredStyle:.actionSheet)
        for(i,l) in savedLayouts().enumerated(){a.addAction(UIAlertAction(title:l.name,style:.destructive){[weak self]_ in guard let self=self else{return};var list=self.savedLayouts();list.remove(at:i);if let d=try? JSONEncoder().encode(list){UserDefaults.standard.set(d,forKey:"layouts")}})}
        a.addAction(UIAlertAction(title:"Hủy",style:.cancel));presentSheet(a,source:layoutButton)
    }
    // MARK: HLV offline (Docs/AI-COACH-SPEC.md): luật + mô phỏng phản thực tế bằng chính solver.
    // Chỉ chạy sau cú hoặc lúc mở bài, ở chế độ Luyện; ẩn khi giữ khoá/vuốt cơ. Không có số độ khi đánh.
    private var coachOn:Bool{coaching}
    private var diamondNumbersOn:Bool{coaching}
    private func n1(_ v:Double)->String{String(format:"%.1f",v).replacingOccurrences(of:".",with:",")}
    private func diamondPoint(_ x:Double,_ y:Double)->String{
        "ngắn \(n1(BLDiamondAlongShort(x,geometry.width))) · dài \(n1(BLDiamondAlongLong(y,geometry.length)))"
    }
    private func railLabel(_ rail:BLRail)->String{String(cString:BLRailNameVI(rail))}
    private func railContacts(_ events:[[String:NSNumber]],ball:Int,untilFirstHit:Bool)->[(rail:BLRail,diamond:Double,x:Double,y:Double)]{
        var out:[(rail:BLRail,diamond:Double,x:Double,y:Double)]=[]
        for e in events {
            let kind=e["kind"]?.intValue ?? -1,a=e["a"]?.intValue ?? -1,b=e["b"]?.intValue ?? -1
            if untilFirstHit && kind==1 && (a==ball || b==ball) {break}
            guard kind==0,a==ball,let x=e["x"]?.doubleValue,let y=e["y"]?.doubleValue else{continue}
            let rail=BLNearestRail(x,y,geometry.width,geometry.length)
            out.append((rail,BLRailDiamond(x,y,rail,geometry.width,geometry.length),x,y))
        }
        return out
    }
    private func drillBrief(_ d:Drill)->String{
        var lines=["📍 "+d.title+" — "+d.note]
        let all=balls
        if let c=all.first(where:{$0.id==0}) {lines.append("Bi cái: "+diamondPoint(c.x,c.y))}
        if let t=all.first(where:{$0.id==1}),!t.sunk {lines.append("Bi 1: "+diamondPoint(t.x,t.y))}
        if let g=d.goal {lines.append("Vùng đích: "+diamondPoint(g.x,g.y)+String(format:" · bán kính %.0f cm",g.radius*100))}
        if d.kick,d.rails==1,let c=all.first(where:{$0.id==0}),let t=all.first(where:{$0.id==1}) {
            var refs:[String]=[]
            for rail in [BLRailLeft,BLRailRight,BLRailFoot,BLRailHead] {
                let k=BLMirrorKickDiamond(c.x,c.y,t.x,t.y,rail,geometry.width,geometry.length,geometry.radius,geometry.nose)
                if k.isFinite {refs.append(railLabel(rail)+" ≈ nút "+n1(k))}
            }
            if !refs.isEmpty {lines.append("Hệ gương 1 băng (hình học, chưa tính xoáy/ma sát): "+refs.joined(separator:"; "))}
        } else if d.rails>=2 {
            lines.append("Nhiều băng: app chưa nhúng công thức corner-5/plus đã kiểm chứng. Sau mỗi cú, điểm va băng được đánh số để bạn tự lập bảng nút cho bàn này.")
        }
        lines.append("Nhìn kỹ rồi giữ khoá để đánh — ghi chú tự ẩn khi vuốt.")
        return lines.joined(separator:"\n")
    }
    /// Chạy một cú phản thực tế từ thế bi trước cú (không đổi bàn thật), trả về world sau đó.
    private func counterfactual(_ body:()->Void){
        let after=balls.map{$0.dictionary}
        engine.loadLayout(before.map{$0.dictionary})
        body()
        engine.loadLayout(after)
    }
    /// Điểm chạm theo đúng quy ước bánh xe effect (vòng 25/50 = % bán kính), để người dùng chỉnh lại y hệt.
    private func effectLabel(_ side:Double,_ top:Double)->String{
        if hypot(side,top)<0.05 {return " · đánh tâm"}
        var parts:[String]=[]
        if abs(top)>=0.05 {parts.append((top>0 ? "trên ":"dưới ")+String(format:"%.0f%%",abs(top)*100))}
        if abs(side)>=0.05 {parts.append((side>0 ? "phải ":"trái ")+String(format:"%.0f%%",abs(side)*100))}
        return " · effect "+parts.joined(separator:", ")
    }
    private func coachReport(drill d:Drill,events:[[String:NSNumber]],passed:Bool,scratch:Bool)->String{
        guard let shot=lastShot else{return passed ? "ĐẠT":"Chưa đạt"}
        var lines=[passed ? "✅ ĐẠT":(scratch ? "❌ Bi cái vào lỗ":"❌ Chưa đạt")]
        let strike=shot.strikeAngle ?? shot.aimAngle
        // Internal numerical bins explore nearby speeds; advice uses the swipe vocabulary.
        let base=Int(BLPowerLevelForSpeed(shot.speed))
        func levelSpeed(_ l:Int)->Double{BLPowerSpeed(Int32(l))}
        func levelChange(_ to:Int)->String{
            let d=to-base
            return (d<0 ? "đẩy nhẹ hơn một chút":"đẩy mạnh hơn một chút")
        }
        lines.append("Cú vuốt vừa rồi"+effectLabel(shot.side,shot.top))
        if d.kick {
            let contacts=railContacts(events,ball:0,untilFirstHit:true)
            if contacts.isEmpty {lines.append("Bi cái không chạm băng trước khi gặp bi.")}
            for (i,c) in contacts.enumerated() {lines.append("Băng \(i+1): \(railLabel(c.rail)) · nút \(n1(c.diamond))")}
            if !passed {
                var ideal:(rail:BLRail,diamond:Double)?
                counterfactual{
                    let k=engine.kick(target:1,rails:d.rails,speed:shot.speed,side:shot.side,top:shot.top)
                    if (k["hit"]?.intValue ?? 0)==1,let a=k["angle"]?.doubleValue {
                        let o=engine.simulate(angle:a,speed:shot.speed,side:shot.side,top:shot.top)
                        if let ev=o["events"] as? [[String:NSNumber]],let first=railContacts(ev,ball:0,untilFirstHit:true).first {ideal=(first.rail,first.diamond)}
                    }
                }
                if let ideal=ideal {
                    lines.append("Vật lý app (cùng lực, cùng effect): băng 1 cần chạm \(railLabel(ideal.rail)) · nút \(n1(ideal.diamond)).")
                    if let first=contacts.first,first.rail==ideal.rail {
                        let delta=ideal.diamond-first.diamond
                        lines.append(abs(delta)<0.05 ? "Điểm va băng đã đúng; xem lại lực và effect.":"👉 Một thay đổi: dời điểm va băng thứ nhất \(n1(abs(delta))) nút về phía nút \(n1(ideal.diamond)). Giữ nguyên lực và effect.")
                    } else {lines.append("👉 Một thay đổi: chọn đúng băng thứ nhất như trên.")}
                } else {
                    var alternative:(level:Int,rail:BLRail,diamond:Double)?
                    counterfactual{
                        for delta in [-1,1,-2,2] {
                            let level=Int(BLPowerClampLevel(Int32(base+delta)));guard level != base else{continue}
                            let k=engine.kick(target:1,rails:d.rails,speed:levelSpeed(level),side:shot.side,top:shot.top)
                            guard (k["hit"]?.intValue ?? 0)==1,let a=k["angle"]?.doubleValue else{continue}
                            let o=engine.simulate(angle:a,speed:levelSpeed(level),side:shot.side,top:shot.top)
                            if let ev=o["events"] as? [[String:NSNumber]],let first=railContacts(ev,ball:0,untilFirstHit:true).first {alternative=(level,first.rail,first.diamond);break}
                        }
                    }
                    if let alt=alternative {
                        lines.append("👉 Một thay đổi: \(levelChange(alt.level)), giữ effect. Khi đó băng 1 cần chạm \(railLabel(alt.rail)) · nút \(n1(alt.diamond)).")
                    } else {lines.append("Với vài mức vận tốc gần cú vừa rồi, vật lý app không tìm được đường \(d.rails) băng — thử đổi effect.")}
                }
            }
        } else if let goal=d.goal {
            if let cb=balls.first(where:{$0.id==0}),!cb.sunk {
                let miss=hypot(cb.x-goal.x,cb.y-goal.y)
                lines.append("Bi cái dừng: "+diamondPoint(cb.x,cb.y)+String(format:" · cách tâm vùng %.0f cm",miss*100))
                if !passed {
                    var best:(label:String,miss:Double)?
                    var candidates:[(String,Double,Double)]=[]
                    for delta in [-2,-1,1,2] {
                        let level=Int(BLPowerClampLevel(Int32(base+delta)))
                        if level != base {candidates.append((levelChange(level)+", giữ effect",levelSpeed(level),0))}
                    }
                    candidates.append(("giữ nhịp đẩy, điểm chạm cao hơn 20% bán kính (gần tới vòng 25)",shot.speed,0.2))
                    candidates.append(("giữ nhịp đẩy, điểm chạm thấp hơn 20% bán kính (gần tới vòng 25)",shot.speed,-0.2))
                    counterfactual{
                        for (label,speed,dTop) in candidates {
                            let top=max(-0.6,min(0.6,shot.top+dTop))
                            let o=engine.simulate(angle:strike,speed:speed,side:shot.side,top:top)
                            guard let bs=o["balls"] as? [[String:NSNumber]],let c=bs.first(where:{$0["id"]?.intValue==0}),!(c["sunk"]?.boolValue ?? false),
                                  let x=c["x"]?.doubleValue,let y=c["y"]?.doubleValue else{continue}
                            let ev=o["events"] as? [[String:NSNumber]] ?? []
                            let potted=ev.contains{$0["kind"]?.intValue==2 && $0["a"]?.intValue==1 && ($0["b"]?.intValue ?? -1)>=0}
                            if goal.potRequired && !potted {continue}
                            let m=hypot(x-goal.x,y-goal.y)
                            if best==nil || m<best!.miss {best=(label,m)}
                        }
                    }
                    if let best=best,best.miss<miss*0.7 {
                        lines.append("👉 Một thay đổi: \(best.label). Vật lý app dự báo bi cái dừng cách vùng "+String(format:"%.0f cm",best.miss*100)+(best.miss<=goal.radius ? " (vào vùng).":"."))
                    } else {lines.append("Đổi lực/điểm chạm đơn lẻ không cải thiện rõ — giữ nguyên, tập lại cho đều tay.")}
                }
            }
        } else if d.rails>0 {
            let contacts=railContacts(events,ball:1,untilFirstHit:false)
            for (i,c) in contacts.prefix(5).enumerated() {lines.append("Bi 1 · băng \(i+1): \(railLabel(c.rail)) · nút \(n1(c.diamond))")}
            if !passed {
                var fix:String?
                counterfactual{
                    for delta in [0.0025,-0.0025,0.005,-0.005,0.01,-0.01] {
                        let o=engine.simulate(angle:strike+delta,speed:shot.speed,side:shot.side,top:shot.top)
                        let ev=o["events"] as? [[String:NSNumber]] ?? []
                        var rails=0,ok=false
                        for e in ev {
                            if e["kind"]?.intValue==0 && e["a"]?.intValue==1 {rails+=1}
                            if e["kind"]?.intValue==2 && e["a"]?.intValue==1 {ok=rails==d.rails && (e["b"]?.intValue ?? -1)>=0;break}
                        }
                        let cueSafe = !ev.contains{$0["kind"]?.intValue==2 && $0["a"]?.intValue==0}
                        if ok && cueSafe {fix=(delta>0 ? "sang phải":"sang trái")+(abs(delta)<0.004 ? " rất ít (dưới nửa bề rộng đầu cơ)":(abs(delta)<0.007 ? " một chút":" rõ hơn"));break}
                    }
                }
                lines.append(fix.map{"👉 Một thay đổi: lệch hướng ngắm \($0); giữ nhịp đẩy và effect."} ?? "Lệch ngắm nhỏ không cứu được cú này — thử đổi lực hoặc effect.")
            }
        }
        lines.append("Dự báo theo vật lý của app, chưa đối chiếu bàn thật. Chạm để ẩn.")
        return lines.joined(separator:"\n")
    }
    private func showCoach(_ text:String){
        guard coachOn,replayIndex==nil,!isPlacingBalls else{return}
        coachLabel.text=text;coachCard.alpha=1;coachCard.isHidden=locked || menuOpen || !coachOn
    }
    private func hideCoach(){coachCard.alpha=0;coachCard.isHidden=true}
    private func buildCoachCard(){
        coachCard.backgroundColor=UIColor(white:0.02,alpha:0.62);coachCard.layer.cornerRadius=14
        coachCard.translatesAutoresizingMaskIntoConstraints=false;coachCard.accessibilityIdentifier="CoachCard"
        coachLabel.numberOfLines=0;coachLabel.font = .systemFont(ofSize:12,weight:.medium);coachLabel.textColor=UIColor.white.withAlphaComponent(0.92)
        coachLabel.translatesAutoresizingMaskIntoConstraints=false;coachCard.addSubview(coachLabel);view.addSubview(coachCard)
        NSLayoutConstraint.activate([
            coachCard.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:12),
            coachCard.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:10),
            coachCard.widthAnchor.constraint(lessThanOrEqualToConstant:360),
            coachCard.trailingAnchor.constraint(lessThanOrEqualTo:menuButton.leadingAnchor,constant:-12),
            coachCard.bottomAnchor.constraint(lessThanOrEqualTo:lockButton.topAnchor,constant:-10),
            coachLabel.leadingAnchor.constraint(equalTo:coachCard.leadingAnchor,constant:12),coachLabel.trailingAnchor.constraint(equalTo:coachCard.trailingAnchor,constant:-12),
            coachLabel.topAnchor.constraint(equalTo:coachCard.topAnchor,constant:10),coachLabel.bottomAnchor.constraint(equalTo:coachCard.bottomAnchor,constant:-10)])
        coachCard.addGestureRecognizer(UITapGestureRecognizer(target:self,action:#selector(coachTapped)))
        hideCoach()
    }
    @objc private func coachTapped(){hideCoach()}
    private func replayMenu()->UIMenu{
        let saved=SavedShot.all()
        var items:[UIMenuElement]=[
            UIAction(title:replayIndex != nil ? "Dừng xem lại":"Xem lại cú vừa đánh",image:UIImage(systemName:"play.circle"),
                     attributes:frames.isEmpty ? [.disabled]:[]){[weak self]_ in self?.replay()},
            UIAction(title:"Lưu cú này",image:UIImage(systemName:"star"),attributes:lastShot==nil ? [.disabled]:[]){[weak self]_ in self?.saveLastShot()}]
        if !saved.isEmpty {
            let formatter=DateFormatter();formatter.dateFormat="dd/MM HH:mm"
            items.append(UIMenu(title:"Cú đã lưu (\(saved.count))",image:UIImage(systemName:"star.square.on.square"),children:
                saved.enumerated().reversed().map{index,shot in
                    UIMenu(title:shot.name,subtitle:formatter.string(from:shot.date)+String(format:" · %.1f m/s",shot.speed),children:[
                        UIAction(title:"Đánh lại cú này",image:UIImage(systemName:"arrow.clockwise")){[weak self]_ in self?.playSaved(shot)},
                        UIAction(title:"Chỉ đặt lại thế bi",image:UIImage(systemName:"square.grid.3x3")){[weak self]_ in self?.loadSaved(shot)},
                        UIAction(title:"Xoá",image:UIImage(systemName:"trash"),attributes:.destructive){[weak self]_ in
                            var all=SavedShot.all();if index<all.count{all.remove(at:index)};SavedShot.store(all);self?.syncQuickRail()}])
                }))
        }
        return UIMenu(title:"Xem lại",children:items)
    }
    private func saveLastShot(){
        guard var shot=lastShot else{return}
        let alert=UIAlertController(title:"Lưu cú này",message:"Đặt tên để tìm lại trong Xem lại › Cú đã lưu.",preferredStyle:.alert)
        alert.addTextField{field in field.text=String(format:"Cú %@ · %.1f m/s",DateFormatter.localizedString(from:Date(),dateStyle:.none,timeStyle:.short),shot.speed)}
        alert.addAction(UIAlertAction(title:"Huỷ",style:.cancel))
        alert.addAction(UIAlertAction(title:"Lưu",style:.default){[weak self,weak alert]_ in
            shot.name=alert?.textFields?.first?.text?.trimmingCharacters(in:.whitespaces).nilIfEmpty ?? "Cú đã lưu"
            var all=SavedShot.all();all.append(shot);SavedShot.store(all)
            self?.statusLabel.text="Đã lưu: "+shot.name;self?.syncQuickRail()
        })
        present(alert,animated:true)
    }
    private func loadSaved(_ shot:SavedShot){
        guard localTurn,!presentationBusy else{return}
        lockButton.releaseHold();setHold(false)
        engine.loadLayout(shot.balls.map{$0.dictionary});clearShot();initial=balls;before=balls;locked=false
        chooseShotKind(shot.shotKind ?? shot.cueType)
        setElevation(shot.elevation);angle=shot.aimAngle;spin.select(side:shot.side,top:shot.top)
        selectCamera(2);refresh();updateControls()
    }
    private func playSaved(_ shot:SavedShot){
        loadSaved(shot)
        guard !presentationBusy,cue?.sunk==false else{return}
        locked=true;shoot(shot.speed);locked=false;updateControls()
        statusLabel.text="Đánh lại: "+shot.name
    }
    /// Xếp bi ngẫu nhiên theo seed (in ra để tái tạo): không chồng bi, cách miệng lỗ và băng.
    private func addRandomBalls(_ count:Int,replacing:Bool=false,chosenSeed:UInt64?=nil){
        guard localTurn,!presentationBusy,!locked else{return}
        var seed=chosenSeed ?? (UInt64(Date().timeIntervalSince1970*1000) & 0xFFFFFF)
        let shown=seed
        func next()->Double{seed &+= 0x9E3779B97F4A7C15;var z=seed;z=(z^(z>>30)) &* 0xBF58476D1CE4E5B9;z=(z^(z>>27)) &* 0x94D049BB133111EB;return Double((z^(z>>31))>>11)/Double(1<<53)}
        let g=engine.settings,width=g["tableWidth"]?.doubleValue ?? 1.27,length=g["tableLength"]?.doubleValue ?? 2.54,r=g["ballRadius"]?.doubleValue ?? 0.028575
        var state=balls.filter{($0.id==0) || (!replacing && !$0.sunk)}
        var added=0,tries=0
        while added<count && tries<4000 {
            tries+=1
            guard let id=(1...15).first(where:{id in !state.contains{$0.id==id}}) else{break}
            let x=(next()-0.5)*(width-6*r),y=(next()-0.5)*(length-6*r)
            let pockets=[(-width/2,-length/2),(width/2,-length/2),(-width/2,0),(width/2,0),(-width/2,length/2),(width/2,length/2)]
            if pockets.contains(where:{hypot($0.0-x,$0.1-y)<0.16}) {continue}
            if state.contains(where:{!$0.sunk && hypot($0.x-x,$0.y-y)<2.3*r}) {continue}
            state.append(BallState(id:id,x:x,y:y));added+=1
        }
        engine.loadLayout(state.map{$0.dictionary});clearShot();initial=balls;before=balls
        statusLabel.text="Xếp ngẫu nhiên \(added) bi · seed \(shown)";refresh();updateControls();syncQuickRail()
    }
    private func randomOptions(){
        guard !presentationBusy,!isPlacingBalls else{return}
        let alert=UIAlertController(title:"Thêm bi ngẫu nhiên",message:"Nhập seed để tái tạo cùng thế bi. Giữ nguyên bi cái và các bi đang có.",preferredStyle:.alert)
        alert.addTextField{$0.placeholder="Số bi 1–15";$0.keyboardType = .numberPad}
        alert.addTextField{$0.placeholder="Seed (để trống: ngẫu nhiên)";$0.keyboardType = .numberPad}
        alert.addAction(UIAlertAction(title:"Thêm",style:.default){[weak self,weak alert]_ in
            let count=Int(alert?.textFields?[0].text ?? "") ?? 3
            let seed=UInt64(alert?.textFields?[1].text ?? "")
            self?.addRandomBalls(max(1,min(15,count)),chosenSeed:seed)
        })
        alert.addAction(UIAlertAction(title:"Hủy",style:.cancel));present(alert,animated:true)
    }
    private func addBall(){
        guard localTurn,!presentationBusy,!locked else{return}
        var state=balls.filter{!$0.sunk || $0.id==0};guard let id=(1...15).first(where:{id in !state.contains{$0.id==id}})else{statusLabel.text="Đã đủ 15 bi mục tiêu";return}
        for row in 0..<8 {for col in 0..<5 {
            let x = -0.4+Double(col)*0.2,y = -0.9+Double(row)*0.25
            if !state.contains(where:{!$0.sunk && hypot($0.x-x,$0.y-y)<0.065}) {
                let previous=balls
                state.append(BallState(id:id,x:x,y:y));engine.loadLayout(state.map{$0.dictionary});clearShot();initial=balls;before=balls
                editingSnapshot=previous;editingPose=captureCamera();isPlacingBalls=true;selectCamera(1)
                notifyStatus("Đã thêm bi \(id) · kéo bi mới để đặt · Xong / Hủy")
                refresh();updateControls();return
            }
        }}
    }
    private func practiceRecords()->[PracticeRecord]{
        guard let data=UserDefaults.standard.data(forKey:"practiceHistory") else{return []}
        return (try? JSONDecoder().decode([PracticeRecord].self,from:data)) ?? []
    }
    private func showPracticeHistory(){
        let history=practiceRecords(),grouped=Dictionary(grouping:practiceRecords(),by:{$0.drill})
        let lines=grouped.keys.sorted().map{key -> String in
            let list=grouped[key] ?? [],wins=list.filter{$0.passed}.count
            return "\(key): \(wins)/\(list.count) đạt"
        }
        let message=history.isEmpty ? "Chưa có cú chấm điểm. Chọn bài và hoàn tất cú đánh để lưu tự động.":lines.joined(separator:"\n")+"\n\nTối đa 200 cú gần nhất. Các góc, lực và thế bi có thể khác nhau; tỷ lệ này chưa phải điểm kỹ năng chuẩn hóa."
        let a=UIAlertController(title:"Nhật ký trên máy",message:message,preferredStyle:.alert)
        a.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(a)
    }
    private func applyGraphics(){
        table.quality(highGraphics)
        scn.antialiasingMode=highGraphics ? .multisampling4X:.multisampling2X
        scn.preferredFramesPerSecond=60
        UserDefaults.standard.set(highGraphics,forKey:"highGraphics")
    }
    private func loadShowcase(){
        guard !shotActive,replayIndex==nil else{return}
        loadDrill(0)
        var layout=[BallState(id:0,x:0.11,y:-0.66)]
        let ids=[1,9,2,10,8,3,11,4,12,5,6,13,7,14,15]
        var index=0
        for row in 0..<5 {for column in 0...row{
            layout.append(BallState(id:ids[index],x:(Double(column)-Double(row)/2)*0.058,y:0.27+Double(row)*0.0503));index+=1
        }}
        initial=layout;before=layout;engine.loadLayout(layout.map{$0.dictionary});angle=Double.pi/2
        table.cameraMode=0;table.orbit=0;table.zoom=1
        cameraButton.configuration?.title="Toàn bàn";titleLabel.text="Studio · 15 bi"
        guideOn=false;guideButton.configuration?.title="Dự báo: tắt";clearShot();refresh();updateControls()
    }
    private func graphics(){
        let a=UIAlertController(title:"Hình ảnh · Studio",message:"Cao: khử răng cưa 4×, bóng 2048 và bóng tiếp xúc SSAO. Cân bằng: giảm tải GPU. Chưa đo FPS trên iPhone 14 Pro Max.",preferredStyle:.actionSheet)
        a.addAction(UIAlertAction(title:highGraphics ? "✓ Chất lượng cao":"Chất lượng cao",style:.default){[weak self]_ in self?.highGraphics=true;self?.applyGraphics()})
        a.addAction(UIAlertAction(title:highGraphics ? "Cân bằng":"✓ Cân bằng",style:.default){[weak self]_ in self?.highGraphics=false;self?.applyGraphics()})
        for item in [("Tối",-1.25),("Dịu · mặc định",-0.95),("Sáng",-0.65)] {
            a.addAction(UIAlertAction(title:item.0,style:.default){[weak self]_ in
                self?.table.camera.camera?.exposureOffset=CGFloat(item.1)
                UserDefaults.standard.set(item.1,forKey:"zokerExposure017")
            })
        }
        a.addAction(UIAlertAction(title:"Hiện FPS / thống kê render",style:.default){[weak self]_ in self?.scn.showsStatistics.toggle()})
        a.addAction(UIAlertAction(title:"Nhịp hiển thị cú vừa đánh",style:.default){[weak self]_ in
            guard let self=self else{return}
            let values=self.displayDurations.sorted(),count=values.count
            let message=count==0 ? "Đánh một cú trước để đo nhịp CADisplayLink trên thiết bị.":String(format:"%d khung · median %.2f ms · p95 %.2f ms · max %.2f ms\n%d nhịp dài hơn 25 ms.\nĐây là nhịp cập nhật, không phải phép đo thời gian GPU; xem thêm thống kê render.",count,values[count/2]*1000,values[min(count-1,Int(Double(count)*0.95))]*1000,(values.last ?? 0)*1000,values.filter{$0>0.025}.count)
            let alert=UIAlertController(title:"Chẩn đoán độ mượt",message:message,preferredStyle:.alert)
            alert.addAction(UIAlertAction(title:"Đóng",style:.cancel));self.presentSheet(alert)
        })
        let overviewOn=autoCamera
        a.addAction(UIAlertAction(title:overviewOn ? "✓ Sau cú đánh: chuyển toàn cảnh":"Sau cú đánh: giữ góc ngắm",style:.default){_ in
            UserDefaults.standard.set(!overviewOn,forKey:"autoCamera017")
        })
        a.addAction(UIAlertAction(title:"Khôi phục góc máy",style:.default){[weak self]_ in self?.table.orbit=0;self?.table.zoom=1;self?.table.aimPitch=TableScene.defaultAimPitch
            UserDefaults.standard.removeObject(forKey:"aimCameraPitch014");UserDefaults.standard.removeObject(forKey:"aimCameraZoom013")})
        if !shotActive,replayIndex==nil {
            a.addAction(UIAlertAction(title:"Mở cảnh studio 15 bi",style:.default){[weak self]_ in self?.loadShowcase()})
            a.addAction(UIAlertAction(title:"Kiểm tra lăn · 0.5 m/s",style:.default){[weak self]_ in self?.rollingCheck()})
        }
        a.addAction(UIAlertAction(title:"Xuất ảnh cảnh 3D",style:.default){[weak self]_ in
            guard let self=self else{return}
            let snapshot=self.scn.snapshot()
            let share=UIActivityViewController(activityItems:[snapshot],applicationActivities:nil)
            share.popoverPresentationController?.sourceView=self.graphicsButton
            share.popoverPresentationController?.sourceRect=self.graphicsButton.bounds
            self.present(share,animated:true)
        })
        a.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(a,source:graphicsButton)
    }
    private func rollingCheck(){
        guard !shotActive,replayIndex==nil else{return}
        loadDrill(8)
        table.cameraMode=2;table.zoom=1;table.orbit=0
        cameraButton.configuration?.title="Ngắm cơ"
        // At top=0.4 the strike gives omega=v/R: rolling from the first step.
        spin.select(side:0,top:0.4)
        guideOn=false;guideDirty=true;guideButton.configuration?.title="Dự báo: tắt"
        locked=true;shoot(0.5)
        titleLabel.text="Kiểm tra lăn · theo dõi chấm đỏ"
    }
    private func lessons(){
        guard !shotActive,replayIndex==nil else{return}
        let vc=LessonsController(style:.insetGrouped)
        vc.load={[weak self]index in self?.loadDrill(index)}
        present(UINavigationController(rootViewController:vc),animated:true)
    }
    private func exportShot(){
        guard !frames.isEmpty else{return}
        var csv="time_s,ball_id,x_m,y_m,vx_m_s,vy_m_s,wx_rad_s,wy_rad_s,spin_rad_s,sunk,rail_count\n"
        for (i,frame) in frames.enumerated(){for b in frame {
            let values=[String(frameTimes[i]),String(b.id),String(b.x),String(b.y),String(b.vx ?? 0),String(b.vy ?? 0),String(b.wx),String(b.wy),String(b.spin),b.sunk ? "1":"0",String(b.rails)]
            csv+=values.joined(separator:",")+"\n"
        }}
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("BankLab-shot-\(UUID().uuidString).csv")
        do {
            try csv.write(to:url,atomically:true,encoding:.utf8)
            let share=UIActivityViewController(activityItems:[url],applicationActivities:nil)
            share.popoverPresentationController?.sourceView=layoutButton
            share.popoverPresentationController?.sourceRect=layoutButton.bounds
            present(share,animated:true)
        }catch{statusLabel.text="Không xuất được CSV: \(error.localizedDescription)"}
    }
    private func settings(){
        guard localTurn,!presentationBusy else{return}
        let vc=SettingsController(settings:engine.settings,sensitivity:stroke.sensitivity)
        vc.apply={[weak self]settings,sensitivity in
            guard let self=self else{return};self.engine.settings=settings;self.stroke.sensitivity=sensitivity
            UserDefaults.standard.set(settings,forKey:"physics");UserDefaults.standard.set(sensitivity,forKey:"sensitivity")
            self.table.selectCue(self.engine.settings["cueType"]?.intValue ?? 0)
            self.table.cueElevation=(self.engine.settings["experimental3D"]?.boolValue ?? false) ? (self.engine.settings["cueElevationDegrees"]?.doubleValue ?? 0):0
            self.spin.maximumOffset=(self.engine.settings["experimental3D"]?.boolValue ?? false) ? 0.6:0.7
            self.spin.select(side:self.side,top:self.top)
            self.statusLabel.text="Đã lưu cấu hình bàn trên máy"
            self.syncQuickRail()
            self.guideDirty=true
        }
        let nav=UINavigationController(rootViewController:vc);nav.modalPresentationStyle = .formSheet;present(nav,animated:true)
    }
}

/// Recorded pool impacts. Source, licence, trimming and hashes: Tools/AudioSources/manifest.json.
final class PoolAudio {
    private let engine=AVAudioEngine()
    private let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)!
    private var nodes=[AVAudioPlayerNode]()
    private var next=0,variation=0
    private var buffers=[[AVAudioPCMBuffer]]()
    private(set) var scheduled=0
    private(set) var started=false
    var sampleCount:Int{buffers.reduce(0){$0+$1.count}}
    init(){
        let session=AVAudioSession.sharedInstance()
        try? session.setCategory(.playback,mode:.default,options:[.mixWithOthers]);try? session.setActive(true)
        for _ in 0..<12 {let node=AVAudioPlayerNode();engine.attach(node);engine.connect(node,to:engine.mainMixerNode,format:format);nodes.append(node)}
        for names in [["PoolRail0"],["PoolBall0","PoolBall1","PoolBall2","PoolBall3"],["PoolPocket0"],["PoolCue0"]] {
            buffers.append(names.map{name in
                guard let data=NSDataAsset(name:name)?.data else{preconditionFailure("Missing recorded audio: \(name)")}
                return Self.buffer(data,format:format)
            })
        }
        engine.prepare();start()
        NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main){[weak self] note in
            if (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)==AVAudioSession.InterruptionType.ended.rawValue{self?.start()}
        }
        NotificationCenter.default.addObserver(forName:.AVAudioEngineConfigurationChange,object:engine,queue:.main){[weak self]_ in self?.start()}
        NotificationCenter.default.addObserver(forName:UIApplication.didBecomeActiveNotification,object:nil,queue:.main){[weak self]_ in self?.start()}
    }
    private func start(){
        if engine.isRunning{started=true;return}
        do{try AVAudioSession.sharedInstance().setActive(true);try engine.start();started=true}catch{started=false;NSLog("PoolAudio: %@",String(describing:error))}
    }
    var isRunning:Bool{engine.isRunning}
    func play(kind:Int,impact:Double,pan:Double){
        guard impact.isFinite,pan.isFinite else{return}
        if !engine.isRunning{start()};guard engine.isRunning else{return}
        let type=max(0,min(3,kind)),variants=buffers[max(0,min(3,kind))]
        let buffer=variants[variation%variants.count];variation+=1
        let node=nodes.first(where:{!$0.isPlaying}) ?? nodes[next];next=(next+1)%nodes.count
        node.stop();node.pan=Float(max(-1,min(1,pan)))
        let gain=pow(max(0.005,min(1,impact/3.2)),0.65)
        node.volume=Float(min(0.95,gain * (type==0 ? 0.8:1)))
        node.scheduleBuffer(buffer,at:nil,options:[]);node.play();scheduled+=1
    }
    private static func buffer(_ wav:Data,format:AVAudioFormat)->AVAudioPCMBuffer{
        precondition(wav.count>44 && String(data:wav.prefix(4),encoding:.ascii)=="RIFF","Invalid recorded WAV")
        let pcm=wav.dropFirst(44),frames=pcm.count/2
        let out=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(frames))!;out.frameLength=AVAudioFrameCount(frames)
        let channel=out.floatChannelData![0]
        pcm.withUnsafeBytes{raw in for i in 0..<frames{channel[i]=Float(Int16(littleEndian:raw.loadUnaligned(fromByteOffset:i*2,as:Int16.self)))/32768}}
        return out
    }
}

private extension String {var nilIfEmpty:String?{isEmpty ? nil:self}}
