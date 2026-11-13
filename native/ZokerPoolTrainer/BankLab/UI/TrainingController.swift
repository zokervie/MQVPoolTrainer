import UIKit
import GameKit
import SceneKit
import simd
import AVFoundation

/// 0.30 QA only: passive record of which view each touch lands on (never receives, never cancels).
final class QATouchProbe:NSObject,UIGestureRecognizerDelegate {
    var record:((String)->Void)?
    func gestureRecognizer(_ g:UIGestureRecognizer,shouldReceive touch:UITouch)->Bool{
        let v=touch.view,p=touch.location(in:nil)
        record?((v.map{String(describing:type(of:$0))+"#"+($0.accessibilityIdentifier ?? "")} ?? "nil")+String(format:"@%.0f,%.0f",p.x,p.y))
        return false
    }
}

final class TrainingController:UIViewController,UIGestureRecognizerDelegate {
    let engine=BLWorld()
    var table:TableScene!
    var scn:SCNView!
    var displayLink:CADisplayLink?
    var lastTime:TimeInterval=0
    var angle=Double.pi/2,side=0.0,top=0.0,pull=0.0
    var locked=false,isPlacingBalls=false,guideOn=false,shotActive=false
    var drillIndex=Drill.startup,attempts=0,successes=0
    /// 0.35: lượt bài tập 5 cú (chỉ khi mở từ menu Bài tập).
    var lessonActive=false,lessonScores:[Int]=[],lessonPasses=0
    var before:[BallState]=[],initial:[BallState]=[]
    var shotCameraAnchor:BallState?
    var savedAimCamera:CameraPose?
    var observationCamera=false
    var cameraTransition=0.0
    var cameraTransitionDuration=0.45
    var shotCameraState=BLShotCameraState()
    var localTurn=true // Offline by default; future networking owns this value.
    var qaAwaitingAimReturn=false,qaPeekReleased=false
    var qaExpectedCameraAngle=0.0
    var frames:[[BallState]]=[],frameTimes:[Double]=[],replayIndex:Int?,replayClock=0.0
    var aimBuffer:[ReplayAimSample]=[],lastPreparation:[ReplayAimSample]=[]
    var replayPreparation:ReplayAimSample?
    var replayRenderedCueType:Int?
    var replayEquipment:(Int,Double)?
    var replayStrikePlayed=false
    var preparationDuration:Double{lastPreparation.last?.time ?? 0}
    /// 0.37 (owner): replay starts 1.5 s before the strike and ends 1.5 s after the balls stop.
    var replayLead:Double{min(1.0,preparationDuration)}   // 0.41 (owner): 1 s before the cue meets the ball
    static let replayTail=1.0   // 0.41 (owner): 1 s after the last ball stops
    func capturePreparation(time:Double){
        guard localTurn,!presentationBusy,!menuOpen,!isPlacingBalls,cue?.sunk==false else{aimBuffer.removeAll();return}
        if let last=aimBuffer.last {
            if time-last.time>0.5{aimBuffer.removeAll()}
            else if time-last.time<1.0/30.0{return}
        }
        let sample=ReplayAimSample(time:time,angle:angle,side:side,top:top,pull:pull,mode:table.cameraMode,zoom:table.zoom,orbit:table.orbit,pitch:table.orbitPitch,aimPitch:table.aimPitch,cameraYaw:aimCameraYaw,elevation:table.cueElevation,cueType:engine.settings["cueType"]?.intValue ?? 0)
        guard sample.isValid else{return}
        aimBuffer.append(sample);aimBuffer.removeAll{time-$0.time>8}
        if aimBuffer.count>241{aimBuffer.removeFirst(aimBuffer.count-241)}
    }
    var paths:[Int:[SIMD3<Float>]]=[:]
    var sampleClock=0.0,draggedBall:Int?
    var displayDurations:[Double]=[]
    /// 0.39c AUTOPSY: main-thread CPU time per live-shot frame, split by stage (seconds), plus how many times UIKit
    /// laid the HUD out while balls were rolling. Evidence for the owner's device, not a guess from the simulator.
    struct ShotProfile {
        var physics:[Double]=[],record:[Double]=[],events:[Double]=[],scene:[Double]=[],tick:[Double]=[]
        var layoutPasses=0,hudRelayouts=0,recordedSamples=0
    }
    var shotProfile=ShotProfile()
    var hudLayoutKey="",hudLayoutDeferred=false
    var appliedClothTint = -2
    var qaShots=0,qaJumpSeen=false   // UI-test latches: polling every 0.5 s can miss a short shot
    var shotTickStart:Double?
    /// A/B switches for the same build (Chẩn đoán độ mượt): bring back the 0.39 behaviours to prove or refute a cause.
    static var legacyStatusAB:Bool{UserDefaults.standard.bool(forKey:"diagLegacyStatus039")}
    static var replayNoSlowAB:Bool{UserDefaults.standard.bool(forKey:"diagReplayNoSlow039")}
    var lastEventCount=0
    let titleLabel=UILabel(),statusLabel=UILabel(),scoreLabel=UILabel(),hintLabel=UILabel()
    let spinCenter=UIButton(type:.system)
    let spin=SpinPad(frame:.zero),stroke=StrokePad(frame:.zero)
    let powerFX=PowerFX(frame:.zero)   // 0.41 thang lực 7 màu + vệt vuốt
    var testShotButton:UIButton!
    var lastPassed=false,lastScratch=false
    var lastShotSpeed=0.0
    var testSpeed=2.0
    var highGraphics=false
    var missWindow=0.0,missCount=0,cleanSeconds=0.0
    /// Pass rate of the last 20 graded drill shots (0…1) — drives the skill fade of the guide.
    var recentPassRate:Double{
        if let c=passRateCache,Date().timeIntervalSince(c.1)<5{return c.0}
        let r=practiceRecords().suffix(20);let v=r.isEmpty ? 0:Double(r.filter{$0.passed}.count)/Double(r.count)
        passRateCache=(v,Date());return v
    }
    var passRateCache:(Double,Date)?=nil
    /// True when the straight aim line from the cue ball reaches a cushion before any ball.
    func aimHitsRail()->Bool{
        guard let c=cue,!c.sunk else{return false}
        let R=geometry.radius,d=SIMD2<Double>(cos(angle),sin(angle)),p=SIMD2<Double>(c.x,c.y)
        let hx=geometry.width/2-R,hy=geometry.length/2-R
        var wall=Double.infinity
        if d.x>1e-9{wall=min(wall,(hx-p.x)/d.x)}else if d.x < -1e-9{wall=min(wall,(-hx-p.x)/d.x)}
        if d.y>1e-9{wall=min(wall,(hy-p.y)/d.y)}else if d.y < -1e-9{wall=min(wall,(-hy-p.y)/d.y)}
        for b in balls where b.id != 0 && !b.sunk {
            let m=p-SIMD2<Double>(b.x,b.y),bq=simd_dot(m,d),cc=simd_dot(m,m)-4*R*R,disc=bq*bq-cc
            if disc>=0 && -bq-disc.squareRoot()>0 && -bq-disc.squareRoot()<wall{return false}
        }
        return wall.isFinite
    }
    /// 0.39: the first object ball on the straight aim line (cue fade keeps it visible), nil when a cushion comes first.
    func aimTargetBall()->SIMD2<Float>?{
        guard let c=cue,!c.sunk else{return nil}
        let R=geometry.radius,d=SIMD2<Double>(cos(angle),sin(angle)),p=SIMD2<Double>(c.x,c.y)
        var best=Double.infinity,hit:SIMD2<Float>?
        for b in balls where b.id != 0 && !b.sunk {
            let m=p-SIMD2<Double>(b.x,b.y),bq=simd_dot(m,d),cc=simd_dot(m,m)-4*R*R,disc=bq*bq-cc
            if disc>=0 {let t = -bq-disc.squareRoot();if t>0 && t<best{best=t;hit=SIMD2<Float>(Float(b.x),Float(b.y))}}
        }
        return hit
    }
    var hudFaded=false
    var lastTurnCheck:Double=0
    var pendingLevelCheck=false,pendingThermal=false,shadersPrewarmed=false
    var forcedElevationRestore:[String:NSNumber]?
    var highlightRecorder:HighlightRecorder?
    var consistencyKey="",consistencyStops:[SIMD2<Double>]=[]
    func applyHUDFade(){
        let a:CGFloat=hudFaded ? 0.22:CGFloat(Tuning.hudAlpha)
        UIView.animate(withDuration:hudFaded ? 0.18:0.25,delay:0,options:[.beginFromCurrentState,.allowUserInteraction]){
            for v in self.cueIcons{v.alpha=a}
            for v in [self.quickScroll,self.lockButton,self.elevationPad,self.menuButton,self.coachButton] as [UIView]{v.alpha=a}
            self.spin.alpha=self.hudFaded ? 0.25:(self.spinExpanded ? 0.97:0.60*CGFloat(Tuning.hudAlpha))
        }
    }
    var focusMode=true
    var menuOpen=false
    var trailsOn=false
    var spinWidth:NSLayoutConstraint!,spinHeight:NSLayoutConstraint!
    var quickRailBottom:NSLayoutConstraint!
    let menuButton=UIButton(type:.system)
    let fineWheel=FineAimWheel(frame:.zero)
    var fineAim=false
    let retryButton=UIButton(type:.system)
    var fineStartAngle=0.0
    var aimRecognizers:[UIGestureRecognizer]=[]
    var graphicsButton:UIButton!
    let lockButton=HoldLockControl(frame:.zero)
    let statusToast=UILabel()
    let coachButton=UIButton(type:.system)
    var coaching=false
    var qaCoachDown=0,qaCoachUp=0   // 0.29 QA probe: touches that actually reach the Coach button
    var qaLastTouch="none";let qaTouchProbe=QATouchProbe()
    let qaReplayHold=ProcessInfo.processInfo.arguments.contains("--replay-hold-qa")
    var guidedCoachBefore:Bool?
    var shotKind=0 {didSet{spin.maxTop=shotKind==1 ? 0:1}} // Stable legacy IDs: 0 playing, 1 jump, 2 break; 3 massé preset.
    var quickPlace:UIButton!,quickAdd:UIButton!
    let replayBar=UIStackView(),replaySlider=UISlider(),replayPause=UIButton(type:.system),replayRate=UIButton(type:.system),replayAutoButton=UIButton(type:.system)
    var replayPaused=false,replaySpeed=1.0,replayAuto=true,replayAudioIndex=0
    var lastShotEvents:[[String:NSNumber]]=[]
    struct CameraPose {var mode:Int;var zoom:Float;var yaw:Float;var pitch:Float;var aimPitch:Float;var focus:SIMD4<Float>?=nil}
    var cameraMemory:[Int:CameraPose]=[:]
    var peekPose:CameraPose?,replayOrigin:CameraPose?,editingPose:CameraPose?
    var editingSnapshot:[BallState]?
    var cameraManual=false,lastDirectorTime = -10.0
    var eyePressDuringShot=false
    var eyeHoldWork:DispatchWorkItem?
    var frameLayoutAdopted=false
    var replayBarRight:[NSLayoutConstraint]=[],replayBarLeft:[NSLayoutConstraint]=[]
    var matchCallPicking=0,matchCallBall=0,matchCallPose:CameraPose?
    // 0.25: practice history (step back / forward per shot or whole session) and session highlights.
    /// 0.30: each step keeps the layout AND the setup used for the shot taken from it (gậy, độ dốc, effect, hướng).
    struct ShotSetup{var angle:Double,side:Double,top:Double,kind:Int,elevation:Double}
    struct ShotStep{var balls:[BallState];var setup:ShotSetup?}
    var shotBack:[ShotStep]=[],shotForward:[ShotStep]=[]
    /// 0.30: Đánh / Jump / Massé / Break above the effect ball (BLHUDCueIcon, BLCueIconKind).
    var cueIcons:[UIButton]=[]
    /// 0.33: "Nút số" (diamond numbers, always offered) and "Chỉ dẫn" (aim/guide lines, shown when Coach is on),
    /// next to Coach. Replay camera: 0 điện ảnh tự động, 1 người đánh 3D, 2 toàn bàn, 3 trên cao.
    let numbersButton=UIButton(type:.system),guideToggle=UIButton(type:.system),cardToggle=UIButton(type:.system)
    /// 0.35: Chỉ dẫn has two modes — 1 to the aim point (cue path to first contact), 2 the whole run. Bảng shows/hides the coach card.
    var guideMode=UserDefaults.standard.integer(forKey:"guideMode035")==1 ? 1:2,cardOn=true
    var numbersOn=UserDefaults.standard.object(forKey:"numbersOn033") as? Bool ?? true
    var replayCamera=UserDefaults.standard.integer(forKey:"replayCamera041")
    /// 0.41 Action camera state: current cut, smoothed travel directions, crane yaw.
    var actionShot = -1,actionDirections:[Int:SIMD2<Float>]=[:],actionCraneYaw:Float=0
    func currentSetup()->ShotSetup{ShotSetup(angle:angle,side:side,top:top,kind:shotKind,elevation:table.cueElevation)}
    var sessionShots:[(shot:SavedShot,score:Int,label:String)]=[]
    var autoSaveEveryShot:Bool{UserDefaults.standard.bool(forKey:"autoSaveEveryShot025")}
    let quickCall=UIButton(type:.system)
    var leftHanded:Bool{UserDefaults.standard.bool(forKey:"leftHanded022")}
    var lastObservedMode=0
    var referenceSpeed:Double{lastShotSpeed>0 ? lastShotSpeed:testSpeed}
    var cameraButton:UIButton!,guideButton:UIButton!,editButton:UIButton!
    var replayButton:UIButton!,undoButton:UIButton!,resetButton:UIButton!
    var drillButton:UIButton!,layoutButton:UIButton!,settingsButton:UIButton!
    let panel=UIView()
    var spinExpanded=false
    let quickRail=UIStackView(),elevationPad=ElevationPad(frame:.zero)
    var quickReplay:UIButton!
    let coachCard=UIView(),coachLabel=UILabel()
    var lastShot:SavedShot?
    var replayYaw=0.0
    var quickCamera:UIButton!,quickTools:UIButton!,quickRole:UIButton!,quickCue:UIButton!,quickBag:UIButton!
    var lastGuideAngle=Double.infinity,lastGuideVisible=false
    var guideDirty=true,aimGuideShown=false,predictionRevealAngle:Double?
    var lastPredictionTime:TimeInterval=0
    let feedback=UIImpactFeedbackGenerator(style:.light)
    let poolAudio=PoolAudio()
    let matchPlay=MatchPlayState()
    let quickScroll=UIScrollView()
    var quickScrollHeight:NSLayoutConstraint!
    var aimCameraYaw=0.0,liveCameraAngle=Double.pi/2
    var frameStateCache:[BallState]?
    var renderUntil=0.0,lastStatusTime=0.0,startupRenderUntil=0.0
    var premiumProbeWritten=false,cameraInitialCommit=false
    var premiumProbeEye:SIMD3<Float>?,premiumProbeStable=0,premiumProbeLastMove:TimeInterval=0
    var replayPreparing=false,archiveGeneration=0,activeArchiveID:String?
    var replayPlan:ReplayDirector.Plan?
    struct ReplayReturnState {var frames:[[BallState]];var times:[Double];var events:[[String:NSNumber]];var shot:SavedShot?;var paths:[Int:[SIMD3<Float>]];var coach:Bool;var preparation:[ReplayAimSample]}
    var archiveReturn:ReplayReturnState?
    let predictionQueue=DispatchQueue(label:"ZTrainer.prediction",qos:.utility)
    var predictionPending=false,predictionGeneration=0,coachGeneration=0
    let coachQueue=DispatchQueue(label:"ZTrainer.coach",qos:.utility)
    func wakeRendering(){
        renderUntil=ProcessInfo.processInfo.systemUptime+0.4
        // 0.39c: never re-assign an unchanged rate — re-arming the link mid-shot can shift its phase by a frame.
        if displayLink?.preferredFramesPerSecond != Tuning.frameRate {displayLink?.preferredFramesPerSecond=Tuning.frameRate}
        scn?.setNeedsDisplay()
    }
    /// 0.39b: a thermal change rebuilds shader variants (shadow taps, ball segments) = a visible stall; never mid-shot.
    @objc func thermalChanged(){
        if shotActive || replayIndex != nil {pendingThermal=true;return}
        table.setThermalState(ProcessInfo.processInfo.thermalState);wakeRendering();prewarmShaders()
    }
    /// 0.39b: compile every material/shader variant in the scene in the background before it is first drawn, so the
    /// first shot (contact shadows, pockets, trails) does not stall on shader compilation.
    func prewarmShaders(){scn?.prepare([table.scene],completionHandler:nil)}
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override var prefersStatusBarHidden:Bool{true}
    override var prefersHomeIndicatorAutoHidden:Bool{true}
    override func viewDidLoad(){
        if ProcessInfo.processInfo.arguments.contains("--visual-qa") {
            let probe=UITapGestureRecognizer();probe.cancelsTouchesInView=false;probe.delegate=qaTouchProbe
            qaTouchProbe.record={[weak self] text in self?.qaLastTouch=text};view.addGestureRecognizer(probe)
        }
        super.viewDidLoad();view.backgroundColor = UIColor(red:0.025,green:0.033,blue:0.044,alpha:1)
        // Visual probes must not inherit Jump/elevation from a previous scene.
        if !ProcessInfo.processInfo.arguments.contains("--visual-qa"),var config=UserDefaults.standard.dictionary(forKey:"physics") as? [String:NSNumber]{
            // 0.14: ma sát bi–bi đổi nghĩa (μ₀ của mô hình theo tốc độ). Bỏ giá trị cũ 0,035 đã lưu để dùng mặc định mới.
            if UserDefaults.standard.integer(forKey:"physicsModelVersion")<14 {
                config["ballFriction"]=nil;UserDefaults.standard.set(config,forKey:"physics");UserDefaults.standard.set(14,forKey:"physicsModelVersion")
            }
            // 0.21: hồ sơ vật lý mới (spinDecay 11, β băng .30, squirt theo độ nâng, lực gậy phá). Bỏ giá trị cũ đã
            // lưu của các khóa này để dùng mặc định mới; các chỉnh tay khác giữ nguyên.
            if UserDefaults.standard.integer(forKey:"physicsModelVersion")<21 {
                for key in ["spinDecay","railTangentialRestitution","squirtRampDegrees","breakSpeedGain","tipProfile","squirtEnabled"]{config[key]=nil}
                UserDefaults.standard.set(config,forKey:"physics");UserDefaults.standard.set(21,forKey:"physicsModelVersion")
            }
            // 0.30: ma sát băng .45 (đo bàn thật, mục 11) và xoáy ngang tắt nhanh hơn (18 rad/s²).
            if UserDefaults.standard.integer(forKey:"physicsModelVersion")<30 {
                for key in ["railFriction","spinDecay","ballFrictionMin","railGrip0","railGrip1","railGrip2","railGrip3"]{config[key]=nil}
                UserDefaults.standard.set(config,forKey:"physics");UserDefaults.standard.set(30,forKey:"physicsModelVersion")
            }
            // 0.31: hệ số theo nguồn công bố (băng .20, xoáy ngang 15 rad/s²).
            if UserDefaults.standard.integer(forKey:"physicsModelVersion")<31 {
                for key in ["railFriction","spinDecay","ballFrictionMin","railGrip0","railGrip1","railGrip2","railGrip3"]{config[key]=nil}
                UserDefaults.standard.set(config,forKey:"physics");UserDefaults.standard.set(31,forKey:"physicsModelVersion")
            }
            engine.settings=config
        }
        table=TableScene(rails:engine.rails)
        // 0.40b: four "300" card colours were put in front of the list — shift a colour saved by 0.39 or earlier.
        if !UserDefaults.standard.bool(forKey:"clothTintMigrated040"){
            if let old=UserDefaults.standard.object(forKey:"clothTintIndex") as? Int {UserDefaults.standard.set(old+4,forKey:"clothTintIndex")}
            UserDefaults.standard.set(true,forKey:"clothTintMigrated040")}
        if let color=UserDefaults.standard.object(forKey:"clothTintIndex") as? Int {table.setClothColor(color)}
        scn=SCNView(frame:.zero);scn.scene=table.scene;scn.pointOfView=table.camera;scn.delegate=table.pacer
        scn.backgroundColor = .black;scn.antialiasingMode = .multisampling2X;scn.preferredFramesPerSecond=60;scn.contentScaleFactor=UIScreen.main.scale*CGFloat(Tuning.renderScale)
        scn.isPlaying=false;scn.rendersContinuously=false;scn.translatesAutoresizingMaskIntoConstraints=false
        view.addSubview(scn)
        scn.isMultipleTouchEnabled=true
        if ProcessInfo.processInfo.arguments.contains("--visual-qa"){scn.isAccessibilityElement=true;scn.accessibilityIdentifier="PoolScene"}
        NSLayoutConstraint.activate([
            scn.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            scn.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            scn.topAnchor.constraint(equalTo:view.topAnchor),
            scn.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
        buildHUD();buildQuickRail();buildCoachCard();buildStatusToast();configureGestures();loadDrill(drillIndex);configureMatchPlay()
        // 0.27 Game Center: invitations can arrive at any time; QA launches stay offline.
        GameCenterHub.shared.presenter=self
        GameCenterHub.shared.onStatus={[weak self] text in self?.notifyStatus(text)}
        GameCenterHub.shared.onMatch={[weak self] match,rule in self?.startGameCenterMatch(match,rule:rule)}
        if !ProcessInfo.processInfo.arguments.contains(where:{$0.hasPrefix("--")}){GameCenterHub.shared.authenticate()}
        let aimZoom=UserDefaults.standard.double(forKey:"aimCameraZoom013")
        table.zoom=Float(aimZoom>=0.45 && aimZoom<=2.6 ? aimZoom:1)
        let savedPitch=Float(UserDefaults.standard.double(forKey:"aimCameraPitch014"))
        table.aimPitch=TableScene.aimPitchRange.contains(savedPitch) ? savedPitch:TableScene.defaultAimPitch
        let configured=engine.settings
        spin.maximumOffset=tipLimit(elevated:configured["experimental3D"]?.boolValue ?? false)
        table.selectCue(configured["cueType"]?.intValue ?? 0)
        table.cueElevation=(configured["experimental3D"]?.boolValue ?? false) ? (configured["cueElevationDegrees"]?.doubleValue ?? 0):0
        shotKind=ProcessInfo.processInfo.arguments.contains("--visual-qa") ? 0:(UserDefaults.standard.object(forKey:"shotKind017") as? Int ?? (configured["cueType"]?.intValue ?? 0))
        applySquirtPolicy()
        syncQuickRail()
        highGraphics=UserDefaults.standard.object(forKey:"highGraphics018") as? Bool ?? false
        applyGraphics()
        table.camera.camera?.exposureOffset=CGFloat(UserDefaults.standard.object(forKey:"zokerExposure017") as? Double ?? -0.8)
        if ProcessInfo.processInfo.arguments.contains("--visual-qa") {
            let startupCameraMode=table.cameraMode
            loadShowcase()
            let args=ProcessInfo.processInfo.arguments
            if args.contains("--ux017-qa"){loadDrill(Drill.free)}
            if args.contains("--replay-preroll-qa") {
                loadDrill(Drill.rollTest);table.cameraMode=2
                // 0.30: shoot once >= 5.5 s of continuous preparation exists (a slow CI simulator stalls ticks and
                // restarts the buffer, so a fixed 9 s delay was flaky). Keeps rendering awake meanwhile.
                func tryShoot(_ left:Int){
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.5){[weak self] in
                        guard let self=self else{return};self.wakeRendering()
                        let span=(self.aimBuffer.last?.time ?? 0)-(self.aimBuffer.first?.time ?? 0)
                        if span>=5.5 || left<=0 {
                            self.locked=true;self.shoot(0.5)
                            // 0.36: a skipped rack intro or a busy gate swallows the stroke — say why, then retry.
                            if !self.shotActive && left>0 {
                                self.statusLabel.text="qa-shot-blocked rack:\(self.table.rackIntroPlaying ? 1:0) allowed:\(self.strokeAllowed ? 1:0) busy:\(self.presentationBusy ? 1:0) menu:\(self.menuOpen ? 1:0) spin:\(self.spinExpanded ? 1:0) turn:\(self.localTurn ? 1:0) can:\(self.matchCanStroke ? 1:0)"
                                tryShoot(left-1)
                            }
                        } else {tryShoot(left-1)}
                    }
                }
                tryShoot(120)
            }
            if args.contains("--premium-qa") {
                table.setClothColor(nil);table.selectTable(TableLook.all.first{$0.id=="allenton"}!);table.camera.camera?.exposureOffset = -0.8
                if args.contains("--premium-high"){table.quality(true);scn.antialiasingMode = .multisampling4X}
            }
            if args.contains("--ux018-match-nine-qa"){startMatch(rule:"nineBall",network:false)}
            if args.contains("--ux018-match-rotation-qa"){startMatch(rule:"rotation15",network:false)}
            // 0.40b: the computer breaks a 9-ball rack by itself (owner: "đến lượt máy cứ chờ"); CI waits for cpuShots ≥ 2.
            if args.contains("--computer-qa") {
                DispatchQueue.main.asyncAfter(deadline:.now()+1.5){[weak self] in guard let self=self else{return}
                    self.startMatch(rule:"nineBall",network:false)
                    self.matchPlay.computerLevel=1;self.matchPlay.breaker=1
                    self.matchPlay.rules?.reset(breaker:1);self.updateMatchState()
                    self.syncMatchControls();self.updateControls()}
            }
            if args.contains("--ux017-shot-qa") {
                DispatchQueue.main.asyncAfter(deadline:.now()+1){[weak self] in guard let self=self else{return};self.loadDrill(Drill.rollTest);self.spin.select(side:0,top:0.4);self.locked=true;self.shoot(0.2)}
            }
            if args.contains("--ux018-live-qa") || args.contains("--ux018-jump-qa") {
                self.loadDrill(Drill.free);self.table.cameraMode=2;self.table.zoom=1.18
                if args.contains("--ux018-jump-qa"){self.chooseShotKind(1)}
                self.spin.select(side:0.2,top:0.3)
                // 0.38: retry until the stroke really starts (a rack intro or busy gate on a slow CI start swallowed it).
                func fire(_ left:Int){
                    DispatchQueue.main.asyncAfter(deadline:.now()+(left==40 ? (args.contains("--ux018-jump-qa") ? 2:0.8):0.5)){[weak self] in
                        guard let self=self,!self.shotActive,self.frames.isEmpty else{return}
                        // 0.39d: a startup gate can swallow chooseShotKind(1) — re-select before every attempt.
                        if args.contains("--ux018-jump-qa") && self.shotKind != 1 {self.locked=false;self.chooseShotKind(1)}
                        self.locked=true;self.shoot(args.contains("--ux018-jump-qa") ? 1:2)
                        if self.shotActive {self.qaShots+=1}
                        if !self.shotActive && left>0 {fire(left-1)}
                    }
                }
                fire(40)
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
                    precondition(self.poolAudio.sampleCount==27,"All 27 real audio assets must load (0.41: 7 + 20 from the owner's pack, Tools/AudioSources/manifest.json)")
                    self.recordG1QA("audio",["engineRunning":self.poolAudio.isRunning,"scheduled":self.poolAudio.scheduled,"recordedSamples":self.poolAudio.sampleCount])
                }
            }
            if args.contains("--g1-hud-qa") {
                DispatchQueue.main.asyncAfter(deadline:.now()+1){[weak self] in self?.verifyRightHUD()}
            }
            if args.contains("--g1-return-qa") {
                DispatchQueue.main.asyncAfter(deadline:.now()+0.8){[weak self] in
                    guard let self=self else{return}
                    self.loadDrill(Drill.rollTest);self.table.cameraMode=2;self.table.zoom=1.18
                    self.spin.select(side:0,top:0.4);self.locked=true;self.shoot(0.15)
                    precondition(self.shotActive,"G1 return probe must really strike")
                    self.qaAwaitingAimReturn=true;self.qaPeekReleased=true
                    self.qaExpectedCameraAngle=self.angle+self.aimCameraYaw
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
            if args.contains("--table-arc"){table.selectTable(TableLook.all.first{$0.id=="arc"}!);table.cameraMode=0}
            // 0.34: screenshot gates measure GREEN cloth pixels; keep the legacy green table + classic club for every QA
            // shot except the explicit Z-Max / space shots (those use a brightness gate in ci_screenshots.sh).
            let spaceShot=(0..<TableScene.spaces.count).first{args.contains("--camera-space-\($0)")}
            if args.contains("--visual-qa") && !args.contains("--table-zmax") && spaceShot==nil {table.selectTable(TableLook.all.first{$0.id=="allenton"}!);table.selectSpace(6)}
            if let k=spaceShot{table.selectSpace(k);table.cameraMode=0}
            if args.contains("--table-zmax"){table.selectTable(TableLook.all[0]);table.selectSpace(0);table.cameraMode=0}
            if args.contains("--table-classic"){table.selectTable(TableLook.all.first{$0.id=="allenton"}!);table.cameraMode=0}
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
                    guard let self=self else{return};self.loadDrill(Drill.rollTest);self.table.cameraMode=2;self.locked=true;self.shoot(1.8)
                }
            }
            setMenu(false)
        }
        applyCoachVisibility()
        NotificationCenter.default.addObserver(self,selector:#selector(thermalChanged),name:ProcessInfo.thermalStateDidChangeNotification,object:nil);thermalChanged()

        stroke.sensitivity=UserDefaults.standard.double(forKey:"sensitivity");if stroke.sensitivity==0{stroke.sensitivity=1}
        spin.changed={[weak self]x,y in self?.side=x;self?.top=y;self?.guideDirty=true;self?.wakeRendering()}
        if ProcessInfo.processInfo.arguments.contains("--cue-contact-qa") {spin.select(side:-0.5,top:0.49)}
        if ProcessInfo.processInfo.arguments.contains("--spin-detail") {
            spinWidth.constant=190;spinHeight.constant=190;spin.alpha=0.97
            spinExpanded=true;quickRail.isHidden=false
            spin.select(side:0.25,top:0.35)
        }
        stroke.shot={[weak self]v in guard let self=self else{return}
            self.powerFX.fire(self.stroke.convert(self.stroke.lastPoint,to:self.powerFX),speed:v*Tuning.maxPower)
            self.shoot(v*Tuning.maxPower);self.spin.collapse();self.setHold(false)}   // 0.30b: reset after the stroke
        stroke.track={[weak self]p,v,forward in guard let self=self else{return}
            self.powerFX.maxSpeed=8*Tuning.maxPower
            self.powerFX.track(self.stroke.convert(p,to:self.powerFX),speed:v*Tuning.maxPower,forward:forward)}
        stroke.released={[weak self] fired in guard let self=self,!fired,self.locked else{return};self.setHold(false)}
        stroke.pullChanged={[weak self]p in self?.pull=p}
        displayLink=CADisplayLink(target:self,selector:#selector(tick(_:)));displayLink?.preferredFramesPerSecond=60
        displayLink?.add(to:.main,forMode:.common)
        NotificationCenter.default.addObserver(self,selector:#selector(resumed),name:UIApplication.willResignActiveNotification,object:nil)
    }
    deinit{displayLink?.invalidate();NotificationCenter.default.removeObserver(self)}
    @objc func resumed(){lastTime=0;spin.collapse();lockButton.releaseHold();setHold(false)}
    override func viewWillAppear(_ animated:Bool){
        super.viewWillAppear(animated);lastTime=0;displayLink?.isPaused=false
        scn?.isPlaying=false;scn?.rendersContinuously=false;wakeRendering()
    }
    override func viewWillDisappear(_ animated:Bool){
        super.viewWillDisappear(animated);spin.collapse();lockButton.releaseHold();setHold(false)
        // Do not keep a second rendering loop running behind the research workspace.
        displayLink?.isPaused=true;scn?.isPlaying=false;scn?.rendersContinuously=false
    }
    /// 0.39c ROOT CAUSE candidate (live-only 5 Hz hitch): ANY Auto Layout change under this view — a label text in the
    /// hidden menu, a toast, a score — ends here, and this used to re-place ~25 keys, redraw the effect ball and B,
    /// re-read saved offsets, restart a fade animation and re-arm the display link. Now the HUD is laid out only when
    /// its inputs changed (size, safe area, hand, expanded ball, key count, scale); everything else is a no-op.
    override func viewDidLayoutSubviews(){
        super.viewDidLayoutSubviews()
        if shotActive {shotProfile.layoutPasses+=1}
        let safe=hudSafeFrame
        let key="\(view.bounds.size)|\(safe)|\(leftHanded)|\(spinExpanded)|\(menuOpen)|\(matchIsCompetitive)|\(matchIsCompetitive && matchBool("requiresCall"))|\(Tuning.hudScale)|\(replayIndex != nil)"
        // 0.39d (CI 125): skip ONLY while balls are moving (live shot / replay) and nothing that places keys changed.
        // At rest every pass lays the HUD out exactly like 0.39 (shot kind, coach, ball editing… all rely on it);
        // a pass skipped mid-motion is replayed once the table is still.
        // Code audit: a guest watching the host's shot gets scoreboard text at up to 10 Hz — that is motion too.
        let moving=shotActive || replayIndex != nil || (matchPlay.session.role == .guest && matchPlay.session.latestSnapshot?.isMoving==true)
        if moving && key==hudLayoutKey && !Self.legacyStatusAB {hudLayoutDeferred=true;return}
        hudLayoutKey=key;hudLayoutDeferred=false
        if shotActive {shotProfile.hudRelayouts+=1}
        layoutRightHUD();wakeRendering()
    }
    /// 0.22: HUD controls are placed by the portable policy BLHUDLayout (PresentationPolicy.h, C++-tested):
    /// thumb column on the dominant-hand edge, effect ball 76/100 pt, elevation beside it, wheel under it,
    /// Menu + Coach at the top on the other side, B bottom on the other side. Left-handed mirrors everything.
    func adoptFrameLayoutOnce(){
        guard !frameLayoutAdopted else{return};frameLayoutAdopted=true
        for v:UIView in [quickScroll,spin,fineWheel,elevationPad,menuButton,coachButton,lockButton,panel]{
            var owned:[NSLayoutConstraint]=v.constraints.filter{($0.firstItem as? UIView)===v && $0.secondItem==nil}
            var ancestor=v.superview
            while let a=ancestor{owned+=a.constraints.filter{($0.firstItem as? UIView)===v};ancestor=a.superview}
            NSLayoutConstraint.deactivate(owned);v.translatesAutoresizingMaskIntoConstraints=true
        }
    }
    func layoutRightHUD(){
        guard spinWidth != nil,quickRailBottom != nil else{return}
        adoptFrameLayoutOnce()
        let safe=hudSafeFrame,pad=UIDevice.current.userInterfaceIdiom == .pad
        // 6 shortcuts in practice (Lùi cú) and in called-shot matches (Call); 5 otherwise.
        let sixItems = !matchIsCompetitive || matchBool("requiresCall")
        let f=BLHUDLayout(Double(safe.minX),Double(safe.minY),Double(safe.width),Double(safe.height),pad ? 1:0,leftHanded ? 1:0,sixItems ? 1:0,spinExpanded ? 1:0)
        // bounds + center (not frame): elevation/wheel may carry a zoom transform while touched.
        func place(_ v:UIView,_ b:BLRect){v.bounds=CGRect(x:0,y:0,width:b.w,height:b.h);v.center=CGPoint(x:b.x+b.w/2,y:b.y+b.h/2)}
        place(quickScroll,f.rail);place(spin,f.spin);place(fineWheel,f.wheel);place(elevationPad,f.elevation)
        place(menuButton,f.menu);place(coachButton,f.coach);place(panel,f.panel);spin.setNeedsDisplay()
        place(lockButton,f.lock);lockButton.isHidden=menuOpen || spinExpanded;lockButton.setNeedsDisplay()   // 0.36: B is back (hold = lock aim), square, left of the effect ball
        for (k,icon) in cueIcons.enumerated(){place(icon,BLHUDCueIcon(f,Int32(k)))}
        elevationPad.leftHanded=leftHanded
        let small=BLRectMake(0,f.coach.y+4,pad ? 76:62,36),guideW=pad ? 92:80
        var n=small,g=small,c=small;g.w=Double(guideW);c.w=pad ? 64:52
        if leftHanded{n.x=f.coach.x-6-n.w;g.x=n.x-6-g.w;c.x=g.x-6-c.w}else{n.x=f.coach.x+f.coach.w+6;g.x=n.x+n.w+6;c.x=g.x+g.w+6}
        place(numbersButton,n);place(guideToggle,g);place(cardToggle,c)
        // Replay bar: top row between Coach and the shortcut column (never over Coach); mirrored for left hand.
        if (replayBarRight.first?.isActive ?? false) == leftHanded {   // only on a hand change (avoids a layout loop)
            NSLayoutConstraint.deactivate(leftHanded ? replayBarRight:replayBarLeft);NSLayoutConstraint.activate(leftHanded ? replayBarLeft:replayBarRight)
        }
        retryButton.isHidden=matchIsCompetitive
        if spinExpanded{elevationPad.isHidden=true;for icon in cueIcons{icon.isHidden=true}}   // only the held ball + wheel stay (0.30)
        quickCall.isHidden = !(matchIsCompetitive && matchBool("requiresCall"))
        for item in quickRail.arrangedSubviews{item.constraints.first{$0.firstAttribute == .height && $0.secondItem==nil}?.constant=CGFloat(f.button)}
        spinWidth.constant=CGFloat(f.spin.w);spinHeight.constant=CGFloat(f.spin.h)
        applyHUDOffsets()
    }
    /// 0.27 account management: Game Center profile, friends, sign-in. No password is stored by the app.
    /// 0.37 Sảnh chính: Luyện tập (green) · Thi đấu (orange) · Hồ sơ (blue). Shown at launch and from Menu → Về sảnh.
    func openLobby(){
        guard presentedViewController==nil else{return}
        let lobby=LobbyController()
        typealias A=LobbyController.Action
        lobby.cards=[
            .init(title:"Luyện tập",subtitle:"Tập tự do, bài tập chấm sao, tìm góc kick",icon:"target",color:LobbyController.practice,actions:[
                A(title:"Tập tự do",icon:"circle.dashed",id:"LobbyFree",run:{[weak self] in self?.setMenu(false)}),
                A(title:"Bài tập · 5 cấp",icon:"star.circle",id:"LobbyDrills",run:{[weak self] in self?.chooseDrill()}),
                A(title:"Thử thách kick 1–3 băng",icon:"arrow.triangle.turn.up.right.diamond",id:"LobbyKick",run:{[weak self] in self?.chooseKick()})]),
            .init(title:"Thi đấu",subtitle:"8 · 9 · 10 Ball luật WPA, 15 Ball Rotation",icon:"trophy",color:LobbyController.match,actions:[
                A(title:"Đấu với máy · 6 cấp",icon:"cpu",id:"LobbyComputer",run:{[weak self] in self?.openComputerMatch()}),
                A(title:"Hai người · một máy",icon:"person.2",id:"LobbyLocal",run:{[weak self] in self?.openMatchMenu(scope:0)}),
                A(title:"Wi‑Fi gần nhau",icon:"wifi",id:"LobbyWifi",run:{[weak self] in self?.openMatchMenu(scope:1)}),
                A(title:"Online · Game Center",icon:"globe",id:"LobbyOnline",run:{[weak self] in self?.openMatchMenu(scope:2)})]),
            .init(title:"Hồ sơ",subtitle:"Nhật ký tập, cú đánh đã lưu, tài khoản",icon:"person.crop.circle",color:LobbyController.profile,actions:[
                A(title:"Nhật ký · tiến bộ",icon:"chart.line.uptrend.xyaxis",id:"LobbyJournal",run:{[weak self] in self?.layouts()}),
                A(title:"Cú đã lưu · video highlight",icon:"film.stack",id:"LobbyShots",run:{[weak self] in guard let self=self else{return}
                    let sheet=UIAlertController(title:"Thư viện cú đánh",message:nil,preferredStyle:.actionSheet)
                    for shot in SavedShot.all().reversed(){sheet.addAction(UIAlertAction(title:shot.name,style:.default){[weak self]_ in self?.playSaved(shot)})}
                    sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));self.presentSheet(sheet,source:self.menuButton)}),
                A(title:"Tài khoản · Game Center",icon:"gamecontroller",id:"LobbyAccount",run:{[weak self] in self?.openAccount()})])]
        // 0.39 (owner: lobby a bit confusing): Tuỳ chỉnh first (most used), Hướng dẫn, then the lab under a plain name.
        lobby.footer=[A(title:"Tuỳ chỉnh",icon:"slider.horizontal.3",id:"LobbyCustomize",run:{[weak self] in self?.openCustomize()}),
                      A(title:"Hướng dẫn",icon:"questionmark.circle",id:"LobbyHelp",run:{[weak self] in self?.help()}),
                      A(title:"Phòng thử vật lý (nâng cao)",icon:"flask",id:"LobbyLab",run:{[weak self] in self?.present(UINavigationController(rootViewController:ZupeLabController()),animated:true)})]
        lobby.modalPresentationStyle = .fullScreen;lobby.modalTransitionStyle = .crossDissolve
        present(lobby,animated:true)
    }
    var lobbyShown=false
    override func viewDidAppear(_ animated:Bool){
        super.viewDidAppear(animated)
        if !shadersPrewarmed {shadersPrewarmed=true;prewarmShaders()}
        table.pacingOwner={[weak self] in
            guard let self=self else{return false}
            return self.shotActive || self.replayIndex != nil || (self.matchPlay.session.latestSnapshot?.isMoving==true && self.matchPlay.session.role == .guest)
        }
        // QA/CI launches go straight to the table so probes and gestures are unchanged.
        let qa=ProcessInfo.processInfo.arguments.contains{$0.hasPrefix("--") && $0.hasSuffix("qa")} || ProcessInfo.processInfo.arguments.contains("--visual-qa")
        if !lobbyShown && !qa {lobbyShown=true;openLobby()}
    }
    func openAccount(){
        let hub=GameCenterHub.shared
        let sheet=UIAlertController(title:"Tài khoản",message:hub.isSignedIn ? "Đăng nhập Game Center: \(hub.displayName)":(hub.unavailableReason ?? "Đăng nhập Game Center để chơi online với bạn bè. Wi‑Fi mã phòng không cần tài khoản."),preferredStyle:.actionSheet)
        if hub.isSignedIn {
            sheet.addAction(UIAlertAction(title:"Hồ sơ người chơi",style:.default){_ in hub.showProfile()})
            sheet.addAction(UIAlertAction(title:"Bạn bè / mời bạn",style:.default){_ in hub.showFriends()})
        } else {
            sheet.addAction(UIAlertAction(title:"Đăng nhập Game Center",style:.default){_ in hub.authenticate()})
        }
        sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(sheet,source:menuButton)
    }
    func setLeftHanded(_ on:Bool){
        UserDefaults.standard.set(on,forKey:"leftHanded022");hudLayoutKey="";view.setNeedsLayout();view.layoutIfNeeded()
        notifyStatus(on ? "Tay trái: phím và bi effect bên trái":"Tay phải: phím và bi effect bên phải")
    }
    func recordG1QA(_ name:String,_ values:[String:Any]){
        let directory=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("g1-qa")
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            var record=values;if record["result"]==nil{record["result"]="PASS"};record["probe"]=name
            let data=try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys])
            try data.write(to:directory.appendingPathComponent(name+".json"),options:.atomic)
        }catch{preconditionFailure("Cannot write G1 QA evidence: \(error)")}
    }
    /// 0.36 (owner): on iPhone pull both side clusters a little closer to the screen edges (35 % of the notch /
    /// rounded-corner inset is given back). iPad has no horizontal inset to give.
    var hudSafeFrame:CGRect{
        var safe=view.safeAreaLayoutGuide.layoutFrame
        if UIDevice.current.userInterfaceIdiom != .pad {let l=view.safeAreaInsets.left*0.35,r=view.safeAreaInsets.right*0.35;safe.origin.x-=l;safe.size.width+=l+r}
        return safe
    }
    func verifyRightHUD(){
        view.layoutIfNeeded()
        let controls:[UIView]=([spin,lockButton,elevationPad,quickScroll,menuButton,coachButton]+cueIcons).filter{!$0.isHidden}
        let safe=hudSafeFrame.insetBy(dx:-0.5,dy:-0.5)
        var failures:[String]=[],frames:[String:String]=[:],hitResults:[String:String]=[:]
        for (index,control) in controls.enumerated(){
            let name=String(describing:type(of:control))+"-\(index)"
            frames[name]=String(describing:control.frame)
            if !safe.contains(control.frame){failures.append("Outside safe area: \(name)")}
            if control.bounds.width<44 || control.bounds.height<44{failures.append("Touch area below 44 pt: \(name)")}
            for other in controls.dropFirst(index+1){if control.frame.intersects(other.frame){failures.append("Overlapping HUD containers: \(name)")}}
        }
        if !spinExpanded{
            if elevationPad.frame.maxY>fineWheel.frame.minY+1{failures.append("Elevation fan is not on top of the wheel")}
            if leftHanded ? spin.frame.minX<view.bounds.midX : spin.frame.maxX>view.bounds.midX{failures.append("Effect ball is not on the side opposite the shortcut column")}
        }
        let interactive:[UIControl]=([spin,coachButton,quickReplay!,retryButton,quickCall,quickPlace!,quickAdd!,quickRole!,quickCamera!]+cueIcons).filter{!$0.isHidden}
        for control in interactive {
            let name=control.accessibilityIdentifier ?? control.accessibilityLabel ?? String(describing:type(of:control))
            frames[name]=String(describing:control.convert(control.bounds,to:view))
            if control.bounds.width<44 || control.bounds.height<44{failures.append("Child touch area below 44 pt: \(name)")}
            if control.isDescendant(of:quickScroll),!quickScroll.bounds.contains(control.convert(control.bounds,to:quickScroll)){hitResults[name]="scroll to reveal";continue}
            // Replay is deliberately disabled before a shot. Its enabled hit path is exercised by XCUITest.
            guard control.isEnabled else{hitResults[name]="intentionally disabled";continue}
            let point=control.convert(CGPoint(x:control.bounds.midX,y:control.bounds.midY),to:view)
            let hit=view.hitTest(point,with:nil)
            hitResults[name]=hit.map{String(describing:type(of:$0))} ?? "nil"
            if !(hit===control || hit?.isDescendant(of:control)==true){failures.append("Another view intercepts enabled control: \(name)")}
        }
        // Persist FAIL as evidence instead of crashing before diagnostics can be retrieved. CI still requires PASS.
        recordG1QA(spinExpanded ? "hud-expanded":"hud",["result":failures.isEmpty ? "PASS":"FAIL","failures":failures,"frames":frames,"hitResults":hitResults,"safeArea":String(describing:safe),"width":safe.width,"height":safe.height])
    }
    func text(_ label:UILabel,_ size:CGFloat,_ color:UIColor,_ weight:UIFont.Weight = .medium){label.font = .systemFont(ofSize:size,weight:weight);label.textColor=color}
    func stack(_ axis:NSLayoutConstraint.Axis,_ spacing:CGFloat,_ views:[UIView])->UIStackView {
        let s=UIStackView(arrangedSubviews:views);s.axis=axis;s.spacing=spacing;s.alignment = .fill;return s
    }
    func buildHUD(){
        // The SceneKit viewport never changes size when the menu opens.
        powerFX.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(powerFX)
        NSLayoutConstraint.activate([powerFX.leadingAnchor.constraint(equalTo:view.leadingAnchor),powerFX.trailingAnchor.constraint(equalTo:view.trailingAnchor),
                                     powerFX.topAnchor.constraint(equalTo:view.topAnchor),powerFX.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
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
        spinWidth=spin.widthAnchor.constraint(equalToConstant:52)
        spinHeight=spin.heightAnchor.constraint(equalToConstant:52)
        spin.expandedChanged={[weak self] expanded in
            guard let self=self else{return}
            // 0.30b (owner): touching the effect ball (hold or tap) LATCHES the aim lock. Lifting the finger keeps it;
            // the next stroke on the empty table fires, then everything resets. A non-firing touch on the table unlocks.
            self.spinExpanded=expanded
            // 0.37 (owner): by default only B locks; the effect ball just chooses the tip contact. Old latch in Tuỳ chỉnh.
            if expanded{self.hideCoach();if !self.locked && Tuning.effectLock{self.setHold(!self.presentationBusy && self.localTurn && !self.isPlacingBalls)}}
            self.spin.alpha=expanded ? 0.97:0.60
            self.layoutRightHUD();self.updateControls()
            self.fineWheel.isHidden=self.menuOpen
            self.elevationPad.isHidden=expanded || self.menuOpen || self.locked
            for icon in self.cueIcons{icon.isHidden=expanded || self.menuOpen || self.locked}
            self.coachButton.isEnabled = !expanded
            self.spin.isHidden=self.menuOpen
            self.spinCenter.isHidden = !expanded
            self.hudLayoutKey="";self.view.setNeedsLayout();self.view.layoutIfNeeded()
        }
        lockButton.heldChanged={[weak self] held in self?.setHold(held)}
        NSLayoutConstraint.activate([
            spin.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12),
            spinWidth,spinHeight,
            lockButton.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:12),
            lockButton.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12),
            lockButton.widthAnchor.constraint(equalToConstant:UIDevice.current.userInterfaceIdiom == .pad ? 92:72),lockButton.heightAnchor.constraint(equalToConstant:UIDevice.current.userInterfaceIdiom == .pad ? 92:72)])
        coachButton.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(coachButton)
        coachButton.setTitle("Coach",for:.normal);coachButton.titleLabel?.font = .systemFont(ofSize:11,weight:.bold)
        coachButton.layer.cornerRadius=10;coachButton.backgroundColor=UIColor.rgb(0x131218).withAlphaComponent(0.88);coachButton.layer.borderWidth=0.7;coachButton.layer.borderColor=UIColor.rgb(0xEAC583).cgColor
        coachButton.accessibilityIdentifier="CoachToggle";coachButton.accessibilityLabel="Coach · Huấn luyện viên"
        coachButton.addAction(UIAction{[weak self]_ in self?.toggleCoach()},for:.touchUpInside)
        coachButton.addAction(UIAction{[weak self]_ in self?.qaCoachDown+=1},for:.touchDown)
        coachButton.addAction(UIAction{[weak self]_ in self?.qaCoachUp+=1},for:.touchUpInside)
        fineWheel.translatesAutoresizingMaskIntoConstraints=false
        fineWheel.accessibilityIdentifier="FineAimWheel";view.addSubview(fineWheel)
        fineWheel.changed={[weak self] delta in guard let self=self,!self.presentationBusy,self.localTurn else{return};self.angle+=delta;self.aimCameraYaw=0;self.shotCameraAnchor=nil;self.beginCameraTransition(0.25);self.refresh();self.wakeRendering()}
        menuButton.setTitle("Menu",for:.normal)
        menuButton.titleLabel?.font = .systemFont(ofSize:13,weight:.semibold)
        menuButton.setTitleColor(UIColor.rgb(0xEAC583),for:.normal)
        menuButton.backgroundColor=UIColor(white:0.03,alpha:0.45);menuButton.layer.cornerRadius=18
        menuButton.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(menuButton)
        menuButton.addAction(UIAction{[weak self]_ in guard let self=self else{return};self.setMenu(!self.menuOpen)},for:.touchUpInside)
        NSLayoutConstraint.activate([
            menuButton.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:12),
            menuButton.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:10),
            menuButton.widthAnchor.constraint(equalToConstant:78),menuButton.heightAnchor.constraint(equalToConstant:44)])

        // 0.41 (owner): the menu opens in a wooden frame (10 pt walnut rim), the inside a deep muted tone.
        panel.layer.cornerRadius=20;panel.layer.borderWidth=1.5;panel.layer.borderColor=MenuSkin.gold.withAlphaComponent(0.6).cgColor
        panel.layer.shadowColor=UIColor.black.cgColor;panel.layer.shadowOpacity=0.6;panel.layer.shadowRadius=14
        panel.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(panel)
        let scroll=UIScrollView();scroll.translatesAutoresizingMaskIntoConstraints=false;panel.addSubview(scroll)
        MenuSkin.frame(panel,content:scroll,tone:UIColor(red:0.06,green:0.05,blue:0.045,alpha:0.97),radius:12)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo:menuButton.leadingAnchor),
            panel.topAnchor.constraint(equalTo:menuButton.bottomAnchor,constant:8),
            panel.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12),
            panel.widthAnchor.constraint(equalToConstant:318),
            scroll.leadingAnchor.constraint(equalTo:panel.leadingAnchor,constant:10),scroll.trailingAnchor.constraint(equalTo:panel.trailingAnchor,constant:-10),
            scroll.topAnchor.constraint(equalTo:panel.topAnchor,constant:10),scroll.bottomAnchor.constraint(equalTo:panel.bottomAnchor,constant:-10)])
        let brand=UILabel();text(brand,17,.white,.bold);brand.text="ZOKER POOL · Trainer";brand.textColor=MenuSkin.gold
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
        let lessons=UIButton.lab("Bài tập"){[weak self]in self?.chooseDrill()}
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
        let coachToggle=UIButton.lab("Coach · Bật / tắt toàn bộ trợ giúp"){[weak self] in self?.toggleCoach()}
        let cameraOptions=UIButton.lab("Góc nhìn / Camera replay"){[weak self] in self?.cycleCamera()}
        let recordings=UIButton.lab("Lưu trữ · Cú đánh / Highlight"){[weak self] in
            guard let self=self else{return}
            let sheet=UIAlertController(title:"Thư viện cú đánh",message:nil,preferredStyle:.actionSheet)
            sheet.addAction(UIAlertAction(title:"Lưu cú vừa đánh",style:.default){[weak self]_ in self?.saveLastShot()})
            sheet.addAction(UIAlertAction(title:"Xuất video highlight (3 cảnh điện ảnh)",style:.default){[weak self]_ in self?.setMenu(false);self?.exportHighlight()})
            for shot in SavedShot.all().reversed(){sheet.addAction(UIAlertAction(title:shot.name,style:.default){[weak self]_ in self?.playSaved(shot)})}
            sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));self.presentSheet(sheet,source:self.menuButton)
        }
        let center=UIButton.lab("Ép phê về tâm"){[weak self]in self?.spin.reset()}
        let matches=UIButton.lab("Chơi theo luật / Wi-Fi"){[weak self]in self?.openMatchMenu()}
        let close=UIButton.lab("Đóng Menu"){[weak self]in self?.setMenu(false)}
        func row(_ buttons:[UIView])->UIStackView{let r=stack(.horizontal,8,buttons);r.distribution = .fillEqually;return r}
        let fine=UIButton.lab("Ngắm tinh · bánh xe dọc"){[weak self]in self?.setMenu(false);self?.notifyStatus("Kéo bánh xe mờ cạnh phải để vi chỉnh góc ngắm")}
        // 0.21: chỉnh tay vật lý + xuất Markdown nghiệm thu, đưa ra Menu chính (trước đây nằm trong Nâng cao).
        let physicsTuning=UIButton.lab("Hiệu chỉnh vật lý · xuất Markdown"){[weak self]in self?.settings()}
        physicsTuning.accessibilityIdentifier="MenuPhysicsTuning"
        let advanced=UIButton.lab("Nâng cao"){[weak self]in guard let self=self else{return};let a=UIAlertController(title:"Nâng cao",message:nil,preferredStyle:.actionSheet)
            a.addAction(UIAlertAction(title:"Hiệu chỉnh vật lý",style:.default){[weak self]_ in self?.settings()})
            a.addAction(UIAlertAction(title:"ZUPE Lab · nghiên cứu",style:.default){[weak self]_ in self?.setMenu(false);self?.present(UINavigationController(rootViewController:ZupeLabController()),animated:true)})
            a.addAction(UIAlertAction(title:"Đóng",style:.cancel));self.presentSheet(a,source:self.menuButton)
        }
        // 0.21: Menu chỉ còn 7 mục theo nghiệm thu 03/11 (Chế độ chơi, Hướng dẫn, Bài tập, Lưu trữ, Thư viện, Nhật ký,
        // Hiệu chỉnh vật lý). Coach, Camera, Đặt bi, Lùi cú, Xem lại đã nằm trên màn hình chính; các mục khác gộp vào trong.
        func group(_ title:String,_ items:[(String,()->Void)])->UIButton{
            UIButton.lab(title){[weak self] in
                guard let self=self else{return}
                let sheet=UIAlertController(title:title,message:nil,preferredStyle:.actionSheet)
                for (name,action) in items{sheet.addAction(UIAlertAction(title:name,style:.default){_ in action()})}
                sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));self.presentSheet(sheet,source:self.menuButton)
            }
        }
        let modes=group("Chế độ chơi · Offline / Wi‑Fi / Online",[
            ("Offline · luyện tự do",{[weak self] in self?.setMenu(false)}),
            ("Wi‑Fi (mã phòng) / Online / Game Center",{[weak self] in self?.openMatchMenu()}),
            ("Tài khoản · Game Center",{[weak self] in self?.openAccount()})])
        modes.accessibilityIdentifier="MenuModes"
        let guide=group("Hướng dẫn",[
            ("Cách chơi & điều khiển",{[weak self] in self?.help()})])
        let drills=group("Bài tập · 5 cấp · chấm điểm 5 sao",[
            ("Chọn bài tập",{[weak self] in self?.chooseDrill()}),
            ("Tìm góc kick 1–3 băng",{[weak self] in self?.chooseKick()})])
        let library=group("Thư viện · Bàn – Nỉ – Bi – Gậy – Không gian",[
            ("Nỉ: mới / cũ (đổi)",{[weak self] in guard let self=self else{return};self.table.setClothWear(old:!self.table.oldCloth);self.wakeRendering();self.notifyStatus(self.table.oldCloth ? "Nỉ cũ: vệt lăn, vết chấm, bụi phấn":"Nỉ mới")}),
            ("Bi: mới / cũ (đổi)",{[weak self] in guard let self=self else{return};self.table.setBallWear(old:!self.table.oldBalls);self.wakeRendering();self.notifyStatus(self.table.oldBalls ? "Bi cũ: mờ bóng":"Bi mới: bóng gương")}),
            ("Màu nỉ",{[weak self] in self?.chooseClothColor()}),
            ("Thư viện 24 bàn · 12 cơ",{[weak self] in self?.openLibrary()}),
            ("Không gian bàn (7 cảnh)",{[weak self] in self?.chooseSpace()}),
            ("Tay trái / tay phải (đổi bên phím)",{[weak self] in guard let self=self else{return};self.setLeftHanded(!self.leftHanded)}),
            ("Bao cơ / Gậy",{[weak self] in self?.equipment()}),
            ("Bàn & không gian · hình ảnh",{[weak self] in self?.graphics()}),
            ("Âm thanh: bật / tắt",{[weak self] in
                let enabled = !(UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true)
                UserDefaults.standard.set(enabled,forKey:"poolAudioEnabled");self?.statusLabel.text=enabled ? "Âm thanh bi: bật":"Âm thanh bi: tắt"})])
        let journal=UIButton.lab("Nhật ký tập luyện · Thế bi"){[weak self]in self?.layouts()}
        let tuning=group("Hiệu chỉnh vật lý · xuất Markdown",[
            ("Mở bảng hiệu chỉnh",{[weak self] in self?.settings()}),
            ("ZUPE Lab · nghiên cứu",{[weak self] in self?.setMenu(false);self?.present(UINavigationController(rootViewController:ZupeLabController()),animated:true)})])
        tuning.accessibilityIdentifier="MenuPhysicsTuning"
        // 0.36: one place for every user preference (owner IQ200 #4).
        let customize=UIButton.lab("Tuỳ chỉnh · ánh sáng, lực, bố cục phím, độ mượt"){[weak self] in self?.openCustomize()}
        customize.accessibilityIdentifier="MenuCustomize"
        _=(center,trails,fine,felt,sound,coachToggle,cameraOptions,kick,advanced,physicsTuning,equipment,lessons,help,matches,guideButton,resetButton,graphicsButton,layoutButton,drillButton)
        // 0.37 (owner chose): in-game menu = 5 items. Modes, drills, journal and guide live in the Lobby (Về sảnh);
        // physics tuning in Tuỳ chỉnh → Vật lý.
        let resume=UIButton.lab("Tiếp tục"){[weak self]in self?.setMenu(false)}
        resume.accessibilityIdentifier="MenuResume"
        if var c=resume.configuration{c.baseBackgroundColor=LobbyController.gold;c.baseForegroundColor = .black;c.background.backgroundColor=LobbyController.gold;resume.configuration=c}
        library.configuration?.title="Đổi bàn · bi · gậy · không gian"
        customize.configuration?.title="Tuỳ chỉnh · hình ảnh, điều khiển, vật lý, âm thanh"
        recordings.configuration?.title="Lưu và xem lại · cú đánh / highlight"
        let lobby=UIButton.lab("Về sảnh · chế độ chơi, bài tập, hồ sơ"){[weak self]in self?.setMenu(false);self?.openLobby()}
        lobby.accessibilityIdentifier="MenuLobby"
        // 0.41: each section its own muted tone (bàn = rừng thông, tuỳ chỉnh = xanh đêm, lưu trữ = đỏ rượu, sảnh = đá).
        MenuSkin.tone(library,MenuSkin.tones[0]);MenuSkin.tone(customize,MenuSkin.tones[1])
        MenuSkin.tone(recordings,MenuSkin.tones[4]);MenuSkin.tone(lobby,MenuSkin.tones[5])
        _=(modes,guide,drills,journal,tuning,close)
        let controls=stack(.vertical,10,[brand,titleLabel,statusLabel,scoreLabel,hintLabel,
            resume,library,customize,recordings,lobby])
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
        retry.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:9,weight:.medium);return a}
        retry.title="Tập lại";retryButton.configuration=retry;retryButton.translatesAutoresizingMaskIntoConstraints=false;retryButton.accessibilityLabel="Dừng và đánh lại cú vừa rồi";view.addSubview(retryButton)
        retryButton.addAction(UIAction{[weak self]_ in guard let self=self else{return};if self.shotBack.isEmpty{self.undo()}else{self.stepShot(-1)}},for:.touchUpInside)
        retryButton.menu=UIMenu(title:"Lùi / tiến cú",children:[UIDeferredMenuElement.uncached{[weak self] completion in
            guard let self=self else{completion([]);return}
            let back=self.shotBack.count,forward=self.shotForward.count
            completion([UIAction(title:"Lùi 1 cú (còn \(back))",attributes:back==0 ? [.disabled]:[]){[weak self]_ in self?.stepShot(-1)},
                        UIAction(title:"Tiến 1 cú (còn \(forward))",attributes:forward==0 ? [.disabled]:[]){[weak self]_ in self?.stepShot(1)},
                        UIAction(title:"Về đầu phiên",attributes:back==0 ? [.disabled]:[]){[weak self]_ in self?.stepShot(-99)},
                        UIAction(title:"Tới cú mới nhất",attributes:forward==0 ? [.disabled]:[]){[weak self]_ in self?.stepShot(99)}])}])
        panel.isHidden=true;table.cameraMode=2;table.showNumbers=false
    }
    func setMenu(_ open:Bool){
        spin.collapse();lockButton.releaseHold();setHold(false)
        menuOpen=open;focusMode = !open;panel.isHidden = !open
        menuButton.setTitle(open ? "Đóng":"Menu",for:.normal)
        fineWheel.isHidden=open
        spinCenter.isHidden=true;spin.isHidden=open;lockButton.isHidden=open;coachButton.isHidden=open
        quickScroll.isHidden=open;elevationPad.isHidden=open;for icon in cueIcons{icon.isHidden=open}
        coachCard.isHidden=open || !coachOn || !cardOn || coachCard.alpha==0
        updateControls()
    }
    func buildQuickRail(){
        quickRail.axis = .vertical;quickRail.spacing=2;quickRail.distribution = .fillEqually
        quickRail.translatesAutoresizingMaskIntoConstraints=false
        func button(_ symbol:String,_ name:String,_ id:String)->UIButton {
            let b=UIButton(type:.system);var c=UIButton.Configuration.plain()
            c.image=UIImage(systemName:symbol);c.title=name;c.imagePlacement = .top;c.imagePadding=1
            c.baseForegroundColor = .rgb(0xF3D9A4);c.background.backgroundColor=UIColor.rgb(0x131218).withAlphaComponent(0.42);c.background.cornerRadius=10
            c.background.strokeColor=UIColor.rgb(0xEAC583).withAlphaComponent(0.4);c.background.strokeWidth=0.7
            let names=["QuickCamera":"Camera","QuickTools":"Tools","QuickReplay":"Replay","unused":"Undo"]
            if let name=names[id],let data=NSDataAsset(name:"PC_Icon_"+name),let image=UIImage(data:data.data){c.image=(image.preparingThumbnail(of:CGSize(width:18,height:18)) ?? image).withRenderingMode(.alwaysOriginal)}
            c.preferredSymbolConfigurationForImage=UIImage.SymbolConfiguration(pointSize:12,weight:.medium)
            c.contentInsets=NSDirectionalEdgeInsets(top:4,leading:2,bottom:4,trailing:2)
            c.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:10.5,weight:.semibold);return a}
            b.configuration=c;b.accessibilityIdentifier=id;b.titleLabel?.layer.shadowOpacity=0.8;return b
        }
        quickCamera=button("camera","Camera","QuickCamera")
        quickCamera.addAction(UIAction{[weak self]_ in self?.eyeDown()},for:.touchDown)
        quickCamera.addAction(UIAction{[weak self]_ in self?.eyeUp()},for:.touchUpInside)
        quickCamera.addAction(UIAction{[weak self]_ in self?.releasePeek()},for:[.touchUpOutside,.touchCancel])
        quickReplay=button("play.circle","Xem lại","QuickReplay")
        quickReplay.addAction(UIAction{[weak self]_ in self?.replay()},for:.touchUpInside)
        quickReplay.menu=UIMenu(title:"Lưu cú / Thư viện",children:[UIDeferredMenuElement.uncached{[weak self] completion in completion(self?.replayMenu().children ?? [])}])
        retryButton.configuration=button("arrow.uturn.backward","Lùi cú","unused").configuration
        retryButton.accessibilityIdentifier="QuickRetry"
        quickRole=button("bag","Bao cơ","QuickCue")   // 0.30b: Bao cơ = thư viện gậy (links the looks to the cue icons)
        quickRole.addAction(UIAction{[weak self]_ in self?.equipment()},for:.touchUpInside)
        quickPlace=button("hand.draw","Đặt bi","QuickPlace")
        quickPlace.addAction(UIAction{[weak self]_ in self?.toggleEdit()},for:.touchUpInside)
        quickAdd=button("plus.circle","Thêm bi","QuickAdd")
        quickAdd.addAction(UIAction{[weak self]_ in guard let self=self else{return};if self.isPlacingBalls{self.cancelPlacement()}else{self.addBall()}},for:.touchUpInside)
        quickTools=button("slider.horizontal.3","Dụng cụ","QuickTools");quickTools.showsMenuAsPrimaryAction=true
        quickTools.menu=UIMenu(title:"Dụng cụ",children:[UIDeferredMenuElement.uncached{[weak self] completion in
            guard let self=self else{completion([]);return}
            var items:[UIMenuElement]=[]
            if let cue=self.quickRole.menu{items.append(cue)}
            items.append(UIAction(title:self.isPlacingBalls ? "Xong đặt bi":"Đặt bi"){[weak self]_ in self?.toggleEdit()})
            items.append(UIAction(title:"Thêm bi · số lượng / bố trí"){[weak self]_ in self?.randomOptions()})
            items.append(UIAction(title:"Thêm từng bi"){[weak self]_ in self?.addBall()})
            items.append(UIAction(title:"Thư viện 20 bàn · 12 cơ"){[weak self]_ in self?.openLibrary()})
            if self.isPlacingBalls{items.append(UIAction(title:"Hủy đặt bi",attributes:.destructive){[weak self]_ in self?.cancelPlacement()})}
            completion(items)
        }])
        quickCue=UIButton(type:.system);quickBag=UIButton(type:.system)
        // 0.22 order, top to bottom: Xem lại · Lùi cú (practice) · Đặt bi · Thêm bi · Bao cơ · Camera (under the thumb).
        quickPlace.menu=UIMenu(title:"Đặt bi",children:[UIDeferredMenuElement.uncached{[weak self] completion in
            guard let self=self,self.isPlacingBalls else{completion([]);return}
            completion([UIAction(title:"Xong đặt bi"){[weak self]_ in self?.toggleEdit()},UIAction(title:"Hủy đặt bi",attributes:.destructive){[weak self]_ in self?.cancelPlacement()}])}])
        // 0.26: in 8/10-ball matches the Lùi cú slot becomes Call (full-screen pick: ball, then pocket).
        quickCall.configuration=button("scope","Call","QuickCall").configuration;quickCall.accessibilityIdentifier="QuickCall"
        quickCall.addAction(UIAction{[weak self]_ in self?.beginMatchCallPick()},for:.touchUpInside)
        for item in [quickReplay!,retryButton,quickCall,quickPlace!,quickAdd!,quickRole!,quickCamera!] {
            item.heightAnchor.constraint(equalToConstant:44).isActive=true;quickRail.addArrangedSubview(item)
        }
        quickScroll.translatesAutoresizingMaskIntoConstraints=false;quickScroll.accessibilityIdentifier="QuickRailScroll";quickScroll.showsVerticalScrollIndicator=false
        quickScroll.addSubview(quickRail);view.addSubview(quickScroll)
        elevationPad.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(elevationPad)
        quickRailBottom=quickScroll.bottomAnchor.constraint(equalTo:elevationPad.topAnchor,constant:-6)
        quickScrollHeight=quickScroll.heightAnchor.constraint(equalToConstant:182)
        NSLayoutConstraint.activate([
            quickScroll.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-6),
            quickScroll.widthAnchor.constraint(equalToConstant:56),quickScrollHeight,quickRailBottom,
            quickRail.leadingAnchor.constraint(equalTo:quickScroll.contentLayoutGuide.leadingAnchor),quickRail.trailingAnchor.constraint(equalTo:quickScroll.contentLayoutGuide.trailingAnchor),
            quickRail.topAnchor.constraint(equalTo:quickScroll.contentLayoutGuide.topAnchor),quickRail.bottomAnchor.constraint(equalTo:quickScroll.contentLayoutGuide.bottomAnchor),quickRail.widthAnchor.constraint(equalTo:quickScroll.frameLayoutGuide.widthAnchor),
            coachButton.bottomAnchor.constraint(equalTo:lockButton.topAnchor,constant:-8),coachButton.widthAnchor.constraint(equalToConstant:76),coachButton.heightAnchor.constraint(equalToConstant:44),coachButton.centerXAnchor.constraint(equalTo:lockButton.centerXAnchor),
            elevationPad.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-8),
            elevationPad.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-8),
            elevationPad.widthAnchor.constraint(equalToConstant:44),elevationPad.heightAnchor.constraint(equalToConstant:96),
            fineWheel.centerXAnchor.constraint(equalTo:spin.centerXAnchor),fineWheel.bottomAnchor.constraint(equalTo:spin.topAnchor,constant:-8),fineWheel.widthAnchor.constraint(equalToConstant:44),fineWheel.heightAnchor.constraint(equalToConstant:100),
            spin.trailingAnchor.constraint(equalTo:elevationPad.leadingAnchor,constant:-16)])
        elevationPad.changed={[weak self] value in self?.setElevation(value)}
        buildCueIcons()
        for (b,title,id) in [(numbersButton,"Nút số","NumbersToggle"),(guideToggle,"Chỉ dẫn","GuideToggle"),(cardToggle,"Board","CoachCardToggle")] {
            var c=UIButton.Configuration.plain();c.title=title;c.background.backgroundColor=UIColor(white:0.03,alpha:0.42);c.background.cornerRadius=10
            c.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:12,weight:.semibold);return a}
            b.configuration=c;b.accessibilityIdentifier=id;view.addSubview(b)
        }
        numbersButton.addAction(UIAction{[weak self]_ in guard let self=self else{return};self.numbersOn.toggle()
            UserDefaults.standard.set(self.numbersOn,forKey:"numbersOn033");self.applyCoachVisibility();self.syncOverlayButtons()},for:.touchUpInside)
        cardToggle.addAction(UIAction{[weak self]_ in guard let self=self,self.coachOn else{return}
            self.cardOn.toggle();self.coachCard.isHidden = !self.cardOn || self.locked || self.coachCard.alpha==0;self.syncOverlayButtons()},for:.touchUpInside)
        guideToggle.addAction(UIAction{[weak self]_ in guard let self=self,self.coachOn else{return}
            // tắt → điểm ngắm → cả đường → tắt
            if !self.guideOn {self.guideOn=true;self.guideMode=1} else if self.guideMode==1 {self.guideMode=2} else {self.guideOn=false}
            UserDefaults.standard.set(self.guideMode,forKey:"guideMode035");self.guideDirty=true;self.guideButton?.configuration?.title=self.guideOn ? "Dự báo: bật":"Dự báo: tắt"
            self.wakeRendering();self.syncOverlayButtons()},for:.touchUpInside)
        buildReplayBar();syncQuickRail();applyCoachVisibility()
    }
    func buildCueIcons(){
        let names=["Đánh","Jump","Massé","Break"],ids=["CueIconPlay","CueIconJump","CueIconMasse","CueIconBreak"]
        for k in 0..<Int(BL_CUE_ICONS) {
            let b=UIButton(type:.system);var c=UIButton.Configuration.plain()
            c.title=names[k];c.image=UIImage(systemName:k==2 ? "arrow.turn.up.right":(k==1 ? "arrow.up.forward":(k==3 ? "burst":"line.diagonal")))
            c.imagePlacement = .top;c.imagePadding=2;c.preferredSymbolConfigurationForImage=UIImage.SymbolConfiguration(pointSize:11,weight:.semibold)
            c.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:10.5,weight:.bold);return a}
            c.subtitleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:8,weight:.medium);return a}
            c.background.backgroundColor=UIColor(white:0.03,alpha:0.32);c.background.cornerRadius=8;c.contentInsets = .zero
            b.configuration=c;b.accessibilityIdentifier=ids[k];b.accessibilityLabel="Gậy "+names[k]
            b.addAction(UIAction{[weak self]_ in self?.chooseCueIcon(k)},for:.touchUpInside)
            view.addSubview(b);cueIcons.append(b)
        }
    }
    func chooseCueIcon(_ k:Int){
        let kind=Int(BLCueIconKind(Int32(k)))
        if kind != shotKind {chooseShotKind(kind)} else if kind==3 || kind==1 {setElevation(BLCueIconElevation(Int32(k)))}
        syncQuickRail()
    }
    /// 0.34: Club (like the owner's photo) · Trong nhà · Ngoài trời · Cung điện · Hoàng gia · Thi đấu quốc tế · Club cổ điển
    func chooseSpace(){
        let sheet=UIAlertController(title:"Không gian bàn",message:nil,preferredStyle:.actionSheet)
        for (k,name) in TableScene.spaces.enumerated(){
            sheet.addAction(UIAlertAction(title:(k==table.space ? "✓ ":"")+name,style:.default){[weak self]_ in
                self?.table.selectSpace(k);self?.wakeRendering();self?.notifyStatus("Không gian: "+name)})
        }
        sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(sheet,source:menuButton)
    }
    func syncOverlayButtons(){
        let hidden=locked || menuOpen || replayIndex != nil || matchIsCompetitive || isPlacingBalls
        // 0.35 (owner): Nút số, Chỉ dẫn and Bảng appear only while Coach is on.
        numbersButton.isHidden=hidden || !coachOn;guideToggle.isHidden=hidden || !coachOn;cardToggle.isHidden=hidden || !coachOn
        guideToggle.configuration?.title=guideOn ? (guideMode==1 ? "Điểm ngắm":"Cả đường"):"Chỉ dẫn"
        cardToggle.configuration?.baseForegroundColor=cardOn ? .white:UIColor.rgb(0xEAC583).withAlphaComponent(0.7)
        cardToggle.configuration?.background.backgroundColor=cardOn ? UIColor.rgb(0xEAC583).withAlphaComponent(0.38):UIColor(white:0.03,alpha:0.42)
        let gold=UIColor.rgb(0xEAC583)
        numbersButton.configuration?.baseForegroundColor=numbersOn ? .white:gold.withAlphaComponent(0.7)
        numbersButton.configuration?.background.backgroundColor=numbersOn ? gold.withAlphaComponent(0.38):UIColor(white:0.03,alpha:0.42)
        guideToggle.configuration?.baseForegroundColor=guideOn ? .white:gold.withAlphaComponent(0.7)
        guideToggle.configuration?.background.backgroundColor=guideOn ? gold.withAlphaComponent(0.38):UIColor(white:0.03,alpha:0.42)
        numbersButton.accessibilityValue=numbersOn ? "Bật":"Tắt";guideToggle.accessibilityValue=guideOn ? "Bật":"Tắt"
    }
    func syncCueIcons(){
        syncOverlayButtons()
        for (k,icon) in cueIcons.enumerated(){
            let on=Int(BLCueIconKind(Int32(k)))==shotKind
            icon.configuration?.baseForegroundColor=on ? .white:UIColor.rgb(0xEAC583).withAlphaComponent(0.8)
            icon.configuration?.background.backgroundColor=on ? UIColor.rgb(0xEAC583).withAlphaComponent(0.42):UIColor(white:0.03,alpha:0.32)
            icon.configuration?.background.strokeColor=on ? .white:UIColor.white.withAlphaComponent(0.15);icon.configuration?.background.strokeWidth=on ? 1:0.5
            icon.isEnabled = localTurn && !presentationBusy && !locked
            icon.accessibilityValue=on ? "Đang chọn":""
            let role=Int(BLCueIconKind(Int32(k)))==2 ? 2:(Int(BLCueIconKind(Int32(k)))==1 ? 1:0)
            icon.configuration?.subtitle=CueBag.cue(role).title.components(separatedBy:" · ").first
        }
    }
    func syncQuickRail(){
        syncCueIcons()
        guard quickRole != nil else{return}
        let wantCall=matchIsCompetitive && matchBool("requiresCall"),wantRetry = !matchIsCompetitive
        if quickCall.isHidden == wantCall || retryButton.isHidden == wantRetry {quickCall.isHidden = !wantCall;retryButton.isHidden = !wantRetry;hudLayoutKey="";view.setNeedsLayout()}
        let role=engine.settings["cueType"]?.intValue ?? 0
        elevationPad.degrees=table.cueElevation
        let kindNames=[0:"Đánh",1:"Jump",2:"Break",3:"Massé"]
        quickRole.configuration?.title="Bao cơ · "+(kindNames[shotKind] ?? "Đánh")
        // Bao cơ: only the three cues of the selected bag, brand in brackets. Massé = Đánh raised to 60°+.
        quickRole.menu=nil
        quickPlace.configuration?.title=isPlacingBalls ? "Xong":"Đặt bi"
        quickPlace.showsMenuAsPrimaryAction=false
        quickAdd.configuration?.title=isPlacingBalls ? "Hủy":"Thêm bi"
        quickAdd.showsMenuAsPrimaryAction = !isPlacingBalls
        quickAdd.menu=isPlacingBalls ? nil:UIMenu(title:"Thêm bi",children:[
            UIAction(title:"Thêm từng bi"){[weak self]_ in self?.addBall()},
            UIAction(title:"Thêm bi · số lượng / bố trí"){[weak self]_ in self?.randomOptions()},
            UIMenu(title:"Thêm nhanh",children:Array(1...15).map{n in UIAction(title:"Thêm \(n) bi"){[weak self]_ in self?.addRandomBalls(n)}}),
            UIMenu(title:"Tạo thế mới",children:Array(1...15).map{n in UIAction(title:"Tạo thế \(n) bi"){[weak self]_ in self?.addRandomBalls(n,replacing:true)}})])
        // Camera: hold = overview, release = back to the aim view; quick tap = toggle. No long-press menu (it would steal the hold).
        quickCamera.menu=nil
        quickCamera.configuration?.title=table.cameraMode==2 ? "Camera · ngắm":"Camera · toàn cảnh"
        quickCue.menu=UIMenu(title:"Cơ",children:(0...2).map{i in UIAction(title:CueBag.cue(i).title){[weak self]_ in self?.chooseRole(i)}})
        quickBag.menu=UIMenu(title:"Bao cơ",children:[quickCue.menu!,UIMenu(title:"Đổi bao",children:CueBag.names.enumerated().map{i,title in UIAction(title:title){[weak self]_ in CueBag.active=i;self?.chooseRole(role)}}),UIAction(title:"Thư viện bàn & cơ"){[weak self]_ in self?.openLibrary()}])
    }
    // Đánh/Phá: no squirt, the ball leaves on the aim line. Jump/Massé keep TP A.31 squirt.
    /// 0.21: squirt on for every cue but faded in by elevation (level cue = aim line); tip by shot kind.
    func shotKindPhysics(_ kind:Int,_ values:inout [String:NSNumber]){
        values["squirtEnabled"]=1;values["squirtRampDegrees"]=NSNumber(value:BL_SQUIRT_RAMP_DEGREES)
        values["masseCoupledContact"]=NSNumber(value:BLMasseCoupledForShotKind(Int32(kind))>0)
        values["tipProfile"]=NSNumber(value:BLTipForShotKind(Int32(kind)))
    }
    /// Largest effect offset (fraction of R) before a miscue, by tip (Config::tipMaxOffset).
    func tipLimit(elevated:Bool)->Double{
        let tip=Int(BLTipForShotKind(Int32(shotKind)))
        return (elevated ? 0.60:0.70)+(tip==1 ? 0.08:(tip==2 ? -0.05:0))
    }
    func applySquirtPolicy(){
        var values=engine.settings;shotKindPhysics(shotKind,&values);engine.settings=values
    }
    func chooseShotKind(_ kind:Int){
        guard !presentationBusy,!locked,localTurn,(0...3).contains(kind) else{return}
        UserDefaults.standard.set(["elevation":table.cueElevation,"side":side,"top":top],forKey:"cuePreset017-\(shotKind)")
        shotKind=kind;UserDefaults.standard.set(kind,forKey:"shotKind017")
        let role=kind==3 ? 0:kind
        var values=engine.settings;values["cueType"]=NSNumber(value:role);shotKindPhysics(kind,&values);engine.settings=values;table.masseLook=kind==3;table.selectCue(role)
        let preset=UserDefaults.standard.dictionary(forKey:"cuePreset017-\(kind)") as? [String:Double]
        // 0.41 (owner: "chọn cơ Break bị mặc định có độ dốc"): the break cue always starts level. Its saved preset could
        // hold a lift forced over the rail on an earlier shot; the clearance still raises the stroke when needed.
        setElevation(kind==2 ? 0:(preset?["elevation"] ?? (kind==1 ? 45:(kind==3 ? 70:0))))
        spin.select(side:preset?["side"] ?? 0,top:preset?["top"] ?? 0)
        syncQuickRail()
    }
    var toastGeneration=0
    func buildStatusToast(){
        statusToast.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(statusToast)
        statusToast.textColor = .white;statusToast.backgroundColor=UIColor(white:0.035,alpha:0.9)
        statusToast.font = .systemFont(ofSize:13,weight:.medium);statusToast.textAlignment = .center;statusToast.numberOfLines=2
        statusToast.layer.cornerRadius=10;statusToast.clipsToBounds=true;statusToast.isHidden=true
        NSLayoutConstraint.activate([statusToast.centerXAnchor.constraint(equalTo:view.safeAreaLayoutGuide.centerXAnchor),statusToast.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:56),statusToast.widthAnchor.constraint(lessThanOrEqualToConstant:390),statusToast.widthAnchor.constraint(lessThanOrEqualTo:view.safeAreaLayoutGuide.widthAnchor,multiplier:0.7),statusToast.heightAnchor.constraint(greaterThanOrEqualToConstant:44)])
    }
    /// 0.37 "Dự đoán trước": after the shot, draw the line the first object ball needed (contact → pocket centre it
    /// was heading for) and say how many degrees the real line was off.
    func revealPrediction(_ events:[[String:NSNumber]]){
        guard let hit=events.first(where:{$0["kind"]?.intValue==1 && ($0["a"]?.intValue==0 || $0["b"]?.intValue==0)}),
              let t=hit["time"]?.doubleValue else{notifyStatus("Dự đoán: bi cái chưa chạm bi nào");return}
        let target=(hit["a"]?.intValue==0 ? hit["b"]:hit["a"])?.intValue ?? -1
        guard let i=frameTimes.firstIndex(where:{$0>=t}),let j=frameTimes.firstIndex(where:{$0>=t+0.12}),
              let p0=frames[i].first(where:{$0.id==target}),let p1=frames[j].first(where:{$0.id==target}),
              let c0=frames[i].first(where:{$0.id==0}) else{return}
        let dx=p1.x-p0.x,dy=p1.y-p0.y;guard hypot(dx,dy)>1e-4 else{return}
        let travel=atan2(dy,dx)
        let pockets:[(String,Double,Double)]=[("góc dưới trái",-0.670,-1.305),("góc dưới phải",0.670,-1.305),("giữa trái",-0.706,0),("giữa phải",0.706,0),("góc trên trái",-0.670,1.305),("góc trên phải",0.670,1.305)]
        func wrap(_ a:Double)->Double{var x=a;while x>Double.pi{x-=2*Double.pi};while x < -Double.pi{x+=2*Double.pi};return x}
        let best=pockets.min{abs(wrap(atan2($0.2-p0.y,$0.1-p0.x)-travel))<abs(wrap(atan2($1.2-p0.y,$1.1-p0.x)-travel))}!
        let need=atan2(best.2-p0.y,best.1-p0.x),off=wrap(travel-need)*180/Double.pi
        let potted=events.contains{$0["kind"]?.intValue==2 && $0["a"]?.intValue==target}
        table.aimGuide(cue:SIMD2(Float(c0.x),Float(c0.y)),ghost:SIMD2(Float(c0.x),Float(c0.y)),object:SIMD2(Float(p0.x),Float(p0.y)),objectEnd:SIMD2(Float(best.1),Float(best.2)))
        aimGuideShown=true;predictionRevealAngle=angle
        notifyStatus(String(format:"Dự đoán · bi %d %@ lỗ %@: lệch %.1f°",target,potted ? "vào":"tới",best.0,abs(off)))
    }
    /// 0.38 "Chấm độ đều tay": the same layout shot again and again (Tập lại) — how tightly do the cue ball's stopping
    /// points cluster? RMS radius from their centre, in cm; 5 stars under 3 cm (coach standard for a repeatable stroke).
    func scoreConsistency(){
        guard let start=lastShot?.balls,let cb=balls.first(where:{$0.id==0}),!cb.sunk else{return}
        let key=start.sorted{$0.id<$1.id}.map{String(format:"%d:%.3f,%.3f",$0.id,$0.x,$0.y)}.joined(separator:"|")
        if key != consistencyKey {consistencyKey=key;consistencyStops=[]}
        consistencyStops.append(SIMD2(cb.x,cb.y));if consistencyStops.count>10{consistencyStops.removeFirst()}
        let n=consistencyStops.count;guard n>=2 else{return}
        let c=consistencyStops.reduce(SIMD2<Double>(0,0),+)/Double(n)
        let rms=(consistencyStops.map{simd_length_squared($0-c)}.reduce(0,+)/Double(n)).squareRoot()*100
        let stars=rms<3 ? 5:(rms<6 ? 4:(rms<10 ? 3:(rms<16 ? 2:1)))
        notifyStatus(String(format:"Độ đều tay · %d cú cùng thế: điểm dừng chụm ±%.1f cm · %@",n,rms,String(repeating:"★",count:stars)+String(repeating:"☆",count:5-stars)))
    }
    func notifyStatus(_ text:String){
        statusLabel.text=text;statusToast.text="  "+text+"  ";statusToast.isHidden=false;view.bringSubviewToFront(statusToast)
        toastGeneration+=1;let generation=toastGeneration
        DispatchQueue.main.asyncAfter(deadline:.now()+3){[weak self] in guard let self=self,self.toastGeneration==generation else{return};self.statusToast.isHidden=true}
    }
    var lastCoachToggle=0.0
    func toggleCoach(){
        // 0.30: one physical tap can arrive as two touch sequences (seen on CI: 2 taps -> 3 touch-downs); debounce.
        let now=ProcessInfo.processInfo.systemUptime;guard now-lastCoachToggle>0.35 else{return};lastCoachToggle=now
        guard !locked,!spinExpanded else{return};if matchIsCompetitive{matchToggleNumbers();return};coaching.toggle();persistArchiveCoach();applyCoachVisibility()
        if coaching && replayIndex==nil {if lastShot != nil,!shotActive{requestCoachReport(drill:Drill.all[drillIndex],events:lastShotEvents,passed:lastPassed,scratch:lastScratch)}else{showCoach(drillBrief(Drill.all[drillIndex]))}}
    }
    func applyCoachVisibility(){
        guard table != nil else{return}
        wakeRendering()
        if replayIndex != nil{applyReplayCoach();return}
        if matchIsCompetitive{hideCoach();hintLabel.isHidden=true;scoreLabel.isHidden=true;table.setCompetitivePresentation(numbers:matchPlay.showNumbers);coachButton.setTitle("123",for:.normal);return}
        coachButton.setTitle("Coach",for:.normal)
        coachButton.setTitleColor(coaching ? .white:.rgb(0xEAC583),for:.normal)
        coachButton.accessibilityValue=coaching ? "Bật":"Tắt"
        table.showsDiamondNumbers=numbersOn && coaching   // 0.35: Nút số lives under Coach
        table.target(coaching ? Drill.all[drillIndex].goal:nil)
        table.setTrainingOverlaysHidden(!coaching || locked)
        if !coaching {hideCoach();table.showRailContacts([]);table.trails([:]);table.prediction([],visible:false);guideOn=false;lastGuideVisible=false;guideButton?.configuration?.title="Dự báo: tắt"}
        hintLabel.isHidden = !coaching;scoreLabel.isHidden = !coaching
        syncOverlayButtons()
    }

    func setElevation(_ degrees:Double){
        guard !presentationBusy,localTurn,!locked else{return}
        var values=engine.settings;values["cueElevationDegrees"]=NSNumber(value:degrees);values["experimental3D"]=NSNumber(value:degrees>0)
        engine.settings=values;table.cueElevation=degrees
        let followed=Int(BLShotKindForElevation(Int32(shotKind),degrees))
        if followed != shotKind{shotKind=followed;UserDefaults.standard.set(followed,forKey:"shotKind017");applySquirtPolicy();table.masseLook=followed==3;table.selectCue(followed==3 ? 0:followed)}
        spin.maximumOffset=tipLimit(elevated:degrees>0)
        UserDefaults.standard.set(engine.settings,forKey:"physics");guideDirty=true;syncQuickRail()
    }
    func chooseRole(_ role:Int){chooseShotKind(max(0,min(2,role)))}

    func openLibrary(initialTab:Int=0){
        guard localTurn,!presentationBusy else{return};setMenu(false)
        let controller=EquipmentLibraryController(table:table);controller.initialTab=initialTab
        controller.changed={[weak self] role in if let role=role{self?.chooseRole(role)};self?.syncQuickRail()}
        let navigation=UINavigationController(rootViewController:controller);navigation.modalPresentationStyle = .fullScreen;present(navigation,animated:true)
    }
    func equipment(){
        guard matchAllowsEditing else{return}
        guard localTurn,!presentationBusy else{return}
        setMenu(false)
        let controller=CueEquipmentController(settings:engine.settings,table:table)
        controller.apply={[weak self] values in
            guard let self=self else{return}
            self.engine.settings=values
            self.spin.maximumOffset=self.tipLimit(elevated:values["experimental3D"]?.boolValue ?? false)
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
    func setHold(_ held:Bool){
        locked=held && strokeAllowed
        powerFX.showMeter(locked)
        wakeRendering();table.setTrainingOverlaysHidden(locked);coachCard.isHidden=locked || !cardOn || coachCard.alpha==0
        for recognizer in aimRecognizers{recognizer.isEnabled = !locked}
        stroke.isUserInteractionEnabled=locked;stroke.isEnabled=locked
        menuButton.isHidden=locked
        fineWheel.isHidden=menuOpen   // 0.30: fine aim stays usable while the effect ball is held
        spin.isHidden=menuOpen   // 0.30b: the effect ball stays (it is the lock)
        quickScroll.isHidden=locked || menuOpen;elevationPad.isHidden=locked || menuOpen || spinExpanded;lockButton.isHidden=menuOpen || spinExpanded
        for icon in cueIcons{icon.isHidden=locked || menuOpen || spinExpanded}
        coachButton.isHidden=locked || menuOpen
        syncOverlayButtons()
        table.setTrainingOverlaysHidden(!coachOn || locked)
        if !locked{stroke.cancelStroke();pull=0;if matchIsCompetitive{table.setCompetitivePresentation(numbers:matchPlay.showNumbers)}}
    }
    /// Trục của lần kéo một ngón hiện tại: 0 chưa quyết, 1 ngang (hướng ngắm), 2 dọc (độ cao camera).
    var aimPanAxis=0
    var presentationBusy:Bool{shotActive || replayIndex != nil || replayPreparing || BLShotCameraBusy(shotCameraState)}
    var strokeHint:String{
        "Chọn gậy → ngắm → giữ bi effect (khóa hướng, chỉnh điểm chạm) → ngón khác kéo lùi rồi đẩy tới: nhanh hơn là mạnh hơn. Buông bi effect để ngắm lại."
    }

    var strokeAllowed:Bool{
        BLStrokeAllowed(localTurn && matchCanStroke,presentationBusy,menuOpen,spinExpanded,isPlacingBalls,cue?.sunk==false)
    }
    var balls:[BallState]{matchDisplayedBalls ?? frameStateCache ?? engine.states.map{BallState($0)}}
    var cue:BallState?{balls.first{$0.id==0}}
    func loadDrill(_ index:Int){
        guard matchAllowsEditing else{return}
        guard !presentationBusy,localTurn else{return}
        drillIndex=index;attempts=0;successes=0;lessonActive=false;lessonScores=[];lessonPasses=0;let drill=Drill.all[index]
        table.target(coachOn ? drill.goal:nil)
        initial=drill.balls;before=initial;angle=drill.angle
        engine.loadLayout(initial.map{$0.dictionary});clearShot();locked=false;isPlacingBalls=false;spin.reset()
        titleLabel.text=drill.title;hintLabel.text=strokeHint
        statusLabel.text="Trắng: bi cái · Vàng: bi 1";updateControls();refresh()
        table.showRailContacts([])
        table.showsDiamondNumbers=numbersOn && coaching
        if coachOn && (drill.goal != nil || drill.rails>0) {showCoach(drillBrief(drill))}else{hideCoach()}
    }
    func clearShot(){if let restore=forcedElevationRestore{engine.settings=restore;forcedElevationRestore=nil};
        coachGeneration+=1;predictionGeneration+=1
        if replayIndex != nil{stopReplay()};releasePeek();replayBar.isHidden=true
        aimBuffer=[];lastPreparation=[];replayPreparation=nil
        frames=[];frameTimes=[];paths=[:];shotActive=false;replayIndex=nil;lastEventCount=0
        BLShotCameraReset(&shotCameraState);table.trails([:]);guideDirty=true
        table.resetPocketPresentation();shotCameraAnchor=nil
    }
    // MARK: Cơ tránh băng (BankLab/UI/CueClearance.h, Tests/CueClearanceTests.cpp)
    struct TableGeometry {var width=1.27,length=2.54,radius=0.028575,nose=0.27}
    var geometry=TableGeometry()
    /// Góc nghiêng tối đa cho cú thường (không bật cơ nâng 3D): 35° — giả định, cần đối chiếu trên bàn thật.
    var maxStrokeElevation:Double{(engine.settings["experimental3D"]?.boolValue ?? false) ? 80:45}   // 0.37: 45° — frozen-to-rail top shots need ~38° over the rendered rail
    func cueClearance(side s:Double,top t:Double)->Double{
        guard let c=cue,!c.sunk else{return 0}
        // 0.30: balls behind the cue ball count too — the cue is never drawn through a ball.
        var xs=obstacleXs,ys=obstacleYs
        return BLCueMinimumElevationBalls(c.x,c.y,angle,s,t,geometry.width,geometry.length,geometry.radius,geometry.nose,&xs,&ys,Int32(xs.count))
    }
    /// Object-ball positions for the clearance test; refreshed in updateCueClearance (the effect pad samples it often).
    var obstacleXs:[Double]=[],obstacleYs:[Double]=[]
    func updateCueClearance(){
        let g=engine.settings
        geometry=TableGeometry(width:g["tableWidth"]?.doubleValue ?? 1.27,length:g["tableLength"]?.doubleValue ?? 2.54,
                               radius:g["ballRadius"]?.doubleValue ?? 0.028575,nose:g["railHeight"]?.doubleValue ?? 0.27)
        let limit=maxStrokeElevation
        let others=balls.filter{$0.id != 0 && !$0.sunk};obstacleXs=others.map{$0.x};obstacleYs=others.map{$0.y}
        if spin.reachable==nil {
            spin.reachable={[weak self] x,y in guard let self=self else{return true};return self.cueClearance(side:x,top:y)<=self.maxStrokeElevation}
            spin.clampTop={[weak self] x,y in
                guard let self=self,let c=self.cue else{return y}
                var xs=self.obstacleXs,ys=self.obstacleYs
                return BLCueClampTopBalls(c.x,c.y,self.angle,x,y,self.geometry.width,self.geometry.length,self.geometry.radius,self.geometry.nose,self.maxStrokeElevation,self.spin.maximumOffset,&xs,&ys,Int32(xs.count))
            }
        }
        if cueClearance(side:side,top:top)>limit {spin.select(side:side,top:top)} // select() kẹp lên vùng với tới
        table.clearanceElevation=cueClearance(side:side,top:top)
        elevationPad.minimum=min(table.clearanceElevation,85)   // 0.37: the fan follows the real (auto-raised) cue live
        spin.setNeedsDisplay()
    }
    func refresh(){wakeRendering();updateCueClearance();table.update(balls,dt:0);guideDirty=true;scoreLabel.text="\(successes) / \(attempts) đạt · góc \(String(format:"%.1f",angle*180/Double.pi))°"}
    func updateControls(){
        let busy=presentationBusy
        syncCueIcons()
        fineWheel.isEnabled = !busy && localTurn && !isPlacingBalls
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
        syncQuickRail();syncMatchControls()
        spin.isEnabled = !busy && localTurn && !isPlacingBalls;editButton.configuration?.title=isPlacingBalls ? "Xong đặt bi":"Đặt bi"
        for b in [drillButton,layoutButton,settingsButton,editButton] {b?.isEnabled = !busy && localTurn}
        replayButton.isEnabled = !shotActive && !frames.isEmpty && localTurn
        replayButton.configuration?.title=replayIndex == nil ? "Xem lại":"Dừng xem"
        undoButton.isEnabled = !before.isEmpty && localTurn
        retryButton.isEnabled = !before.isEmpty && !isPlacingBalls && localTurn && !spinExpanded
        syncMatchControls()
    }
    func nudge(_ amount:Double){guard !locked,!isPlacingBalls,!shotActive,replayIndex==nil else{return};angle+=amount;refresh()}
    func captureCamera()->CameraPose{CameraPose(mode:table.cameraMode,zoom:table.zoom,yaw:table.orbit,pitch:table.orbitPitch,aimPitch:table.aimPitch,focus:table.focusBounds)}
    func applyCamera(_ pose:CameraPose){
        table.cameraMode=pose.mode;table.zoom=pose.zoom;table.orbit=pose.yaw;table.orbitPitch=pose.pitch;table.aimPitch=pose.aimPitch
        table.focusBounds=pose.focus;observationCamera=pose.mode != 2;beginCameraTransition(0.35)
    }
    func selectCamera(_ mode:Int){
        guard (0...2).contains(mode),!locked else{return}
        cameraMemory[table.cameraMode]=captureCamera()
        let pose=cameraMemory[mode] ?? CameraPose(mode:mode,zoom:1,yaw:0,pitch:0.85,aimPitch:table.aimPitch)
        applyCamera(pose);observationCamera=mode != 2
        if mode != 2{lastObservedMode=mode}
        if shotActive{cameraManual=true}
        cameraButton.configuration?.title=["Toàn bàn","Trên cao","Ngắm cơ"][mode];syncQuickRail()
    }
    func beginCameraTransition(_ duration:Double){cameraTransitionDuration=duration;cameraTransition=duration}
    func restoreAimCamera(transition:Double=0.45){
        guard localTurn,replayIndex==nil else{return}
        releasePeek()
        var saved=savedAimCamera ?? cameraMemory[2] ?? CameraPose(mode:2,zoom:1,yaw:0,pitch:0.57,aimPitch:table.aimPitch)
        // 0.38 Tuỳ chỉnh · góc ngắm mặc định: once set, the camera always comes back to it after a shot.
        if UserDefaults.standard.object(forKey:"tuneAimPitch038") != nil{saved.aimPitch=Float(Tuning.aimPitch)}
        if UserDefaults.standard.object(forKey:"tuneAimZoom038") != nil{saved.zoom=Float(Tuning.aimZoom)}
        aimCameraYaw=0;shotCameraAnchor=nil;applyCamera(saved);table.cameraMode=2;observationCamera=false;table.focusBounds=nil
        beginCameraTransition(transition);cameraButton.configuration?.title="Ngắm cơ";syncQuickRail()
    }
    func eyeDown(){
        eyePressDuringShot=shotActive || BLShotCameraBusy(shotCameraState);wakeRendering()
        eyeHoldWork?.cancel()
        guard !eyePressDuringShot,replayIndex==nil,!isPlacingBalls else{return}
        // Held 0.25 s = peek at the other view (aim <-> overview); releasing returns at once.
        let work=DispatchWorkItem{[weak self] in
            guard let self=self,self.quickCamera.isTracking,self.peekPose==nil else{return}
            self.peekPose=self.captureCamera();self.aimCameraYaw=0;self.shotCameraAnchor=nil
            self.selectCamera(self.table.cameraMode==2 ? 1:2)   // 0.30b: aim <-> top-down 2D
        }
        eyeHoldWork=work;DispatchQueue.main.asyncAfter(deadline:.now()+0.25,execute:work)
    }
    func releasePeek(){
        eyeHoldWork?.cancel();eyeHoldWork=nil
        guard let pose=peekPose else{return};peekPose=nil;applyCamera(pose);syncQuickRail()
    }
    func eyeUp(){
        eyeHoldWork?.cancel();eyeHoldWork=nil
        let observingShot=eyePressDuringShot;eyePressDuringShot=false
        if peekPose != nil{releasePeek();return}
        if observingShot{return}
        guard !shotActive,replayIndex==nil,!isPlacingBalls,!locked else{return}
        // Quick tap toggles between the two views the owner kept: aim (2) and top-down 2D (1) — 0.30b.
        aimCameraYaw=0;shotCameraAnchor=nil;selectCamera(table.cameraMode==2 ? 1:2);syncQuickRail()
    }
    func directCamera(time:Double,state:[BallState],replay:Bool){
        guard replay,replayAuto,!cameraManual else{return}
        guard let frame=replayPlan?.frame(time:time,balls:state) else{return}
        if lastDirectorTime != Double(frame.segmentID){beginCameraTransition(lastDirectorTime < -5 ? 0.0:0.9);lastDirectorTime=Double(frame.segmentID)}   // 0.37: slow cinematic glide
        table.cameraMode=frame.mode;table.zoom=frame.zoom;table.orbit=frame.yaw;table.focusBounds=frame.focus
        if frame.mode==2{table.aimPitch=frame.pitch}else{table.orbitPitch=frame.pitch}
    }
    func resetShotInputsAndAim(){
        spin.reset();side=0;top=0
        if shotKind==1 {
            shotKind=0;var settings=engine.settings;settings["cueType"]=0;settings["cueElevationDegrees"]=0;settings["experimental3D"]=false;shotKindPhysics(0,&settings)
            engine.settings=settings;table.selectCue(0);table.cueElevation=0;spin.maximumOffset=0.7;UserDefaults.standard.set(0,forKey:"shotKind017")
        }
        if let c=cue,!c.sunk,let target=matchPreferredAimTarget(in:balls) {
            let old=angle;angle=atan2(target.y-c.y,target.x-c.x);aimCameraYaw+=old-angle
        }
        syncQuickRail();guideDirty=true;wakeRendering()
    }

    func cycleCamera(){
        let sheet=UIAlertController(title:"Góc nhìn",message:nil,preferredStyle:.actionSheet)
        for (index,title) in ["Toàn bàn · quan sát cú đánh","Trên cao · luyện thế bi","Ngắm cơ · sát bi"].enumerated(){
            sheet.addAction(UIAlertAction(title:title,style:.default){[weak self]_ in
                self?.selectCamera(index)
                self?.cameraButton.configuration?.title=["Toàn bàn","Trên cao","Ngắm cơ"][index]
                self?.setMenu(false);self?.syncQuickRail()
            })
        }

        sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(sheet,source:menuButton)
    }
    func placementValid()->Bool{
        let state=balls.filter{!$0.sunk}
        for (i,a) in state.enumerated(){for b in state.dropFirst(i+1){if hypot(a.x-b.x,a.y-b.y)<geometry.radius*2+0.0001{return false}}}
        return state.contains{$0.id==0}
    }
    func toggleEdit(){
        if handleMatchPlacementToggle(){return}
        guard !presentationBusy,localTurn,!locked else{return}
        if isPlacingBalls {
            guard placementValid() else{notifyStatus("Vị trí đang vướng bi khác — kéo bi cái ra vùng trống");return}
            isPlacingBalls=false;table.placementBlocked=false;editingSnapshot=nil
            initial=balls;before=balls;clearShot();if let pose=editingPose{applyCamera(pose)};editingPose=nil
        }else{
            hideCoach();editingSnapshot=balls;editingPose=captureCamera();isPlacingBalls=true
            var state=balls
            // 0.22: free spot nearest the centre (BLFreeSpotNearCentre), never on top of another ball.
            let others=state.filter{$0.id != 0 && !$0.sunk},geo=engine.settings
            var xs=others.map{$0.x},ys=others.map{$0.y},fx=0.0,fy=0.0
            _=BLFreeSpotNearCentre(&xs,&ys,Int32(others.count),geo["ballRadius"]?.doubleValue ?? 0.028575,(geo["tableWidth"]?.doubleValue ?? 1.27)/2,(geo["tableLength"]?.doubleValue ?? 2.54)/2,&fx,&fy)
            // 0.30 (owner item 22): in practice, back to where the cue ball was for the last shot when that spot is free.
            let r=geo["ballRadius"]?.doubleValue ?? 0.028575
            if lastShot != nil,!matchIsCompetitive,let last=before.first(where:{$0.id==0 && !$0.sunk}),
               others.allSatisfy({hypot($0.x-last.x,$0.y-last.y)>2*r+0.002}) {fx=last.x;fy=last.y}
            if let i=state.firstIndex(where:{$0.id==0}){state[i].x=fx;state[i].y=fy;state[i].sunk=false}else{state.append(BallState(id:0,x:fx,y:fy))}
            engine.loadLayout(state.map{$0.dictionary});selectCamera(1)
            table.placementBlocked = !placementValid();notifyStatus("Bi cái về chỗ vừa đánh (hoặc ô trống gần giữa bàn) · kéo để chỉnh · Xong để nhận · Hủy để phục hồi")
        }
        refresh();updateControls();syncQuickRail()
    }
    func cancelPlacement(){
        if handleMatchPlacementCancel(){return}
        guard isPlacingBalls,let snapshot=editingSnapshot else{return}
        engine.loadLayout(snapshot.map{$0.dictionary});isPlacingBalls=false;table.placementBlocked=false;editingSnapshot=nil
        if let pose=editingPose{applyCamera(pose)};editingPose=nil;refresh();updateControls()
    }

    func shoot(_ speed:Double){
        // 0.41 (owner: "cú phá đầu tiên không thao tác được"): the first stroke of a rack only ended the rack intro and
        // was thrown away. The intro is presentation only (the solver already holds the rack): end it and play the shot.
        if table.rackIntroPlaying{table.skipRackIntro()}
        if routeMatchShot(speed){return}
        guard locked,strokeAllowed,speed.isFinite,speed>0 else{return}
        capturePreparation(time:ProcessInfo.processInfo.systemUptime)
        let origin=aimBuffer.first?.time ?? 0
        lastPreparation=aimBuffer.map{var sample=$0;sample.time-=origin;return sample}
        aimBuffer.removeAll()
        coachGeneration+=1;predictionGeneration+=1
        lastShotSpeed=speed
        displayDurations=[]
        table.pacer.clear()
        table.pacer.interval=1.5/Double(Tuning.frameRate)   // 0.39d: half a frame of slack for main-thread jitter
        table.pacer.resetDiagnostics();shotProfile=ShotProfile()
        // Seed the pre-strike pose, so the first interpolated frame includes
        // the start of the stroke rather than jumping to the first sample.
        let previousPresentAt=table.presentAt
        table.presentAt=lastTime>0 ? lastTime:CACurrentMediaTime()
        table.update(balls,dt:0)
        table.presentAt=previousPresentAt
        testSpeed=speed
        hintLabel.text=String(format:"Cú vuốt vừa rồi · %.2f m/s · %@",speed,CueLook.roles[engine.settings["cueType"]?.intValue ?? 0])
        shotCameraAnchor=cue;liveCameraAngle=angle
        if table.cameraMode==2 {savedAimCamera=captureCamera()}
        BLShotCameraStart(&shotCameraState)
        cameraManual=false;lastDirectorTime = -10;peekPose=nil;lastShotEvents=[]
        if !matchIsCompetitive{shotBack.append(ShotStep(balls:balls,setup:currentSetup()));shotForward.removeAll()}
        before=balls;frames=[before];frameTimes=[0];paths=[:];sampleClock=0;lastEventCount=0
        // 0.37 (owner): a cue raised over the rail / a ball behind is a REAL elevated stroke — squirt fades in with the
        // elevation (squirtRampDegrees) and the 3D strike adds swerve/hop by speed. Restored when the shot ends.
        var strikeElevation=table.cueElevation
        let forced=min(table.clearanceElevation,85)
        if forced>table.cueElevation+0.25 {
            forcedElevationRestore=engine.settings
            var values=engine.settings;values["cueElevationDegrees"]=NSNumber(value:forced);values["experimental3D"]=true
            engine.settings=values;strikeElevation=forced
        }
        let strikeAngle=table.shotAngle(cue,angle:angle,side:side,top:top)
        lastShot=SavedShot(name:"",date:Date(),balls:balls,aimAngle:angle,speed:speed,side:side,top:top,
                           elevation:strikeElevation,cueType:engine.settings["cueType"]?.intValue ?? 0,strikeAngle:strikeAngle,shotKind:shotKind,physicsSettings:engine.settings.mapValues{$0.doubleValue})
        hideCoach()
        engine.strike(angle:strikeAngle,speed:speed,side:side,top:top)
        if UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true {poolAudio.play(kind:3,impact:speed,pan:audioPan(cue?.x ?? 0,cue?.y ?? 0))}
        shotActive=true;didStartMatchShot();attempts+=1;statusLabel.text=String(format:"Đang chạy · tốc độ đầu %.2f m/s",speed)
        feedback.impactOccurred();guideDirty=true;table.trails([:]);setMenu(false);updateControls()
    }
    @objc func tick(_ link:CADisplayLink){
        // Cold shader compilation can outlast the wake requested in viewDidLoad.
        // Always present the initial camera and accessibility state on first tick.
        if lastTime==0{startupRenderUntil=ProcessInfo.processInfo.systemUptime+8;wakeRendering()}
        // 0.33: advance to the time this frame will be SHOWN (targetTimestamp), not when the callback ran — removes the
        // judder of variable callback latency; on ProMotion the shot runs at up to 120 Hz.
        let shownAt=link.targetTimestamp
        let dt=lastTime==0 ? 0:min(0.1,max(0,shownAt-lastTime));lastTime=shownAt
        frameStateCache=nil;defer{frameStateCache=nil}
        // 0.39 (owner: Wi-Fi/online break impossible, all keys grey on both phones). Belt and braces: a network state
        // change that arrives without a callback (link up, relay peer, snapshot) can no longer leave the turn stale —
        // twice a second the real permission is compared with what the controls show, and re-synced if they differ.
        if matchPlay.active, shownAt-lastTurnCheck>0.5 {
            lastTurnCheck=shownAt
            if matchAllowsInput != localTurn {syncMatchControls()}
            else if matchPlay.session.role == .host && !shotActive {publishMatchSnapshot()}   // de-duplicated by the session
            matchNetworkWatch()   // 0.41: opponent away · turn timeout · forfeit
        }
        capturePreparation(time:ProcessInfo.processInfo.systemUptime)
        let guestTick=matchGuestTick(dt)
        driveComputerTurn()   // 0.40 Đấu với máy (no-op unless it is the computer's turn at rest)
        tickShotClock(dt)     // 0.40b đồng hồ cú + gia hạn (no-op when off)
        // Keep rendering until a Premium QA probe has recorded its result; slow
        // Simulator GPUs can need longer than the startup window.
        let premiumPending = !premiumProbeWritten && ProcessInfo.processInfo.arguments.contains("--premium-qa")
        // 0.37 (owner video: 30 fps while dragging the aim/camera): any live touch gesture keeps the full rate.
        let touching=aimRecognizers.contains{$0.state == .began || $0.state == .changed}
        if touching {renderUntil=max(renderUntil,ProcessInfo.processInfo.systemUptime+0.25)}
        // 0.37 (owner chose): keys fade while the player aims so the table is fully visible; back on release.
        let fade=touching && Tuning.hudFade && !locked && !menuOpen
        if fade != hudFaded {hudFaded=fade;applyHUDFade()}
        let active=premiumPending || touching || ProcessInfo.processInfo.systemUptime<startupRenderUntil || (shotActive && !matchSimulationPaused) || replayIndex != nil || table.hasActivePocketAnimations || (BLShotCameraBusy(shotCameraState) && !matchSimulationPaused) || locked || ProcessInfo.processInfo.systemUptime<renderUntil || cameraTransition>0
        let guestMoving=guestTick && matchPlay.session.isConnected && matchPlay.session.latestSnapshot?.isMoving==true
        // 0.35 (owner: still judders and the phone gets hot): 120 Hz doubled GPU work and heat without curing the judder.
        // One fixed 60 Hz cadence for simulation and rendering; idle drops to 15 Hz.
        // 0.39: SceneKit's own loop must run at the same rate as the tick, or paced frames repeat (120 Hz tick, 60 Hz view).
        if scn.preferredFramesPerSecond != Tuning.frameRate {scn.preferredFramesPerSecond=Tuning.frameRate}
        table.presentAt=link.targetTimestamp
        defer{
            table.presentAt=nil
            if let start=shotTickStart {shotTickStart=nil;if shotProfile.tick.count<3600 {shotProfile.tick.append(CACurrentMediaTime()-start)}}
        }
        // Keep the presentation delay fixed through a motion segment. Changing
        // it on a missed refresh would move the sampling clock backwards.
        // 0.39c: the idle link runs at 30 Hz, so its duration is NOT the active refresh; use the chosen rate.
        if !table.pacer.isActive {table.pacer.interval=1.5/Double(Tuning.frameRate)}
        // 0.36: idle 30 (15 made the first aim frame lag); active 60/120 from Tuỳ chỉnh. 0.39c: set only on change.
        let wantRate=active ? Tuning.frameRate:30,playing=active || guestMoving
        if displayLink?.preferredFramesPerSecond != wantRate {displayLink?.preferredFramesPerSecond=wantRate}
        if scn.isPlaying != playing {scn.isPlaying=playing}
        if scn.rendersContinuously != playing {scn.rendersContinuously=playing}
        if hudLayoutDeferred && !shotActive && replayIndex == nil && !guestMoving {hudLayoutDeferred=false;view.setNeedsLayout()}

        if !active && !guestMoving && !(coachOn && guideOn && guideDirty){missWindow=0;missCount=0;return}
        // 0.37: adaptive quality — if more than 25 % of active frames over 2 s miss their slot, drop one render level
        // (shadow samples / map size). Physics and interpolation are unaffected (render cost only).
        if dt>0 {
            missWindow+=dt;if dt>1.5/Double(Tuning.frameRate){missCount+=1}
            if missWindow>=2 {
                let frames=missWindow*Double(Tuning.frameRate)
                // 0.39b ROOT CAUSE of mid-shot freezes: a level change alters the shadow sample count = a new shader
                // variant, compiled on the spot (100–300 ms stall) — right while balls roll, which caused more missed
                // frames and another drop. Level changes now wait until the table is still (no shot, no replay).
                let still = !shotActive && replayIndex==nil && !table.hasActivePocketAnimations
                if !still {if Double(missCount)>0.25*frames {pendingLevelCheck=true}}
                else if (pendingLevelCheck || Double(missCount)>0.25*frames) && table.performanceLevel<2 {table.setPerformanceLevel(table.performanceLevel+1);cleanSeconds=0;pendingLevelCheck=false}
                // 0.38: climb back when the device keeps up for 20 s and is not warm.
                else if still && Double(missCount)<0.03*frames && table.performanceLevel>0 && ProcessInfo.processInfo.thermalState.rawValue<=ProcessInfo.ThermalState.fair.rawValue {
                    cleanSeconds+=missWindow;if cleanSeconds>=20{table.setPerformanceLevel(table.performanceLevel-1);cleanSeconds=0}
                }
                missWindow=0;missCount=0
            }
        }
        if pendingThermal && !shotActive && replayIndex==nil {pendingThermal=false;thermalChanged()}
        let wasSimulating=shotActive,wasReplaying=replayIndex != nil
        if let index=replayIndex {
            let direction=replayPlan?.frame(time:replayClock,balls:frames[index])
            let endingRate=ReplayDirector.endingRate(time:replayClock,duration:frameTimes.last ?? 0)
            let rate=replayClock<0 || Self.replayNoSlowAB ? 1:min(endingRate,replayAuto && !cameraManual ? (direction?.slowMotion ?? 1):1)
            replayClock += replayPaused ? 0:dt*replaySpeed*rate
            var i=index
            while i+1<frames.count && replayClock>=frameTimes[i+1] {i+=1}
            if replayClock>=(frameTimes.last ?? 0)+Self.replayTail && qaReplayHold {replayClock=(frameTimes.last ?? 0)+Self.replayTail;replayPaused=true}   // QA: hold the last frame until Done
            if replayClock>=(frameTimes.last ?? 0)+Self.replayTail && !qaReplayHold {stopReplay()}
            else{
                replayIndex=i
                let j=min(i+1,frames.count-1)
                let span=frameTimes[j]-frameTimes[i]
                table.replay(frames[i],to:frames[j],fraction:span>0 ? (replayClock-frameTimes[i])/span:0,span:span)
                replayPreparation=nil
                if replayClock<0 {
                    let clock=replayClock+preparationDuration   // sample time in the recorded preparation (lead may be shorter)
                    replayPreparation=lastPreparation.last(where:{$0.time<=clock}) ?? lastPreparation.first
                    // 0.37 (owner): the replay opens on the wide establishing shot, also during the 1.5 s lead-in.
                    if replayAuto,!cameraManual {directCamera(time:0,state:frames[0],replay:true)}
                    if replayCamera>=4 {updateActionCamera(0,0,fraction:0,span:0,dt:dt)}   // 0.41: action cams run in the lead-in too
                }else{
                    directCamera(time:replayClock,state:frames[i],replay:true)
                    if replayCamera>=4 {updateActionCamera(i,j,fraction:span>0 ? (replayClock-frameTimes[i])/span:0,span:span,dt:dt)}
                    if !replayStrikePlayed {
                        replayStrikePlayed=true
                        if !replayPaused,UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true{poolAudio.play(kind:3,impact:lastShot?.speed ?? 1,pan:0)}
                    }
                }
                replaySlider.value=Float(replayClock)
                if let recorder=highlightRecorder{recorder.capture(scn.snapshot(),now:ProcessInfo.processInfo.systemUptime)}
                if !replayPaused {playReplayAudio()}
            }
        }else if shotActive && !guestTick && !matchSimulationPaused {
            if dt>0 {displayDurations.append(dt);if displayDurations.count>3600{displayDurations.removeFirst(displayDurations.count-3600)}}
            // 0.37 (owner replay: object ball moving before the cue ball arrives): frames were sampled at 30 Hz, so a
            // 6 m/s jump shot moved 20 cm between samples and slow-motion interpolation started the object ball early.
            // Advance in 1/240 s chunks and sample by speed: 240 Hz while anything is fast, 60 Hz medium, 30 Hz slow.
            var remaining=dt
            let tickStart=CACurrentMediaTime();var physicsTime=0.0,recordTime=0.0
            while remaining>1e-9 {
                let p0=CACurrentMediaTime()
                let h=min(1.0/240.0,remaining);engine.advance(h);remaining-=h;sampleClock+=h
                let fastest=engine.maximumSpeed
                let p1=CACurrentMediaTime();physicsTime+=p1-p0
                defer{recordTime+=CACurrentMediaTime()-p1}
                let interval=fastest>0.8 ? 1.0/240.0:(fastest>0.25 ? 1.0/60.0:1.0/30.0)
                if sampleClock>=interval-1e-9 {
                    shotProfile.recordedSamples+=1
                    let chunk=engine.states.map{BallState($0)}
                    sampleClock=0
                    frames.append(chunk);frameTimes.append(engine.elapsed)
                    if frames.count%4==0{for b in chunk where !b.sunk {paths[b.id,default:[]].append(SIMD3<Float>(Float(b.x),Float((b.height ?? 0)+0.004),Float(b.y)))}}
                }
            }
            // Dispatch impacts before rendering, labels or archive sampling.
            let e0=CACurrentMediaTime()
            let fresh=engine.events(since:UInt(lastEventCount))
            if !fresh.isEmpty {
                if UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true {
                    for event in fresh {poolAudio.play(kind:event["kind"]?.intValue ?? 1,impact:event["impact"]?.doubleValue ?? 0.3,pan:audioPan(event["x"]?.doubleValue ?? 0,event["y"]?.doubleValue ?? 0),eventAge:max(0,engine.elapsed-(event["time"]?.doubleValue ?? engine.elapsed)))}
                }
                lastEventCount+=fresh.count
            }
            didAdvanceMatchShot()
            let s0=CACurrentMediaTime()
            let state=engine.states.map{BallState($0)};frameStateCache=state
            table.update(engine.presentationStates.map{BallState($0)},dt:dt)
            let s1=CACurrentMediaTime()
            if shotProfile.tick.count<3600 {
                shotProfile.physics.append(physicsTime);shotProfile.record.append(recordTime)
                shotProfile.events.append(s0-e0);shotProfile.scene.append(s1-s0)
            }
            shotTickStart=tickStart
            // The multiline status label lives inside the menu's Auto Layout stack.
            // Updating it while that menu is hidden can invalidate layout at 5 Hz;
            // viewDidLayoutSubviews then lays out the whole HUD and wakes rendering.
            // Keep live status work tied to visibility. finishShot supplies the result.
            if menuOpen || Self.legacyStatusAB,link.timestamp-lastStatusTime>0.2,let cb=state.first(where:{$0.id==0}),!cb.sunk {
                lastStatusTime=link.timestamp
                statusLabel.text=String(format:"Đang chạy · %.2f m/s · %.1f s",hypot(cb.vx ?? 0,cb.vy ?? 0),engine.elapsed)
            }
            if !engine.moving || engine.elapsed>60 {finishShot(timedOut:engine.moving);frameStateCache=nil}
        }
        table.animatePockets(dt)
        let wasBusy=BLShotCameraBusy(shotCameraState)
        let cameraGestureActive=peekPose != nil || aimRecognizers.contains{recognizer in
            (recognizer is UIPinchGestureRecognizer || (recognizer as? UIPanGestureRecognizer)?.minimumNumberOfTouches==2) && (recognizer.state == .began || recognizer.state == .changed)
        }
        let authorityReadiness=localTurn || (matchIsCompetitive && matchPlay.session.role != .guest)
        if BLShotCameraTick(&shotCameraState,dt,wasSimulating || shotActive || engine.moving,table.hasActivePocketAnimations,wasReplaying || replayIndex != nil,authorityReadiness,isPlacingBalls,cameraGestureActive) {
            wakeRendering() // Readiness gate; practice keeps the live camera pose.
            // 0.29: in a match (also pass-and-play on one device) the player to shoot starts in the aim view.
            // 0.36 (owner: 0.35 still did not return): the shot camera usually STAYS in mode 2 while it follows the
            // balls, so "cameraMode != 2" never fired. Once everything stops, always restore the saved aim pose behind
            // the cue ball (yaw 0, zoom kept) — match and practice alike.
            if localTurn && replayIndex == nil && peekPose == nil && !isPlacingBalls {restoreAimCamera(transition:0.2)}
        }
        // 0.41 (owner: after the opponent's shot, B stayed hidden and the turn could not be played). The host published
        // its end-of-shot snapshot while the shot camera was still settling (isMoving = true) and nothing re-published
        // when it settled, so the guest waited forever. Any readiness change now re-syncs the match (host republishes).
        if wasBusy != BLShotCameraBusy(shotCameraState){if matchPlay.active{syncMatchControls()};updateControls()}
        if qaAwaitingAimReturn && !presentationBusy {
            precondition(qaPeekReleased,"Camera settled before observation completed")
            precondition(table.cameraMode==2,"Live shot changed camera mode")
            precondition(abs(table.zoom-1.18)<0.001,"G1: selected aim zoom was lost")
            precondition(abs(angle+aimCameraYaw-qaExpectedCameraAngle)<0.00001,"Next-ball aiming changed the live camera angle")
            precondition(!table.hasActivePocketAnimations && !engine.moving)
            qaAwaitingAimReturn=false;recordG1QA("return",["cameraMode":table.cameraMode,"zoom":table.zoom,"settleSeconds":BL_SHOT_READY_SECONDS,"cameraAngle":angle+aimCameraYaw,"expectedCameraAngle":qaExpectedCameraAngle,"automaticViewChanges":0])
        }
        let displayCue:BallState? = replayIndex.flatMap{frames[$0].first{$0.id==0}} ?? cue
        var cameraCue=displayCue
        if replayIndex==nil,let anchor=shotCameraAnchor {cameraCue=anchor}
        if displayCue?.sunk==true,let anchor=shotCameraAnchor {cameraCue=anchor}
        var cameraAngle=(shotActive ? liveCameraAngle:angle)+aimCameraYaw
        if replayIndex != nil {cameraCue=frames.first?.first(where:{$0.id==0});cameraAngle=(replayPreparation?.angle ?? lastShot?.aimAngle ?? angle)+replayYaw
            if let sample=replayPreparation,replayAuto,!cameraManual{cameraAngle=sample.angle+sample.cameraYaw}
        }
        let blend=BLCameraTweenBlend(cameraTransition,dt,cameraTransitionDuration)
        table.placeCamera(cue:cameraCue,angle:cameraAngle,aspect:scn.bounds.width/max(1,scn.bounds.height),blend:Float(blend))
        if !premiumProbeWritten,ProcessInfo.processInfo.arguments.contains("--premium-qa"),scn.bounds.width>scn.bounds.height {
            // Settled = the authoritative (model) camera pose is unchanged for 20
            // consecutive ticks after cold start. The presentation node is only
            // refreshed by a rendered frame, so it is reported, not required.
            let eye=table.camera.simdPosition
            let step=premiumProbeEye.map{simd_distance($0,eye)} ?? 1
            let uptimeNow=ProcessInfo.processInfo.systemUptime
            if step<0.001 {premiumProbeStable+=1} else {premiumProbeStable=0;premiumProbeLastMove=uptimeNow}
            premiumProbeEye=eye
            let uptime=ProcessInfo.processInfo.systemUptime
            // Slow simulators (Intel CI) render few frames once idle: also accept a pose unchanged for 1 s of
            // wall time across at least two samples. Same criterion (model pose unchanged), tick-rate independent.
            let settled=(premiumProbeStable>=10 || (premiumProbeStable>=1 && uptime-premiumProbeLastMove>=1.0)) && uptime>startupRenderUntil-5
            if settled || uptime>startupRenderUntil+12 {
                let high=ProcessInfo.processInfo.arguments.contains("--premium-high")
                let args=ProcessInfo.processInfo.arguments
                let name=args.contains("--camera-top") ? "top":(args.contains("--camera-aim") ? "aim":"overview")
                let expected=name=="top" ? 1:(name=="aim" ? 2:0)
                let valid=settled && table.cameraMode==expected && eye.y>0.02 && table.usesHighDetail==high
                recordG1QA("premium-"+(high ? "high-":"")+name,["result":valid ? "PASS":"FAIL","settled":settled,"stableTicks":premiumProbeStable,"lastStep":Double(step),"secondsAfterStart":uptime-(startupRenderUntil-8),"cameraMode":table.cameraMode,"expectedMode":expected,"eyeY":Double(eye.y),"presentationDelta":Double(simd_distance(table.camera.presentation.simdPosition,eye)),"highDetail":table.usesHighDetail,"aspect":Double(scn.bounds.width/scn.bounds.height)])
                premiumProbeWritten=true
            }
        }
        if !cameraInitialCommit{SCNTransaction.flush();cameraInitialCommit=true}
        cameraTransition=max(0,cameraTransition-dt)
        if shotActive && shotKind==1 {qaJumpSeen=true}
        if ProcessInfo.processInfo.arguments.contains("--visual-qa"){scn.accessibilityValue=String(format:"angle=%.6f;mode=%d;moving=%d;pitch=%.4f;coach=%d;kind=%d;zoom=%.4f;replay=%d;editing=%d;cueX=%.4f;cueY=%.4f",angle,table.cameraMode,shotActive ? 1:0,table.aimPitch,coaching ? 1:0,shotKind,table.zoom,replayIndex == nil ? 0:1,isPlacingBalls ? 1:0,cue?.x ?? 0,cue?.y ?? 0)+String(format:";side=%.4f;top=%.4f;cameraYaw=%.6f;worldCameraAngle=%.6f;ballCount=%d;cameraAngle=%.6f",side,top,aimCameraYaw,cameraAngle,balls.filter{!$0.sunk && $0.id>0}.count,cameraAngle)+String(format:";match=%d;guide=%d;numbers=%d",matchIsCompetitive ? 1:0,guideOn ? 1:0,table.showsDiamondNumbers ? 1:0)+String(format:";preRoll=%.3f;replayTime=%.3f",preparationDuration,replayClock)+String(format:";coachDown=%d;coachUp=%d;locked=%d;expanded=%d;coachEnabled=%d",qaCoachDown,qaCoachUp,locked ? 1:0,spinExpanded ? 1:0,coachButton.isEnabled ? 1:0)+";coachHit="+(view.hitTest(coachButton.center,with:nil).map{String(describing:type(of:$0))+"#"+($0.accessibilityIdentifier ?? "")} ?? "nil")+";lastTouch="+qaLastTouch+";busy="+(presentationBusy ? "1":"0")+";shots=\(qaShots);cpuShots=\(matchPlay.computerShots);cpuTurn="+(matchPlay.computerLevel != nil && matchInt("currentPlayer")==1 ? "1":"0")+";jumpSeen="+(qaJumpSeen ? "1":"0")+";status="+(statusLabel.text ?? "").replacingOccurrences(of:";",with:",").replacingOccurrences(of:"=",with:":")}
        if let sample=replayPreparation,replayIndex != nil {
            if replayRenderedCueType != sample.cueType{table.selectCue(sample.cueType);replayRenderedCueType=sample.cueType}
            table.cueElevation=sample.elevation
            table.showCue(displayCue,angle:sample.angle,visible:true,pull:sample.pull,side:sample.side,top:sample.top)
        }else if let remote=matchRemoteCue(dt){
            // 0.41 (owner: "đối thủ đang đánh không thấy hình cơ"): the other player's live cue, eased.
            table.showCue(displayCue,angle:remote.angle,visible:true,pull:remote.pull,side:remote.side,top:remote.top)
        }else{
            if matchPlay.localCueVisual != nil {matchRestoreLocalCue()}
            table.showCue(displayCue,angle:angle,visible:!presentationBusy && (localTurn || matchPlay.computerAim != nil) && !isPlacingBalls,pull:pull,side:side,top:top)   // 0.40c: the computer's cue is seen lining up
            table.updateCueFade(view:scn,cue:displayCue,angle:angle,target:aimTargetBall(),dt:dt)
            if matchPlay.active && matchPlay.session.role != .none {matchPublishAim()}
        }
        // 0.37 "Dự đoán trước": no guide while aiming — the player commits by eye, the truth is shown after the shot.
        let guideAllowed=coachOn && guideOn && !presentationBusy && localTurn && !isPlacingBalls && !locked && !Tuning.predictFirst
        // 0.36: "Điểm ngắm" = analytic line to the ghost ball, every frame (realtime); "Cả đường" = full simulated roll.
        if let a=predictionRevealAngle,abs(a-angle)>0.0005 || shotActive || replayIndex != nil {predictionRevealAngle=nil}   // kept until the player aims again
        if guideAllowed && guideMode==1 {updateAimGuide();aimGuideShown=true} else if aimGuideShown && predictionRevealAngle==nil {table.aimGuide(cue:nil);aimGuideShown=false}
        // 0.38: Nút số appears on its own while the aim line runs into a cushion (practice only).
        let autoNumbers=Tuning.autoNumbers && !matchIsCompetitive && localTurn && !shotActive && replayIndex==nil && aimHitsRail()
        let wantNumbers=(numbersOn && coaching) || autoNumbers
        if !matchIsCompetitive && table.showsDiamondNumbers != wantNumbers {table.showsDiamondNumbers=wantNumbers}
        // 0.38: the guide fades as the player's recent pass rate rises (eye training).
        let skillFade=Tuning.guideBySkill ? CGFloat(1-0.65*recentPassRate):1
        if abs(table.guideOpacity-skillFade)>0.01 {table.guideOpacity=skillFade}
        let show=guideAllowed && guideMode==2
        if !show && lastGuideVisible {
            table.prediction([],visible:false);lastGuideVisible=false
        }
        let changed=guideDirty || abs(angle-lastGuideAngle)>0.00001 || !lastGuideVisible
        if !show{predictionGeneration+=1}
        if show && changed && !predictionPending && link.timestamp-lastPredictionTime>=0.08 {
            predictionPending=true;predictionGeneration+=1;let generation=predictionGeneration
            var settings=engine.settings
            // 0.38: the predicted path uses the elevation the cue really has (auto-raised over a rail / ball).
            let forced=min(table.clearanceElevation,85)
            if forced>table.cueElevation+0.25 {settings["cueElevationDegrees"]=NSNumber(value:forced);settings["experimental3D"]=true}
            let layout=engine.states,a=table.shotAngle(cue,angle:angle,side:side,top:top),v=referenceSpeed,x=side,y=top,aim=angle
            lastPredictionTime=link.timestamp;guideDirty=false;lastGuideAngle=aim
            let simSettings=settings
            predictionQueue.async{[weak self] in
                let world=BLWorld();world.settings=simSettings;world.loadLayout(layout)
                let samples=world.prediction(angle:a,speed:v,side:x,top:y)
                DispatchQueue.main.async{
                    guard let self=self else{return};self.predictionPending=false
                    guard generation==self.predictionGeneration,self.coachOn,self.guideOn,self.guideMode==2,!self.presentationBusy,abs(self.angle-aim)<0.00001,self.side==x,self.top==y else{self.guideDirty=true;return}
                    guard self.guideMode==2 else{return};self.table.prediction(samples,visible:true);self.lastGuideVisible=true;self.wakeRendering()
                }
            }
        }
    }

    /// "Điểm ngắm": the cue ball's path up to the moment another ball starts to move, plus that ball's first 0.25 s.
    static func toFirstContact(_ samples:[[String:NSNumber]])->[[String:NSNumber]]{
        var start:[Int:(Double,Double)]=[:],contact=Double.infinity
        for s in samples {
            let id=s["id"]?.intValue ?? 0,x=s["x"]?.doubleValue ?? 0,y=s["y"]?.doubleValue ?? 0,t=s["time"]?.doubleValue ?? 0
            guard id != 0 else{continue}
            if let p=start[id] {if hypot(x-p.0,y-p.1)>0.001 {contact=min(contact,t)}} else {start[id]=(x,y)}
        }
        return samples.filter{s in let t=s["time"]?.doubleValue ?? 0;return (s["id"]?.intValue ?? 0)==0 ? t<=contact:t<=contact+0.25}
    }
    func finishShot(timedOut:Bool){
        table.pacer.endDiagnostics()
        if let restore=forcedElevationRestore{engine.settings=restore;forcedElevationRestore=nil}
        let d=Drill.all[drillIndex],events=engine.events
        lastShotEvents=events
        recordSessionShot(events)
        frames.append(balls);frameTimes.append(engine.elapsed)
        if timedOut {let stopped=balls;engine.loadLayout(stopped.map{$0.dictionary})}
        shotActive=false;locked=false
        let finishedMatch=finishMatchShot()
        resetShotInputsAndAim()
        if finishedMatch{refresh();updateControls();return}
        table.trails(coachOn && trailsOn ? paths:[:])
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
            history.append(PracticeRecord(date:Date(),drill:d.title,passed:passed,speed:lastShotSpeed,side:lastShot?.side ?? 0,top:lastShot?.top ?? 0))
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
        if Tuning.predictFirst && !timedOut {revealPrediction(events)}
        else if !timedOut && !scratch {scoreConsistency()}
        if coachOn && !timedOut && (d.goal != nil || d.rails>0) {
            let tracked=d.kick || d.goal != nil ? 0:1
            table.showRailContacts(railContacts(events,ball:tracked,untilFirstHit:d.kick).map{($0.x,$0.y)})
            requestCoachReport(drill:d,events:events,passed:passed,scratch:scratch)
        }
        if lessonActive && d.level>0 {scoreLesson(d,passed:passed,scratch:scratch,timedOut:timedOut,railCount:railCount,events:events)}
    }
    /// 0.25 highlight score: object balls potted, kick cushions before contact, banked pots.
    func recordSessionShot(_ events:[[String:NSNumber]]){
        guard var shot=lastShot,!matchIsCompetitive else{return}
        var firstContact = -1.0,cueRails=0,pots:[Int]=[],railsBy:[Int:Int]=[:],banks=0
        for e in events {
            let kind=e["kind"]?.intValue ?? -1,a=e["a"]?.intValue ?? -1,b=e["b"]?.intValue ?? -1,t=e["time"]?.doubleValue ?? 0
            if kind==1,firstContact<0,a==0||b==0{firstContact=t}
            if kind==0{railsBy[a,default:0]+=1;if a==0,firstContact<0{cueRails+=1}}
            if kind==2,a>0,b>=0{pots.append(a);if (railsBy[a] ?? 0)>0{banks+=1}}
        }
        let score=pots.count*3+banks*3+(firstContact>=0 ? cueRails*2:0)
        guard score>0 else{return}
        var parts:[String]=[]
        if cueRails>0{parts.append("kick \(cueRails) băng")}
        if banks>0{parts.append("\(banks) bi băng")}
        if !pots.isEmpty{parts.append("vào \(pots.count) bi")}
        let label=parts.joined(separator:" · ")
        shot.name="Highlight · "+label;shot.coachVisible=coaching
        sessionShots.append((shot,score,label));if sessionShots.count>60{sessionShots.removeFirst()}
        if autoSaveEveryShot{var all=SavedShot.all();var copy=shot;copy.name="Tự lưu · "+label;all.append(copy);SavedShot.store(all)}
    }
    var sessionHighlights:[(shot:SavedShot,score:Int,label:String)]{Array(sessionShots.enumerated().sorted{$0.element.score==$1.element.score ? $0.offset>$1.offset:$0.element.score>$1.element.score}.prefix(5).map{$0.element})}
    /// 0.25: practice only. -1/+1 one shot; -99 start of session; +99 latest position.
    func stepShot(_ direction:Int){
        guard matchAllowsEditing,!matchIsCompetitive,localTurn,replayIndex==nil,!isPlacingBalls else{return}
        // 0.30: "Lùi cú" also while the balls are still rolling (practice only): the running shot is dropped.
        let rolling=shotActive
        if rolling && direction != -1 {return}
        let here=ShotStep(balls:balls,setup:currentSetup())
        var target:ShotStep?
        switch direction {
        case -1: guard let state=shotBack.popLast() else{notifyStatus("Đã ở cú đầu");return};if !rolling{shotForward.append(here)};target=state
        case 1: guard let state=shotForward.popLast() else{notifyStatus("Đã ở cú mới nhất");return};shotBack.append(here);target=state
        case -99: guard !shotBack.isEmpty else{return};shotForward.append(here);shotForward+=shotBack.dropFirst().reversed();target=shotBack.first;shotBack.removeAll()
        default: guard !shotForward.isEmpty else{return};shotBack.append(here);shotBack+=shotForward.dropFirst().reversed();target=shotForward.first;shotForward.removeAll()
        }
        guard let step=target else{return}
        lockButton.releaseHold();setHold(false);engine.loadLayout(step.balls.map{$0.dictionary});clearShot();restoreAimCamera();locked=false
        applySetup(step.setup)
        notifyStatus("Cú \(shotBack.count+1)/\(shotBack.count+shotForward.count+1)");refresh();updateControls();syncQuickRail()
    }
    /// Restores cue, elevation, effect and aim exactly as they were when that shot was played (0.30).
    func applySetup(_ setup:ShotSetup?){
        guard let setup=setup else{spin.reset();side=0;top=0;return}
        if setup.kind != shotKind {chooseShotKind(setup.kind)}
        setElevation(setup.elevation);spin.select(side:setup.side,top:setup.top);side=setup.side;top=setup.top
        let old=angle;angle=setup.angle;aimCameraYaw+=old-angle
    }
    func undo(){guard matchAllowsEditing,localTurn,!before.isEmpty,!isPlacingBalls else{return};lockButton.releaseHold();setHold(false);engine.loadLayout(before.map{$0.dictionary});clearShot();restoreAimCamera();locked=false
        if !matchIsCompetitive,let shot=lastShot{applySetup(ShotSetup(angle:shot.aimAngle,side:shot.side,top:shot.top,kind:shot.shotKind ?? 0,elevation:shot.elevation))}
        statusLabel.text="Đã trở về trước cú đánh";refresh();updateControls()}
    func reset(){
        guard matchAllowsEditing else{return}
        guard localTurn else{return}
        if shotActive {shotActive=false}
        replayIndex=nil;engine.loadLayout(initial.map{$0.dictionary});before=initial;clearShot();locked=false;isPlacingBalls=false
        statusLabel.text="Đã khôi phục thế bi bài tập";refresh();updateControls()
    }
    func replay(){
        guard localTurn,!shotActive,!frames.isEmpty,!isPlacingBalls else{return}
        lockButton.releaseHold();setHold(false)
        if replayIndex != nil{stopReplay();return}
        hideCoach();table.resetPocketPresentation();replayPlan=ReplayDirector.Plan(duration:frameTimes.last ?? 0,events:lastShotEvents,initialAngle:lastShot?.aimAngle ?? angle);replayOrigin=captureCamera();replayEquipment=(engine.settings["cueType"]?.intValue ?? 0,table.cueElevation);replayRenderedCueType=nil;replayPreparation=nil;replayStrikePlayed=false;replayIndex=0;replayClock = -replayLead;replayYaw=0;replayAudioIndex=0
        replayPaused=false;replayAuto=true;cameraManual=false;lastDirectorTime = -10
        actionDirections=[:];actionCraneYaw=0;actionShot = -1;if replayCamera>8 {replayCamera=0}
        DispatchQueue.main.async{[weak self] in self?.syncOverlayButtons()}
        if replayCamera != 0 {DispatchQueue.main.async{[weak self] in guard let self=self,self.replayIndex != nil else{return};self.chooseReplayCamera(self.replayCamera)}} else {replayAutoButton.setTitle("Điện ảnh",for:.normal)}
        if let pose=savedAimCamera{applyCamera(pose)}else{table.cameraMode=2}
        replaySlider.minimumValue=Float(-replayLead);replaySlider.maximumValue=Float(frameTimes.last ?? 1);replaySlider.value=Float(replayClock)
        replayBar.isHidden=false;menuButton.isHidden=true;replayPause.setTitle("Dừng",for:.normal)
        statusLabel.text="Xem lại · kéo để đổi góc · tua để xem điểm chạm"
        applyReplayCoach();wakeRendering()
        updateControls()
    }
    /// 0.38: export the cinematic replay of the last shot as a video (share sheet: save to Photos, send…).
    func exportHighlight(){
        guard !shotActive,!frames.isEmpty,replayIndex==nil else{notifyStatus("Chưa có cú đánh để xuất video");return}
        guard let recorder=HighlightRecorder(aspect:scn.bounds.width/max(1,scn.bounds.height)) else{notifyStatus("Không tạo được video");return}
        highlightRecorder=recorder;replay()
        replayBar.isHidden=true;menuButton.isHidden=true
        notifyStatus("Đang quay video highlight…")
    }
    func stopReplay(){
        table.actionCamera=nil;actionShot = -1
        if let recorder=highlightRecorder{
            highlightRecorder=nil
            recorder.finish{[weak self] url in
                guard let self=self else{return}
                guard let url=url else{self.notifyStatus("Video trống");return}
                let share=UIActivityViewController(activityItems:[url],applicationActivities:nil)
                share.popoverPresentationController?.sourceView=self.menuButton
                self.present(share,animated:true)
            }
        }
        replayPreparation=nil;replayRenderedCueType=nil
        if let equipment=replayEquipment{table.selectCue(equipment.0);table.cueElevation=equipment.1};replayEquipment=nil
        replayIndex=nil;replayPlan=nil;replayBar.isHidden=true;menuButton.isHidden=false;table.resetPocketPresentation();syncOverlayButtons()
        if let saved=archiveReturn {
            frames=saved.frames;frameTimes=saved.times;lastShotEvents=saved.events;lastShot=saved.shot;paths=saved.paths;coaching=saved.coach;lastPreparation=saved.preparation;archiveReturn=nil
        }
        activeArchiveID=nil;table.update(balls,dt:0)
        if let pose=replayOrigin{applyCamera(pose)};replayOrigin=nil;observationCamera=false
        statusLabel.text="Xem lại xong";updateControls();applyCoachVisibility()
    }
    func buildReplayBar(){
        replayBar.axis = .horizontal;replayBar.spacing=8;replayBar.alignment = .fill
        replayBar.backgroundColor=UIColor(white:0.04,alpha:0.9);replayBar.layer.cornerRadius=12
        replayBar.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(replayBar)
        replayPause.setTitle("Dừng",for:.normal);replayRate.setTitle("1×",for:.normal);replayAutoButton.setTitle("Auto",for:.normal)
        let close=UIButton(type:.system);close.setTitle("Xong",for:.normal);close.accessibilityIdentifier="ReplayDone";replayAutoButton.accessibilityIdentifier="ReplayAuto"
        // 0.33: "Lưu" saves the shot being replayed; the camera button picks 1 of 4 replay angles.
        let save=UIButton(type:.system);save.setTitle("Lưu",for:.normal);save.accessibilityIdentifier="ReplaySave"
        save.addAction(UIAction{[weak self]_ in self?.saveLastShot(fromReplay:true)},for:.touchUpInside)
        for item in [replayPause,replayRate,save,close]{item.titleLabel?.font = .systemFont(ofSize:13,weight:.semibold);item.widthAnchor.constraint(equalToConstant:46).isActive=true}
        replayAutoButton.titleLabel?.font = .systemFont(ofSize:13,weight:.semibold);replayAutoButton.widthAnchor.constraint(equalToConstant:86).isActive=true
        for item in [replayPause,replayRate,replaySlider,replayAutoButton,save,close] as [UIView]{replayBar.addArrangedSubview(item)}
        replayBarRight=[replayBar.leadingAnchor.constraint(equalTo:coachButton.trailingAnchor,constant:8),replayBar.trailingAnchor.constraint(equalTo:quickScroll.leadingAnchor,constant:-8)]
        replayBarLeft=[replayBar.leadingAnchor.constraint(equalTo:quickScroll.trailingAnchor,constant:8),replayBar.trailingAnchor.constraint(equalTo:coachButton.leadingAnchor,constant:-8)]
        NSLayoutConstraint.activate(replayBarRight+[replayBar.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),replayBar.heightAnchor.constraint(equalToConstant:48)])
        replayPause.accessibilityIdentifier="ReplayPause";replaySlider.accessibilityIdentifier="ReplaySeek"
        replayPause.addAction(UIAction{[weak self]_ in guard let self=self else{return};self.replayPaused.toggle();self.replayPause.setTitle(self.replayPaused ? "Tiếp":"Dừng",for:.normal)},for:.touchUpInside)
        replayRate.showsMenuAsPrimaryAction=true;replayRate.menu=UIMenu(children:[0.25,0.5,1.0].map{rate in UIAction(title:"\(rate)×"){[weak self]_ in self?.replaySpeed=rate;self?.replayRate.setTitle("\(rate)×",for:.normal)}})
        replayAutoButton.setTitle("Điện ảnh",for:.normal);replayAutoButton.showsMenuAsPrimaryAction=true
        replayAutoButton.menu=UIMenu(title:"Góc máy xem lại",children:Self.replayCameraTitles.enumerated().map{item->UIMenuElement in
            UIAction(title:item.element){[weak self]_ in self?.chooseReplayCamera(item.offset)}})
        close.addAction(UIAction{[weak self]_ in self?.stopReplay()},for:.touchUpInside)
        replaySlider.addAction(UIAction{[weak self]_ in
            guard let self=self,self.replayIndex != nil else{return};self.replayClock=Double(self.replaySlider.value);self.replayStrikePlayed=self.replayClock>=0
            self.replayIndex=self.frameTimes.lastIndex(where:{$0<=self.replayClock}) ?? 0
            self.replayAudioIndex=self.lastShotEvents.prefix(while:{($0["time"]?.doubleValue ?? 0)<=self.replayClock}).count
            self.lastDirectorTime = -10;self.table.resetPocketPresentation();self.wakeRendering()
        },for:.valueChanged)
        replayBar.isHidden=true
    }
    /// 0.33 replay angles: 0 cinematic director (cuts + slow motion around collisions), 1 shooter 3D, 2 whole table, 3 top.
    static let replayCameraTitles=["Điện ảnh · tự chuyển, chậm khi va chạm","Người đánh 3D","Toàn bàn","Trên cao",
                                   "Action · bám bi cái","Action · bám bi mục tiêu","Action · đón bi ở lỗ","Cẩu quay quanh bàn",
                                   "Action Mix · tự cắt cảnh"]
    func chooseReplayCamera(_ k:Int){
        replayCamera=k;replayAuto = k==0;cameraManual = k != 0 && k<4;lastDirectorTime = -10
        replayAutoButton.setTitle(["Điện ảnh","Người đánh","Toàn bàn","Trên cao","Bi cái","Bi mục tiêu","Đón ở lỗ","Cẩu quay","Action Mix"][min(k,8)],for:.normal)
        if k<4 {table.actionCamera=nil};actionShot = -1
        UserDefaults.standard.set(k,forKey:"replayCamera041")
        beginCameraTransition(0.45)
        switch k {
        case 1: table.cameraMode=2;table.zoom=1;table.focusBounds=nil
        case 2: table.cameraMode=0;table.zoom=1;table.orbit=0;table.orbitPitch=0.85;table.focusBounds=nil
        case 3: table.cameraMode=1;table.zoom=1;table.focusBounds=nil
        default: break
        }
        wakeRendering()
    }
    func playReplayAudio(){
        while replayAudioIndex<lastShotEvents.count {
            let event=lastShotEvents[replayAudioIndex]
            guard (event["time"]?.doubleValue ?? 0)<=replayClock else{break}
            if UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true {poolAudio.play(kind:event["kind"]?.intValue ?? 1,impact:event["impact"]?.doubleValue ?? 0.3,pan:audioPan(event["x"]?.doubleValue ?? 0,event["y"]?.doubleValue ?? 0))}
            replayAudioIndex+=1
        }
    }
    func audioPan(_ x:Double,_ y:Double)->Double{
        let point=scn.projectPoint(SCNVector3(Float(x),0.03,Float(y)))
        return max(-1,min(1,Double(point.x/max(1,Float(scn.bounds.width)))*2-1))
    }

    func configureGestures(){
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
        return !isPlacingBalls || localTurn
    }
    func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith other:UIGestureRecognizer)->Bool{
        let pair=[gestureRecognizer,other]
        return pair.contains{$0 is UIPinchGestureRecognizer} && pair.contains{($0 as? UIPanGestureRecognizer)?.minimumNumberOfTouches==2}
    }
    func tablePoint(_ p:CGPoint)->SIMD2<Double>? {
        let a=scn.unprojectPoint(SCNVector3(Float(p.x),Float(p.y),0)),b=scn.unprojectPoint(SCNVector3(Float(p.x),Float(p.y),1))
        let dy=b.y-a.y;guard abs(dy)>0.00001 else{return nil};let t = -a.y/dy
        guard t>0,t<1 else{return nil}
        return SIMD2<Double>(Double(a.x+(b.x-a.x)*t),Double(a.z+(b.z-a.z)*t))
    }
    @objc func tapTable(_ g:UITapGestureRecognizer){
        guard localTurn,!presentationBusy,!menuOpen,!spinExpanded,!locked,let p=tablePoint(g.location(in:scn)) else{return}
        wakeRendering()
        if table.rackIntroPlaying{table.skipRackIntro();return}
        if handleMatchCallTap(p){return}
        shotCameraAnchor=nil;aimCameraYaw=0
        if isPlacingBalls {moveBall(0,to:p)}else if let c=cue {angle=atan2(p.y-c.y,p.x-c.x);refresh()}
    }
    @objc func panTable(_ g:UIPanGestureRecognizer){
        wakeRendering()
        if replayIndex==nil && (shotActive || !localTurn || BLShotCameraBusy(shotCameraState)) {
            let delta=g.translation(in:scn)
            if table.cameraMode==2{aimCameraYaw+=Double(delta.x)*0.004;table.aimPitch=max(TableScene.aimPitchRange.lowerBound,min(TableScene.aimPitchRange.upperBound,table.aimPitch+Float(delta.y)*0.004))}
            else{table.orbit+=Float(delta.x)*0.006;table.orbitPitch=max(0.2,min(1.4,table.orbitPitch+Float(delta.y)*0.004))}
            cameraTransition=0;g.setTranslation(.zero,in:scn);return
        }
        if replayIndex != nil,!menuOpen {
            if !cameraManual,let sample=replayPreparation{replayYaw=sample.cameraYaw}
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
            if g.state == .began {aimPanAxis=0;shotCameraAnchor=nil;aimCameraYaw=0;beginCameraTransition(0.25)}
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
    @objc func orbitTable(_ g:UIPanGestureRecognizer){
        guard !menuOpen,!spinExpanded,!locked else{return}
        let delta=g.translation(in:scn)
        if replayIndex != nil,!cameraManual,let sample=replayPreparation{replayYaw=sample.cameraYaw}
        cameraManual=true;if replayIndex != nil{replayAuto=false;replayAutoButton.setTitle("Tay",for:.normal)};table.focusBounds=nil
        wakeRendering()
        if table.cameraMode==2 {
            if replayIndex != nil{replayYaw+=Double(delta.x)*0.004}else{aimCameraYaw+=Double(delta.x)*0.004}
            table.aimPitch=max(TableScene.aimPitchRange.lowerBound,min(TableScene.aimPitchRange.upperBound,table.aimPitch+Float(delta.y)*0.004))
        }else{table.orbit+=Float(delta.x)*0.006;table.orbitPitch=max(0.20,min(1.40,table.orbitPitch+Float(delta.y)*0.004))}
        cameraTransition=0;g.setTranslation(.zero,in:scn)
    }
    @objc func pinchTable(_ g:UIPinchGestureRecognizer){
        guard !menuOpen,!spinExpanded,!locked else{return}
        if replayIndex != nil,!cameraManual,let sample=replayPreparation{replayYaw=sample.cameraYaw}
        cameraManual=true;if replayIndex != nil{replayAuto=false;replayAutoButton.setTitle("Tay",for:.normal)};table.focusBounds=nil
        wakeRendering();cameraTransition=0;table.zoom=max(0.45,min(2.6,table.zoom/Float(g.scale)));g.scale=1
        if table.cameraMode==2 && !observationCamera && replayIndex==nil{
            UserDefaults.standard.set(Double(table.zoom),forKey:"aimCameraZoom013")
        }
    }
    func chooseClothColor(){
        let sheet=UIAlertController(title:"Màu nỉ",message:"Chọn màu bàn luyện. Vân nỉ matte và texture vẫn được giữ.",preferredStyle:.actionSheet)
        for (index,item) in TableScene.clothColors.enumerated(){sheet.addAction(UIAlertAction(title:item.0,style:.default){[weak self]_ in UserDefaults.standard.set(index,forKey:"clothTintIndex");self?.table.setClothColor(index)})}
        sheet.addAction(UIAlertAction(title:"Theo mẫu bàn đang chọn",style:.default){[weak self]_ in UserDefaults.standard.removeObject(forKey:"clothTintIndex");self?.table.setClothColor(nil)})
        sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(sheet,source:menuButton)
    }
    func moveBall(_ id:Int,to p:SIMD2<Double>){
        if handleMatchMoveBall(id,to:p){return}
        guard localTurn,!presentationBusy,isPlacingBalls else{return}
        var state=balls;guard let i=state.firstIndex(where:{$0.id==id}) else{return}
        let x=max(-0.590,min(0.590,p.x)),y=max(-1.225,min(1.225,p.y))
        guard !state.contains(where:{$0.id != id && !$0.sunk && hypot($0.x-x,$0.y-y)<0.0573}) else{return}
        state[i].x=x;state[i].y=y;state[i].sunk=false;engine.loadLayout(state.map{$0.dictionary});table.placementBlocked = isPlacingBalls && !placementValid();refresh()
    }
    func presentSheet(_ sheet:UIAlertController,source:UIView?=nil){
        sheet.overrideUserInterfaceStyle = .dark   // 0.30b: readable over the bright table (owner: menu text washed out)
        sheet.popoverPresentationController?.sourceView=source ?? view
        sheet.popoverPresentationController?.sourceRect=source?.bounds ?? CGRect(x:view.bounds.midX,y:view.bounds.midY,width:1,height:1)
        present(sheet,animated:true)
    }
    func beginDrill(_ index:Int,guided:Bool){
        if let previous=guidedCoachBefore{coaching=previous;guidedCoachBefore=nil}
        if guided{guidedCoachBefore=coaching;coaching=true}
        loadDrill(index);applyCoachVisibility()
        lessonActive=Drill.all[index].level>0;lessonScores=[];lessonPasses=0
        if lessonActive {scoreLabel.text="Lượt 5 cú · 0 / 5";notifyStatus("Bài tập: "+Drill.all[index].title+" · cần đạt 3/5 cú")}
    }
    func chooseDrill(){
        guard matchAllowsEditing else{return}
        guard !shotActive,replayIndex==nil else{return}
        let vc=DrillsController(style:.insetGrouped)
        vc.load={[weak self]index in self?.beginDrill(index,guided:false)}
        vc.guidedLoad={[weak self]index in self?.beginDrill(index,guided:true)}
        present(UINavigationController(rootViewController:vc),animated:true)
    }
    func chooseKick(){
        guard matchAllowsEditing else{return}
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
    func findKick(target:Int,rails:Int){
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
    func help(){
        let message="Giữ B: khóa hướng. Ngón khác kéo lùi rồi đẩy tới: tốc độ vuốt quyết định lực. Buông B để hủy. C: bật/tắt toàn bộ trợ giúp. Ngang: ngắm, dọc: nâng mắt, hai ngón: quan sát. Bi đang chạy: kéo hoặc dùng hai ngón để quan sát, chụm để zoom; camera giữ góc đang chọn. Góc điện ảnh chỉ có khi xem lại. Chạm + Bi thêm từng bi, giữ để xếp ngẫu nhiên.\n\nÂm thanh thu thật: bsumusictech, Za-Games, mccarthy@bedmas.com, AmberdeMeillon (CC0). ‘Pool Ball in pocket.wav’ — jtroan, CC BY 3.0, freesound.org/people/jtroan/sounds/241373/ ; creativecommons.org/licenses/by/3.0/ . Đã cắt, đổi mono/PCM, chỉnh gain và fade. Bản dùng từ HQ MP3 preview. Bộ 0.41: dhoy42 (CC0) freesound.org/people/dhoy42/sounds/114308/ ; ‘pool break.wav’ — cameronmusic, CC BY 3.0, freesound.org/people/cameronmusic/sounds/138405/ ."
        let alert=UIAlertController(title:"Điều khiển 0.18 & ghi công",message:message,preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"Xong",style:.cancel));present(alert,animated:true)
    }

    func layouts(){
        guard matchAllowsEditing else{return}
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
    func savedLayouts()->[Layout]{guard let data=UserDefaults.standard.data(forKey:"layouts") else{return []};return (try? JSONDecoder().decode([Layout].self,from:data)) ?? []}
    func saveLayout(){
        let a=UIAlertController(title:"Tên thế bi",message:nil,preferredStyle:.alert);a.addTextField{$0.placeholder="Ví dụ: Kick 3 băng góc dài"}
        a.addAction(UIAlertAction(title:"Lưu",style:.default){[weak self,weak a]_ in
            guard let self=self else{return};var list=self.savedLayouts();list.append(Layout(name:a?.textFields?.first?.text?.isEmpty==false ? a!.textFields!.first!.text!:"Thế bi \(list.count+1)",balls:self.balls,angle:self.angle))
            if let data=try? JSONEncoder().encode(list){UserDefaults.standard.set(data,forKey:"layouts")};self.statusLabel.text="Đã lưu thế bi"
        });a.addAction(UIAlertAction(title:"Hủy",style:.cancel));presentSheet(a)
    }
    func openLayout(_ index:Int){
        guard matchAllowsEditing else{return}
        guard localTurn,!presentationBusy else{return}
        let l=savedLayouts()[index];loadDrill(Drill.free);initial=l.balls;before=initial;engine.loadLayout(initial.map{$0.dictionary});angle=l.angle
        titleLabel.text=l.name;refresh();updateControls()
    }
    func deleteLayout(){
        let a=UIAlertController(title:"Xóa thế bi",message:nil,preferredStyle:.actionSheet)
        for(i,l) in savedLayouts().enumerated(){a.addAction(UIAlertAction(title:l.name,style:.destructive){[weak self]_ in guard let self=self else{return};var list=self.savedLayouts();list.remove(at:i);if let d=try? JSONEncoder().encode(list){UserDefaults.standard.set(d,forKey:"layouts")}})}
        a.addAction(UIAlertAction(title:"Hủy",style:.cancel));presentSheet(a,source:layoutButton)
    }
    // MARK: HLV offline (Docs/AI-COACH-SPEC.md): luật + mô phỏng phản thực tế bằng chính solver.
    // Chỉ chạy sau cú hoặc lúc mở bài, ở chế độ Luyện; ẩn khi giữ khoá/vuốt cơ. Không có số độ khi đánh.
    var coachOn:Bool{coaching && !matchIsCompetitive}
    var diamondNumbersOn:Bool{coachOn}
    func n1(_ v:Double)->String{String(format:"%.1f",v).replacingOccurrences(of:".",with:",")}
    func diamondPoint(_ x:Double,_ y:Double)->String{
        "ngắn \(n1(BLDiamondAlongShort(x,geometry.width))) · dài \(n1(BLDiamondAlongLong(y,geometry.length)))"
    }
    func railLabel(_ rail:BLRail)->String{String(cString:BLRailNameVI(rail))}
    func railContacts(_ events:[[String:NSNumber]],ball:Int,untilFirstHit:Bool)->[(rail:BLRail,diamond:Double,x:Double,y:Double)]{
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
    func drillBrief(_ d:Drill)->String{
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
    func requestCoachReport(drill:Drill,events:[[String:NSNumber]],passed:Bool,scratch:Bool){
        guard coachOn,let shot=lastShot else{return}
        coachGeneration+=1;let generation=coachGeneration
        let analysis=ShotCoachAnalysis(settings:shot.physicsSettings?.mapValues{NSNumber(value:$0)} ?? engine.settings,before:before,balls:balls,lastShot:shot,geometry:geometry)
        showCoach("Đang phân tích cú đánh…")
        coachQueue.async{[weak self] in
            let report=analysis.report(drill:drill,events:events,passed:passed,scratch:scratch)
            DispatchQueue.main.async{
                guard let self=self,self.coachGeneration==generation,self.coachOn,!self.shotActive,!self.locked,self.replayIndex==nil,self.lastShot?.date==shot.date else{return}
                self.showCoach(report);self.wakeRendering()
            }
        }
    }
    func showCoach(_ text:String){
        guard coachOn,replayIndex==nil,!isPlacingBalls else{return}
        coachLabel.text=text;coachCard.alpha=1;coachCard.isHidden=locked || menuOpen || !coachOn || !cardOn
    }
    func hideCoach(){coachCard.alpha=0;coachCard.isHidden=true}
    func buildCoachCard(){
        coachCard.backgroundColor=UIColor(white:0.02,alpha:0.62);coachCard.layer.cornerRadius=14
        coachCard.translatesAutoresizingMaskIntoConstraints=false;coachCard.accessibilityIdentifier="CoachCard"
        coachLabel.numberOfLines=0;coachLabel.font = .systemFont(ofSize:12,weight:.medium);coachLabel.textColor=UIColor.white.withAlphaComponent(0.92)
        coachLabel.translatesAutoresizingMaskIntoConstraints=false;coachCard.addSubview(coachLabel);view.addSubview(coachCard)
        NSLayoutConstraint.activate([
            coachCard.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:12),
            coachCard.topAnchor.constraint(equalTo:menuButton.bottomAnchor,constant:8),
            coachCard.widthAnchor.constraint(lessThanOrEqualToConstant:360),
            coachCard.trailingAnchor.constraint(lessThanOrEqualTo:quickScroll.leadingAnchor,constant:-12),
            // 0.29: Coach now sits top-left beside Menu; keep the card clear of the bottom controls instead.
            coachCard.bottomAnchor.constraint(lessThanOrEqualTo:lockButton.topAnchor,constant:-8),
            coachCard.bottomAnchor.constraint(lessThanOrEqualTo:spin.topAnchor,constant:-8),
            coachLabel.leadingAnchor.constraint(equalTo:coachCard.leadingAnchor,constant:12),coachLabel.trailingAnchor.constraint(equalTo:coachCard.trailingAnchor,constant:-12),
            coachLabel.topAnchor.constraint(equalTo:coachCard.topAnchor,constant:10),coachLabel.bottomAnchor.constraint(equalTo:coachCard.bottomAnchor,constant:-10)])
        coachCard.addGestureRecognizer(UITapGestureRecognizer(target:self,action:#selector(coachTapped)))
        hideCoach()
    }
    @objc func coachTapped(){hideCoach()}
    func replayMenu()->UIMenu{
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
                        UIAction(title:"Xem lại cú này",image:UIImage(systemName:"arrow.clockwise")){[weak self]_ in self?.playSaved(shot)},
                        UIAction(title:"Chỉ đặt lại thế bi",image:UIImage(systemName:"square.grid.3x3")){[weak self]_ in self?.loadSaved(shot)},
                        UIAction(title:"Xoá",image:UIImage(systemName:"trash"),attributes:.destructive){[weak self]_ in
                            var all=SavedShot.all();if index<all.count{if let id=all[index].recordingID{ShotArchive.shared.remove(id:id)};all.remove(at:index)};SavedShot.store(all);self?.syncQuickRail()}])
                }))
        }
        let highlights=sessionHighlights
        if !highlights.isEmpty {
            items.append(UIMenu(title:"Highlight phiên (\(highlights.count))",image:UIImage(systemName:"sparkles"),children:
                highlights.map{h in UIAction(title:h.label){[weak self]_ in self?.playSaved(h.shot)}}+[
                UIAction(title:"Lưu highlight vào Lưu trữ",image:UIImage(systemName:"square.and.arrow.down")){[weak self]_ in
                    guard let self=self else{return};var all=SavedShot.all();all+=self.sessionHighlights.map{$0.shot};SavedShot.store(all)
                    self.notifyStatus("Đã lưu \(self.sessionHighlights.count) cú highlight");self.syncQuickRail()}]))
        }
        items.append(UIAction(title:"Tự lưu mọi cú",image:UIImage(systemName:"tray.and.arrow.down"),state:autoSaveEveryShot ? .on:.off){_ in
            UserDefaults.standard.set(!UserDefaults.standard.bool(forKey:"autoSaveEveryShot025"),forKey:"autoSaveEveryShot025")})
        return UIMenu(title:"Xem lại",children:items)
    }
    func saveLastShot(fromReplay:Bool=false){
        guard matchAllowsEditing,!shotActive,fromReplay || replayIndex==nil,var shot=lastShot,!frames.isEmpty else{return}
        if fromReplay{replayPaused=true;replayPause.setTitle("Tiếp",for:.normal)}
        let alert=UIAlertController(title:"Lưu cú này",message:"Đặt tên để tìm lại trong Xem lại › Cú đã lưu.",preferredStyle:.alert)
        alert.addTextField{field in field.text=String(format:"Cú %@ · %.1f m/s",DateFormatter.localizedString(from:Date(),dateStyle:.none,timeStyle:.short),shot.speed)}
        alert.addAction(UIAlertAction(title:"Huỷ",style:.cancel))
        alert.addAction(UIAlertAction(title:"Lưu",style:.default){[weak self,weak alert]_ in
            shot.name=alert?.textFields?.first?.text?.trimmingCharacters(in:.whitespaces).nilIfEmpty ?? "Cú đã lưu"
            guard let self=self else{return};shot.coachVisible=self.coaching
            let recording=ShotRecording(frames:self.frames,frameTimes:self.frameTimes,events:self.lastShotEvents,preparation:self.lastPreparation)
            ShotArchive.shared.save(recording){[weak self] result in
                switch result {
                case .success(let id):shot.recordingID=id;var all=SavedShot.all();all.append(shot);SavedShot.store(all);self?.notifyStatus("Đã lưu: "+shot.name);self?.syncQuickRail()
                case .failure(let error):self?.notifyStatus("Không lưu được cú: "+error.localizedDescription)
                }
            }
        })
        present(alert,animated:true)
    }
    func loadSaved(_ shot:SavedShot){
        guard matchAllowsEditing else{return}
        guard localTurn,!presentationBusy else{return}
        lockButton.releaseHold();setHold(false)
        engine.loadLayout(shot.balls.map{$0.dictionary});clearShot();initial=balls;before=balls;locked=false
        chooseShotKind(shot.shotKind ?? shot.cueType)
        setElevation(shot.elevation);angle=shot.aimAngle;spin.select(side:shot.side,top:shot.top)
        selectCamera(2);refresh();updateControls()
    }
    func playSaved(_ shot:SavedShot){
        guard matchAllowsEditing,localTurn,!presentationBusy,!isPlacingBalls else{return}
        replayPreparing=true;archiveGeneration+=1;let generation=archiveGeneration;setMenu(false);updateControls()
        notifyStatus("Đang mở cú đã lưu…")
        let ready:(Result<ShotRecording,Error>)->Void = {[weak self] result in
            guard let self=self,self.archiveGeneration==generation else{return};self.replayPreparing=false
            switch result {
            case .failure(let error):self.notifyStatus("Không mở được cú: "+error.localizedDescription);self.updateControls()
            case .success(let record):
                self.archiveReturn=ReplayReturnState(frames:self.frames,times:self.frameTimes,events:self.lastShotEvents,shot:self.lastShot,paths:self.paths,coach:self.coaching,preparation:self.lastPreparation)
                self.frames=record.frames;self.frameTimes=record.frameTimes;self.lastShotEvents=record.events;self.lastPreparation=record.preparation ?? [];self.lastShot=shot;self.paths=[:]
                for frame in record.frames{for ball in frame where !ball.sunk{self.paths[ball.id,default:[]].append(SIMD3(Float(ball.x),Float((ball.height ?? 0)+0.004),Float(ball.y)))}}
                self.coaching=shot.coachVisible ?? false;self.activeArchiveID=shot.recordingID;self.replay()
            }
        }
        if let id=shot.recordingID{
            ShotArchive.shared.load(id:id){[weak self] result in
                guard let self=self,self.archiveGeneration==generation else{return}
                if case .failure(let error)=result,let archiveError=error as? ShotArchiveError {
                    switch archiveError {
                    case .missingRecording:
                        self.notifyStatus("Bản ghi hình đã được dọn · đang dựng lại từ đầu vào đã lưu…")
                        self.reconstructSavedShot(shot,completion:ready);return
                    default:break
                    }
                }
                ready(result)
            }
            return
        }
        reconstructSavedShot(shot,completion:ready)
    }
    func reconstructSavedShot(_ shot:SavedShot,completion:@escaping (Result<ShotRecording,Error>)->Void){
        // Legacy archives stored inputs only. Reconstruct on a private world;
        // viewing never changes the live table, score, or current drill.
        let settings=shot.physicsSettings?.mapValues{NSNumber(value:$0)} ?? engine.settings
        predictionQueue.async{
            let world=BLWorld();var values=settings;values["cueType"]=NSNumber(value:shot.cueType);values["cueElevationDegrees"]=NSNumber(value:shot.elevation);values["experimental3D"]=NSNumber(value:shot.elevation>0);world.settings=values
            world.loadLayout(shot.balls.map{$0.dictionary});var samples=[shot.balls],times=[0.0]
            world.strike(angle:shot.strikeAngle ?? shot.aimAngle,speed:shot.speed,side:shot.side,top:shot.top)
            while world.moving && world.elapsed<60{world.advance(1.0/30.0);samples.append(world.states.map{BallState($0)});times.append(world.elapsed)}
            let recording=ShotRecording(frames:samples,frameTimes:times,events:world.events)
            let result:Result<ShotRecording,Error>
            do{try recording.validate();result = .success(recording)}catch{result = .failure(error)}
            DispatchQueue.main.async{completion(result)}
        }
    }
    func persistArchiveCoach(){
        guard let id=activeArchiveID else{return};var all=SavedShot.all()
        if let index=all.firstIndex(where:{$0.recordingID==id}){all[index].coachVisible=coaching;SavedShot.store(all)}
    }
    func applyReplayCoach(){
        coachButton.setTitle("Coach",for:.normal);coachButton.setTitleColor(coaching ? .white:.rgb(0xEAC583),for:.normal);coachButton.accessibilityValue=coaching ? "Bật":"Tắt"
        hideCoach();table.target(nil);table.setTrainingOverlaysHidden(!coaching);table.showsDiamondNumbers=numbersOn && coaching
        table.prediction([],visible:false);table.trails(coaching ? paths:[:]);table.showRailContacts(coaching ? lastShotEvents.filter{$0["kind"]?.intValue==0}.compactMap{event in guard let x=event["x"]?.doubleValue,let y=event["y"]?.doubleValue else{return nil};return(x,y)}:[])
    }
    /// Xếp bi ngẫu nhiên theo seed (in ra để tái tạo): không chồng bi, cách miệng lỗ và băng.
    func addRandomBalls(_ count:Int,replacing:Bool=false,chosenSeed:UInt64?=nil){
        guard matchAllowsEditing else{return}
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
    func randomOptions(){
        guard matchAllowsEditing,!presentationBusy,!isPlacingBalls else{return}
        let alert=UIAlertController(title:"Thêm bi",message:"Nhập số bi 1–15. Ngẫu nhiên tạo vị trí mới; Mặc định xếp theo hàng, giữ nguyên bi trên bàn.",preferredStyle:.alert)
        alert.addTextField{$0.placeholder="Số bi 1–15";$0.keyboardType = .numberPad}
        for random in [true,false] {
            alert.addAction(UIAlertAction(title:random ? "Ngẫu nhiên":"Mặc định",style:.default){[weak self,weak alert]_ in
                guard let self=self,let count=Int(alert?.textFields?.first?.text ?? ""),(1...15).contains(count) else{self?.notifyStatus("Nhập số nguyên từ 1 đến 15");return}
                if random{self.addRandomBalls(count)}else{self.addDefaultBalls(count)}
            })
        }
        alert.addAction(UIAlertAction(title:"Hủy",style:.cancel));present(alert,animated:true)
    }
    func addDefaultBalls(_ count:Int){
        guard matchAllowsEditing,localTurn,!presentationBusy,!locked else{return}
        var state=balls.filter{!$0.sunk || $0.id==0};var added=0
        for row in 0..<7 {for col in 0..<5 {
            guard added<count,let id=(1...15).first(where:{id in !state.contains{$0.id==id}}) else{continue}
            let x = -0.4+Double(col)*0.2,y = -0.9+Double(row)*0.3
            if state.contains(where:{!$0.sunk && hypot($0.x-x,$0.y-y)<0.065}){continue}
            state.append(BallState(id:id,x:x,y:y));added+=1
        }}
        engine.loadLayout(state.map{$0.dictionary});clearShot();initial=balls;before=balls
        refresh();updateControls();notifyStatus("Đã thêm \(added) / \(count) bi · bố trí mặc định")
    }
    func addBall(){
        guard matchAllowsEditing else{return}
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
    func practiceRecords()->[PracticeRecord]{
        guard let data=UserDefaults.standard.data(forKey:"practiceHistory") else{return []}
        return (try? JSONDecoder().decode([PracticeRecord].self,from:data)) ?? []
    }
    func showPracticeHistory(){
        let history=practiceRecords(),grouped=Dictionary(grouping:practiceRecords(),by:{$0.drill})
        let lines=grouped.keys.sorted().map{key -> String in
            let list=grouped[key] ?? [],wins=list.filter{$0.passed}.count
            return "\(key): \(wins)/\(list.count) đạt"
        }
        let message=history.isEmpty ? "Chưa có cú chấm điểm. Chọn bài và hoàn tất cú đánh để lưu tự động.":lines.joined(separator:"\n")+"\n\nTối đa 200 cú gần nhất. Các góc, lực và thế bi có thể khác nhau; tỷ lệ này chưa phải điểm kỹ năng chuẩn hóa."
        let a=UIAlertController(title:"Nhật ký trên máy",message:message,preferredStyle:.alert)
        a.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(a)
    }
    func applyGraphics(){
        table.quality(highGraphics)
        scn.antialiasingMode=highGraphics ? .multisampling4X:.multisampling2X
        scn.preferredFramesPerSecond=60
        UserDefaults.standard.set(highGraphics,forKey:"highGraphics018")
    }
    func loadShowcase(){
        guard !shotActive,replayIndex==nil else{return}
        loadDrill(Drill.free)
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
    func graphics(){
        let a=UIAlertController(title:"Hình ảnh · Premium Classic",message:"Mặc định Cân bằng: giảm tải GPU; tự giảm chất lượng khi máy nóng. Chất lượng cao tăng độ nét và bóng. Thử trên máy thật để chọn phù hợp.",preferredStyle:.actionSheet)
        a.addAction(UIAlertAction(title:highGraphics ? "✓ Cao cấp":"Cao cấp",style:.default){[weak self]_ in self?.highGraphics=true;self?.applyGraphics()})
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
            let render=self.table.pacer.diagnostics, intervals=render.intervals.sorted()
            func summary(_ v:[Double])->String {
                guard !v.isEmpty else{return "chưa có dữ liệu"}
                return String(format:"%d khung · p50 %.2f · p95 %.2f · max %.2f ms",v.count,v[v.count/2]*1000,v[min(v.count-1,Int(Double(v.count)*0.95))]*1000,(v.last ?? 0)*1000)
            }
            let pr=self.shotProfile
            func ms(_ v:[Double])->String {
                let v=v.sorted();guard !v.isEmpty else{return "—"}
                return String(format:"p50 %.2f · p95 %.2f · max %.2f",v[v.count/2]*1000,v[min(v.count-1,Int(Double(v.count)*0.95))]*1000,(v.last ?? 0)*1000)
            }
            let budget=1000.0/Double(Tuning.frameRate)
            let over=pr.tick.filter{$0*1000>budget*0.8}.count
            var lines:[String]=[]
            lines.append("Cập nhật app: "+summary(values)+"\nRender SceneKit: "+summary(intervals)+String(format:"\n%d/%d khung thiếu mẫu · mẫu trễ nhất %.2f ms · đệm %.2f ms",render.starvedFrames,render.sampledFrames,render.maximumSampleAge*1000,render.interval*1000))
            lines.append("\nĐồng hồ SceneKit − hiện tại (ms): "+ms(render.clockOffsets))
            lines.append("\n\nCPU luồng chính mỗi khung (ms):\nVật lý: "+ms(pr.physics)+"\nGhi xem lại: "+ms(pr.record)+"\nSự kiện/âm: "+ms(pr.events)+"\nCảnh 3D: "+ms(pr.scene)+"\nCả tick: "+ms(pr.tick))
            lines.append(String(format:"\n%d/%d khung dùng quá 80%% ngân sách %.1f ms\nBố cục UIKit giữa cú: %d lượt · dựng lại phím: %d · mẫu xem lại: %d",over,pr.tick.count,budget,pr.layoutPasses,pr.hudRelayouts,pr.recordedSamples))
            lines.append("\nA/B: trạng thái 5 Hz cũ "+(Self.legacyStatusAB ? "BẬT":"tắt")+" · xem lại không quay chậm "+(Self.replayNoSlowAB ? "BẬT":"tắt"))
            let message=count==0 ? "Đánh một cú trước để đo nhịp trên thiết bị.":lines.joined()
            let alert=UIAlertController(title:"Chẩn đoán độ mượt",message:message,preferredStyle:.alert)
            alert.addAction(UIAlertAction(title:Self.legacyStatusAB ? "A/B: tắt trạng thái 5 Hz cũ":"A/B: bật lại trạng thái 5 Hz cũ (để so)",style:.default){_ in
                UserDefaults.standard.set(!Self.legacyStatusAB,forKey:"diagLegacyStatus039")})
            alert.addAction(UIAlertAction(title:Self.replayNoSlowAB ? "A/B: xem lại có quay chậm tự động":"A/B: xem lại 1× không quay chậm",style:.default){_ in
                UserDefaults.standard.set(!Self.replayNoSlowAB,forKey:"diagReplayNoSlow039")})
            alert.addAction(UIAlertAction(title:"Sao chép số đo",style:.default){_ in UIPasteboard.general.string=message})
            alert.addAction(UIAlertAction(title:"Đóng",style:.cancel));self.presentSheet(alert)
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
    func rollingCheck(){
        guard !shotActive,replayIndex==nil else{return}
        loadDrill(Drill.rollTest)
        table.cameraMode=2;table.zoom=1;table.orbit=0
        cameraButton.configuration?.title="Ngắm cơ"
        // At top=0.4 the strike gives omega=v/R: rolling from the first step.
        spin.select(side:0,top:0.4)
        guideOn=false;guideDirty=true;guideButton.configuration?.title="Dự báo: tắt"
        locked=true;shoot(0.5)
        titleLabel.text="Kiểm tra lăn · theo dõi chấm đỏ"
    }
    func exportShot(){
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
    func settings(){
        guard matchAllowsEditing else{return}
        guard localTurn,!presentationBusy else{return}
        let vc=SettingsController(settings:engine.settings,sensitivity:stroke.sensitivity)
        vc.apply={[weak self]settings,sensitivity in
            guard let self=self else{return};self.engine.settings=settings;self.stroke.sensitivity=sensitivity
            UserDefaults.standard.set(settings,forKey:"physics");UserDefaults.standard.set(sensitivity,forKey:"sensitivity")
            self.table.selectCue(self.engine.settings["cueType"]?.intValue ?? 0)
            self.table.cueElevation=(self.engine.settings["experimental3D"]?.boolValue ?? false) ? (self.engine.settings["cueElevationDegrees"]?.doubleValue ?? 0):0
            self.spin.maximumOffset=self.tipLimit(elevated:self.engine.settings["experimental3D"]?.boolValue ?? false)
            self.spin.select(side:self.side,top:self.top)
            self.statusLabel.text="Đã lưu cấu hình bàn trên máy"
            self.syncQuickRail()
            self.guideDirty=true
        }
        let nav=UINavigationController(rootViewController:vc);nav.modalPresentationStyle = .formSheet;present(nav,animated:true)
    }
}

private extension String {var nilIfEmpty:String?{isEmpty ? nil:self}}

/// Captured value data only. A private solver performs analysis off the UI thread.
struct ShotCoachAnalysis {
    let settings:[String:NSNumber]
    let before:[BallState]
    let balls:[BallState]
    let lastShot:SavedShot?
    let geometry:TrainingController.TableGeometry
    func n1(_ v:Double)->String{String(format:"%.1f",v).replacingOccurrences(of:".",with:",")}
    func diamondPoint(_ x:Double,_ y:Double)->String{
        "ngắn \(n1(BLDiamondAlongShort(x,geometry.width))) · dài \(n1(BLDiamondAlongLong(y,geometry.length)))"
    }
    func railLabel(_ rail:BLRail)->String{String(cString:BLRailNameVI(rail))}
    func railContacts(_ events:[[String:NSNumber]],ball:Int,untilFirstHit:Bool)->[(rail:BLRail,diamond:Double,x:Double,y:Double)]{
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
    func counterfactual(_ body:()->Void){
        body()
    }
    /// Điểm chạm theo đúng quy ước bánh xe effect (vòng 25/50 = % bán kính), để người dùng chỉnh lại y hệt.
    func effectLabel(_ side:Double,_ top:Double)->String{
        if hypot(side,top)<0.05 {return " · đánh tâm"}
        var parts:[String]=[]
        if abs(top)>=0.05 {parts.append((top>0 ? "trên ":"dưới ")+String(format:"%.0f%%",abs(top)*100))}
        if abs(side)>=0.05 {parts.append((side>0 ? "phải ":"trái ")+String(format:"%.0f%%",abs(side)*100))}
        return " · effect "+parts.joined(separator:", ")
    }
    func report(drill d:Drill,events:[[String:NSNumber]],passed:Bool,scratch:Bool)->String{
        guard let shot=lastShot else{return passed ? "ĐẠT":"Chưa đạt"}
        let engine=BLWorld();engine.settings=settings;engine.loadLayout(before.map{$0.dictionary})
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
}

// MARK: - 0.35 lesson series: 5 shots, pass at 3/5, stars, on-device scoring
extension TrainingController {
    /// Score one shot 0–100. A pass is 100 (position drills lose points with distance from the circle centre);
    /// a miss earns partial credit by how close it came, so the player sees progress before the first pass.
    func lessonShotScore(_ d:Drill,passed:Bool,scratch:Bool,timedOut:Bool,railCount:Int)->(score:Int,detail:String){
        if timedOut {return (0,"quá 60 giây")}
        if scratch {return (0,"bi cái vào lỗ")}
        let start=Dictionary(before.map{($0.id,$0)},uniquingKeysWith:{a,_ in a})
        func pocketMiss(_ id:Int)->Double{
            let w=geometry.width/2,l=geometry.length/2
            let pockets=[(-w,-l),(w,-l),(-w,0.0),(w,0.0),(-w,l),(w,l)]
            return (paths[id] ?? []).reduce(Double.infinity){best,p in
                min(best,pockets.map{hypot(Double(p.x)-$0.0,Double(p.z)-$0.1)}.min() ?? best)}
        }
        if let g=d.goal {
            if g.potOnly {
                if passed {return (100,"bi 1 vào lỗ")}
                let miss=pocketMiss(1)
                return miss.isFinite ? (max(0,60-Int(miss*150)),String(format:"bi 1 lướt cách lỗ %.0f cm",miss*100)):(0,"bi 1 không chạy")
            }
            guard let cb=balls.first(where:{$0.id==0}) else{return (0,"")}
            let dist=hypot(cb.x-g.x,cb.y-g.y)
            if passed {return (100-Int(35*dist/max(0.01,g.radius)),String(format:"cách tâm vòng %.0f cm",dist*100))}
            return (max(0,60-Int(max(0,dist-g.radius)*200)),String(format:"bi cái cách vòng %.0f cm",max(0,dist-g.radius)*100))
        }
        if d.kick {
            if passed {return (100,"đúng \(d.rails) băng rồi chạm bi 1")}
            guard let o=start[1] else{return (0,"")}
            let closest=(paths[0] ?? []).reduce(Double.infinity){min($0,hypot(Double($1.x)-o.x,Double($1.z)-o.y))}
            let miss=closest.isFinite ? closest-2*geometry.radius:1.0
            let score=max(0,70-Int(max(0,miss)*250)-(railCount != d.rails ? 20:0))
            return (score,String(format:"%d/%d băng · trượt bi 1 %.0f cm",railCount,d.rails,max(0,miss)*100))
        }
        if passed {return (100,"đúng \(d.rails) băng vào lỗ")}
        let miss=pocketMiss(1)
        return (miss.isFinite ? max(0,55-Int(miss*150)):0,String(format:"%d/%d băng · bi 1 cách lỗ %.0f cm",railCount,d.rails,miss.isFinite ? miss*100:0))
    }
    func scoreLesson(_ d:Drill,passed:Bool,scratch:Bool,timedOut:Bool,railCount:Int,events:[[String:NSNumber]]){
        let (score,detail)=lessonShotScore(d,passed:passed,scratch:scratch,timedOut:timedOut,railCount:railCount)
        lessonScores.append(score);if passed{lessonPasses+=1}
        let n=lessonScores.count
        statusLabel.text="Cú \(n)/5 · \(score) điểm · "+(passed ? "ĐẠT":"chưa đạt")+" · "+detail
        scoreLabel.text="Lượt 5 cú · đạt \(lessonPasses) / \(n)"
        notifyStatus(statusLabel.text ?? "")
        let index=drillIndex
        if n<5 {
            // Re-rack the lesson for the next shot once the player has seen where the balls stopped.
            DispatchQueue.main.asyncAfter(deadline:.now()+2.2){[weak self] in
                guard let self=self,self.lessonActive,self.drillIndex==index,!self.shotActive,self.replayIndex==nil,!self.isPlacingBalls else{return}
                if self.shotBack.isEmpty{self.undo()}else{self.stepShot(-1)}
                self.statusLabel.text="Cú \(n+1)/5 · thế bi đã xếp lại"
            }
            return
        }
        let average=lessonScores.reduce(0,+)/max(1,n)
        let stars=lessonPasses>=5 && average>=85 ? 5:min(4,lessonPasses)
        let cleared=lessonPasses>=3
        Drill.recordStars(stars,for:d.title)
        lessonScores=[];lessonPasses=0
        let next=Drill.all.indices.first{$0>index && Drill.all[$0].level>0}
        let alert=UIAlertController(title:(cleared ? "Qua bài · ":"Chưa qua · ")+Drill.starText(stars),
            message:"\(d.title)\nĐiểm trung bình \(average)/100.\n"+(cleared ? "Bài đã được đánh dấu hoàn thành.":"Cần đạt ít nhất 3/5 cú. Gợi ý: bật Coach để xem điểm va băng và một thay đổi cho cú sau."),preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"Tập lại lượt mới",style:.default){[weak self]_ in self?.beginDrill(index,guided:false)})
        if let next=next {alert.addAction(UIAlertAction(title:"Bài tiếp theo",style:.default){[weak self]_ in self?.beginDrill(next,guided:false)})}
        alert.addAction(UIAlertAction(title:"Đóng",style:.cancel){[weak self]_ in self?.lessonActive=false})
        DispatchQueue.main.asyncAfter(deadline:.now()+1.2){[weak self] in self?.present(alert,animated:true)}
    }
}

// 0.36 "Điểm ngắm" — analytic, per frame: cue line to the first ball it meets (ghost-ball contact), the object
// ball's departure line (line of centres) and the cue ball's stun tangent line. Uses the squirt-corrected shot angle.
extension TrainingController {
    func updateAimGuide(){
        guard let c=cue,!c.sunk else{table.aimGuide(cue:nil);return}
        let R=geometry.radius,a=table.shotAngle(c,angle:angle,side:side,top:top)
        let d=SIMD2<Double>(cos(a),sin(a)),p=SIMD2<Double>(c.x,c.y)
        let hx=geometry.width/2-R,hy=geometry.length/2-R
        func wall(_ o:SIMD2<Double>,_ v:SIMD2<Double>)->Double{
            var t=Double.infinity
            if v.x>1e-9{t=min(t,(hx-o.x)/v.x)}else if v.x < -1e-9{t=min(t,(-hx-o.x)/v.x)}
            if v.y>1e-9{t=min(t,(hy-o.y)/v.y)}else if v.y < -1e-9{t=min(t,(-hy-o.y)/v.y)}
            return t.isFinite ? max(0,t):0
        }
        var best=wall(p,d),hit:BallState? = nil
        for b in balls where b.id != 0 && !b.sunk {
            let m=p-SIMD2<Double>(b.x,b.y),bq=simd_dot(m,d),cc=simd_dot(m,m)-4*R*R,disc=bq*bq-cc
            guard disc>=0 else{continue}
            let t = -bq-disc.squareRoot();if t>0 && t<best{best=t;hit=b}
        }
        let g=p+d*best
        func f(_ v:SIMD2<Double>)->SIMD2<Float>{SIMD2<Float>(Float(v.x),Float(v.y))}
        guard let b=hit else{table.aimGuide(cue:f(p),ghost:f(g),ringVisible:false);return}
        let o=SIMD2<Double>(b.x,b.y),n=simd_normalize(o-g)
        let oe=o+n*min(0.9,wall(o,n))
        let tan=d-n*simd_dot(d,n),tl=simd_length(tan)
        let te:SIMD2<Float>? = tl>0.05 ? f(g+(tan/tl)*min(0.3,wall(g,tan/tl))):nil
        table.aimGuide(cue:f(p),ghost:f(g),object:f(o),objectEnd:f(oe),tangentEnd:te,ringVisible:true)
    }
}

// 0.36 Tuỳ chỉnh: lighting / power / smoothness live-apply, and manual HUD arrangement (drag each key; offsets
// from the default layout are saved per hand, so the C++-tested default layout stays the base).
extension TrainingController {
    var hudItems:[(String,UIView)]{
        var items:[(String,UIView)]=[("spin",spin),("lock",lockButton),("wheel",fineWheel),("elevation",elevationPad),("rail",quickScroll),("menu",menuButton),("coach",coachButton)]
        for (k,icon) in cueIcons.enumerated(){items.append(("cue\(k)",icon))}
        return items
    }
    func hudOffsetKey(_ name:String)->String{"hudOffset036-"+(leftHanded ? "L":"R")+"-"+name}
    func applyHUDOffsets(){
        // 0.38 Tuỳ chỉnh · kích thước phím: scale the key bounds about their centre (not a transform: the elevation fan
        // and wheel carry their own zoom transform while touched).
        let k=CGFloat(Tuning.hudScale)
        if abs(k-1)>0.01 {
            var scaled:[UIView]=[lockButton,menuButton,coachButton]+cueIcons
            if !spinExpanded{scaled.append(spin)}
            for v in scaled{let c=v.center;v.bounds.size=CGSize(width:v.bounds.width*k,height:v.bounds.height*k);v.center=c;v.setNeedsDisplay()}
            if !spinExpanded{spinWidth.constant=spin.bounds.width;spinHeight.constant=spin.bounds.height}
        }
        for (name,v) in hudItems{
            guard let o=UserDefaults.standard.array(forKey:hudOffsetKey(name)) as? [Double],o.count==2 else{continue}
            v.center=CGPoint(x:v.center.x+o[0],y:v.center.y+o[1])
        }
        applyHUDFade()
    }
    /// 0.38: three saved key layouts (per hand), copied from/to the live offsets.
    func hudSlotKey(_ n:Int,_ name:String)->String{"hudSlot038-\(n)-"+hudOffsetKey(name)}
    func saveHUDLayout(_ n:Int){
        for (name,_) in hudItems{UserDefaults.standard.set(UserDefaults.standard.array(forKey:hudOffsetKey(name)) ?? [0.0,0.0],forKey:hudSlotKey(n,name))}
        notifyStatus("Đã lưu bố cục phím \(n)")
    }
    func loadHUDLayout(_ n:Int){
        var found=false
        for (name,_) in hudItems{if let o=UserDefaults.standard.array(forKey:hudSlotKey(n,name)){found=true;UserDefaults.standard.set(o,forKey:hudOffsetKey(name))}}
        hudLayoutKey="";view.setNeedsLayout();layoutRightHUD()
        notifyStatus(found ? "Đang dùng bố cục phím \(n)":"Bố cục \(n) chưa lưu")
    }
    func applyTuning(){
        table.applyTuning();layoutRightHUD()
        let tint=UserDefaults.standard.object(forKey:"clothTintIndex") as? Int ?? -1
        if tint != appliedClothTint {appliedClothTint=tint;table.setClothColor(tint<0 ? nil:tint)}   // only rebuild on change
        let worn=UserDefaults.standard.bool(forKey:"clothWear021");if worn != table.oldCloth {table.setClothWear(old:worn)}
        if matchPlay.active {updateScoreboard()}
        if table.cameraMode==2 && !shotActive && replayIndex==nil {restoreAimCamera(transition:0.3)}   // preview the default aim view
        scn.contentScaleFactor=UIScreen.main.scale*CGFloat(Tuning.renderScale)
        displayLink?.preferredFramesPerSecond=Tuning.frameRate
        guideDirty=true;wakeRendering()
    }
    func openCustomize(){
        setMenu(false)
        let vc=CustomizeController()
        vc.changed={[weak self] in self?.applyTuning()}
        vc.openPhysics={[weak self] in self?.settings()}
        vc.openDiagnostics={[weak self] in self?.graphics()}
        vc.arrangeHUD={[weak self] in self?.beginHUDArrange()}
        vc.saveLayout={[weak self] n in self?.saveHUDLayout(n)}
        vc.loadLayout={[weak self] n in self?.loadHUDLayout(n)}
        vc.resetHUD={[weak self] in guard let self=self else{return}
            for (name,_) in self.hudItems{UserDefaults.standard.removeObject(forKey:self.hudOffsetKey(name))}
            self.hudLayoutKey="";self.view.setNeedsLayout();self.layoutRightHUD()}
        let nav=UINavigationController(rootViewController:vc);nav.modalPresentationStyle = .formSheet;present(nav,animated:true)
    }
    func beginHUDArrange(){
        let overlay=UIView(frame:view.bounds);overlay.autoresizingMask=[.flexibleWidth,.flexibleHeight]
        overlay.backgroundColor=UIColor(white:0,alpha:0.25);overlay.accessibilityIdentifier="HUDArrange"
        let note=UILabel();note.text="Kéo từng phím tới vị trí muốn · bấm Xong để lưu";note.textColor = .white
        note.font = .systemFont(ofSize:14,weight:.semibold);note.textAlignment = .center
        note.backgroundColor=UIColor(white:0,alpha:0.6);note.layer.cornerRadius=10;note.clipsToBounds=true
        note.frame=CGRect(x:view.bounds.midX-190,y:view.safeAreaInsets.top+12,width:380,height:36);overlay.addSubview(note)
        let done=UIButton.lab("Xong"){[weak self,weak overlay] in overlay?.removeFromSuperview();self?.layoutRightHUD()}
        done.frame=CGRect(x:view.bounds.midX-50,y:view.safeAreaInsets.top+56,width:100,height:44);overlay.addSubview(done)
        var dragging:(String,UIView,CGPoint)?
        let pan=UIPanGestureRecognizer()
        pan.addAction{[weak self,weak overlay] g in
            guard let self=self,let overlay=overlay else{return}
            let p=g.location(in:self.view)
            switch g.state{
            case .began:
                // Topmost visible HUD key under the finger (enlarged 10 pt so small keys are easy to grab).
                dragging=self.hudItems.reversed().first{!$0.1.isHidden && $0.1.frame.insetBy(dx:-10,dy:-10).contains(p)}.map{($0.0,$0.1,$0.1.center)}
                if let d=dragging{d.1.alpha=0.6;self.view.bringSubviewToFront(d.1);self.view.bringSubviewToFront(overlay)}
            case .changed:
                guard let d=dragging,let pg=g as? UIPanGestureRecognizer else{return};let t=pg.translation(in:self.view)
                var c=CGPoint(x:d.2.x+t.x,y:d.2.y+t.y);let b=self.view.bounds,h=d.1.bounds
                c.x=min(max(c.x,h.width/2),b.width-h.width/2);c.y=min(max(c.y,h.height/2),b.height-h.height/2);d.1.center=c
            default:
                guard let d=dragging else{return};d.1.alpha=1
                let old=UserDefaults.standard.array(forKey:self.hudOffsetKey(d.0)) as? [Double] ?? [0,0]
                let moved=CGPoint(x:d.1.center.x-d.2.x,y:d.1.center.y-d.2.y)
                UserDefaults.standard.set([old[0]+Double(moved.x),old[1]+Double(moved.y)],forKey:self.hudOffsetKey(d.0));dragging=nil
            }
        }
        overlay.addGestureRecognizer(pan);view.addSubview(overlay)
    }
}

private final class GestureAction:NSObject {
    let run:(UIGestureRecognizer)->Void
    init(_ run:@escaping(UIGestureRecognizer)->Void){self.run=run}
    @objc func fire(_ g:UIGestureRecognizer){run(g)}
}
private var gestureActionKey:UInt8=0
extension UIGestureRecognizer {
    func addAction(_ run:@escaping(UIGestureRecognizer)->Void){
        let target=GestureAction(run);objc_setAssociatedObject(self,&gestureActionKey,target,.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        addTarget(target,action:#selector(GestureAction.fire(_:)))
    }
}

// MARK: - 0.38 Highlight video (owner: replay cuts for promotion)

/// Writes the cinematic replay (3 cuts) to an H.264 .mp4 at 30 fps, 1280 px wide, from SCNView snapshots.
/// Render-side only: frames come from the replay clock, so the file has the same timing as the on-screen replay.
final class HighlightRecorder {
    private let writer:AVAssetWriter
    private let input:AVAssetWriterInput
    private let adaptor:AVAssetWriterInputPixelBufferAdaptor
    private let size:CGSize
    private var frame=0
    private var lastCapture=0.0
    let url:URL
    init?(aspect:CGFloat){
        let w:CGFloat=1280,h=(w/max(0.5,aspect)/2).rounded()*2
        size=CGSize(width:w,height:h)
        url=FileManager.default.temporaryDirectory.appendingPathComponent("ZokerPool-highlight-\(Int(Date().timeIntervalSince1970)).mp4")
        guard let w=try? AVAssetWriter(outputURL:url,fileType:.mp4) else{return nil}
        writer=w
        input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:Int(size.width),AVVideoHeightKey:Int(size.height),
            AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:8_000_000,AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel]])
        input.expectsMediaDataInRealTime=true
        adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:Int(size.width),kCVPixelBufferHeightKey as String:Int(size.height)])
        guard writer.canAdd(input) else{return nil}
        writer.add(input);guard writer.startWriting() else{return nil}
        writer.startSession(atSourceTime:.zero)
    }
    /// Call every display tick with the wall-clock time; keeps 30 fps.
    func capture(_ image:UIImage,now:Double){
        guard now-lastCapture>=1.0/30.0-0.002,input.isReadyForMoreMediaData,let pool=adaptor.pixelBufferPool else{return}
        lastCapture=now
        var buffer:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,pool,&buffer);guard let pb=buffer else{return}
        CVPixelBufferLockBaseAddress(pb,[]);defer{CVPixelBufferUnlockBaseAddress(pb,[])}
        guard let ctx=CGContext(data:CVPixelBufferGetBaseAddress(pb),width:Int(size.width),height:Int(size.height),bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pb),
                                space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue),let cg=image.cgImage else{return}
        ctx.draw(cg,in:CGRect(origin:.zero,size:size))
        adaptor.append(pb,withPresentationTime:CMTime(value:CMTimeValue(frame),timescale:30));frame+=1
    }
    func finish(_ done:@escaping(URL?)->Void){
        input.markAsFinished()
        let ok=frame>0;writer.finishWriting{[url] in DispatchQueue.main.async{done(ok ? url:nil)}}
    }
}


// MARK: - 0.41 Xem lại · góc quay "Action camera"
extension TrainingController {
    /// Pocket mouths on the playing surface, physics (x, y) = scene (x, z); order as World::pocket.
    static let actionMouths:[SIMD2<Float>]=[SIMD2(-0.60,-1.235),SIMD2(0.60,-1.235),SIMD2(-0.66,0),SIMD2(0.66,0),SIMD2(-0.60,1.235),SIMD2(0.60,1.235)]
    /// Owner 13/11: more cinematic replay angles, "Action camera" style, with clean cuts.
    /// 4 chase the cue ball (low, just behind it) · 5 chase the first object ball · 6 low pocket cam meeting the potted
    /// ball · 7 crane orbiting the table · 8 Action Mix: cue chase → object chase → pocket cam → crane, cut by events.
    func updateActionCamera(_ i:Int,_ j:Int,fraction:Double,span:Double,dt:Double){
        guard replayIndex != nil,frames.indices.contains(i),frames.indices.contains(j) else{table.actionCamera=nil;return}
        let a=frames[i],b=frames[j],f=Float(max(0,min(1,fraction)))
        func position(_ id:Int)->SIMD2<Float>?{
            guard let p=a.first(where:{$0.id==id}) else{return nil}
            let q=b.first(where:{$0.id==id}) ?? p
            return SIMD2(Float(p.x+(q.x-p.x)*Double(f)),Float(p.y+(q.y-p.y)*Double(f)))
        }
        func heading(_ id:Int)->SIMD2<Float>{
            var dir=actionDirections[id] ?? SIMD2(Float(cos(lastShot?.aimAngle ?? angle)),Float(sin(lastShot?.aimAngle ?? angle)))
            if span>0,let p=a.first(where:{$0.id==id}),let q=b.first(where:{$0.id==id}),!q.sunk {
                let v=SIMD2(Float(q.x-p.x),Float(q.y-p.y))/Float(span)
                if simd_length(v)>0.04 {dir=simd_normalize(dir+(simd_normalize(v)-dir)*min(1,Float(dt)*5))}
            }
            if simd_length(dir)<1e-4 {dir=SIMD2(0,1)}
            dir=simd_normalize(dir);actionDirections[id]=dir;return dir
        }
        let events=lastShotEvents
        let contact=events.first{($0["kind"]?.intValue ?? -1)==1 && (($0["a"]?.intValue ?? -1)==0 || ($0["b"]?.intValue ?? -1)==0)}
        let objectID=contact.map{($0["a"]?.intValue ?? 0)==0 ? ($0["b"]?.intValue ?? 1):($0["a"]?.intValue ?? 1)} ?? 1
        let pot=events.first{($0["kind"]?.intValue ?? -1)==2 && ($0["a"]?.intValue ?? 0)>0}
        let potID=pot?["a"]?.intValue ?? objectID,potPocket=min(5,max(0,pot?["b"]?.intValue ?? 0)),potTime=pot?["time"]?.doubleValue ?? .infinity
        let contactTime=contact?["time"]?.doubleValue ?? 0
        let end=frameTimes.last ?? 0
        var shot=replayCamera
        if replayCamera==8 {
            if replayClock<contactTime-0.12 {shot=4}
            else if replayClock>=potTime-0.8 && replayClock<potTime+0.6 {shot=6}
            else if replayClock>=min(potTime+0.6,end-1.4) {shot=7}
            else {shot=5}
        }
        if shot != actionShot {beginCameraTransition(actionShot<0 ? 0:0.35);actionShot=shot}   // quick glide = action cut
        func chase(_ id:Int)->(SIMD3<Float>,SIMD3<Float>,Float)?{
            guard let p=position(id) else{return nil}
            let d=heading(id)
            var eye=SIMD3(p.x-d.x*0.42,0.11,p.y-d.y*0.42)
            if abs(eye.x)>0.64||abs(eye.z)>1.28 {eye.y=0.16}   // over the rail: rise above the wood
            eye.x=max(-0.95,min(0.95,eye.x));eye.z=max(-1.6,min(1.6,eye.z))
            return (eye,SIMD3(p.x+d.x*0.55,0.03,p.y+d.y*0.55),54)
        }
        var pose:(SIMD3<Float>,SIMD3<Float>,Float)?
        switch shot {
        case 4: pose=chase(0)
        case 5: pose=chase(objectID) ?? chase(0)
        case 6:
            let mouth=Self.actionMouths[potPocket]
            let outward=simd_normalize(mouth)   // from the table centre out through the pocket
            let eye=SIMD3(mouth.x+outward.x*0.05,0.05,mouth.y+outward.y*0.05)
            let ball=position(potID).map{SIMD3($0.x,0.028,$0.y)} ?? SIMD3(mouth.x*0.7,0.028,mouth.y*0.7)
            pose=(eye,ball,40)
        default:
            actionCraneYaw+=Float(dt)*0.22*(replayPaused ? 0:1)
            let moving=a.filter{!$0.sunk}
            var centre=SIMD2<Float>(0,0)
            if !moving.isEmpty {centre=moving.reduce(SIMD2<Float>(0,0)){$0+SIMD2(Float($1.x),Float($1.y))}/Float(moving.count)*0.5}
            let yaw=Float(lastShot?.aimAngle ?? angle)+Float.pi+actionCraneYaw
            pose=(SIMD3(cos(yaw)*1.7,1.15,sin(yaw)*2.3),SIMD3(centre.x,0,centre.y),46)
        }
        if let pose=pose {table.actionCamera=(eye:pose.0,target:pose.1,fov:pose.2)}
    }
}
