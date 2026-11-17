import UIKit
import GameKit
import SceneKit
import simd
import AVFoundation

// 0.45 M2: tách nguyên khối từ TrainingController.swift (không đổi hành vi). ShotLoop: quyền ra cơ, shoot, tick/frameStep (pacing, đo), finishShot, phiên cú, undo/reset.
extension TrainingController {
    var presentationBusy:Bool{shotActive || replayIndex != nil || replayPreparing || BLShotCameraBusy(shotCameraState)}
    var strokeHint:String{
        "Chọn gậy → ngắm → giữ bi effect (khóa hướng, chỉnh điểm chạm) → ngón khác kéo lùi rồi đẩy tới: nhanh hơn là mạnh hơn. Buông bi effect để ngắm lại."
    }

    var strokeAllowed:Bool{
        BLStrokeAllowed(localTurn && matchCanStroke,presentationBusy,menuOpen,spinExpanded,isPlacingBalls,cue?.sunk==false)
    }
    // ---- 0.44 (owner item 2: "đã hiển thị mức lực mà không ra cơ", Wi‑Fi / cùng máy) ----------------------------------
    // ROOT CAUSE: permission was re-evaluated on every control sync (a network snapshot, the 0.5 s turn check, the camera
    // finishing its return) and `stroke.isEnabled = locked && strokeAllowed` CANCELLED a stroke already in progress, and the
    // release re-checked it again and dropped the shot silently. Now permission is granted once, when the effect ball is
    // held (setHold); from then on only a HARD block (turn really lost, match over, menu, ball in hand, cue ball gone, a shot
    // already running) cancels. A release that meets a transient block (pending packet, camera settling) is queued ≤ 1.2 s.
    var strokeHardBlocked:Bool{
        if shotActive || replayIndex != nil || menuOpen || isPlacingBalls || cue?.sunk != false || !localTurn {return true}
        guard matchPlay.active else{return false}
        if matchInt("winner",fallback:-1)>=0 || matchPlay.placementDraft != nil {return true}
        if matchPlay.computerLevel != nil && matchInt("currentPlayer")==1 {return true}
        if matchPlay.session.role != .none && matchInt("currentPlayer") != matchPlay.session.localPlayer {return true}
        return false
    }
    var strokeStaysArmed:Bool{locked && !strokeHardBlocked}
    func deferStroke(_ speed:Double){
        guard !strokeHardBlocked || (matchPlay.active && matchPlay.session.isApplyingCommand) else{notifyStatus("Hết lượt / đang có cú khác — cú vừa rồi không được đánh");return}
        deferredStroke=(speed,ProcessInfo.processInfo.systemUptime+1.2);wakeRendering()
    }
    func serviceDeferredStroke(){
        guard let pending=deferredStroke else{return}
        if strokeHardBlocked && !shotActive {deferredStroke=nil;notifyStatus("Hết lượt — cú vừa rồi không được đánh");return}
        if shotActive {deferredStroke=nil;return}
        if strokeAllowed {
            deferredStroke=nil;locked=true;shoot(pending.speed);if locked{setHold(false)}
            return
        }
        if ProcessInfo.processInfo.systemUptime>pending.until {deferredStroke=nil;notifyStatus("Chưa đồng bộ kịp với máy bạn — anh đánh lại cú này")}
        else{wakeRendering()}
    }
    var balls:[BallState]{matchDisplayedBalls ?? frameStateCache ?? engine.ballStates}
    var cue:BallState?{balls.first{$0.id==0}}
    func loadDrill(_ index:Int){
        guard matchAllowsEditing else{return}
        guard !presentationBusy,localTurn else{return}
        drillIndex=index;attempts=0;successes=0;lessonActive=false;lessonScores=[];lessonPasses=0;let drill=Drill.all[index]
        table.target(coachOn ? drill.goal:nil)
        initial=drill.balls;before=initial;angle=drill.angle
        engine.loadLayout(initial.map{$0.dictionary});clearShot();locked=false;isPlacingBalls=false;spin.reset();applyDrillTip()
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
    func shoot(_ speed:Double){
        // 0.41 (owner: "cú phá đầu tiên không thao tác được"): the first stroke of a rack only ended the rack intro and
        // was thrown away. The intro is presentation only (the solver already holds the rack): end it and play the shot.
        if table.rackIntroPlaying{table.skipRackIntro()}
        if routeMatchShot(speed){return}
        guard locked,speed.isFinite,speed>0 else{return}
        guard strokeAllowed else{deferStroke(speed);return}   // 0.44: never drop a stroke the power bar already showed
        // 0.44-mm --perf-qa: main-thread cost of the strike itself, by stage (the next tick's dt includes all of it).
        var strikeMark=CACurrentMediaTime();var strikeStages:[String:Double]=[:]
        func mark(_ name:String){let now=CACurrentMediaTime();strikeStages[name]=now-strikeMark;strikeMark=now}
        let strikeAge=lastTime>0 ? strikeMark-lastTime:-1   // how old the previous tick's target was at the strike
        defer{strikeStages["previousTickAge"]=strikeAge;Self.perfSegment?.strike=strikeStages;Self.perfSegment?.strikeEnd=CACurrentMediaTime()}
        capturePreparation(time:ProcessInfo.processInfo.systemUptime);mark("preparation")
        let origin=aimBuffer.first?.time ?? 0
        lastPreparation=aimBuffer.map{var sample=$0;sample.time-=origin;return sample}
        aimBuffer.removeAll()
        coachGeneration+=1;predictionGeneration+=1
        lastShotSpeed=speed
        displayDurations=[]
        table.pacer.clear()
        table.pacer.interval=1.5/Double(Tuning.frameRate)   // 0.39d: half a frame of slack for main-thread jitter
        table.pacer.resetDiagnostics();shotProfile=ShotProfile();shotProfile.frameRate=Tuning.frameRate
        perfBegin("live")   // 0.44-mm: no-op unless --perf-qa
        liveStartPending=true
        // Seed the pre-strike pose, so the first interpolated frame includes
        // the start of the stroke rather than jumping to the first sample.
        let previousPresentAt=table.presentAt
        table.presentAt=lastTime>0 ? lastTime:CACurrentMediaTime()
        table.update(balls,dt:0);mark("seedPose")
        table.presentAt=previousPresentAt
        testSpeed=speed
        hintLabel.text=String(format:"Cú vuốt vừa rồi · %.2f m/s · %@",speed,CueLook.roles[engine.settings["cueType"]?.intValue ?? 0])
        shotCameraAnchor=cue;liveCameraAngle=angle
        if table.cameraMode==2 {savedAimCamera=captureCamera()}
        BLShotCameraStart(&shotCameraState)
        cameraManual=false;lastDirectorTime = -10;peekPose=nil;lastShotEvents=[]
        lastShotSetup=currentSetup()
        if !matchIsCompetitive{shotBack.append(ShotStep(balls:balls,setup:lastShotSetup));shotForward.removeAll()}
        before=balls;frames=[before];frameTimes=[0];paths=[:];sampleClock=0;lastEventCount=0;mark("camera+history")
        // 0.37 (owner): a cue raised over the rail / a ball behind is a REAL elevated stroke — squirt fades in with the
        // elevation (squirtRampDegrees) and the 3D strike adds swerve/hop by speed. Restored when the shot ends.
        applySquirtPolicy()   // 0.43: picks up "Squirt thực tế" changed in Tuỳ chỉnh before this stroke
        var strikeElevation=table.cueElevation
        let forced=min(strokeClearance,85)
        if forced>table.cueElevation+0.25 {
            forcedElevationRestore=engine.settings
            var values=engine.settings;values["cueElevationDegrees"]=NSNumber(value:forced);values["experimental3D"]=true
            engine.settings=values;strikeElevation=forced
        }
        let strikeAngle=table.shotAngle(cue,angle:angle,side:side,top:top)
        lastShot=SavedShot(name:"",date:Date(),balls:balls,aimAngle:angle,speed:speed,side:side,top:top,
                           elevation:strikeElevation,cueType:engine.settings["cueType"]?.intValue ?? 0,strikeAngle:strikeAngle,shotKind:shotKind,physicsSettings:engine.settings.mapValues{$0.doubleValue})
        mark("squirt+record");hideCoach();mark("hideCoach")
        publishShotStart(strikeAngle:strikeAngle,speed:speed)   // 0.44 lockstep: the guest runs the same solver
        engine.strike(angle:strikeAngle,speed:speed,side:side,top:top);mark("strike")
        if UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true {poolAudio.play(kind:3,impact:speed,pan:audioPan(cue?.x ?? 0,cue?.y ?? 0))}
        mark("cueSound")
        shotActive=true;didStartMatchShot();mark("matchStart");attempts+=1;statusLabel.text=String(format:"Đang chạy · tốc độ đầu %.2f m/s",speed)
        feedback.impactOccurred();mark("haptic");guideDirty=true;table.trails([:]);mark("trails");setMenu(false);mark("menu");updateControls();mark("controls")
    }
    @objc func tick(_ link:CADisplayLink){
        frameStep(targetTimestamp:link.targetTimestamp,linkStamp:link.timestamp)
    }
    /// 0.44: one display frame; the video exporter (#17) drives it with a fixed 1/60 s clock while the link is paused.
    func frameStep(targetTimestamp:CFTimeInterval,linkStamp:CFTimeInterval){
        // Cold shader compilation can outlast the wake requested in viewDidLoad.
        // Always present the initial camera and accessibility state on first tick.
        if lastTime==0{startupRenderUntil=ProcessInfo.processInfo.systemUptime+8;wakeRendering()}
        if introRunning {lastTime=targetTimestamp;return}   // 0.44.1 M5: the intro director owns the table
        // 0.33: advance to the time this frame will be SHOWN (targetTimestamp), not when the callback ran — removes the
        // judder of variable callback latency; on ProMotion the shot runs at up to 120 Hz.
        let shownAt=targetTimestamp
        let dt=lastTime==0 ? 0:min(0.1,max(0,shownAt-lastTime));lastTime=shownAt
        // 0.44-mm --perf-qa: main-thread CPU of this tick, split by stage (nil segment = no cost).
        let perf=Self.perfSegment,perfT0=CACurrentMediaTime();var perfT1=perfT0,perfT2=perfT0
        if let perf=perf,perf.tick.isEmpty,perf.strikeEnd>0 {perf.strike["strikeToFirstTick"]=perfT0-perf.strikeEnd;perf.strike["firstTargetMinusNow"]=targetTimestamp-perfT0}
        defer{if let perf=perf {let end=CACurrentMediaTime();perf.tick.append(end-perfT0);perf.dt.append(dt);perf.match.append(perfT1-perfT0);perf.motion.append(perfT2-perfT1);perf.camera.append(end-perfT2)}}
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
        serviceDeferredStroke()   // 0.44
        let guestTick=matchGuestTick(dt)
        driveComputerTurn()   // 0.40 Đấu với máy (no-op unless it is the computer's turn at rest)
        tickShotClock(dt)     // 0.40b đồng hồ cú + gia hạn (no-op when off)
        perfT1=CACurrentMediaTime()
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
        table.presentAt=targetTimestamp
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
        // 0.45 M1 (c): a frame-rate RANGE, so ProMotion may hold 60 when a 120 Hz deadline cannot be met instead of
        // dropping single frames (owner's device: 33–36 % starved at 120 Hz). Set only on change (0.39c).
        setLinkRate(wantRate)
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
            // 0.44: slow motion only in the four "key moment" angles; the others always play in real time.
            let slowCam=Self.replaySlowCameras.contains(replayCamera) && !cameraManual
            let rate=replayClock<0 || Self.replayNoSlowAB || !slowCam ? 1:min(endingRate,replayAuto ? (direction?.slowMotion ?? 1):actionSlowRate(endingRate))
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
                        // 0.44 (owner item 15): the replay shows its stroke's power in the same free slot, not on the HUD.
                        if let shot=lastShot{showOpponentShot(speed:shot.speed,side:shot.side,top:shot.top,elevation:shot.elevation,cueType:shot.cueType,who:"",mirrorControls:false)}
                        if let export=videoExport {export.sound(kind:3,impact:lastShot?.speed ?? 1,pan:0)}
                        else if !replayPaused,UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true{poolAudio.play(kind:3,impact:lastShot?.speed ?? 1,pan:0)}
                    }
                }
                replaySlider.value=Float(replayClock)
                if let recorder=highlightRecorder{recorder.capture(scn.snapshot(),now:ProcessInfo.processInfo.systemUptime)}
                if !replayPaused {let a0=CACurrentMediaTime(),n=replayAudioIndex;playReplayAudio();if let perf=perf,replayAudioIndex>n {perf.audio.append(CACurrentMediaTime()-a0);perf.audioCalls+=replayAudioIndex-n}}
            }
        }else if shotActive && !guestTick && !matchSimulationPaused {
            if dt>0 {displayDurations.append(dt);if displayDurations.count>3600{displayDurations.removeFirst(displayDurations.count-3600)}}
            // 0.37 (owner replay: object ball moving before the cue ball arrives): frames were sampled at 30 Hz, so a
            // 6 m/s jump shot moved 20 cm between samples and slow-motion interpolation started the object ball early.
            // Advance in 1/240 s chunks and sample by speed: 240 Hz while anything is fast, 60 Hz medium, 30 Hz slow.
            var remaining=liveStartPending ? min(dt,1.0/Double(Tuning.frameRate)):dt
            liveStartPending=false
            perf?.physicsDt.append(remaining)
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
                    let chunk=engine.ballStates
                    sampleClock=0
                    frames.append(chunk);frameTimes.append(engine.elapsed)
                    if frames.count%4==0{for b in chunk where !b.sunk {paths[b.id,default:[]].append(SIMD3<Float>(Float(b.x),Float((b.height ?? 0)+0.004),Float(b.y)))}}
                }
            }
            // Dispatch impacts before rendering, labels or archive sampling.
            let e0=CACurrentMediaTime()
            let fresh=engine.events(since:UInt(lastEventCount))
            if !fresh.isEmpty {
                defer{if let perf=perf {perf.audio.append(CACurrentMediaTime()-e0);perf.audioCalls+=fresh.count}}
                if UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true {
                    for event in fresh {poolAudio.play(kind:event["kind"]?.intValue ?? 1,impact:event["impact"]?.doubleValue ?? 0.3,pan:audioPan(event["x"]?.doubleValue ?? 0,event["y"]?.doubleValue ?? 0),eventAge:max(0,engine.elapsed-(event["time"]?.doubleValue ?? engine.elapsed)))}
                }
                lastEventCount+=fresh.count
            }
            didAdvanceMatchShot()
            let s0=CACurrentMediaTime()
            let state=engine.ballStates;frameStateCache=state
            table.update(engine.presentationBallStates,dt:dt)
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
            if menuOpen || Self.legacyStatusAB,linkStamp-lastStatusTime>0.2,let cb=state.first(where:{$0.id==0}),!cb.sunk {
                lastStatusTime=linkStamp
                statusLabel.text=String(format:"Đang chạy · %.2f m/s · %.1f s",hypot(cb.vx ?? 0,cb.vy ?? 0),engine.elapsed)
            }
            if !engine.moving || engine.elapsed>60 {finishShot(timedOut:engine.moving);frameStateCache=nil}
        }
        perfT2=CACurrentMediaTime()
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
        if ProcessInfo.processInfo.arguments.contains("--visual-qa") || ProcessInfo.processInfo.arguments.contains("--keep-lobby-qa") || ProcessInfo.processInfo.arguments.contains("--intro-lobby-qa"){scn.accessibilityValue=String(format:"angle=%.6f;mode=%lld;moving=%lld;pitch=%.4f;coach=%lld;kind=%lld;zoom=%.4f;replay=%lld;editing=%lld;cueX=%.4f;cueY=%.4f",angle,table.cameraMode,shotActive ? 1:0,table.aimPitch,coaching ? 1:0,shotKind,table.zoom,replayIndex == nil ? 0:1,isPlacingBalls ? 1:0,cue?.x ?? 0,cue?.y ?? 0)+String(format:";side=%.4f;top=%.4f;cameraYaw=%.6f;worldCameraAngle=%.6f;ballCount=%lld;cameraAngle=%.6f",side,top,aimCameraYaw,cameraAngle,balls.filter{!$0.sunk && $0.id>0}.count,cameraAngle)+String(format:";match=%lld;guide=%lld;numbers=%lld",matchIsCompetitive ? 1:0,guideOn ? 1:0,table.showsDiamondNumbers ? 1:0)+String(format:";preRoll=%.3f;replayTime=%.3f;replayLead=%.3f",preparationDuration,replayClock,replayLead)+String(format:";coachDown=%lld;coachUp=%lld;locked=%lld;expanded=%lld;coachEnabled=%lld",qaCoachDown,qaCoachUp,locked ? 1:0,spinExpanded ? 1:0,coachButton.isEnabled ? 1:0)+";coachHit="+(view.hitTest(coachButton.center,with:nil).map{String(describing:type(of:$0))+"#"+($0.accessibilityIdentifier ?? "")} ?? "nil")+";lastTouch="+qaLastTouch+";busy="+(presentationBusy ? "1":"0")+";shots=\(qaShots);cpuShots=\(matchPlay.computerShots);cpuTurn="+(matchPlay.computerLevel != nil && matchInt("currentPlayer")==1 ? "1":"0")+";jumpSeen="+(qaJumpSeen ? "1":"0")+";lang="+L10n.code+";intro="+(intro?.mode ?? "none")+";introDone=\(introFinishCount)"+";lobby="+(presentedViewController is LobbyController ? "1":"0")+";tut="+(firstShotCoach?.state ?? "none")+String(format:";aimTarget=%.6f;elev=%.2f;stroke=%.2f",Drill.all[Drill.startup].angle,table.cueElevation,strokeClearance)+";status="+(statusLabel.text ?? "").replacingOccurrences(of:";",with:",").replacingOccurrences(of:"=",with:":")}
        if let sample=replayPreparation,replayIndex != nil {
            if replayRenderedCueType != sample.cueType{table.selectCue(sample.cueType);replayRenderedCueType=sample.cueType}
            table.cueElevation=sample.elevation
            table.showCue(displayCue,angle:sample.angle,visible:true,pull:replayStrokePull(sample.pull,clock:replayClock),side:sample.side,top:sample.top)
        }else if replayIndex != nil,replayClock>=0,replayClock<0.26,let last=lastPreparation.last,let origin=frames.first?.first(where:{$0.id==0}){
            // 0.42: the tip meets the ball and follows through at the strike position while the ball leaves.
            table.cueElevation=last.elevation
            table.showCue(origin,angle:last.angle,visible:true,pull:-Self.followThrough(replayClock),side:last.side,top:last.top)
        }else if let strike=cueStrikeAnimPose(){
            table.selectCue(strike.anim.cueType);table.cueElevation=strike.anim.elevation
            table.showCue(strike.anim.origin,angle:strike.anim.angle,visible:true,pull:strike.pull,side:strike.anim.side,top:strike.anim.top)
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
        if show && changed && !predictionPending && linkStamp-lastPredictionTime>=0.08 {
            predictionPending=true;predictionGeneration+=1;let generation=predictionGeneration
            var settings=engine.settings
            // 0.38: the predicted path uses the elevation the cue really has (auto-raised over a rail / ball).
            let forced=min(strokeClearance,85)
            if forced>table.cueElevation+0.25 {settings["cueElevationDegrees"]=NSNumber(value:forced);settings["experimental3D"]=true}
            let layout=engine.states,a=table.shotAngle(cue,angle:angle,side:side,top:top),v=referenceSpeed,x=side,y=top,aim=angle
            lastPredictionTime=linkStamp;guideDirty=false;lastGuideAngle=aim
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
        // 0.44.1 (owner device: 120 Hz → 202/557 late frames, 60 Hz → 0): a 120 Hz shot with > 10 % late frames
        // switches the app to 60 Hz for good (saved; Tuỳ chỉnh → Độ mượt can set 120 again). PresentationPolicy.h.
        let paced=table.pacer.diagnostics
        if BLShouldDropTo60Hz(Int32(shotProfile.frameRate),Int32(clamping:paced.starvedFrames),Int32(clamping:paced.sampledFrames)) != 0 {
            UserDefaults.standard.set(60,forKey:"tuneFPS036")
            setLinkRate(60)
            notifyStatus("Đã chuyển 60 Hz cho mượt")   // one language (L10n: en "Switched to 60 Hz for smoothness")
        }
        perfEnd();perfAfterShot()   // 0.44-mm: no-op unless --perf-qa
        if let restore=forcedElevationRestore{engine.settings=restore;forcedElevationRestore=nil}
        let d=Drill.all[drillIndex],events=engine.events
        lastShotEvents=events
        recordSessionShot(events)
        frames.append(balls);frameTimes.append(engine.elapsed)
        if timedOut {let stopped=balls;engine.loadLayout(stopped.map{$0.dictionary})}
        shotActive=false;locked=false
        let finishedMatch=finishMatchShot()
        tutorialShotFinished(events:events)   // 0.44.1 M4: "Vào rồi!" / "Thử lại nhé" + one contextual hint
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
        if let type=setup.cueType,type != engine.settings["cueType"]?.intValue {
            var values=engine.settings;values["cueType"]=NSNumber(value:type);engine.settings=values;table.selectCue(type);syncCueIcons()
        }
        setElevation(setup.elevation);spin.select(side:setup.side,top:setup.top);side=setup.side;top=setup.top
        angle=setup.angle
        // 0.44: back to the exact aim view of that stroke (before: the yaw was "compensated" by the angle change, which
        // swung the camera off the aim line after every undo).
        aimCameraYaw=setup.aimYaw
        if let pose=setup.camera,localTurn,replayIndex==nil {
            applyCamera(pose);table.cameraMode=2;observationCamera=false;table.focusBounds=nil;cameraButton.configuration?.title="Ngắm cơ";syncQuickRail()
        }
    }
    func undo(){guard matchAllowsEditing,localTurn,!before.isEmpty,!isPlacingBalls else{return};lockButton.releaseHold();setHold(false);engine.loadLayout(before.map{$0.dictionary});clearShot();restoreAimCamera();locked=false
        if !matchIsCompetitive,let setup=lastShotSetup{applySetup(setup)}
        else if !matchIsCompetitive,let shot=lastShot{applySetup(ShotSetup(angle:shot.aimAngle,side:shot.side,top:shot.top,kind:shot.shotKind ?? 0,elevation:shot.elevation))}
        statusLabel.text="Đã trở về trước cú đánh";refresh();updateControls()}
    func reset(){
        guard matchAllowsEditing else{return}
        guard localTurn else{return}
        if shotActive {shotActive=false}
        replayIndex=nil;engine.loadLayout(initial.map{$0.dictionary});before=initial;clearShot();locked=false;isPlacingBalls=false
        statusLabel.text="Đã khôi phục thế bi bài tập";refresh();updateControls()
    }
}
