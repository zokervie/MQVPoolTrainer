import UIKit
import GameKit
import SceneKit
import simd
import AVFoundation

// 0.45 M2: tách nguyên khối từ TrainingController.swift (không đổi hành vi). Replay: xem lại, thanh xem lại, góc quay, lưu/mở cú, ghi video highlight, Action camera.
extension TrainingController {
    func replay(){
        guard localTurn,!shotActive,!frames.isEmpty,!isPlacingBalls else{return}
        lockButton.releaseHold();setHold(false)
        if replayIndex != nil{stopReplay();return}
        hideCoach();table.resetPocketPresentation();replayPlan=nil;replayOrigin=captureCamera();replayEquipment=(engine.settings["cueType"]?.intValue ?? 0,table.cueElevation);replayRenderedCueType=nil;replayPreparation=nil;replayStrikePlayed=false;replayIndex=0;replayClock = -replayLead;replayYaw=0;replayAudioIndex=0
        replayPaused=false;replayAuto=true;cameraManual=false;lastDirectorTime = -10
        actionShot = -1;planReplayCamera048();cameraSmooth048=CameraSmoothness048()   // 0.48 M2
        DispatchQueue.main.async{[weak self] in self?.syncOverlayButtons()}
        replayAutoButton.setTitle(replayAngle048.title,for:.normal);table.replayTrails048([:],ghost:nil)
        if let pose=savedAimCamera{applyCamera(pose)}else{table.cameraMode=2}
        replaySlider.minimumValue=Float(-replayLead);replaySlider.maximumValue=Float(frameTimes.last ?? 1);replaySlider.value=Float(replayClock)
        showReplayBar();menuButton.isHidden=true;replayPause.setTitle("Dừng",for:.normal)
        statusLabel.text="Xem lại · kéo để đổi góc · tua để xem điểm chạm"
        applyReplayCoach();wakeRendering()
        updateControls()
    }
    /// 0.38: export the cinematic replay of the last shot as a video (share sheet: save to Photos, send…).
    func exportHighlight(){
        guard !shotActive,!frames.isEmpty,replayIndex==nil else{notifyStatus("Chưa có cú đánh để xuất video");return}
        guard let recorder=HighlightRecorder(aspect:scn.bounds.width/max(1,scn.bounds.height)) else{notifyStatus("Không tạo được video");return}
        highlightRecorder=recorder;replay()
        hideReplayBar();menuButton.isHidden=true
        notifyStatus("Đang quay video highlight…")
    }
    func stopReplay(){
        perfEnd();perfAfterReplay()   // 0.44-mm
        table.actionCamera=nil;actionShot = -1
        cameraSmooth048.finish(plan:cameraPlan048);cameraPlan048=nil;trailCache048=nil;trailShown048 = -1   // 0.48
        table.replayTrails048([:],ghost:nil)
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
        replayIndex=nil;replayPlan=nil;hideReplayBar();menuButton.isHidden=false;table.resetPocketPresentation();syncOverlayButtons()
        if let saved=archiveReturn {
            frames=saved.frames;frameTimes=saved.times;lastShotEvents=saved.events;lastShot=saved.shot;paths=saved.paths;coaching=saved.coach;lastPreparation=saved.preparation;archiveReturn=nil
        }
        activeArchiveID=nil;table.update(balls,dt:0)
        if let pose=replayOrigin{applyCamera(pose)};replayOrigin=nil;observationCamera=false
        statusLabel.text="Xem lại xong";updateControls();applyCoachVisibility()
        if replayAngle048 == .learn {table.trails(coachOn && trailsOn ? paths:[:])}   // 0.48: Learn hid the Coach trails
        // 0.44 #11: a highlight reel plays its next shot (the exporter chains its own frames).
        if !Self.highlightQueue.isEmpty && videoExport==nil {
            DispatchQueue.main.async{[weak self] in guard let self=self,self.replayIndex==nil,!self.shotActive else{return};if self.loadNextHighlight(){self.replay()}}
        }
    }
    /// 0.53 stability — ROOT CAUSE of testNoUIKitLayoutPassWhileTheBallsRoll flaking (~30 %): UIKit materialises the title label of a HIDDEN button
    /// ("Đạo diễn", 30 → 56 pt) lazily on a Core Animation update, which landed in the middle of the first shot as one stray UIKit layout pass
    /// (traced with --layout-trace-qa: UIButtonLegacyVisualProvider ← CALayer perform_update_ ← l10n_setText ← setNeedsLayout). The replay bar now
    /// lives in the view hierarchy only while a replay is shown, so nothing hidden can be laid out during a live shot.
    func showReplayBar(){
        if replayBar.superview==nil{
            view.addSubview(replayBar)
            NSLayoutConstraint.activate((leftHanded ? replayBarLeft:replayBarRight)+replayBarFixed)   // removeFromSuperview dropped them
        }
        replayBar.isHidden=false
    }
    func hideReplayBar(){replayBar.isHidden=true;replayBar.removeFromSuperview()}
    func buildReplayBar(){
        replayBar.axis = .horizontal;replayBar.spacing=8;replayBar.alignment = .fill
        replayBar.backgroundColor=UIColor(white:0.04,alpha:0.9);replayBar.layer.cornerRadius=12
        replayBar.translatesAutoresizingMaskIntoConstraints=false   // 0.53 stability: the bar joins the view only while a replay runs (see showReplayBar)
        replayPause.setTitle("Dừng",for:.normal);replayRate.setTitle("1×",for:.normal);replayAutoButton.setTitle("Auto",for:.normal)
        let close=UIButton(type:.system);close.setTitle("Xong",for:.normal);close.accessibilityIdentifier="ReplayDone";replayAutoButton.accessibilityIdentifier="ReplayAuto"
        // 0.33: "Lưu" saves the shot being replayed; the camera button picks 1 of 4 replay angles.
        let save=UIButton(type:.system);save.setTitle("Lưu",for:.normal);save.accessibilityIdentifier="ReplaySave"
        save.addAction(UIAction{[weak self]_ in self?.saveLastShot(fromReplay:true)},for:.touchUpInside)
        // 0.44 (owner item 17): "Xuất video" — the replay as an MP4 with the angle being watched.
        let export=UIButton(type:.system);export.setTitle("Video",for:.normal);export.accessibilityIdentifier="ReplayExport"
        export.addAction(UIAction{[weak self]_ in self?.offerVideoExport(source:export)},for:.touchUpInside)
        for item in [replayPause,replayRate,save,export,close]{item.titleLabel?.font = .systemFont(ofSize:13,weight:.semibold);item.widthAnchor.constraint(equalToConstant:46).isActive=true}
        replayAutoButton.titleLabel?.font = .systemFont(ofSize:13,weight:.semibold);replayAutoButton.widthAnchor.constraint(equalToConstant:86).isActive=true
        for item in [replayPause,replayRate,replaySlider,replayAutoButton,save,export,close] as [UIView]{replayBar.addArrangedSubview(item)}
        replayBarRight=[replayBar.leadingAnchor.constraint(equalTo:coachButton.trailingAnchor,constant:8),replayBar.trailingAnchor.constraint(equalTo:quickScroll.leadingAnchor,constant:-8)]
        replayBarLeft=[replayBar.leadingAnchor.constraint(equalTo:quickScroll.trailingAnchor,constant:8),replayBar.trailingAnchor.constraint(equalTo:coachButton.leadingAnchor,constant:-8)]
        replayBarFixed=[replayBar.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),replayBar.heightAnchor.constraint(equalToConstant:48)]
        replayPause.accessibilityIdentifier="ReplayPause";replaySlider.accessibilityIdentifier="ReplaySeek"
        replayPause.addAction(UIAction{[weak self]_ in guard let self=self else{return};self.replayPaused.toggle();self.replayPause.setTitle(self.replayPaused ? "Tiếp":"Dừng",for:.normal)},for:.touchUpInside)
        replayRate.showsMenuAsPrimaryAction=true;replayRate.menu=UIMenu(children:[0.25,0.5,1.0].map{rate in UIAction(title:"\(rate)×"){[weak self]_ in self?.replaySpeed=rate;self?.replayRate.setTitle("\(rate)×",for:.normal)}})
        replayAutoButton.setTitle(replayAngle048.title,for:.normal);replayAutoButton.showsMenuAsPrimaryAction=true
        replayAutoButton.menu=replayAngleMenu048()
        close.addAction(UIAction{[weak self]_ in Self.highlightQueue=[];self?.stopReplay()},for:.touchUpInside)   // 0.44: Xong ends a highlight reel
        replaySlider.addAction(UIAction{[weak self]_ in
            guard let self=self,self.replayIndex != nil else{return};self.replayClock=Double(self.replaySlider.value);self.replayStrikePlayed=self.replayClock>=0
            self.replayIndex=self.frameTimes.lastIndex(where:{$0<=self.replayClock}) ?? 0
            self.replayAudioIndex=self.lastShotEvents.prefix(while:{($0["time"]?.doubleValue ?? 0)<=self.replayClock}).count
            self.lastDirectorTime = -10;self.cameraSmooth048.reset();self.trailShown048 = -1;self.table.resetPocketPresentation();self.wakeRendering()
        },for:.valueChanged)
        replayBar.isHidden=true;replayBar.removeFromSuperview()
        #if DEBUG
        if QA.has("--layout-trace-qa"){LayoutTrace.watched=[replayAutoButton,replayAutoButton.titleLabel!,replayBar];LayoutTrace.install()}
        #endif
    }
    /// 0.48 M2: 2 automatic angles + 6 hand-picked (was 14). The menu rebuilds so the tick follows the current choice.
    func replayAngleMenu048()->UIMenu{
        func item(_ a:ReplayAngle048)->UIAction{
            let action=UIAction(title:a.title,subtitle:a.subtitle.isEmpty ? nil:a.subtitle,state:a==replayAngle048 ? .on:.off){[weak self] _ in self?.chooseReplayAngle048(a)}
            action.accessibilityIdentifier="ReplayAngle-\(a.rawValue)";return action
        }
        return UIMenu(title:L10n.tr("Góc máy xem lại"),children:[
            UIMenu(title:L10n.tr("Tự động"),options:.displayInline,children:ReplayAngle048.automatic.map(item)),
            UIMenu(title:L10n.tr("Chọn tay"),options:.displayInline,children:ReplayAngle048.manual.map(item))])
    }
    func chooseReplayAngle048(_ a:ReplayAngle048){
        replayAngle048=a;ReplayAngle048.stored=a
        replayAuto=true;cameraManual=false;lastDirectorTime = -10
        replayAutoButton.setTitle(a.title,for:.normal);replayAutoButton.menu=replayAngleMenu048()
        if replayIndex != nil {
            table.replayTrails048([:],ghost:nil)
            planReplayCamera048();cameraSmooth048=CameraSmoothness048()
            beginCameraTransition(0.45)
        }
        wakeRendering()
    }
    func playReplayAudio(){
        while replayAudioIndex<lastShotEvents.count {
            let event=lastShotEvents[replayAudioIndex]
            guard (event["time"]?.doubleValue ?? 0)<=replayClock else{break}
            if let export=videoExport {export.sound(kind:event["kind"]?.intValue ?? 1,impact:event["impact"]?.doubleValue ?? 0.3,pan:audioPan(event["x"]?.doubleValue ?? 0,event["y"]?.doubleValue ?? 0))}
            else if UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true {poolAudio.play(kind:event["kind"]?.intValue ?? 1,impact:event["impact"]?.doubleValue ?? 0.3,pan:audioPan(event["x"]?.doubleValue ?? 0,event["y"]?.doubleValue ?? 0))}
            replayAudioIndex+=1
        }
    }
    func audioPan(_ x:Double,_ y:Double)->Double{
        // 0.57 I4: pan by the impact's x across the table width, −0.8…+0.8, signed by which way the camera looks (screen left stays left)
        if UserDefaults.standard.object(forKey:Prefs.ballStereo) as? Bool ?? true {
            let half=(engine.settings["tableWidth"]?.doubleValue ?? 1.27)/2
            let a=scn.projectPoint(SCNVector3(-0.3,0.03,Float(y))).x,b=scn.projectPoint(SCNVector3(0.3,0.03,Float(y))).x
            return max(-0.8,min(0.8,(x/half)*0.8))*(b>=a ? 1:-1)
        }
        let point=scn.projectPoint(SCNVector3(Float(x),0.03,Float(y)))
        return max(-1,min(1,Double(point.x/max(1,Float(scn.bounds.width)))*2-1))
    }

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
}

