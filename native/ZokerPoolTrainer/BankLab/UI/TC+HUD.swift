import UIKit
import GameKit
import SceneKit
import simd
import AVFoundation

// 0.45 M2: tách nguyên khối từ TrainingController.swift (không đổi hành vi). HUD: bố cục phím, nhãn, toast, đồng bộ phím nhanh, kiểm HUD (G1), sắp xếp HUD tay.
extension TrainingController {
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
        let loupeOn=(UserDefaults.standard.object(forKey:Prefs.loupes) as? Bool ?? true) && !ProcessInfo.processInfo.arguments.contains("--spin-detail")   // 0.43: loupe only, no in-place zoom (QA --spin-detail keeps the big pad)
        spin.dragRadius=loupeOn ? Double(pad ? 240:170)*0.43:nil
        let f=BLHUDLayout(Double(safe.minX),Double(safe.minY),Double(safe.width),Double(safe.height),pad ? 1:0,leftHanded ? 1:0,sixItems ? 1:0,spinExpanded && !loupeOn ? 1:0)
        // bounds + center (not frame): elevation/wheel may carry a zoom transform while touched.
        func place(_ v:UIView,_ b:BLRect){v.bounds=CGRect(x:0,y:0,width:b.w,height:b.h);v.center=CGPoint(x:b.x+b.w/2,y:b.y+b.h/2)}
        // 0.46: cột phím chỉ còn 2–3 nút: thu chiều cao theo số nút đang hiện, giữ đáy (dưới ngón cái) như cũ.
        var railFrame=f.rail
        if quickTable != nil {
            let visible=Double(1+(matchIsCompetitive ? (matchBool("requiresCall") ? 1:0):1)+2)   // Xem lại + (Lùi cú | Call) + Camera + Bàn
            if visible>0 {let h=min(f.rail.h,visible*f.button+(visible-1)*Double(quickRail.spacing));railFrame.y=f.rail.y+f.rail.h-h;railFrame.h=h}
        }
        place(quickScroll,railFrame);place(spin,f.spin);place(fineWheel,f.wheel);place(elevationPad,f.elevation)
        place(menuButton,f.menu);place(coachButton,f.coach);place(panel,f.panel);spin.setNeedsDisplay()
        place(lockButton,f.lock);lockButton.isHidden=menuOpen || spinExpanded;lockButton.setNeedsDisplay()   // 0.36: B is back (hold = lock aim), square, left of the effect ball
        for (k,icon) in cueIcons.enumerated(){place(icon,BLHUDCueIcon(f,Int32(k)))}
        elevationPad.leftHanded=leftHanded
        let small=BLRectMake(0,f.coach.y+4,pad ? 76:62,36),guideW=pad ? 92:80
        var n=small,g=small,c=small;g.w=Double(guideW);c.w=pad ? 72:60   // 0.44.1: "Chấm cú" fits on one line
        if leftHanded{n.x=f.coach.x-6-n.w;g.x=n.x-6-g.w;c.x=g.x-6-c.w}else{n.x=f.coach.x+f.coach.w+6;g.x=n.x+n.w+6;c.x=g.x+g.w+6}
        place(numbersButton,n);place(guideToggle,g);place(cardToggle,c)
        for b in [numbersButton,guideToggle,cardToggle]{b.setNeedsUpdateConfiguration()}
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
        placePowerBar(rail:railFrame,safe:safe)   // 0.47 M1
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
        let interactive:[UIControl]=([spin,coachButton,quickReplay!,retryButton,quickCall,quickCamera!,quickTable!]+cueIcons).filter{!$0.isHidden}
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
            self.updateSpinLoupe(expanded:expanded && !ProcessInfo.processInfo.arguments.contains("--spin-detail"))
            // 0.37 (owner): by default only B locks; the effect ball just chooses the tip contact. Old latch in Tuỳ chỉnh.
            if expanded{self.hideCoach();if !self.locked && Tuning.effectLock{self.setHold(!self.presentationBusy && self.localTurn && !self.isPlacingBalls)}}
            self.spin.alpha=expanded ? (self.loupesActive ? 0.02:0.97):0.60   // 0.44: one image — the lifted copy
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
        Wood.panel(panel,radius:20)   // 0.49c G2: the same solid wood panel as the pickers (opaque, raised border, drop shadow)
        panel.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(panel)
        let scroll=UIScrollView();scroll.translatesAutoresizingMaskIntoConstraints=false;panel.addSubview(scroll)
        MenuSkin.frame(panel,content:scroll,tone:UIColor(red:0.06,green:0.05,blue:0.045,alpha:1),radius:12)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo:menuButton.leadingAnchor),
            panel.topAnchor.constraint(equalTo:menuButton.bottomAnchor,constant:8),
            panel.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12),
            panel.widthAnchor.constraint(equalToConstant:318),
            scroll.leadingAnchor.constraint(equalTo:panel.leadingAnchor,constant:10),scroll.trailingAnchor.constraint(equalTo:panel.trailingAnchor,constant:-10),
            scroll.topAnchor.constraint(equalTo:panel.topAnchor,constant:10),scroll.bottomAnchor.constraint(equalTo:panel.bottomAnchor,constant:-10)])
        let brand=UILabel();text(brand,17,.white,.bold);brand.text="ZOKER POOL · Trainer";brand.font=Wood.titleFont(28);brand.textColor=Wood.burnt;brand.textAlignment = .center;brand.backgroundColor=Wood.cardTop;brand.layer.cornerRadius=10;brand.clipsToBounds=true;brand.layer.shadowColor=Wood.edgeGlow.cgColor   // 0.49c G2: title burnt into a light plank
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
            let enabled = !(UserDefaults.standard.object(forKey:Prefs.audioEnabled) as? Bool ?? true)
            UserDefaults.standard.set(enabled,forKey:Prefs.audioEnabled)
            self?.statusLabel.text=enabled ? "Âm thanh bi: bật":"Âm thanh bi: tắt"
        }
        let kick=UIButton.lab("Tìm góc kick · 1–3 băng"){[weak self]in self?.chooseKick()}
        let coachToggle=UIButton.lab("Coach · Bật / tắt toàn bộ trợ giúp"){[weak self] in self?.toggleCoach()}
        let cameraOptions=UIButton.lab("Góc nhìn / Camera replay"){[weak self] in self?.cycleCamera()}
        let recordings=UIButton.lab("Lưu trữ · Cú đánh / Highlight"){[weak self] in
            guard let self=self else{return}
            let sheet=UIAlertController(title:"Thư viện cú đánh",message:nil,preferredStyle:.actionSheet)
            sheet.addAction(UIAlertAction(title:"Lưu cú vừa đánh",style:.default){[weak self]_ in self?.saveLastShot()})
            sheet.addAction(UIAlertAction(title:"Xuất video cú vừa rồi (MP4)",style:.default){[weak self]_ in self?.setMenu(false);self?.offerVideoExport(source:self?.menuButton)})
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
        let more=group("Thêm…",[
            ("Lưu cú vừa đánh",{[weak self] in self?.saveLastShot()}),
            ("Xuất video cú vừa rồi (MP4)",{[weak self] in self?.setMenu(false);self?.offerVideoExport(source:self?.menuButton)}),
            ("Cú đã lưu · video highlight",{[weak self] in guard let self=self else{return}
                let sheet=UIAlertController(title:"Thư viện cú đánh",message:nil,preferredStyle:.actionSheet)
                for shot in SavedShot.all().reversed(){sheet.addAction(UIAlertAction(title:shot.name,style:.default){[weak self]_ in self?.playSaved(shot)})}
                sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));self.presentSheet(sheet,source:self.menuButton)}),
            ("Nỉ: mới / cũ (đổi)",{[weak self] in guard let self=self else{return};self.table.setClothWear(old:!self.table.oldCloth);self.wakeRendering();self.notifyStatus(self.table.oldCloth ? "Nỉ cũ: vệt lăn, vết chấm, bụi phấn":"Nỉ mới")}),
            ("Bi: mới / cũ (đổi)",{[weak self] in guard let self=self else{return};self.table.setBallWear(old:!self.table.oldBalls);self.wakeRendering();self.notifyStatus(self.table.oldBalls ? "Bi cũ: mờ bóng":"Bi mới: bóng gương")}),
            ("Màu nỉ",{[weak self] in self?.chooseClothColor()}),
            ("Hướng dẫn chơi",{[weak self] in self?.setMenu(false);DispatchQueue.main.asyncAfter(deadline:.now()+0.3){self?.showTutorialList()}}),
            ("Không gian bàn (\(TableScene.spaces.count) cảnh)",{[weak self] in self?.chooseSpace()}),
            ("Tay trái / tay phải (đổi bên phím)",{[weak self] in guard let self=self else{return};self.setLeftHanded(!self.leftHanded)}),
            ("Bao cơ / Gậy",{[weak self] in self?.setMenu(false);self?.showCueBag()}),
            ("Bàn & không gian · hình ảnh",{[weak self] in self?.graphics()}),
            ("Âm thanh: bật / tắt",{[weak self] in
                let enabled = !(UserDefaults.standard.object(forKey:Prefs.audioEnabled) as? Bool ?? true)
                UserDefaults.standard.set(enabled,forKey:Prefs.audioEnabled);self?.statusLabel.text=enabled ? "Âm thanh bi: bật":"Âm thanh bi: tắt"})])
        // 0.46 M2: menu trong trận = Tiếp tục · Đổi bàn‑bi‑gậy · Tuỳ chỉnh · Về sảnh (+ "Thêm…" giữ các mục còn lại, không xoá chức năng).
        let library=UIButton.lab("Đổi bàn · bi · gậy"){[weak self]in self?.openLibrary()}
        library.accessibilityIdentifier="MenuLibrary";more.accessibilityIdentifier="MenuMore"
        let journal=UIButton.lab("Nhật ký tập luyện · Thế bi"){[weak self]in self?.layouts()}
        let tuning=group("Hiệu chỉnh vật lý · xuất Markdown",[
            ("Mở bảng hiệu chỉnh",{[weak self] in self?.settings()}),
            ("ZUPE Lab · nghiên cứu",{[weak self] in self?.setMenu(false);self?.present(UINavigationController(rootViewController:ZupeLabController()),animated:true)})])
        tuning.accessibilityIdentifier="MenuPhysicsTuning"
        // 0.36: one place for every user preference (owner IQ200 #4).
        let customize=UIButton.lab("Tuỳ chỉnh · ánh sáng, lực, bố cục phím, độ mượt"){[weak self] in self?.openCustomize()}
        customize.accessibilityIdentifier="MenuCustomize"
        _=(recordings,center,trails,fine,felt,sound,coachToggle,cameraOptions,kick,advanced,physicsTuning,equipment,lessons,help,matches,guideButton,resetButton,graphicsButton,layoutButton,drillButton)
        // 0.37 (owner chose): in-game menu = 5 items. Modes, drills, journal and guide live in the Lobby (Về sảnh);
        // physics tuning in Tuỳ chỉnh → Vật lý.
        let resume=UIButton.lab("Tiếp tục"){[weak self]in self?.setMenu(false)}
        resume.accessibilityIdentifier="MenuResume"
        if var c=resume.configuration{c.baseBackgroundColor=LobbyController.gold;c.baseForegroundColor = .black;c.background.backgroundColor=LobbyController.gold;resume.configuration=c}
        customize.configuration?.title="Tuỳ chỉnh · hình ảnh, điều khiển, vật lý, âm thanh"
        let lobby=UIButton.lab("Về sảnh · chế độ chơi, bài tập, hồ sơ"){[weak self]in self?.setMenu(false);self?.openLobby()}
        lobby.accessibilityIdentifier="MenuLobby"
        // 0.41: each section its own muted tone (bàn = rừng thông, tuỳ chỉnh = xanh đêm, lưu trữ = đỏ rượu, sảnh = đá).
        MenuSkin.tone(library,MenuSkin.tones[0]);MenuSkin.tone(customize,MenuSkin.tones[1])
        MenuSkin.tone(more,MenuSkin.tones[4]);MenuSkin.tone(lobby,MenuSkin.tones[5])
        _=(modes,guide,drills,journal,tuning,close)
        let controls=stack(.vertical,10,[brand,titleLabel,statusLabel,scoreLabel,hintLabel,
            resume,library,customize,lobby,more])
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
        syncPuzzleBar();updateControls()
    }
    func buildQuickRail(){
        quickRail.axis = .vertical;quickRail.spacing=2;quickRail.distribution = .fillEqually
        quickRail.translatesAutoresizingMaskIntoConstraints=false
        func button(_ symbol:String,_ name:String,_ id:String)->UIButton {
            let b=UIButton(type:.system);var c=UIButton.Configuration.plain()
            c.image=UIImage(systemName:symbol);c.title=name;c.imagePlacement = .top;c.imagePadding=1
            c.baseForegroundColor = .rgb(0xF3D9A4);c.background.backgroundColor=UIColor.rgb(0x131218).withAlphaComponent(0.42);c.background.cornerRadius=10
            c.background.strokeColor=UIColor.rgb(0xEAC583).withAlphaComponent(0.4);c.background.strokeWidth=0.7
            let names=["QuickCamera":"Camera","QuickTools":"Tools","QuickTable":"Tools","QuickReplay":"Replay","unused":"Undo"]
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
        quickRole.addAction(UIAction{[weak self]_ in self?.showCueBag()},for:.touchUpInside)   // 0.44 #18: bag sheet with "Thêm cơ vào bao" 
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
            if self.isPlacingBalls{items.append(UIAction(title:"Hủy đặt bi",attributes:self.quickPlace.isEnabled ? .destructive:[.destructive,.disabled]){[weak self]_ in self?.cancelPlacement()})}
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
        // 0.46 M2: Xem lại · Lùi cú (hoặc Call) luôn hiện; Đặt bi · Thêm bi · Bao cơ gom vào nút "Bàn"; Camera giữ phím riêng (chạm = đổi góc, giữ = nhìn lướt).
        // quickPlace/quickAdd/quickRole vẫn là đối tượng (trạng thái bật/tắt theo luật trận) nhưng không còn trên màn hình.
        quickTable=button("tablecells","Bàn","QuickTable");quickTable.showsMenuAsPrimaryAction=true
        quickTable.accessibilityLabel="Bàn";quickTable.accessibilityHint="Đặt bi, thêm bi, bao cơ"
        quickTable.menu=UIMenu(title:"Bàn",children:[UIDeferredMenuElement.uncached{[weak self] completion in completion(self?.tableMenuItems() ?? [])}])
        for item in [quickReplay!,retryButton,quickCall,quickCamera!,quickTable!] {
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
        elevationPad.changed={[weak self] value in self?.setElevation(value);self?.updateElevationLoupe()}
        buildCueIcons();buildPlaceBallButton();buildPowerBarSwitch()
        for (b,title,id) in [(numbersButton,"Nút số","NumbersToggle"),(guideToggle,"Chỉ dẫn","GuideToggle"),(cardToggle,"Chấm cú","CoachCardToggle")] {
            var c=UIButton.Configuration.plain();c.title=title;c.background.backgroundColor=UIColor(white:0.03,alpha:0.42);c.background.cornerRadius=10
            c.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:12,weight:.semibold);return a}
            c.titleLineBreakMode = .byClipping   // 0.44.1 owner: one line, never split inside a word
            b.configuration=c;b.accessibilityIdentifier=id;view.addSubview(b)
            // One line that shrinks (down to 70 %) to the button's real width instead of wrapping or clipping a word.
            // UIButton.Configuration ignores adjustsFontSizeToFitWidth, so the font size is computed here.
            b.configurationUpdateHandler={button in
                guard var c=button.configuration,let title=c.title,button.bounds.width>0 else{return}
                c.contentInsets=NSDirectionalEdgeInsets(top:4,leading:5,bottom:4,trailing:5)
                let full=(title as NSString).size(withAttributes:[.font:UIFont.systemFont(ofSize:12,weight:.semibold)]).width
                let size=12*max(0.7,min(1,(button.bounds.width-10)/max(1,full)))
                c.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:size,weight:.semibold);return a}
                button.configuration=c
            }
        }
        numbersButton.addAction(UIAction{[weak self]_ in guard let self=self else{return};self.numbersOn.toggle()
            UserDefaults.standard.set(self.numbersOn,forKey:Prefs.numbersOn);self.applyCoachVisibility();self.syncOverlayButtons()},for:.touchUpInside)
        cardToggle.addAction(UIAction{[weak self]_ in guard let self=self,self.coachOn else{return}
            self.cardOn.toggle();UserDefaults.standard.set(self.cardOn,forKey:Prefs.coachCard);self.coachCard.isHidden = !self.cardOn || self.locked || self.coachCard.alpha==0;self.syncOverlayButtons()},for:.touchUpInside)
        guideToggle.addAction(UIAction{[weak self]_ in guard let self=self,self.coachOn else{return}
            // tắt → điểm ngắm → cả đường → tắt
            if !self.guideOn {self.guideOn=true;self.guideMode=1} else if self.guideMode==1 {self.guideMode=2} else {self.guideOn=false}
            UserDefaults.standard.set(self.guideMode,forKey:Prefs.guideMode);self.guideDirty=true;self.guideButton?.configuration?.title=self.guideOn ? "Dự báo: bật":"Dự báo: tắt"
            self.wakeRendering();self.syncOverlayButtons()},for:.touchUpInside)
        buildReplayBar();syncQuickRail();applyCoachVisibility()
    }
    /// 0.49c G6 (IPA 163): "Đặt bi" out of the "Bàn" menu — 64 pt, left edge, right above the cue-kind row; lit only when the rules let
    /// the player place balls; one tap = drag the cue ball, tap again = done (same action as the old shortcut).
    func buildPlaceBallButton(){
        let b=UIButton(type:.system);var c=UIButton.Configuration.filled()
        c.image=UIImage(systemName:"hand.draw");c.preferredSymbolConfigurationForImage=UIImage.SymbolConfiguration(pointSize:22,weight:.semibold)
        c.baseBackgroundColor=UIColor(white:0.03,alpha:0.55);c.baseForegroundColor = .white;c.cornerStyle = .capsule;c.contentInsets = .zero
        b.configuration=c;b.accessibilityIdentifier="PlaceBallButton";b.accessibilityLabel="Nút đặt bi"
        b.addAction(UIAction{[weak self]_ in self?.toggleEdit()},for:.touchUpInside)
        view.addSubview(b);placeBallButton=b
    }
    func syncPlaceBallButton(){
        guard let b=placeBallButton else{return}
        let on=quickPlace?.isEnabled ?? false
        b.isHidden=menuOpen || spinExpanded || replayIndex != nil
        placeCaption?.isHidden=b.isHidden;placeCaption?.alpha=on ? 1:0.4
        b.isEnabled=on;b.alpha=on ? 1:0.35
        b.configuration?.baseBackgroundColor=isPlacingBalls ? ZDesign.Color.gold:UIColor(white:0.03,alpha:0.55)
        b.configuration?.baseForegroundColor=isPlacingBalls ? .black:.white
        b.accessibilityLabel=isPlacingBalls ? "Nút xong đặt bi":"Nút đặt bi"
    }
    func buildCueIcons(){
        let names=["Cơ chơi","Cơ phá"],ids=["CueIconPlay","CueIconBreak"]
        for k in 0..<Int(BL_CUE_ICONS) {
            let b=UIButton(type:.system);var c=UIButton.Configuration.plain()
            c.title=L10n.tr(names[k]);c.image=UIImage(systemName:k==1 ? "burst":"line.diagonal")
            c.imagePlacement = .top;c.imagePadding=2;c.preferredSymbolConfigurationForImage=UIImage.SymbolConfiguration(pointSize:11,weight:.semibold)
            c.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:10.5,weight:.bold);return a}
            c.subtitleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{a in var a=a;a.font=UIFont.systemFont(ofSize:8,weight:.medium);return a}
            c.background.backgroundColor=UIColor(white:0.03,alpha:0.32);c.background.cornerRadius=8;c.contentInsets = .zero
            b.configuration=c;b.accessibilityIdentifier=ids[k];b.accessibilityLabel="Gậy "+names[k];b.accessibilityValue=""
            b.addAction(UIAction{[weak self]_ in self?.chooseCueIcon(k)},for:.touchUpInside)
            view.addSubview(b);cueIcons.append(b)
        }
    }
    func chooseCueIcon(_ k:Int){
        // 0.53 B2: two buttons = two families. Outside the family the tap picks its base cue; inside it, the tap puts the cue level again.
        let kind=Int(BLCueIconKind(Int32(k)))
        let inFamily=k==0 ? (shotKind==0 || shotKind==3):(shotKind==1 || shotKind==2)
        if !inFamily {chooseShotKind(kind)} else if table.cueElevation>0 {setElevation(0)}
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
            let on=k==0 ? (shotKind==0 || shotKind==3):(shotKind==1 || shotKind==2)
            icon.configuration?.baseForegroundColor=on ? .white:UIColor.rgb(0xEAC583).withAlphaComponent(0.8)
            icon.configuration?.background.backgroundColor=on ? UIColor.rgb(0xEAC583).withAlphaComponent(0.42):UIColor(white:0.03,alpha:0.32)
            icon.configuration?.background.strokeColor=on ? .white:UIColor.white.withAlphaComponent(0.15);icon.configuration?.background.strokeWidth=on ? 1:0.5
            icon.isEnabled = localTurn && !presentationBusy && !locked
            icon.accessibilityValue=on ? "Đang chọn":""
            // the label follows the cue the elevation made: Cơ chơi → Massé, Cơ phá → Nhảy
            icon.configuration?.title=L10n.tr(k==0 ? (shotKind==3 ? "Massé":"Cơ chơi"):(shotKind==1 ? "Nhảy":"Cơ phá"))
            let role=k==1 ? (shotKind==1 ? 1:2):0
            icon.configuration?.subtitle=nil   // 0.46: icon 3D của cơ trong bao thay cho nhãn phụ tên cơ
            // 0.44 (#18): the key shows the cue that is in the bag — colour, inlay, shaft, ferrule and tip.
            let look=CueBag.cue(role)
            if icon.accessibilityHint != look.id {icon.accessibilityHint=look.id;icon.configuration?.image=look.iconImage()}
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
        syncPlaceBallButton()
        quickAdd.configuration?.title=isPlacingBalls ? "Hủy":"Thêm bi"
        quickAdd.showsMenuAsPrimaryAction = !isPlacingBalls
        quickAdd.menu=isPlacingBalls ? nil:UIMenu(title:"Thêm bi",children:addBallMenuChildren())
        // Camera: hold = overview, release = back to the aim view; quick tap = toggle. No long-press menu (it would steal the hold).
        quickCamera.menu=nil
        quickCamera.configuration?.title=table.cameraMode==2 ? "Camera · ngắm":"Toàn cảnh"   // 0.43: was 3 lines (overflow)
        quickCue.menu=UIMenu(title:"Cơ",children:(0...2).map{i in UIAction(title:CueBag.cue(i).title){[weak self]_ in self?.chooseRole(i)}})
        quickBag.menu=UIMenu(title:"Bao cơ",children:[quickCue.menu!,UIMenu(title:"Đổi bao",children:CueBag.names.enumerated().map{i,title in UIAction(title:title){[weak self]_ in CueBag.active=i;self?.chooseRole(role)}}),UIAction(title:"Thư viện bàn & cơ"){[weak self]_ in self?.openLibrary()}])
    }
    func buildStatusToast(){
        statusToast.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(statusToast)
        // 0.45 M3 (ZDesign): the black toast becomes a ZPill behind the label (a sibling — a subview would cover the
        // text), following the label's frame, visibility and fade.
        statusToast.textColor = ZDesign.Color.textPrimary;statusToast.backgroundColor = .clear
        statusToast.font = ZDesign.font(.footnote,weight:.semibold);statusToast.textAlignment = .center;statusToast.numberOfLines=2
        statusToast.isHidden=true
        let pill=UIView();pill.isUserInteractionEnabled=false;pill.translatesAutoresizingMaskIntoConstraints=false;pill.isHidden=true
        pill.accessibilityIdentifier="ZToastPill";ZPill.apply(to:pill,cornerRadius:ZDesign.Radius.card)
        view.insertSubview(pill,belowSubview:statusToast)
        NSLayoutConstraint.activate([pill.leadingAnchor.constraint(equalTo:statusToast.leadingAnchor,constant:-12),pill.trailingAnchor.constraint(equalTo:statusToast.trailingAnchor,constant:12),
                                     pill.topAnchor.constraint(equalTo:statusToast.topAnchor),pill.bottomAnchor.constraint(equalTo:statusToast.bottomAnchor)])
        toastObservers=[statusToast.observe(\.isHidden,options:[.new]){[weak pill] l,_ in pill?.isHidden=l.isHidden;if let p=pill,let s=p.superview{s.insertSubview(p,belowSubview:l)}},
                        statusToast.observe(\.alpha,options:[.new]){[weak pill] l,_ in pill?.alpha=l.alpha}]
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
        notifyStatus(String(format:"Dự đoán · bi %lld %@ lỗ %@: lệch %.1f°",target,potted ? "vào":"tới",best.0,abs(off)))
    }
    /// 0.38 "Chấm độ đều tay": the same layout shot again and again (Tập lại) — how tightly do the cue ball's stopping
    /// points cluster? RMS radius from their centre, in cm; 5 stars under 3 cm (coach standard for a repeatable stroke).
    func scoreConsistency(){
        guard let start=lastShot?.balls,let cb=balls.first(where:{$0.id==0}),!cb.sunk else{return}
        let key=start.sorted{$0.id<$1.id}.map{String(format:"%lld:%.3f,%.3f",$0.id,$0.x,$0.y)}.joined(separator:"|")
        if key != consistencyKey {consistencyKey=key;consistencyStops=[]}
        consistencyStops.append(SIMD2(cb.x,cb.y));if consistencyStops.count>10{consistencyStops.removeFirst()}
        let n=consistencyStops.count;guard n>=2 else{return}
        let c=consistencyStops.reduce(SIMD2<Double>(0,0),+)/Double(n)
        let rms=(consistencyStops.map{simd_length_squared($0-c)}.reduce(0,+)/Double(n)).squareRoot()*100
        let stars=rms<3 ? 5:(rms<6 ? 4:(rms<10 ? 3:(rms<16 ? 2:1)))
        notifyStatus(String(format:"Độ đều tay · %lld cú cùng thế: điểm dừng chụm ±%.1f cm · %@",n,rms,String(repeating:"★",count:stars)+String(repeating:"☆",count:5-stars)))
    }
    func notifyStatus(_ text:String){
        statusLabel.text=text;statusToast.text="  "+text+"  ";view.bringSubviewToFront(statusToast);statusToast.isHidden=false   // 0.45 review: front first, the pill follows
        toastGeneration+=1;let generation=toastGeneration
        DispatchQueue.main.asyncAfter(deadline:.now()+3){[weak self] in guard let self=self,self.toastGeneration==generation else{return};self.statusToast.isHidden=true}
    }
    func refresh(){wakeRendering();updateCueClearance();table.update(balls,dt:0);guideDirty=true;scoreLabel.text="\(successes) / \(attempts) đạt · góc \(String(format:"%.1f",angle*180/Double.pi))°"}
    func updateControls(){
        let busy=presentationBusy
        defer{syncPowerBar()}   // 0.47 M1
        syncCueIcons()
        fineWheel.isEnabled = !busy && localTurn && !isPlacingBalls
        lockButton.isEnabled = strokeAllowed
        stroke.isEnabled=strokeStaysArmed
        stroke.isUserInteractionEnabled=stroke.isEnabled
        testShotButton.isEnabled = !busy && localTurn && !isPlacingBalls && cue?.sunk == false
        elevationPad.isEnabled = !busy && localTurn && !isPlacingBalls && !spinExpanded
        quickTools?.isEnabled = !busy && localTurn && !spinExpanded
        quickRole?.isEnabled = !busy && localTurn && !spinExpanded && !isPlacingBalls
        quickPlace?.isEnabled = !busy && localTurn && !spinExpanded;syncPlaceBallButton()
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
        let tint=UserDefaults.standard.object(forKey:Prefs.clothTintIndex) as? Int ?? -1
        if tint != appliedClothTint {appliedClothTint=tint;table.setClothColor(tint<0 ? nil:tint)}   // only rebuild on change
        let worn=UserDefaults.standard.bool(forKey:Prefs.clothWear);if worn != table.oldCloth {table.setClothWear(old:worn)}
        if matchPlay.active {updateScoreboard()}
        if table.cameraMode==2 && !shotActive && replayIndex==nil {restoreAimCamera(transition:0.3)}   // preview the default aim view
        scn.contentScaleFactor=UIScreen.main.scale*CGFloat(Tuning.renderScale)
        setLinkRate(Tuning.frameRate)
        guideDirty=true;wakeRendering()
    }
    func openCustomize(){
        setMenu(false)
        let vc=CustomizeController()
        vc.changed={[weak self] in self?.applyTuning()}
        vc.openPhysics={[weak self] in self?.settings()}
        vc.openDiagnostics={[weak self] in self?.showSmoothnessDiagnostics()}
        vc.copyReport={[weak self] in self?.copySmoothnessReport()}
        vc.copyUsage={[weak self] in self?.copyUsageReport()}
        vc.openZupeLab={[weak self] in self?.present(UINavigationController(rootViewController:ZupeLabController()),animated:true)}
        vc.arrangeHUD={[weak self] in self?.beginHUDArrange()}
        vc.saveLayout={[weak self] n in self?.saveHUDLayout(n)}
        vc.loadLayout={[weak self] n in self?.loadHUDLayout(n)}
        vc.resetHUD={[weak self] in guard let self=self else{return}
            for (name,_) in self.hudItems{UserDefaults.standard.removeObject(forKey:self.hudOffsetKey(name))}
            self.hudLayoutKey="";self.view.setNeedsLayout();self.layoutRightHUD()}
        let nav=UINavigationController(rootViewController:vc);nav.modalPresentationStyle = .formSheet;present(nav,animated:true)
    }
    /// 0.45 M5.5: local usage numbers (PlayerStore) to the clipboard — testers paste them to the owner (D1/D7).
    func copyUsageReport(){
        let info=Bundle.main.infoDictionary
        let version=(info?["CFBundleShortVersionString"] as? String ?? "?")+" ("+(info?["CFBundleVersion"] as? String ?? "?")+")"
        UIPasteboard.general.string=PlayerStore.shared.usageReport(extra:["app: "+version,"device: "+UIDevice.current.model+" iOS "+UIDevice.current.systemVersion,"language: "+L10n.code])
        notifyStatus("Đã sao chép số liệu sử dụng")
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

// 0.46 M2: nút "Bàn" — Đặt bi · Thêm bi · Bao cơ trong MỘT menu (hành động giữ nguyên như phím cũ).
extension TrainingController {
    func addBallMenuChildren()->[UIMenuElement]{
        [UIAction(title:"Thêm từng bi"){[weak self]_ in self?.addBall()},
         UIAction(title:"Thêm bi · số lượng / bố trí"){[weak self]_ in self?.randomOptions()},
         UIMenu(title:"Thêm nhanh",children:Array(1...15).map{n in UIAction(title:"Thêm \(n) bi"){[weak self]_ in self?.addRandomBalls(n)}}),
         UIMenu(title:"Tạo thế mới",children:Array(1...15).map{n in UIAction(title:"Tạo thế \(n) bi"){[weak self]_ in self?.addRandomBalls(n,replacing:true)}})]
    }
    func tableMenuItems()->[UIMenuElement]{
        var items:[UIMenuElement]=[]
        // Đặt bi / Xong đặt bi (bật theo luật trận: bi cầm tay) — đang đặt thì thêm "Hủy đặt bi".
        items.append(UIAction(title:isPlacingBalls ? "Xong đặt bi":"Đặt bi",image:UIImage(systemName:"hand.draw"),attributes:quickPlace.isEnabled ? []:[.disabled]){[weak self]_ in self?.toggleEdit()})
        if isPlacingBalls {
            items.append(UIAction(title:"Hủy đặt bi",image:UIImage(systemName:"xmark.circle"),attributes:.destructive){[weak self]_ in self?.cancelPlacement()})
        } else {
            items.append(UIMenu(title:"Thêm bi",image:UIImage(systemName:"plus.circle"),children:quickAdd.isEnabled ? addBallMenuChildren():[UIAction(title:"Không dùng được lúc này",attributes:.disabled){_ in}]))
        }
        items.append(UIAction(title:"Bao cơ",image:UIImage(systemName:"bag"),attributes:quickRole.isEnabled ? []:[.disabled]){[weak self]_ in self?.showCueBag()})
        return items
    }
}
