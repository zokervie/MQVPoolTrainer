import UIKit
import GameKit
import SceneKit
import simd
import AVFoundation

// 0.45 M2: tách nguyên khối từ TrainingController.swift (không đổi hành vi). Coach: HLV offline, thẻ HLV, phân tích cú (ShotCoachAnalysis), chuỗi bài học 5 cú.
extension TrainingController {
    func toggleCoach(){
        // 0.30: one physical tap can arrive as two touch sequences (seen on CI: 2 taps -> 3 touch-downs); debounce.
        let now=ProcessInfo.processInfo.systemUptime;guard now-lastCoachToggle>0.35 else{return};lastCoachToggle=now
        guard !locked,!spinExpanded else{return};if matchIsCompetitive{matchToggleNumbers();return};coaching.toggle();persistArchiveCoach()
        if coaching {   // 0.44: default Coach view = diamond numbers + aim point
            numbersOn=true;UserDefaults.standard.set(true,forKey:Prefs.numbersOn)
            guideOn=true;guideMode=1;UserDefaults.standard.set(1,forKey:Prefs.guideMode);guideDirty=true
        }
        applyCoachVisibility()
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
        if let g=d.goal,g.radius>0 {lines.append("Vùng đích: "+diamondPoint(g.x,g.y)+String(format:" · bán kính %.0f cm",g.radius*100))}
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
        GlassPill.apply(to:coachCard,cornerRadius:14)   // 0.44.1 owner: no black box — the M4 frosted pill
        coachCard.translatesAutoresizingMaskIntoConstraints=false;coachCard.accessibilityIdentifier="CoachCard"
        coachLabel.numberOfLines=0;GlassPill.styleCaption(coachLabel,size:12.5)
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
}

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
        return " · ép phê "+parts.joined(separator:", ")
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
                    lines.append("Vật lý app (cùng lực, cùng ép phê): băng 1 cần chạm \(railLabel(ideal.rail)) · nút \(n1(ideal.diamond)).")
                    if let first=contacts.first,first.rail==ideal.rail {
                        let delta=ideal.diamond-first.diamond
                        lines.append(abs(delta)<0.05 ? "Điểm va băng đã đúng; xem lại lực và ép phê.":"👉 Một thay đổi: dời điểm va băng thứ nhất \(n1(abs(delta))) nút về phía nút \(n1(ideal.diamond)). Giữ nguyên lực và ép phê.")
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
                        lines.append("👉 Một thay đổi: \(levelChange(alt.level)), giữ ép phê. Khi đó băng 1 cần chạm \(railLabel(alt.rail)) · nút \(n1(alt.diamond)).")
                    } else {lines.append("Với vài mức vận tốc gần cú vừa rồi, vật lý app không tìm được đường \(d.rails) băng — thử đổi ép phê.")}
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
                        if level != base {candidates.append((levelChange(level)+", giữ ép phê",levelSpeed(level),0))}
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
                lines.append(fix.map{"👉 Một thay đổi: lệch hướng ngắm \($0); giữ nhịp đẩy và ép phê."} ?? "Lệch ngắm nhỏ không cứu được cú này — thử đổi lực hoặc ép phê.")
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
        if d.safety {return passed ? (100,"chạm bi 1 trước, bi 2 chắn đường") : (30,"chưa giấu được bi 1")}
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
            return (score,String(format:"%lld/%lld băng · trượt bi 1 %.0f cm",railCount,d.rails,max(0,miss)*100))
        }
        if passed {return (100,"đúng \(d.rails) băng vào lỗ")}
        let miss=pocketMiss(1)
        return (miss.isFinite ? max(0,55-Int(miss*150)):0,String(format:"%lld/%lld băng · bi 1 cách lỗ %.0f cm",railCount,d.rails,miss.isFinite ? miss*100:0))
    }
    func scoreLesson(_ d:Drill,passed:Bool,scratch:Bool,timedOut:Bool,railCount:Int,events:[[String:NSNumber]]){
        let (score,detail)=lessonShotScore(d,passed:passed,scratch:scratch,timedOut:timedOut,railCount:railCount)
        lessonScores.append(score);if passed{lessonPasses+=1}
        let n=lessonScores.count
        // 0.47 M5: full detail after every shot, or (level 3–5 on an easy drill) made/missed only — details kept for "Xem chi tiết".
        if n==1 {feedbackDetails=[];feedbackMode=feedbackMode047(d)}
        feedbackDetails.append("Cú \(n): \(score) điểm · "+(passed ? "ĐẠT":"chưa đạt")+" · "+detail)
        statusLabel.text=feedbackMode==BL_FEEDBACK_SUMMARY ? "Cú \(n)/5 · "+(passed ? "ĐẠT":"chưa đạt"):"Cú \(n)/5 · \(score) điểm · "+(passed ? "ĐẠT":"chưa đạt")+" · "+detail
        scoreLabel.text="Lượt 5 cú · đạt \(lessonPasses) / \(n)"
        notifyStatus(statusLabel.text ?? "")
        let index=drillIndex
        if n<5 {
            // Re-rack the lesson for the next shot once the player has seen where the balls stopped.
            DispatchQueue.main.asyncAfter(deadline:.now()+2.2){[weak self] in
                guard let self=self,self.lessonActive,self.drillIndex==index,!self.shotActive,self.replayIndex==nil,!self.isPlacingBalls else{return}
                if self.drillHasVariants(){self.relayDrill(variant:n)}   // 0.49b X3: the cue ball moves a little each shot
                else{
                    if self.shotBack.isEmpty{self.undo()}else{self.stepShot(-1)}
                    self.statusLabel.text="Cú \(n+1)/5 · thế bi đã xếp lại"
                }
            }
            return
        }
        let average=lessonScores.reduce(0,+)/max(1,n)
        let stars=lessonPasses>=5 && average>=85 ? 5:min(4,lessonPasses)
        let cleared=lessonPasses>=3
        let round=PlayerStore.shared.recordRound(drill:d.id,stars:stars,average:Double(average),made:lessonPasses)   // 0.45 M5: the only writer of progress
        roundFinished047(d,round:round,stars:stars,average:average)   // 0.47 M2/M3/M5/M6: streak, record, summary, challenge
        lessonScores=[];lessonPasses=0
        let next=FeatureFlags.chapters && Chapters.locate(d.id) != nil ? Chapters.nextRung(after:d.id):Drill.all.indices.first{$0>index && Drill.all[$0].level>0}   // 0.47 M0: next rung of the ladder
        let alert=UIAlertController(title:(cleared ? "Qua bài · ":"Chưa qua · ")+Drill.starText(stars),
            message:"\(d.title)\nĐiểm trung bình \(average)/100.\n"+(cleared ? "Bài đã được đánh dấu hoàn thành.":"Cần đạt ít nhất 3/5 cú. Gợi ý: bật Coach để xem điểm va băng và một thay đổi cho cú sau."),preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"Tập lại lượt mới",style:.default){[weak self]_ in self?.beginDrill(index,guided:false)})
        if let next=next {alert.addAction(UIAlertAction(title:"Bài tiếp theo",style:.default){[weak self]_ in self?.beginDrill(next,guided:false)})}
        roundAlertExtras047(alert,drill:d,round:round,index:index)   // 0.47: Bài hôm nay tiếp theo · chuỗi ngày · Xem chi tiết · Thách bạn
        alert.addAction(UIAlertAction(title:"Đóng",style:.cancel){[weak self]_ in self?.lessonActive=false})
        DispatchQueue.main.asyncAfter(deadline:.now()+(round.newRecord && FeatureFlags.progress ? 1.7:1.2)){[weak self] in self?.present(alert,animated:true)}   // 0.47 M3: "Kỷ lục mới" (≤ 1,5 s) first
    }
}
