import UIKit
import GameKit
import SceneKit
import simd
import AVFoundation

// 0.45 M2: tách nguyên khối từ TrainingController.swift (không đổi hành vi). AimInput: kiểu cú/đầu cơ, độ nâng, giữ khoá, cơ tránh băng, camera ngắm, đặt bi, cử chỉ bàn, Điểm ngắm.
extension TrainingController {
    // Đánh/Phá: no squirt, the ball leaves on the aim line. Jump/Massé keep TP A.31 squirt.
    /// 0.21: squirt on for every cue but faded in by elevation (level cue = aim line); tip by shot kind.
    func shotKindPhysics(_ kind:Int,_ values:inout [String:NSNumber]){
        // 0.43 (anh 14/11: "miễn vật lý chân thực"): Tuỳ chỉnh → "Squirt thực tế" = squirt ở mọi độ nâng (TP A.31);
        // tắt (mặc định, quyết định 03/11) = cơ ngang bi đi đúng đường ngắm, squirt tăng dần theo độ nâng.
        let realistic=UserDefaults.standard.bool(forKey:"squirtRealistic043")
        values["squirtEnabled"]=1;values["squirtRampDegrees"]=NSNumber(value:realistic ? 0:BL_SQUIRT_RAMP_DEGREES)
        values["masseCoupledContact"]=NSNumber(value:BLMasseCoupledForShotKind(Int32(kind))>0)
        values["tipProfile"]=NSNumber(value:BLTipForShotKind(Int32(kind)))
    }
    /// Largest effect offset (fraction of R), by tip — 0.43: the ONE source shared with the core (BLTipMaxOffset,
    /// Config::tipMaxOffset). Also handed to the 3D cue so the drawn contact is the contact the physics uses.
    func tipLimit(elevated:Bool)->Double{
        let limit=BLTipMaxOffset(BLTipForShotKind(Int32(shotKind)),elevated ? 1:0)
        table.tipLimit=limit
        return limit
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
    func setElevation(_ degrees:Double){
        guard !presentationBusy,localTurn,!locked else{return}
        var values=engine.settings;values["cueElevationDegrees"]=NSNumber(value:degrees);values["experimental3D"]=NSNumber(value:degrees>0)
        engine.settings=values;table.cueElevation=degrees
        let followed=Int(BLCueMergedKind(Int32(shotKind),degrees))
        if followed != shotKind{UIImpactFeedbackGenerator(style:.light).impactOccurred()}   // 0.53 B2: a light tap when the cue changes family member
        if followed != shotKind{shotKind=followed;UserDefaults.standard.set(followed,forKey:"shotKind017");applySquirtPolicy();table.masseLook=followed==3;table.selectCue(followed==3 ? 0:followed)}
        spin.maximumOffset=tipLimit(elevated:degrees>0)
        UserDefaults.standard.set(engine.settings,forKey:"physics");guideDirty=true;syncQuickRail()
    }
    func chooseRole(_ role:Int){chooseShotKind(max(0,min(2,role)))}
    func setHold(_ held:Bool){
        locked=held && strokeAllowed
        powerFX.showMeter(locked)
        wakeRendering();table.setTrainingOverlaysHidden(locked,holding:locked);coachCard.isHidden=locked || !cardOn || coachCard.alpha==0
        for recognizer in aimRecognizers{recognizer.isEnabled = !locked}
        stroke.isUserInteractionEnabled=locked;stroke.isEnabled=locked
        menuButton.isHidden=locked
        fineWheel.isHidden=menuOpen   // 0.30: fine aim stays usable while the effect ball is held
        spin.isHidden=menuOpen   // 0.30b: the effect ball stays (it is the lock)
        quickScroll.isHidden=locked || menuOpen;elevationPad.isHidden=locked || menuOpen || spinExpanded;lockButton.isHidden=menuOpen || spinExpanded
        for icon in cueIcons{icon.isHidden=locked || menuOpen || spinExpanded}
        coachButton.isHidden=locked || menuOpen
        syncOverlayButtons()
        table.setTrainingOverlaysHidden(!coachOn || locked,holding:inTrainingMode || (coachOn && locked))
        if !locked{stroke.cancelStroke();pull=0;if matchIsCompetitive{table.setCompetitivePresentation(numbers:matchPlay.showNumbers)}}
    }
    /// 0.44: rail clearance that is a real elevated stroke (above the normal 6° stance) — see BLCueStrokeElevation.
    var strokeClearance:Double{BLCueStrokeElevation(table.clearanceElevation)}
    /// Góc nghiêng tối đa cho cú thường (không bật cơ nâng 3D): 35° — giả định, cần đối chiếu trên bàn thật.
    var maxStrokeElevation:Double{(engine.settings["experimental3D"]?.boolValue ?? false) ? 80:45}   // 0.37: 45° — frozen-to-rail top shots need ~38° over the rendered rail
    func cueClearance(side s:Double,top t:Double)->Double{
        guard let c=cue,!c.sunk else{return 0}
        // 0.30: balls behind the cue ball count too — the cue is never drawn through a ball.
        var xs=obstacleXs,ys=obstacleYs
        return BLCueMinimumElevationBalls(c.x,c.y,angle,s,t,geometry.width,geometry.length,geometry.radius,geometry.nose,&xs,&ys,Int32(xs.count))
    }
    func updateCueClearance(){
        let g=engine.settings
        geometry=TableGeometry(width:g["tableWidth"]?.doubleValue ?? 1.27,length:g["tableLength"]?.doubleValue ?? 2.54,
                               radius:g["ballRadius"]?.doubleValue ?? 0.028575,nose:g["railHeight"]?.doubleValue ?? 0.27)
        table.tableSize=SIMD2(geometry.width,geometry.length);table.railNose=geometry.nose
        let limit=maxStrokeElevation
        let others=balls.filter{$0.id != 0 && !$0.sunk};obstacleXs=others.map{$0.x};obstacleYs=others.map{$0.y}
        if spin.reachable==nil {
            spin.reachable={[weak self] x,y in guard let self=self else{return true};return self.cueClearance(side:x,top:y)<=self.maxStrokeElevation}
            spin.reachableSnapshot={[weak self] in
                guard let self=self else{return {_,_ in true}}
                // Identical to cueClearance(side:top:) <= maxStrokeElevation, with the solver read once per draw.
                let limit=self.maxStrokeElevation
                guard let c=self.cue,!c.sunk else{return {_,_ in 0<=limit}}
                let angle=self.angle,g=self.geometry,obstacleXs=self.obstacleXs,obstacleYs=self.obstacleYs
                return {s,t in
                    var xs=obstacleXs,ys=obstacleYs
                    return BLCueMinimumElevationBalls(c.x,c.y,angle,s,t,g.width,g.length,g.radius,g.nose,&xs,&ys,Int32(xs.count))<=limit
                }
            }
            spin.clampTop={[weak self] x,y in
                guard let self=self,let c=self.cue else{return y}
                var xs=self.obstacleXs,ys=self.obstacleYs
                return BLCueClampTopBalls(c.x,c.y,self.angle,x,y,self.geometry.width,self.geometry.length,self.geometry.radius,self.geometry.nose,self.maxStrokeElevation,self.spin.maximumOffset,&xs,&ys,Int32(xs.count))
            }
        }
        if cueClearance(side:side,top:top)>limit {spin.select(side:side,top:top)} // select() kẹp lên vùng với tới
        table.clearanceElevation=cueClearance(side:side,top:top)   // drawn: the cue never passes through the rail
        elevationPad.minimum=min(strokeClearance,85)   // 0.44: the fan shows a real elevated stroke only (stance ≤ 6° = level)
        spin.setNeedsDisplay()
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
    /// 0.44.1 M1.2: a drill's default tip (e.g. "Cú đầu tiên" slightly below centre). Never in a rules match.
    func applyDrillTip(){
        guard !matchPlay.active,Drill.all.indices.contains(drillIndex) else{return}
        let tip=Drill.all[drillIndex].tipTop
        if tip != 0 {spin.select(side:0,top:tip)}
    }
    func resetShotInputsAndAim(){
        spin.reset();side=0;top=0;applyDrillTip()
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

    func configureGestures(){
        let tap=UITapGestureRecognizer(target:self,action:#selector(tapTable(_:)));scn.addGestureRecognizer(tap);aimRecognizers.append(tap)
        let pan=UIPanGestureRecognizer(target:self,action:#selector(panTable(_:)));pan.maximumNumberOfTouches=1;scn.addGestureRecognizer(pan);aimRecognizers.append(pan)
        let orbit=UIPanGestureRecognizer(target:self,action:#selector(orbitTable(_:)));orbit.minimumNumberOfTouches=2;scn.addGestureRecognizer(orbit);aimRecognizers.append(orbit)
        let pinch=UIPinchGestureRecognizer(target:self,action:#selector(pinchTable(_:)));scn.addGestureRecognizer(pinch);aimRecognizers.append(pinch)
        for recognizer in aimRecognizers{recognizer.delegate=self}
        tap.require(toFail:pan);tap.require(toFail:orbit);tap.require(toFail:pinch)
        // One-finger aim must not wait for a two-finger recognizer to fail.
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
                if matchPlay.placementDraft != nil, let c=balls.first(where:{$0.id==0}) {
                    // 0.42 (owner: ball in hand is awkward): in a match only the cue ball moves, so a drag ANYWHERE
                    // moves it, keeping the finger's offset — the finger never covers the ball and nothing jumps.
                    draggedBall=0;placementGrab=SIMD2(c.x-p.x,c.y-p.y)
                }else{
                    placementGrab = .zero
                    draggedBall=balls.filter{!$0.sunk}.min{hypot($0.x-p.x,$0.y-p.y)<hypot($1.x-p.x,$1.y-p.y)}.flatMap{hypot($0.x-p.x,$0.y-p.y)<0.12 ? $0.id:nil}
                }
            }
            if let id=draggedBall {moveBall(id,to:p+placementGrab)}
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
    func moveBall(_ id:Int,to p:SIMD2<Double>){
        if handleMatchMoveBall(id,to:p){return}
        guard localTurn,!presentationBusy,isPlacingBalls else{return}
        var state=balls;guard let i=state.firstIndex(where:{$0.id==id}) else{return}
        // 0.44 (owner item 10: "chưa đặt bi chạm sát băng được"): the clamp stopped 16 mm short of the cushion (±0.590)
        // and a drag into another ball was refused 1 mm early, so a ball could never be frozen to a rail or a ball. Now the
        // limit is the cushion nose (half width − R) and a drag into a ball slides the ball to touching distance.
        let R=geometry.radius,touch=2*R+0.0001
        let hx=geometry.width/2-R-0.0001,hy=geometry.length/2-R-0.0001
        var x=max(-hx,min(hx,p.x)),y=max(-hy,min(hy,p.y))
        for other in state where other.id != id && !other.sunk {
            let dx=x-other.x,dy=y-other.y,dist=hypot(dx,dy)
            if dist<touch {
                let ux=dist>1e-9 ? dx/dist:1,uy=dist>1e-9 ? dy/dist:0
                x=max(-hx,min(hx,other.x+ux*touch));y=max(-hy,min(hy,other.y+uy*touch))
            }
        }
        guard !state.contains(where:{$0.id != id && !$0.sunk && hypot($0.x-x,$0.y-y)<2*R}) else{return}
        state[i].x=x;state[i].y=y;state[i].sunk=false;engine.loadLayout(state.map{$0.dictionary});table.placementBlocked = isPlacingBalls && !placementValid();refresh()
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
