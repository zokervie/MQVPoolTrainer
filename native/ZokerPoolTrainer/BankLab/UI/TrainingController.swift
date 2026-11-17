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
    /// 0.44.1 M4: the new tutorial (Tutorial044.swift).
    var firstShotCoach:FirstShotCoach?
    var tutorialShots=0,freshTutorialDone=false,qaTutorialStrokeFired=false
    /// 0.44.1 M5: the intro films on the play table — while it runs, the play loop leaves the balls and camera alone.
    var introRunning=false,introFinishCount=0,introStarted=false
    var intro:IntroDirector0441?
    func layoutHUDAfterIntro(){refresh();updateControls();view.setNeedsLayout()}
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
        /// 0.44.1: the refresh rate in force when THIS shot was struck (the diagnostics must not read today's setting).
        var frameRate=60
    }
    var shotProfile=ShotProfile()
    /// 0.44-mm: the first live tick after a strike advances at most one refresh, whatever the strike's own main-thread
    /// cost was (UIKit commit, haptics, audio start). Before, that stall went straight into the solver: the cue ball
    /// jumped up to 0.1 s (70 cm at 7 m/s) on the very first frame. Replay never had it — its lead-in absorbs the stall.
    var liveStartPending=false
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
    /// 0.44 (#17): an offline replay → MP4 export in progress (display link paused, frames stepped at 1/60 s).
    var videoExport:ReplayVideoExport?
    var consistencyKey="",consistencyStops:[SIMD2<Double>]=[]
    func applyHUDFade(){
        let a:CGFloat=hudFaded ? 0.22:CGFloat(Tuning.hudAlpha)
        UIView.animate(withDuration:hudFaded ? 0.18:0.25,delay:0,options:[.beginFromCurrentState,.allowUserInteraction]){
            for v in self.cueIcons{v.alpha=a}
            for v in [self.quickScroll,self.lockButton,self.elevationPad,self.menuButton,self.coachButton] as [UIView]{v.alpha=a}
            self.spin.alpha=self.hudFaded ? 0.25:(self.spinExpanded ? (self.loupesActive ? 0.02:0.97):0.60*CGFloat(Tuning.hudAlpha))
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
    var placementGrab=SIMD2<Double>(0,0),placementPose:CameraPose?   // 0.42 ball in hand
    // 0.25: practice history (step back / forward per shot or whole session) and session highlights.
    /// 0.30: each step keeps the layout AND the setup used for the shot taken from it (gậy, độ dốc, effect, hướng).
    /// 0.44 (owner item 7: "lùi cú phải trở lại góc nhắm lúc ra cơ… hiện bị chuyển sang góc khác phải canh lại"): the
    /// setup now carries the aim camera as it was at the stroke (pose + yaw offset from the aim line) and the cue type.
    struct ShotSetup{var angle:Double,side:Double,top:Double,kind:Int,elevation:Double;var aimYaw:Double=0;var camera:CameraPose?=nil;var cueType:Int?=nil}
    struct ShotStep{var balls:[BallState];var setup:ShotSetup?}
    var shotBack:[ShotStep]=[],shotForward:[ShotStep]=[]
    /// 0.30: Đánh / Jump / Massé / Break above the effect ball (BLHUDCueIcon, BLCueIconKind).
    var cueIcons:[UIButton]=[]
    /// 0.33: "Nút số" (diamond numbers, always offered) and "Chỉ dẫn" (aim/guide lines, shown when Coach is on),
    /// next to Coach. Replay camera: 0 điện ảnh tự động, 1 người đánh 3D, 2 toàn bàn, 3 trên cao.
    let numbersButton=UIButton(type:.system),guideToggle=UIButton(type:.system),cardToggle=UIButton(type:.system)
    /// 0.35: Chỉ dẫn has two modes — 1 to the aim point (cue path to first contact), 2 the whole run. Bảng shows/hides the coach card.
    // 0.44 (owner item 9): Coach opens with Nút số + điểm ngắm only; the shot-grading card ("Chấm cú", was "Bảng" —
    // nobody knew what it was) is off until the player turns it on, and stays as chosen.
    var guideMode=UserDefaults.standard.integer(forKey:"guideMode035")==1 ? 1:2,cardOn=UserDefaults.standard.bool(forKey:"coachCard044")
    var numbersOn=UserDefaults.standard.object(forKey:"numbersOn033") as? Bool ?? true
    var replayCamera=UserDefaults.standard.integer(forKey:"replayCamera041")
    /// 0.41 Action camera state: current cut, smoothed travel directions, crane yaw.
    var actionShot = -1,actionDirections:[Int:SIMD2<Float>]=[:],actionCraneYaw:Float=0
    var actionSmooth:(eye:SIMD3<Float>,target:SIMD3<Float>)?
    func currentSetup()->ShotSetup{
        ShotSetup(angle:angle,side:side,top:top,kind:shotKind,elevation:table.cueElevation,aimYaw:aimCameraYaw,
                  camera:table.cameraMode==2 && replayIndex==nil ? captureCamera():savedAimCamera,cueType:engine.settings["cueType"]?.intValue)
    }
    var lastShotSetup:ShotSetup?
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
            // 0.43: xoáy ngang 11 rad/s² của 0.42 — 0.42 quên bỏ giá trị 15 đã lưu nên máy cũ vẫn chạy 15; squirt theo
            // tuỳ chọn mới. Bỏ giá trị đã lưu của các khóa này để dùng mặc định mới.
            if UserDefaults.standard.integer(forKey:"physicsModelVersion")<43 {
                for key in ["spinDecay","squirtRampDegrees","ballFrictionMin","ballFrictionFactor"]{config[key]=nil}   // + độ sạch bi: về Thường
                UserDefaults.standard.set(config,forKey:"physics");UserDefaults.standard.set(43,forKey:"physicsModelVersion")
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
        if ProcessInfo.processInfo.arguments.contains("--visual-qa") || ProcessInfo.processInfo.arguments.contains("--keep-lobby-qa") || ProcessInfo.processInfo.arguments.contains("--intro-lobby-qa"){scn.isAccessibilityElement=true;scn.accessibilityIdentifier="PoolScene"}
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
        // 0.44.1 review (high): Game Center's sign-in sheet used to pop up during the intro, then openLobby() bailed out
        // on presentedViewController and the first launch had neither Lobby nor tutorial. It now waits for the table.
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
            if args.contains("--perf-qa"){startPerfQA()}   // 0.44-mm
            startLANQA()   // 0.44-mm: no-op without --lan-host-qa / --lan-join-qa
            if args.contains("--coach-card-qa"){DispatchQueue.main.asyncAfter(deadline:.now()+1.5){[weak self] in   // 0.44.1 language test
                guard let self=self else{return};self.coaching=true;self.cardOn=true;self.loadDrill(Drill.startup);self.showCoach(self.drillBrief(Drill.all[Drill.startup]))}}
            if args.contains("--cue-look-qa"){DispatchQueue.main.asyncAfter(deadline:.now()+2){[weak self] in self?.startCueLookQA()}}   // 0.44.1 M3 stills
            if args.contains("--wall-photo-qa"){DispatchQueue.main.asyncAfter(deadline:.now()+2){[weak self] in self?.startWallPhotoQA()}}   // 0.44.1 M2
            if args.contains("--nearby-qa"){DispatchQueue.main.asyncAfter(deadline:.now()+(args.contains("--lan-host-qa") ? 6:2)){[weak self] in self?.openNearbyLobby(tab:args.contains("--lan-host-qa") ? 0:1)}}   // 0.44-mm Nearby Play screen (QA guest opens Tìm phòng)
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
                    DispatchQueue.main.asyncAfter(deadline:.now()+(left==40 ? (args.contains("--ux018-jump-qa") ? 2:2.5):0.5)){[weak self] in   // 0.43: 2.5 s — the UI test must see the balls running (CI 144/145)
                        guard let self=self,!self.shotActive,self.frames.isEmpty else{return}
                        // 0.39d: a startup gate can swallow chooseShotKind(1) — re-select before every attempt.
                        if args.contains("--ux018-jump-qa") && self.shotKind != 1 {self.locked=false;self.chooseShotKind(1)}
                        self.locked=true;self.shoot(args.contains("--ux018-jump-qa") ? 1:3)   // 0.44: a longer run so the UI test meets the balls moving
                        if self.shotActive {self.qaShots+=1;self.spin.collapse();self.setHold(false)}   // 0.44: exactly like a real stroke (stroke.shot) — the hold ends, gestures work during the run
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
                    precondition(self.poolAudio.sampleCount==7,"All 7 real audio assets must load (0.41: owner kept the 0.17 set, Tools/AudioSources/manifest.json)")
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
        spin.changed={[weak self]x,y in self?.side=x;self?.top=y;self?.guideDirty=true;self?.wakeRendering();self?.updateSpinLoupe()}
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
        let layoutStart=CACurrentMediaTime();defer{if let perf=Self.perfSegment {perf.layoutTime+=CACurrentMediaTime()-layoutStart}}
        super.viewDidLayoutSubviews()
        if shotActive {shotProfile.layoutPasses+=1}
        Self.perfSegment?.layoutPasses+=1
        let safe=hudSafeFrame
        let key="\(view.bounds.size)|\(safe)|\(leftHanded)|\(spinExpanded)|\(UserDefaults.standard.object(forKey:"loupes042") as? Bool ?? true)|\(menuOpen)|\(matchIsCompetitive)|\(matchIsCompetitive && matchBool("requiresCall"))|\(Tuning.hudScale)|\(replayIndex != nil)"
        // 0.39d (CI 125): skip ONLY while balls are moving (live shot / replay) and nothing that places keys changed.
        // At rest every pass lays the HUD out exactly like 0.39 (shot kind, coach, ball editing… all rely on it);
        // a pass skipped mid-motion is replayed once the table is still.
        // Code audit: a guest watching the host's shot gets scoreboard text at up to 10 Hz — that is motion too.
        let moving=shotActive || replayIndex != nil || (matchPlay.session.role == .guest && matchPlay.session.latestSnapshot?.isMoving==true)
        if moving && key==hudLayoutKey && !Self.legacyStatusAB {hudLayoutDeferred=true;return}
        hudLayoutKey=key;hudLayoutDeferred=false
        if shotActive {shotProfile.hudRelayouts+=1}
        Self.perfSegment?.hudRelayouts+=1
        layoutRightHUD();wakeRendering()
    }
    var lobbyShown=false,gameCenterAsked=false
    override func viewDidAppear(_ animated:Bool){
        super.viewDidAppear(animated)
        if !shadersPrewarmed {shadersPrewarmed=true;prewarmShaders()}
        table.pacingOwner={[weak self] in
            guard let self=self else{return false}
            return self.shotActive || self.replayIndex != nil || (self.matchPlay.session.latestSnapshot?.isMoving==true && self.matchPlay.session.role == .guest)
        }
        // 0.44.1 M5: the intro plays FIRST, on this table; the Lobby opens only when it has finished or was skipped
        // (0.43 put the intro on the window and the Lobby covered it at once).
        if !introStarted {
            introStarted=true
            if let director=makeIntro() {intro=director;director.run{[weak self] in self?.intro=nil;self?.viewDidAppear(false)};return}
        }
        if intro != nil {return}
        // QA/CI launches go straight to the table so probes and gestures are unchanged.
        // 0.44.1: --keep-lobby-qa runs the real first-launch path (Lobby → Tập tự do → tutorial) under QA.
        let qa=(ProcessInfo.processInfo.arguments.contains{$0.hasPrefix("--") && $0.hasSuffix("qa")} || ProcessInfo.processInfo.arguments.contains("--visual-qa")) && !ProcessInfo.processInfo.arguments.contains("--keep-lobby-qa") && !ProcessInfo.processInfo.arguments.contains("--intro-lobby-qa")
        if !lobbyShown && !qa {lobbyShown=openLobby()}   // only "shown" if it really was presented
        // Game Center sign-in only once the player is at the table (after intro and Lobby).
        if lobbyShown && presentedViewController==nil && !gameCenterAsked && !ProcessInfo.processInfo.arguments.contains(where:{$0.hasPrefix("--")}) {
            gameCenterAsked=true;DispatchQueue.main.asyncAfter(deadline:.now()+2.5){GameCenterHub.shared.authenticate()}
        }
        // 0.44.1 M4: the tutorial starts when the player first reaches the table AFTER the Lobby has closed (this
        // runs again when the full-screen Lobby is dismissed). 0.44 started it from a timer while the Lobby covered
        // the table, so startTutorial() bailed out on view.window and the first launch never saw it.
        if presentedViewController==nil && (lobbyShown || ProcessInfo.processInfo.arguments.contains("--tutorial-qa")) {DispatchQueue.main.asyncAfter(deadline:.now()+0.4){[weak self] in self?.maybeStartTutorial()}}
    }
    var toastGeneration=0
    var lastCoachToggle=0.0
    /// Trục của lần kéo một ngón hiện tại: 0 chưa quyết, 1 ngang (hướng ngắm), 2 dọc (độ cao camera).
    var aimPanAxis=0
    var deferredStroke:(speed:Double,until:Double)?
    // MARK: Cơ tránh băng (BankLab/UI/CueClearance.h, Tests/CueClearanceTests.cpp)
    struct TableGeometry {var width=1.27,length=2.54,radius=0.028575,nose=0.27}
    var geometry=TableGeometry()
    /// Object-ball positions for the clearance test; refreshed in updateCueClearance (the effect pad samples it often).
    var obstacleXs:[Double]=[],obstacleYs:[Double]=[]
    func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldReceive touch:UITouch)->Bool{
        guard !menuOpen,!spinExpanded,!locked else{return false}
        if gestureRecognizer is UIPinchGestureRecognizer || (gestureRecognizer as? UIPanGestureRecognizer)?.minimumNumberOfTouches==2{return true}
        return !isPlacingBalls || localTurn
    }
    func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith other:UIGestureRecognizer)->Bool{
        let pair=[gestureRecognizer,other]
        return pair.contains{$0 is UIPinchGestureRecognizer} && pair.contains{($0 as? UIPanGestureRecognizer)?.minimumNumberOfTouches==2}
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
