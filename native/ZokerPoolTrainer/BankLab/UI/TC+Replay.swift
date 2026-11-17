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
        hideCoach();table.resetPocketPresentation();replayPlan=ReplayDirector.Plan(duration:frameTimes.last ?? 0,events:lastShotEvents,initialAngle:lastShot?.aimAngle ?? angle);replayOrigin=captureCamera();replayEquipment=(engine.settings["cueType"]?.intValue ?? 0,table.cueElevation);replayRenderedCueType=nil;replayPreparation=nil;replayStrikePlayed=false;replayIndex=0;replayClock = -replayLead;replayYaw=0;replayAudioIndex=0
        replayPaused=false;replayAuto=true;cameraManual=false;lastDirectorTime = -10
        actionDirections=[:];actionCraneYaw=0;actionShot = -1;actionSmooth=nil;if replayCamera>=Self.replayCameraTitles.count {replayCamera=0}
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
        perfEnd();perfAfterReplay()   // 0.44-mm
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
        // 0.44 #11: a highlight reel plays its next shot (the exporter chains its own frames).
        if !Self.highlightQueue.isEmpty && videoExport==nil {
            DispatchQueue.main.async{[weak self] in guard let self=self,self.replayIndex==nil,!self.shotActive else{return};if self.loadNextHighlight(){self.replay()}}
        }
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
        // 0.44 (owner item 17): "Xuất video" — the replay as an MP4 with the angle being watched.
        let export=UIButton(type:.system);export.setTitle("Video",for:.normal);export.accessibilityIdentifier="ReplayExport"
        export.addAction(UIAction{[weak self]_ in self?.offerVideoExport(source:export)},for:.touchUpInside)
        for item in [replayPause,replayRate,save,export,close]{item.titleLabel?.font = .systemFont(ofSize:13,weight:.semibold);item.widthAnchor.constraint(equalToConstant:46).isActive=true}
        replayAutoButton.titleLabel?.font = .systemFont(ofSize:13,weight:.semibold);replayAutoButton.widthAnchor.constraint(equalToConstant:86).isActive=true
        for item in [replayPause,replayRate,replaySlider,replayAutoButton,save,export,close] as [UIView]{replayBar.addArrangedSubview(item)}
        replayBarRight=[replayBar.leadingAnchor.constraint(equalTo:coachButton.trailingAnchor,constant:8),replayBar.trailingAnchor.constraint(equalTo:quickScroll.leadingAnchor,constant:-8)]
        replayBarLeft=[replayBar.leadingAnchor.constraint(equalTo:quickScroll.trailingAnchor,constant:8),replayBar.trailingAnchor.constraint(equalTo:coachButton.leadingAnchor,constant:-8)]
        NSLayoutConstraint.activate(replayBarRight+[replayBar.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),replayBar.heightAnchor.constraint(equalToConstant:48)])
        replayPause.accessibilityIdentifier="ReplayPause";replaySlider.accessibilityIdentifier="ReplaySeek"
        replayPause.addAction(UIAction{[weak self]_ in guard let self=self else{return};self.replayPaused.toggle();self.replayPause.setTitle(self.replayPaused ? "Tiếp":"Dừng",for:.normal)},for:.touchUpInside)
        replayRate.showsMenuAsPrimaryAction=true;replayRate.menu=UIMenu(children:[0.25,0.5,1.0].map{rate in UIAction(title:"\(rate)×"){[weak self]_ in self?.replaySpeed=rate;self?.replayRate.setTitle("\(rate)×",for:.normal)}})
        replayAutoButton.setTitle("Điện ảnh",for:.normal);replayAutoButton.showsMenuAsPrimaryAction=true
        replayAutoButton.menu=UIMenu(title:"Góc máy xem lại",children:Self.replayCameraGroups.map{group->UIMenuElement in
            UIMenu(title:group.0,options:.displayInline,children:group.1.map{index in
                UIAction(title:Self.replayCameraTitles[index]+(Self.replaySlowCameras.contains(index) ? " · chậm":"")){[weak self]_ in self?.chooseReplayCamera(index)}})})
        close.addAction(UIAction{[weak self]_ in Self.highlightQueue=[];self?.stopReplay()},for:.touchUpInside)   // 0.44: Xong ends a highlight reel
        replaySlider.addAction(UIAction{[weak self]_ in
            guard let self=self,self.replayIndex != nil else{return};self.replayClock=Double(self.replaySlider.value);self.replayStrikePlayed=self.replayClock>=0
            self.replayIndex=self.frameTimes.lastIndex(where:{$0<=self.replayClock}) ?? 0
            self.replayAudioIndex=self.lastShotEvents.prefix(while:{($0["time"]?.doubleValue ?? 0)<=self.replayClock}).count
            self.lastDirectorTime = -10;self.table.resetPocketPresentation();self.wakeRendering()
        },for:.valueChanged)
        replayBar.isHidden=true
    }
    /// 0.33 replay angles: 0 cinematic director (cuts + slow motion around collisions), 1 shooter 3D, 2 whole table, 3 top.
    // 0.44 (owner item 6): 5 more action angles (9–13), every follow cam 0.5–1 m from its ball, slow motion ONLY in the
    // four angles built around the key moments (Điện ảnh, Bi mục tiêu, Đón ở lỗ, Action Mix), and the list grouped by
    // kind of camera. Index = stored setting (replayCamera041), so old choices keep working.
    static let replayCameraTitles=["Điện ảnh · tự chuyển, chậm khi va chạm","Người đánh 3D","Toàn bàn","Trên cao",
                                   "Action · bám bi cái","Action · bám bi mục tiêu","Action · đón bi ở lỗ","Cẩu quay quanh bàn",
                                   "Action Mix · tự cắt cảnh",
                                   "Action · ngang băng thấp","Action · chéo 45° theo bi","Action · đón đầu bi mục tiêu",
                                   "Action · trên đầu theo bi","Action · xoay quanh điểm va chạm"]
    static let replayCameraShort=["Điện ảnh","Người đánh","Toàn bàn","Trên cao","Bi cái","Bi mục tiêu","Đón ở lỗ","Cẩu quay","Action Mix",
                                  "Ngang băng","Chéo 45°","Đón đầu","Trên đầu","Xoay va chạm"]
    /// Menu groups (title, camera indexes).
    static let replayCameraGroups:[(String,[Int])]=[("Tự động",[0,8]),("Toàn cảnh",[2,3,7]),("Theo bi",[4,5,10,12]),
                                                   ("Góc thấp · đón",[1,9,11,6]),("Va chạm",[13])]
    /// Slow motion at impacts/pots only in these four.
    static let replaySlowCameras:Set<Int>=[0,5,6,8]
    func chooseReplayCamera(_ k:Int){
        replayCamera=k;replayAuto = k==0;cameraManual = k != 0 && k<4;lastDirectorTime = -10
        replayAutoButton.setTitle(Self.replayCameraShort[max(0,min(k,Self.replayCameraShort.count-1))],for:.normal)
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
            if let export=videoExport {export.sound(kind:event["kind"]?.intValue ?? 1,impact:event["impact"]?.doubleValue ?? 0.3,pan:audioPan(event["x"]?.doubleValue ?? 0,event["y"]?.doubleValue ?? 0))}
            else if UserDefaults.standard.object(forKey:"poolAudioEnabled") as? Bool ?? true {poolAudio.play(kind:event["kind"]?.intValue ?? 1,impact:event["impact"]?.doubleValue ?? 0.3,pan:audioPan(event["x"]?.doubleValue ?? 0,event["y"]?.doubleValue ?? 0))}
            replayAudioIndex+=1
        }
    }
    func audioPan(_ x:Double,_ y:Double)->Double{
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
            else if replayClock<contactTime+0.6 && potTime-0.8>contactTime+0.6 {shot=11}   // 0.44: meet the object ball head-on
            else if replayClock>=potTime-0.8 && replayClock<potTime+0.6 {shot=6}
            else if replayClock>=min(potTime+0.6,end-1.4) {shot=7}
            else {shot=5}
        }
        if shot != actionShot {beginCameraTransition(actionShot<0 ? 0:0.55);actionShot=shot;actionSmooth=nil}   // 0.44: eased glide, not a snap
        func chase(_ id:Int)->(SIMD3<Float>,SIMD3<Float>,Float)?{
            guard let p=position(id) else{return nil}
            let d=heading(id)
            var eye=SIMD3(p.x-d.x*0.65,0.13,p.y-d.y*0.65)   // 0.44: 0.5–1 m from the ball (was 0.42 m)
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
        case 9:   // low along the rail: side-on, rail height, 0.8 m off the leading ball
            if let p=position(objectID) ?? position(0) {
                let side:Float=p.x>=0 ? 1:-1
                pose=(SIMD3(p.x+side*0.80,0.09,p.y-0.10),SIMD3(p.x,0.03,p.y+0.10),44)
            }
        case 10:  // 45° behind-right of the cue ball, 0.8 m
            if let p=position(0) {
                let d=heading(0),r=SIMD2<Float>(-d.y,d.x),back=simd_normalize(-d+r)*0.80
                pose=(SIMD3(p.x+back.x,0.32,p.y+back.y),SIMD3(p.x+d.x*0.35,0.03,p.y+d.y*0.35),48)
            }
        case 11:  // ahead of the object ball, looking back at it as it comes (0.9 m)
            if let p=position(objectID) {
                let d=heading(objectID)
                var eye=SIMD3(p.x+d.x*0.90,0.10,p.y+d.y*0.90)
                if abs(eye.x)>0.64||abs(eye.z)>1.28 {eye.y=0.16}
                eye.x=max(-0.95,min(0.95,eye.x));eye.z=max(-1.6,min(1.6,eye.z))
                pose=(eye,SIMD3(p.x,0.03,p.y),46)
            }
        case 12:  // straight above the fastest moving ball, 0.9 m up
            let moving=zip(a,b).filter{!$0.1.sunk}.max{hypot($0.1.x-$0.0.x,$0.1.y-$0.0.y)<hypot($1.1.x-$1.0.x,$1.1.y-$1.0.y)}
            if let id=moving?.0.id ?? Optional(0),let p=position(id) {
                pose=(SIMD3(p.x,0.90,p.y-0.08),SIMD3(p.x,0,p.y),52)
            }
        case 13:  // orbit the first contact point (0.7 m), then keep circling it
            let cx=Float(contact?["x"]?.doubleValue ?? 0),cy=Float(contact?["y"]?.doubleValue ?? 0)
            let around=SIMD2<Float>(cx,cy)
            actionCraneYaw+=Float(dt)*(replayClock<contactTime ? 0.15:0.45)*(replayPaused ? 0:1)
            let yaw=Float(lastShot?.aimAngle ?? angle)+Float.pi*0.75+actionCraneYaw
            pose=(SIMD3(around.x+cos(yaw)*0.70,0.30,around.y+sin(yaw)*0.70),SIMD3(around.x,0.03,around.y),50)
        default:
            actionCraneYaw+=Float(dt)*0.22*(replayPaused ? 0:1)
            let moving=a.filter{!$0.sunk}
            var centre=SIMD2<Float>(0,0)
            if !moving.isEmpty {centre=moving.reduce(SIMD2<Float>(0,0)){$0+SIMD2(Float($1.x),Float($1.y))}/Float(moving.count)*0.5}
            let yaw=Float(lastShot?.aimAngle ?? angle)+Float.pi+actionCraneYaw
            pose=(SIMD3(cos(yaw)*1.7,1.15,sin(yaw)*2.3),SIMD3(centre.x,0,centre.y),46)
        }
        // 0.44 (owner: "vài lần xem lại vẫn bị giật lắc"): the follow cams were placed straight from frame-interpolated
        // positions and a heading that turns at every contact, so each kink showed as a shake. Eye and target now follow
        // their goal with a critically-damped spring (≈ 0.12 s), reset on every cut (the cut itself is the glide above).
        if let pose=pose {
            let k=1-exp(-Float(max(0,dt))/0.12)
            var eye=pose.0,target=pose.1
            if let last=actionSmooth,!replayPaused {eye=last.eye+(eye-last.eye)*k;target=last.target+(target-last.target)*k}
            else if let last=actionSmooth,replayPaused {eye=last.eye;target=last.target}
            actionSmooth=(eye,target)
            table.actionCamera=(eye:eye,target:target,fov:pose.2)
        }
    }
    /// Slow motion for the action angles in replaySlowCameras: ×0.35 for 0.4 s around the first contact and the first pot.
    func actionSlowRate(_ endingRate:Double)->Double{
        let events=lastShotEvents
        let keys=[events.first{($0["kind"]?.intValue ?? -1)==1}?["time"]?.doubleValue,
                  events.first{($0["kind"]?.intValue ?? -1)==2 && ($0["a"]?.intValue ?? 0)>0}?["time"]?.doubleValue].compactMap{$0}
        let near=keys.contains{abs(replayClock-$0)<0.2}
        return min(endingRate,near ? 0.35:1)
    }
}
