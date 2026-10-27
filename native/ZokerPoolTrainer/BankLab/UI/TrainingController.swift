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
    private var savedAimCamera:(mode:Int,zoom:Float,orbit:Float,pitch:Float)?
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
    private let spin=SpinPad(frame:.zero),stroke=StrokePad(frame:.zero)
    private var testShotButton:UIButton!
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
    private var cameraButton:UIButton!,guideButton:UIButton!,editButton:UIButton!
    private var replayButton:UIButton!,undoButton:UIButton!,resetButton:UIButton!
    private var drillButton:UIButton!,layoutButton:UIButton!,settingsButton:UIButton!
    private let panel=UIView()
    private var spinExpanded=false
    private let quickRail=UIStackView(),elevationPad=ElevationPad(frame:.zero)
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
        buildHUD();buildQuickRail();configureGestures();loadDrill(drillIndex)
        let aimZoom=UserDefaults.standard.double(forKey:"aimCameraZoom013")
        table.zoom=Float(aimZoom>=0.45 && aimZoom<=2.6 ? aimZoom:1)
        let savedPitch=Float(UserDefaults.standard.double(forKey:"aimCameraPitch014"))
        table.aimPitch=TableScene.aimPitchRange.contains(savedPitch) ? savedPitch:TableScene.defaultAimPitch
        let configured=engine.settings
        spin.maximumOffset=(configured["experimental3D"]?.boolValue ?? false) ? 0.6:0.7
        table.selectCue(configured["cueType"]?.intValue ?? 0)
        table.cueElevation=(configured["experimental3D"]?.boolValue ?? false) ? (configured["cueElevationDegrees"]?.doubleValue ?? 0):0
        syncQuickRail()
        highGraphics=UserDefaults.standard.object(forKey:"highGraphics") as? Bool ?? true
        applyGraphics()
        table.camera.camera?.exposureOffset=CGFloat(UserDefaults.standard.object(forKey:"zokerExposure017") as? Double ?? -0.8)
        if ProcessInfo.processInfo.arguments.contains("--visual-qa") {
            let startupCameraMode=table.cameraMode
            loadShowcase()
            let args=ProcessInfo.processInfo.arguments
            if args.contains("--g1-default-qa") {
                precondition(startupCameraMode==2,"G1: startup must use Aim3D")
                table.cameraMode=2;recordG1QA("default",["cameraMode":startupCameraMode])
            }
            if args.contains("--g1-audio-qa") {
                DispatchQueue.main.asyncAfter(deadline:.now()+0.8){[weak self] in
                    guard let self=self else{return}
                    for kind in 0...3 {self.poolAudio.play(kind:kind,impact:1.2,pan:0)}
                    // Máy CI có thể không có thiết bị âm thanh; khi engine chạy được thì cả 4 loại tiếng phải được phát.
                    if self.poolAudio.isRunning {precondition(self.poolAudio.scheduled==4,"All four impact kinds must be scheduled")}
                    self.recordG1QA("audio",["engineRunning":self.poolAudio.isRunning,"scheduled":self.poolAudio.scheduled])
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

        stroke.sensitivity=UserDefaults.standard.double(forKey:"sensitivity");if stroke.sensitivity==0{stroke.sensitivity=1}
        spin.changed={[weak self]x,y in self?.side=x;self?.top=y;self?.guideDirty=true}
        if ProcessInfo.processInfo.arguments.contains("--cue-contact-qa") {spin.select(side:-0.5,top:0.49)}
        if ProcessInfo.processInfo.arguments.contains("--spin-detail") {
            spinWidth.constant=190;spinHeight.constant=190;spin.alpha=0.97
            spinExpanded=true;quickRail.isHidden=false
            spin.select(side:0.25,top:0.35)
        }
        stroke.shot={[weak self]v in self?.shoot(v)}
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
        spinWidth.constant=CGFloat(metrics.spinSize);spinHeight.constant=CGFloat(metrics.spinSize)
        quickRailBottom.constant = -CGFloat(metrics.railBottomInset)
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
        let controls:[UIView]=[spin,elevationPad,quickRail,menuButton,lockButton]
        let safe=view.safeAreaLayoutGuide.layoutFrame
        for (index,control) in controls.enumerated(){
            precondition(safe.contains(control.frame),"G1: control outside safe area")
            precondition(control.bounds.width>=44 && control.bounds.height>=44)
            for other in controls.dropFirst(index+1){precondition(!control.frame.intersects(other.frame),"G1: overlapping HUD controls")}
        }
        precondition(spin.frame.minX>elevationPad.frame.maxX)
        let interactive:[UIControl]=[spin,lockButton,quickCamera!,retryButton]
        for control in interactive{
            let point=control.convert(CGPoint(x:control.bounds.midX,y:control.bounds.midY),to:view)
            let hit=view.hitTest(point,with:nil)
            precondition(hit===control || hit?.isDescendant(of:control)==true,"G1: another view intercepts the HUD")
        }
        recordG1QA(spinExpanded ? "hud-expanded":"hud",["width":safe.width,"height":safe.height,"effectRightOfElevation":true,"controlsDoNotOverlap":true])
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
            self.view.layoutIfNeeded()
        }
        lockButton.heldChanged={[weak self] held in self?.setHold(held)}
        NSLayoutConstraint.activate([
            spin.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-12),
            spin.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-10),
            spinWidth,spinHeight,
            lockButton.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:12),
            lockButton.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12),
            lockButton.widthAnchor.constraint(equalToConstant:68),lockButton.heightAnchor.constraint(equalToConstant:68)])

        fineSlider.translatesAutoresizingMaskIntoConstraints=false
        fineSlider.minimumValue = -1;fineSlider.maximumValue=1;fineSlider.value=0
        fineSlider.tintColor=UIColor.white.withAlphaComponent(0.20);fineSlider.thumbTintColor=UIColor.white.withAlphaComponent(0.35)
        fineSlider.accessibilityLabel="Vi chỉnh góc ngắm"
        view.addSubview(fineSlider)
        NSLayoutConstraint.activate([fineSlider.centerXAnchor.constraint(equalTo:view.centerXAnchor),fineSlider.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-14),fineSlider.widthAnchor.constraint(equalToConstant:190),fineSlider.heightAnchor.constraint(equalToConstant:44)])
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
            menuButton.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-12),
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
        let brand=UILabel();text(brand,17,.white,.bold);brand.text="Zoker Pool Trainer · 0.13 candidate · Luyện tập";brand.textColor=MenuSkin.gold
        text(titleLabel,14,.white,.bold);text(statusLabel,12,.mint);text(scoreLabel,12,.white);text(hintLabel,12,.mint)
        for label in [titleLabel,statusLabel,scoreLabel,hintLabel]{label.numberOfLines=0}
        hintLabel.text="Giữ nút khóa bằng một ngón. Ngón khác kéo xuống rồi đẩy lên ở bất kỳ chỗ nào trên bàn. Buông khóa để ngắm lại."
        drillButton = .lab("Bài tập"){[weak self]in self?.chooseDrill()}
        layoutButton = .lab("Thế bi / Nhật ký"){[weak self]in self?.layouts()}
        settingsButton = .lab("Hiệu chỉnh vật lý"){[weak self]in self?.settings()}
        graphicsButton = .lab("Hình ảnh"){[weak self]in self?.graphics()}
        cameraButton = .lab("Ngắm cơ"){[weak self]in self?.cycleCamera()}
        guideButton = .lab("Dự báo: tắt"){[weak self]in
            guard let self=self else{return};self.guideOn.toggle();self.guideDirty=true
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
        let help=UIButton.lab("Cách điều khiển"){[weak self]in self?.help()}
        let trails=UIButton.lab("Vệt bi: bật / tắt"){[weak self]in
            guard let self=self else{return};self.trailsOn.toggle()
            self.table.trails(self.trailsOn ? self.paths:[:])
        }
        let felt=UIButton.lab("Màu nỉ bàn"){[weak self]in self?.chooseClothColor()}
        let sound=UIButton.lab("Âm thanh: bật / tắt"){[weak self]in
            let enabled = !(UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true)
            UserDefaults.standard.set(enabled,forKey:"poolAudioEnabled")
            self?.statusLabel.text=enabled ? "Âm thanh bi: bật":"Âm thanh bi: tắt"
        }
        let kick=UIButton.lab("Tìm góc kick · 1–3 băng"){[weak self]in self?.chooseKick()}
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
            row([drillButton,layoutButton]),guideButton,row([editButton,resetButton]),
            replayButton,testShotButton,row([center,trails]),
            row([graphicsButton,fine]),row([felt,sound]),equipment,kick,advanced,lessons,help,close])
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
        retryButton.configuration=retry;retryButton.translatesAutoresizingMaskIntoConstraints=false;retryButton.accessibilityLabel="Dừng và đánh lại cú vừa rồi";view.addSubview(retryButton)
        retryButton.addAction(UIAction{[weak self]_ in self?.undo()},for:.touchUpInside)
        panel.isHidden=true;table.cameraMode=2;table.showNumbers=false
    }
    private func setMenu(_ open:Bool){
        spin.collapse();lockButton.releaseHold();setHold(false)
        menuOpen=open;focusMode = !open;panel.isHidden = !open
        menuButton.setTitle(open ? "Đóng":"Menu",for:.normal)
        fineSlider.isHidden=open || !fineAim
        spin.isHidden=open;lockButton.isHidden=open
        quickRail.isHidden=open;elevationPad.isHidden=open
        updateControls()
    }
    private func buildQuickRail(){
        quickRail.axis = .horizontal;quickRail.spacing=5;quickRail.distribution = .fillEqually;quickRail.translatesAutoresizingMaskIntoConstraints=false
        quickRail.backgroundColor=UIColor(white:0.04,alpha:0.16);quickRail.layer.cornerRadius=16
        func button(_ symbol:String,_ name:String)->UIButton {
            let b=UIButton(type:.system);var c=UIButton.Configuration.plain();c.image=UIImage(systemName:symbol)
            c.title=name;c.imagePlacement = .top;c.imagePadding=2;c.baseForegroundColor=UIColor.white.withAlphaComponent(0.70)
            c.preferredSymbolConfigurationForImage=UIImage.SymbolConfiguration(pointSize:16,weight:.regular)
            c.contentInsets=NSDirectionalEdgeInsets(top:4,leading:2,bottom:4,trailing:2)
            c.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:9,weight:.medium);return a}
            b.configuration=c;b.showsMenuAsPrimaryAction=true;let height=b.heightAnchor.constraint(equalToConstant:48);height.priority = .defaultHigh;height.isActive=true
            quickRail.addArrangedSubview(b);return b
        }
        quickTools=button("slider.horizontal.3","Dụng cụ");quickTools.accessibilityLabel="Cơ, bao cơ và đặt bi"
        quickCamera=button("camera","Góc nhìn");quickCamera.accessibilityLabel="Chọn góc camera"
        // Retain the existing equipment menus inside one flyout, without
        // creating duplicate on-screen controls or removing their functions.
        quickRole=UIButton(type:.system);quickCue=UIButton(type:.system);quickBag=UIButton(type:.system)
        quickRail.addArrangedSubview(retryButton)
        retryButton.configuration?.title="Lùi";retryButton.configuration?.imagePlacement = .top
        retryButton.configuration?.imagePadding=2
        view.addSubview(quickRail);elevationPad.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(elevationPad)
        quickRailBottom=quickRail.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-140)
        NSLayoutConstraint.activate([
            quickRail.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-12),quickRail.widthAnchor.constraint(equalToConstant:154),quickRail.heightAnchor.constraint(equalToConstant:48),quickRailBottom,
            quickRail.topAnchor.constraint(greaterThanOrEqualTo:menuButton.bottomAnchor,constant:8),
            elevationPad.trailingAnchor.constraint(equalTo:spin.leadingAnchor,constant:-8),elevationPad.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12),elevationPad.widthAnchor.constraint(equalToConstant:44),elevationPad.heightAnchor.constraint(equalToConstant:120)])
        elevationPad.changed={[weak self] value in self?.setElevation(value)}
        syncQuickRail()
    }
    private func syncQuickRail(){
        guard quickRole != nil else{return}
        let role=engine.settings["cueType"]?.intValue ?? 0
        elevationPad.degrees=table.cueElevation
        quickRole.configuration?.title=CueLook.roles[max(0,min(2,role))]
        quickCue.configuration?.title=CueBag.cue(role).brand
        quickBag.configuration?.title="Bao cơ"
        quickCamera.menu=UIMenu(title:"Góc camera",children:["Toàn cảnh","Trên cao","Ngắm cơ"].enumerated().map{i,title in
            UIAction(title:title,state:table.cameraMode==i ? .on:.off){[weak self]_ in self?.selectCamera(i)}
        })
        quickCamera.menu=UIMenu(title:"Quan sát cú đánh",children:(quickCamera.menu?.children ?? [])+[
            UIAction(title:"Khôi phục toàn bàn",image:UIImage(systemName:"arrow.up.left.and.arrow.down.right")){[weak self]_ in self?.selectCamera(1)},
            UIAction(title:"Trở về góc ngắm đã lưu"){[weak self]_ in self?.restoreAimCamera()}
        ])
        quickRole.menu=UIMenu(title:"Loại cơ",children:CueLook.roles.enumerated().map{i,title in
            UIAction(title:title,state:role==i ? .on:.off){[weak self]_ in self?.chooseRole(i)}
        })
        quickCue.menu=UIMenu(title:"Bao "+CueBag.names[CueBag.active],children:(0...2).map{i in
            let cue=CueBag.cue(i)
            return UIAction(title:CueLook.roles[i]+" · "+cue.title,state:role==i ? .on:.off){[weak self]_ in self?.chooseRole(i)}
        })
        quickBag.menu=UIMenu(title:"Bao cơ",children:[quickCue.menu!,UIMenu(title:"Đổi bao",children:CueBag.names.enumerated().map{i,title in
            UIAction(title:title,state:CueBag.active==i ? .on:.off){[weak self]_ in CueBag.active=i;self?.chooseRole(role)}
        }),UIAction(title:"Mở thư viện bàn & cơ",image:UIImage(systemName:"square.grid.2x2")){[weak self]_ in self?.openLibrary()}])
        quickTools.menu=UIMenu(title:"Dụng cụ luyện tập",children:[quickRole.menu!,quickBag.menu!,
            UIAction(title:isPlacingBalls ? "Xong đặt bi":"Đặt bi",image:UIImage(systemName:"hand.draw")){[weak self]_ in self?.toggleEdit()},
            UIAction(title:"Thêm 1 bi mục tiêu",image:UIImage(systemName:"plus.circle")){[weak self]_ in self?.addBall()}])
    }
    private func setElevation(_ degrees:Double){
        guard !presentationBusy,localTurn,!locked else{return}
        var values=engine.settings;values["cueElevationDegrees"]=NSNumber(value:degrees);values["experimental3D"]=NSNumber(value:degrees>0)
        engine.settings=values;table.cueElevation=degrees
        spin.maximumOffset=degrees>0 ? 0.6:0.7
        UserDefaults.standard.set(engine.settings,forKey:"physics");guideDirty=true;syncQuickRail()
    }
    private func chooseRole(_ role:Int){
        guard !presentationBusy,localTurn else{return}
        var values=engine.settings;values["cueType"]=NSNumber(value:role);engine.settings=values
        table.selectCue(role);setElevation(role==1 ? 45:0);syncQuickRail()
    }
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
        for recognizer in aimRecognizers{recognizer.isEnabled = !locked}
        stroke.isUserInteractionEnabled=locked;stroke.isEnabled=locked
        menuButton.isHidden=locked
        fineSlider.isHidden=locked || menuOpen || !fineAim
        spin.isHidden=locked || menuOpen
        quickRail.isHidden=locked || menuOpen;elevationPad.isHidden=locked || menuOpen
        if !locked{stroke.cancelStroke();pull=0}
    }
    /// Trục của lần kéo một ngón hiện tại: 0 chưa quyết, 1 ngang (hướng ngắm), 2 dọc (độ cao camera).
    private var aimPanAxis=0
    private var presentationBusy:Bool{shotActive || replayIndex != nil || BLShotCameraBusy(shotCameraState)}
    private var strokeAllowed:Bool{
        BLStrokeAllowed(localTurn,presentationBusy,menuOpen,spinExpanded,isPlacingBalls,cue?.sunk==false)
    }
    private var balls:[BallState]{engine.states.map{BallState($0)}}
    private var cue:BallState?{balls.first{$0.id==0}}
    private func loadDrill(_ index:Int){
        guard !presentationBusy,localTurn else{return}
        drillIndex=index;attempts=0;successes=0;let drill=Drill.all[index]
        table.target(drill.goal)
        initial=drill.balls;before=initial;angle=drill.angle
        engine.loadLayout(initial.map{$0.dictionary});clearShot();locked=false;isPlacingBalls=false;spin.reset()
        titleLabel.text=drill.title;hintLabel.text="Giữ nút khóa; ngón khác kéo xuống rồi đẩy lên trên bàn. Buông nút để ngắm lại."
        statusLabel.text="Trắng: bi cái · Vàng: bi 1";updateControls();refresh()
    }
    private func clearShot(){
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
        spin.isEnabled = !busy && localTurn;editButton.configuration?.title=isPlacingBalls ? "Xong đặt bi":"Đặt bi"
        for b in [drillButton,layoutButton,settingsButton,editButton] {b?.isEnabled = !busy && localTurn}
        replayButton.isEnabled = !shotActive && !frames.isEmpty && localTurn
        replayButton.configuration?.title=replayIndex == nil ? "Xem lại":"Dừng xem"
        undoButton.isEnabled = !before.isEmpty && localTurn
        retryButton.isEnabled = !before.isEmpty && !isPlacingBalls && localTurn && !spinExpanded
    }
    private func nudge(_ amount:Double){guard !locked,!isPlacingBalls,!shotActive,replayIndex==nil else{return};angle+=amount;refresh()}
    private func selectCamera(_ mode:Int){
        guard (0...2).contains(mode) else{return}
        table.cameraMode=mode;table.zoom=1;table.orbit=0;table.orbitPitch=0.57
        beginCameraTransition(0.35);cameraButton.configuration?.title=["Toàn bàn","Trên cao","Ngắm cơ"][mode];syncQuickRail()
    }
    private func beginCameraTransition(_ duration:Double){cameraTransitionDuration=duration;cameraTransition=duration}
    private func restoreAimCamera(){
        guard localTurn,replayIndex==nil else{return}
        let saved=savedAimCamera ?? (mode:2,zoom:Float(1),orbit:Float(0),pitch:Float(0.57))
        table.cameraMode=2;table.zoom=saved.zoom;table.orbit=saved.orbit;table.orbitPitch=saved.pitch
        observationCamera=false;beginCameraTransition(0.45);cameraButton.configuration?.title="Ngắm cơ";syncQuickRail()
    }
    private func cycleCamera(){
        let sheet=UIAlertController(title:"Góc nhìn",message:nil,preferredStyle:.actionSheet)
        for (index,title) in ["Toàn bàn · xem chân bàn","Trên cao · luyện thế bi","Ngắm cơ · sát bi"].enumerated(){
            sheet.addAction(UIAlertAction(title:title,style:.default){[weak self]_ in
                self?.selectCamera(index)
                self?.cameraButton.configuration?.title=["Toàn bàn","Trên cao","Ngắm cơ"][index]
                self?.setMenu(false);self?.syncQuickRail()
            })
        }
        sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(sheet,source:cameraButton)
    }
    private func toggleEdit(){
        guard !presentationBusy,localTurn else{return};isPlacingBalls.toggle();locked=false
        if isPlacingBalls {table.cameraMode=1;cameraButton.configuration?.title="Trên cao";hintLabel.text="Kéo từng bi để đặt · Chạm trống để đặt bi cái"}
        else{hintLabel.text="Giữ nút khóa; ngón khác kéo xuống rồi đẩy lên trên bàn. Buông nút để ngắm lại.";initial=balls;before=balls;clearShot();selectCamera(2)}
        updateControls();syncQuickRail()
    }
    private func shoot(_ speed:Double){
        guard locked,strokeAllowed,speed.isFinite,speed>0 else{return}
        lastShotSpeed=speed
        displayDurations=[]
        let levels=[0.8,1.3,2.0,3.0,4.3,6.0,8.0]
        let band=min(7,(levels.firstIndex(where:{speed<=$0}) ?? 6)+1)
        hintLabel.text=String(format:"Lực liên tục · mức %d/7 · %.2f m/s · %@",band,speed,(engine.settings["experimental3D"]?.boolValue ?? false) ? "tốc độ cơ thử nghiệm":"tốc độ bi đầu")
        shotCameraAnchor=cue
        if table.cameraMode==2 {savedAimCamera=(2,table.zoom,table.orbit,table.orbitPitch)}
        BLShotCameraStart(&shotCameraState)
        // Mặc định giữ góc ngắm vừa đánh (camera neo ở vị trí bi cái trước cú); chỉ chuyển toàn cảnh khi người dùng bật.
        if UserDefaults.standard.bool(forKey:"overviewAfterShot014") {
            observationCamera=true;table.cameraMode=0;table.zoom=1;table.orbitPitch=0.72;beginCameraTransition(0.45)
        }
        before=balls;frames=[before];frameTimes=[0];paths=[:];sampleClock=0;lastEventCount=0
        engine.strike(angle:table.shotAngle(cue,angle:angle,side:side,top:top),speed:speed,side:side,top:top)
        if UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true {poolAudio.play(kind:3,impact:speed,pan:cue?.x ?? 0)}
        shotActive=true;attempts+=1;statusLabel.text=String(format:"Đang chạy · tốc độ đầu %.2f m/s",speed)
        feedback.impactOccurred();guideDirty=true;table.trails([:]);setMenu(false);updateControls()
    }
    @objc private func tick(_ link:CADisplayLink){
        let dt=lastTime==0 ? 0:min(0.1,max(0,link.timestamp-lastTime));lastTime=link.timestamp
        let wasSimulating=shotActive,wasReplaying=replayIndex != nil
        if let index=replayIndex {
            replayClock+=dt
            var i=index
            while i+1<frames.count && replayClock>=frameTimes[i+1] {i+=1}
            if replayClock>=(frameTimes.last ?? 0)+0.25 {replayIndex=nil;table.update(balls,dt:0);statusLabel.text="Xem lại xong";updateControls()}
            else{
                replayIndex=i
                let j=min(i+1,frames.count-1)
                let span=frameTimes[j]-frameTimes[i]
                table.replay(frames[i],to:frames[j],fraction:span>0 ? (replayClock-frameTimes[i])/span:0)
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
                    for event in fresh {poolAudio.play(kind:event["kind"]?.intValue ?? 1,impact:event["impact"]?.doubleValue ?? 0.3,pan:event["x"]?.doubleValue ?? 0)}
                }
                lastEventCount=events.count
            }
            if !engine.moving||engine.elapsed>60 {finishShot(timedOut:engine.moving)}
        }
        table.animatePockets(dt)
        let wasBusy=BLShotCameraBusy(shotCameraState)
        let cameraGestureActive=aimRecognizers.contains{recognizer in
            (recognizer is UIPinchGestureRecognizer || (recognizer as? UIPanGestureRecognizer)?.minimumNumberOfTouches==2) &&
            (recognizer.state == .began || recognizer.state == .changed)
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
        if replayIndex != nil {cameraCue=frames.first?.first(where:{$0.id==0})}
        let blend=BLCameraTweenBlend(cameraTransition,dt,cameraTransitionDuration)
        table.placeCamera(cue:cameraCue,angle:angle,aspect:scn.bounds.width/max(1,scn.bounds.height),blend:Float(blend))
        cameraTransition=max(0,cameraTransition-dt)
        if ProcessInfo.processInfo.arguments.contains("--visual-qa"){scn.accessibilityValue=String(format:"angle=%.6f;mode=%d;moving=%d;pitch=%.4f",angle,table.cameraMode,shotActive ? 1:0,table.aimPitch)}
        table.showCue(displayCue,angle:angle,visible:!presentationBusy && localTurn && !isPlacingBalls,pull:pull,side:side,top:top)
        let show=guideOn && !presentationBusy && localTurn && !isPlacingBalls
        if !show && lastGuideVisible {
            table.prediction([],visible:false);lastGuideVisible=false
        }
        let changed=guideDirty || abs(angle-lastGuideAngle)>0.00001 || !lastGuideVisible
        if show && changed && link.timestamp-lastPredictionTime>=0.18 {
            let samples=engine.prediction(angle:table.shotAngle(cue,angle:angle,side:side,top:top),speed:testSpeed,side:side,top:top)
            table.prediction(samples,visible:true)
            lastGuideAngle=angle;lastGuideVisible=true;guideDirty=false;lastPredictionTime=link.timestamp
            if !focusMode {scoreLabel.text=String(format:"%d/%d đạt · Dự báo %.1f m/s",successes,attempts,testSpeed)}
        }
    }
    private func finishShot(timedOut:Bool){
        let d=Drill.all[drillIndex],events=engine.events
        frames.append(balls);frameTimes.append(engine.elapsed)
        if timedOut {let stopped=balls;engine.loadLayout(stopped.map{$0.dictionary})}
        shotActive=false;locked=false;table.trails(trailsOn ? paths:[:])
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
                if e["kind"]?.intValue==1 && (e["a"]?.intValue==0||e["b"]?.intValue==0) {
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
        hintLabel.text="Trắng: bi cái · Cam: bi mục tiêu · Lùi cú để thử lại cùng thế bi"
        refresh();updateControls()
    }
    private func undo(){guard localTurn,!before.isEmpty,!isPlacingBalls else{return};lockButton.releaseHold();setHold(false);engine.loadLayout(before.map{$0.dictionary});clearShot();locked=false;statusLabel.text="Đã trở về trước cú đánh";refresh();updateControls()}
    private func reset(){
        guard localTurn else{return}
        if shotActive {shotActive=false}
        replayIndex=nil;engine.loadLayout(initial.map{$0.dictionary});before=initial;clearShot();locked=false;isPlacingBalls=false
        statusLabel.text="Đã khôi phục thế bi bài tập";refresh();updateControls()
    }
    private func replay(){
        guard localTurn,!shotActive,!frames.isEmpty else{return}
        lockButton.releaseHold();setHold(false);cameraTransition=0
        if replayIndex != nil {replayIndex=nil;table.update(balls,dt:0)}else{replayIndex=0;replayClock=0;statusLabel.text="Xem lại theo thời gian cú đánh"}
        guideDirty=true;updateControls()
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
        return localTurn && !presentationBusy
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
        guard localTurn,!presentationBusy,!menuOpen,!spinExpanded,!locked else{return}
        if isPlacingBalls {
            guard let p=tablePoint(g.location(in:scn)) else{return}
            if g.state == .began {
                draggedBall=balls.filter{!$0.sunk}.min{hypot($0.x-p.x,$0.y-p.y)<hypot($1.x-p.x,$1.y-p.y)}.flatMap{hypot($0.x-p.x,$0.y-p.y)<0.12 ? $0.id:nil}
            }
            if let id=draggedBall {moveBall(id,to:p)}
            if g.state == .ended||g.state == .cancelled {draggedBall=nil}
        }else{
            guard g.numberOfTouches<=1 else{return}
            // Một ngón: ngang = xoay hướng đánh; dọc = hạ/nâng camera ngắm (sát mặt bàn → nhìn từ trên).
            // Khoá trục theo mỗi lần kéo: chưa áp dụng gì cho tới khi đi đủ 6 pt, rồi chọn trục trội.
            // Rung tay dọc không làm lệch hướng ngắm và ngược lại; cú nhích ngắn < 6 pt vẫn tính là xoay ngang.
            if g.state == .began {aimPanAxis=0}
            let delta=g.translation(in:scn)
            let aimCamera=table.cameraMode==2 && !observationCamera && replayIndex==nil
            let finishing=g.state == .ended||g.state == .cancelled
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
        if table.cameraMode==2 {
            if !observationCamera{savedAimCamera=(2,table.zoom,table.orbit,table.orbitPitch)}
            table.cameraMode=0;table.zoom=1
        }
        table.orbit+=Float(delta.x)*0.006;table.orbitPitch=max(0.20,min(1.40,table.orbitPitch+Float(delta.y)*0.004))
        cameraTransition=0;g.setTranslation(.zero,in:scn)
    }
    @objc private func pinchTable(_ g:UIPinchGestureRecognizer){
        guard !menuOpen,!spinExpanded,!locked else{return}
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
        state[i].x=x;state[i].y=y;state[i].sunk=false;engine.loadLayout(state.map{$0.dictionary});refresh()
    }
    private func presentSheet(_ sheet:UIAlertController,source:UIView?=nil){
        sheet.popoverPresentationController?.sourceView=source ?? view
        sheet.popoverPresentationController?.sourceRect=source?.bounds ?? CGRect(x:view.bounds.midX,y:view.bounds.midY,width:1,height:1)
        present(sheet,animated:true)
    }
    private func chooseDrill(){
        guard !shotActive,replayIndex==nil else{return}
        let vc=DrillsController(style:.insetGrouped)
        vc.load={[weak self]index in self?.loadDrill(index)}
        present(UINavigationController(rootViewController:vc),animated:true)
    }
    private func chooseKick(){
        guard !shotActive,replayIndex==nil,!engine.moving,!isPlacingBalls,cue?.sunk==false else{return}
        let sheet=UIAlertController(title:"Chọn bi đích",message:"Giữ lực Đánh thử và ép phê hiện tại. Tìm trong bộ mô phỏng; chưa hiệu chuẩn bàn thật.",preferredStyle:.actionSheet)
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
        let layout=engine.states,settings=engine.settings,speed=testSpeed,x=side,y=top
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
                    let message=hit ? String(format:"Đã tìm góc trong mô phỏng: %d băng → bi %d, %.1f m/s.\nX %+.0f / Y %+.0f %% bán kính.\n\nDùng Đánh thử để kiểm tra. Kết quả phụ thuộc thông số bàn; chưa xác nhận độ chính xác ngoài thực tế.",rails,target,speed,x*100,y*100):"Chưa tìm được góc ở lực và ép phê hiện tại trong phạm vi tìm kiếm. Thử đổi lực hoặc điểm chạm; điều này không chứng minh cú đánh bất khả thi."
                    let alert=UIAlertController(title:hit ? "Đã cập nhật góc ngắm":"Chưa tìm được lời giải",message:message,preferredStyle:.alert)
                    alert.addAction(UIAlertAction(title:"Đã hiểu",style:.default));self.presentSheet(alert)
                }
            }
        }
    }
    private func help(){
        let message="Ngắm: kéo một ngón ngang để xoay hướng đánh, hoặc chạm mặt bàn. Kéo một ngón dọc để hạ camera sát mặt bàn hoặc nâng lên cao; mỗi lần kéo chỉ đổi một việc. Chụm/mở hai ngón để thu phóng từ góc đó.\n\nĐánh: giữ nút khóa trong suốt cú vuốt. Ngón khác kéo xuống rồi đẩy lên ở bất kỳ vùng trống nào trên bàn; đẩy nhanh hơn cho lực lớn hơn. Buông nút khóa để ngắm lại. Hủy vuốt khi buông khóa trước lúc đánh.\n\nGiữ quả bi effect bên phải thanh nâng cơ để phóng to, kéo để chỉnh ép phê; buông để thu nhỏ. Khi effect mở rộng, nút B và vuốt cơ bị khóa. Vòng 25 / 50 là phần trăm bán kính bi; vòng cam là giới hạn nhập của mô phỏng, không phải bảo đảm tránh trượt cơ ngoài thực tế. X dương sang phải, Y dương lên trên, nhìn từ đuôi cơ. Về tâm trong Menu. Cụm phải có Góc nhìn, Lùi cú và Dụng cụ (cơ, bao cơ, đặt bi, thêm 1 bi). Bài tập chỉ nằm trong Menu. Sau cú đánh camera giữ nguyên góc ngắm (đổi sang toàn cảnh trong Menu > Sau cú đánh). Khi toàn bộ bi dừng ổn định 0,5 giây, camera trở về góc ngắm 3D; khi xem lại hoặc quan sát lượt khác, camera không bị ép trả. Mặt bàn không có chữ hay số nút; nút kim cương vẫn giữ nguyên. Trong lúc bi lăn, kéo hai ngón để xoay camera và chụm/mở để thu phóng toàn cảnh.\n\nTrên Simulator không thể giữ hai điểm bằng một chuột: dùng Đánh thử trong Menu để kiểm tra.\n\n\(Drill.all[drillIndex].note)"
        let a=UIAlertController(title:"Zoker Pool Trainer",message:message,preferredStyle:.alert);a.addAction(UIAlertAction(title:"Đã hiểu",style:.default));presentSheet(a)
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
    private func addBall(){
        guard localTurn,!presentationBusy,!locked else{return}
        var state=balls;guard let id=(1...15).first(where:{id in !state.contains{$0.id==id}})else{return}
        for row in 0..<8 {for col in 0..<5 {
            let x = -0.4+Double(col)*0.2,y = -0.9+Double(row)*0.25
            if !state.contains(where:{!$0.sunk && hypot($0.x-x,$0.y-y)<0.065}) {
                state.append(BallState(id:id,x:x,y:y));engine.loadLayout(state.map{$0.dictionary});clearShot();initial=balls;before=balls;if !isPlacingBalls{toggleEdit()};refresh();updateControls();return
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
        let overviewOn=UserDefaults.standard.bool(forKey:"overviewAfterShot014")
        a.addAction(UIAlertAction(title:overviewOn ? "✓ Sau cú đánh: chuyển toàn cảnh":"Sau cú đánh: giữ góc ngắm",style:.default){_ in
            UserDefaults.standard.set(!overviewOn,forKey:"overviewAfterShot014")
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

/// Original synthesized pool impacts; no third-party recording is bundled.
/// 0.15: AVAudioEngine + bộ đệm PCM nạp sẵn + 12 voice cố định (không tạo AVAudioPlayer mỗi va chạm).
/// Phiên âm thanh .playback + mixWithOthers: vẫn có tiếng khi iPhone gạt im lặng (bản cũ .ambient bị câm).
final class PoolAudio {
    private let engine=AVAudioEngine()
    private let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)!
    private var nodes=[AVAudioPlayerNode]()
    private var next=0
    private var buffers=[Int:AVAudioPCMBuffer]()
    private(set) var scheduled=0
    private(set) var started=false
    init(){
        let session=AVAudioSession.sharedInstance()
        try? session.setCategory(.playback,mode:.default,options:[.mixWithOthers])
        try? session.setActive(true)
        for _ in 0..<12 {
            let node=AVAudioPlayerNode();engine.attach(node)
            engine.connect(node,to:engine.mainMixerNode,format:format);nodes.append(node)
        }
        for kind in 0...3 {for level in 1...8 {buffers[kind*8+level]=Self.buffer(Self.synthesize(kind:kind,impact:Double(level)*0.4),format:format)}}
        engine.prepare();start()
        NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main){[weak self] note in
            let raw=note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if raw==AVAudioSession.InterruptionType.ended.rawValue {self?.start()}
        }
        NotificationCenter.default.addObserver(forName:.AVAudioEngineConfigurationChange,object:engine,queue:.main){[weak self] _ in self?.start()}
        NotificationCenter.default.addObserver(forName:UIApplication.didBecomeActiveNotification,object:nil,queue:.main){[weak self] _ in self?.start()}
    }
    private func start(){
        if engine.isRunning {started=true;return}
        do {try AVAudioSession.sharedInstance().setActive(true);try engine.start();started=true}
        catch {started=false;NSLog("PoolAudio: engine start failed %@",String(describing:error))}
    }
    var isRunning:Bool{engine.isRunning}
    /// kind: 0 băng, 1 bi–bi, 2 rơi lỗ, 3 đầu cơ chạm bi.
    func play(kind:Int,impact:Double,pan:Double){
        if !engine.isRunning {start()}
        guard engine.isRunning else{return}
        let level=max(1,min(8,Int(ceil(max(0,impact)/0.4))))
        let type=max(0,min(3,kind))
        guard let buffer=buffers[type*8+level] else{return}
        let node=nodes[next];next=(next+1)%nodes.count
        node.stop()
        node.pan=Float(max(-1,min(1,pan/0.72)))
        node.volume=Float(type==2 ? 0.95:(type==3 ? 0.85:0.75))
        node.scheduleBuffer(buffer,at:nil,options:[],completionHandler:nil)
        node.play();scheduled+=1
    }
    private static func buffer(_ wav:Data,format:AVAudioFormat)->AVAudioPCMBuffer{
        // WAV 16-bit mono 44,1 kHz; dữ liệu PCM bắt đầu sau header 44 byte.
        let pcm=wav.dropFirst(44),frames=pcm.count/2
        let out=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(frames))!
        out.frameLength=AVAudioFrameCount(frames)
        let channel=out.floatChannelData![0]
        pcm.withUnsafeBytes{raw in
            for i in 0..<frames {channel[i]=Float(Int16(littleEndian:raw.loadUnaligned(fromByteOffset:i*2,as:Int16.self)))/32768}
        }
        return out
    }
    static func synthesize(kind:Int,impact:Double)->Data{
        let count=kind==2 ? 15000:(kind==0 ? 10500:8500)
        let force=min(1,max(0.12,impact/3.2)),decay=kind==2 ? 22.0:(kind==0 ? 31.0:38.0)
        let mode:Double=kind==2 ? 510:(kind==0 ? 930:(kind==3 ? 1280:1650))
        var pcm=Data();pcm.reserveCapacity(count*2)
        var seed=UInt32(0x7a09e667 ^ UInt32(truncatingIfNeeded:Int(impact*10000)))
        for i in 0..<count{
            seed=1664525 &* seed &+ 1013904223
            let noise=Double(Int32(bitPattern:seed))/Double(Int32.max),t=Double(i)/44100
            let env=exp(-decay*t),ring=sin(2*Double.pi*mode*t)*exp(-55*t)
            let secondary=sin(2*Double.pi*(mode*1.91)*t)*exp(-78*t)
            let rattle=(kind==0 || kind==2) ? sin(2*Double.pi*(mode*2.7)*t)*exp(-18*t)*0.18:0
            let sample=max(-1,min(1,force*(noise*0.22*env+ring*0.52+secondary*0.23+rattle)*0.78))
            let value=Int16(sample*32767);var little=value.littleEndian
            withUnsafeBytes(of:&little){pcm.append(contentsOf:$0)}
        }
        var wav=Data("RIFF".utf8)
        func u16(_ value:UInt16){var v=value.littleEndian;withUnsafeBytes(of:&v){wav.append(contentsOf:$0)}}
        func u32(_ value:UInt32){var v=value.littleEndian;withUnsafeBytes(of:&v){wav.append(contentsOf:$0)}}
        u32(UInt32(36+pcm.count));wav.append(contentsOf:"WAVEfmt ".utf8);u32(16);u16(1);u16(1);u32(44100);u32(88200);u16(2);u16(16)
        wav.append(contentsOf:"data".utf8);u32(UInt32(pcm.count));wav.append(pcm)
        return wav
    }
}