private extension String {var nilIfEmpty:String?{isEmpty ? nil:self}}

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
    // 0.48 M2: the frame-by-frame action cameras (0.41–0.47) and their on/off slow motion were removed: every angle
    // now reads a path planned on the whole recording (Camera048.swift → BLCameraPlan).
}

// MARK: - 0.59 Xem lại một chạm (owner: "khó mở xem lại")
// Since 0.53 B1 replay lives in Bàn (two taps) and 0.56 K1/K2 fixed the right column at four keys. Instead of a fifth key,
// a gold "Xem lại cú" chip appears top-centre for 4 s after each practice / drill / free-table shot. Matches never get it
// (finishShot returns early for matches; replay is disabled there). Weekly test: no chip (nothing between shots).
// UI tests keep the old screen unless they pass --replay-chip-qa, so no automatic tap lands on it.
extension TrainingController {
    static let quickReplayChipTag = 5901
    static var quickReplayChipToken = 0
    private var quickReplayChip: UIButton? { view.viewWithTag(Self.quickReplayChipTag) as? UIButton }

    func offerQuickReplay() {
        guard !QA.anyFlag || QA.has("--replay-chip-qa") else { return }
        guard testRun == nil, replayIndex == nil, !shotActive, !frames.isEmpty, !isPlacingBalls, presentedViewController == nil else { return }
        let chip = quickReplayChip ?? makeQuickReplayChip()
        Self.quickReplayChipToken += 1; let token = Self.quickReplayChipToken
        view.bringSubviewToFront(chip); chip.isHidden = false; chip.alpha = 0
        UIView.animate(withDuration: 0.2) { chip.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard Self.quickReplayChipToken == token else { return }
            self?.hideQuickReplayChip()
        }
    }
    func hideQuickReplayChip() {
        guard let chip = quickReplayChip, !chip.isHidden else { return }
        Self.quickReplayChipToken += 1
        UIView.animate(withDuration: 0.2, animations: { chip.alpha = 0 }) { _ in chip.isHidden = true }
    }
    private func makeQuickReplayChip() -> UIButton {
        var c = UIButton.Configuration.filled()
        c.title = L10n.tr("Xem lại cú"); c.image = UIImage(systemName: "play.circle.fill"); c.imagePadding = 6
        c.baseBackgroundColor = UIColor(red: 0.851, green: 0.643, blue: 0.255, alpha: 1)   // #D9A441
        c.baseForegroundColor = UIColor(red: 0.043, green: 0.071, blue: 0.125, alpha: 1)   // #0B1220
        c.cornerStyle = .capsule; c.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 18)
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in var a = a; a.font = UIFont.systemFont(ofSize: 15, weight: .semibold); return a }
        let chip = UIButton(configuration: c); chip.tag = Self.quickReplayChipTag; chip.accessibilityIdentifier = "QuickReplayChip"
        chip.translatesAutoresizingMaskIntoConstraints = false; chip.isHidden = true
        chip.addAction(UIAction { [weak self] _ in self?.hideQuickReplayChip(); self?.replay() }, for: .touchUpInside)
        view.addSubview(chip)
        NSLayoutConstraint.activate([chip.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
                                     chip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 64),
                                     chip.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)])
        return chip
    }
}
