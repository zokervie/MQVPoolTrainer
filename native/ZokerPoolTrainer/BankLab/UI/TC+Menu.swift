import UIKit
import GameKit
import SceneKit
import simd
import AVFoundation

// 0.45 M2: tách nguyên khối từ TrainingController.swift (không đổi hành vi). Menu/Sheet: sảnh, tài khoản, bao cơ, thư viện, bài tập, thế bi, đồ hoạ, Tuỳ chỉnh/Cài đặt.
extension TrainingController {
    /// 0.27 account management: Game Center profile, friends, sign-in. No password is stored by the app.
    /// 0.37 Sảnh chính: Luyện tập (green) · Thi đấu (orange) · Hồ sơ (blue). Shown at launch and from Menu → Về sảnh.
    @discardableResult func openLobby()->Bool{
        guard presentedViewController==nil else{return false}
        let lobby=LobbyController()
        typealias A=LobbyController.Action
        // 0.46 M1: "Tiếp tục" (bài/trận gần nhất) · Tập tự do · Bài tập · Đấu · Thư viện bàn‑cơ; mọi mục cũ còn ở hàng chip.
        lobby.resume=continueCard()
        lobby.daily=dailyCard()   // 0.47 M2
        lobby.cards=[
            .init(title:"Tập tự do",subtitle:"Bàn trống, tự đánh",icon:"circle.dashed",color:LobbyController.practice,actions:[
                A(title:"Tập tự do",icon:"circle.dashed",id:"LobbyFree",run:{[weak self] in RecentPlay.saveFree();self?.setMenu(false)})]),
            .init(title:"Bài tập",subtitle:"Bài chấm sao, tìm góc kick",icon:"star.circle",color:LobbyController.practice,actions:[
                A(title:FeatureFlags.chapters ? "Bài tập · 6 chương":"Bài tập · 5 cấp",icon:"star.circle",id:"LobbyDrills",run:{[weak self] in self?.chooseDrill()}),
                A(title:"Thế bí của ngày",icon:"calendar",id:"LobbyDailyPuzzle",run:{[weak self] in self?.openDailyPuzzle()}),
                A(title:"Đặt thế bí cho bạn",icon:"person.2.badge.plus",id:"LobbyUserPuzzle",run:{[weak self] in self?.openUserPuzzle()}),
                A(title:"Đoán đường bi",icon:"scope",id:"LobbyPredict",run:{[weak self] in self?.openPredict()}),
                A(title:"Thế bí · 9 phòng",icon:"puzzlepiece",id:"LobbyPuzzles",run:{[weak self] in self?.openPuzzles()}),
                A(title:"Thử thách kick 1–3 băng",icon:"arrow.triangle.turn.up.right.diamond",id:"LobbyKick",run:{[weak self] in self?.chooseKick()})]),
            .init(title:"Đấu",subtitle:"8 · 9 · 10 Ball luật WPA, 15 Ball Rotation",icon:"trophy",color:LobbyController.match,actions:[
                A(title:"Đấu với máy · 6 cấp",icon:"cpu",id:"LobbyComputer",run:{[weak self] in self?.openComputerMatch()}),
                A(title:"Hai người · một máy",icon:"person.2",id:"LobbyLocal",run:{[weak self] in self?.openMatchMenu(scope:0)}),
                A(title:"Wi‑Fi gần nhau",icon:"wifi",id:"LobbyWifi",run:{[weak self] in self?.openMatchMenu(scope:1)}),
                A(title:"Online · Game Center",icon:"globe",id:"LobbyOnline",run:{[weak self] in self?.openMatchMenu(scope:2)})]),
            .init(title:"Thư viện bàn · cơ",subtitle:"Bàn, nỉ, bi, gậy, không gian",icon:"books.vertical",color:LobbyController.gold,actions:[
                A(title:"Thư viện bàn · cơ",icon:"books.vertical",id:"LobbyLibrary",run:{[weak self] in self?.openLibrary()})])]
        // Hồ sơ + tiện ích: hàng chip (0.39: Tuỳ chỉnh đứng đầu vì dùng nhiều nhất).
        lobby.footer=[A(title:"Tuỳ chỉnh",icon:"slider.horizontal.3",id:"LobbyCustomize",run:{[weak self] in self?.openCustomize()}),
                      A(title:"Nhật ký · tiến bộ",icon:"chart.line.uptrend.xyaxis",id:"LobbyJournal",run:{[weak self] in self?.layouts()}),
                      A(title:"Cú đã lưu · video highlight",icon:"film.stack",id:"LobbyShots",run:{[weak self] in guard let self=self else{return}
                          let sheet=UIAlertController(title:"Thư viện cú đánh",message:nil,preferredStyle:.actionSheet)
                          for shot in SavedShot.all().reversed(){sheet.addAction(UIAlertAction(title:shot.name,style:.default){[weak self]_ in self?.playSaved(shot)})}
                          sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));self.presentSheet(sheet,source:self.menuButton)}),
                      A(title:"Tài khoản · Game Center",icon:"gamecontroller",id:"LobbyAccount",run:{[weak self] in self?.openAccount()}),
                      A(title:"Hướng dẫn",icon:"questionmark.circle",id:"LobbyHelp",run:{[weak self] in self?.help()})]
        if FeatureFlags.fadingFeedback && !PlayerStore.shared.weeklyTestDone() {lobby.footer.insert(A(title:"Bài kiểm tuần",icon:"flag.checkered",id:"LobbyWeeklyTest",run:{[weak self] in self?.startWeeklyTest()}),at:1)}   // 0.47 M5
        if FeatureFlags.challenge {lobby.footer.insert(A(title:"Nhập mã thách đấu",icon:"person.2.wave.2",id:"LobbyChallenge",run:{[weak self] in self?.enterChallengeCode()}),at:1)}   // 0.47 M6
        if FeatureFlags.progress {lobby.footer.insert(A(title:"Tiến bộ",icon:"chart.bar.xaxis",id:"LobbyProgress",run:{[weak self] in self?.openProgress()}),at:1)}   // 0.47 M3
        // 0.46 M2: engineer tools only with Phòng thí nghiệm on (Tuỳ chỉnh → Máy).
        if Prefs.lab {lobby.footer.append(A(title:"Phòng thử vật lý (nâng cao)",icon:"flask",id:"LobbyLab",run:{[weak self] in self?.present(UINavigationController(rootViewController:ZupeLabController()),animated:true)}))}
        lobby.onClosed={[weak self] in self?.afterLobbyClosed()}
        lobby.modalPresentationStyle = .overFullScreen;lobby.modalTransitionStyle = .crossDissolve
        present(lobby,animated:true);return true
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
        UserDefaults.standard.set(on,forKey:Prefs.leftHanded);hudLayoutKey="";view.setNeedsLayout();view.layoutIfNeeded()
        notifyStatus(on ? "Tay trái: phím và bi ép phê bên trái":"Tay phải: phím và bi ép phê bên phải")
    }

    /// 0.44 (owner item 18): "Bao cơ" on the quick rail — the three slots of the active bag (tap = choose that slot's cue),
    /// "Thêm cơ vào bao…" (all cues, tap one = it goes into its slot), change bag, and the physics settings.
    func showCueBag(){
        guard matchAllowsEditing || !matchIsCompetitive else{return}
        let sheet=UIAlertController(title:"Bao "+CueBag.names[CueBag.active],message:"Cơ trong bao gắn với các phím Đánh · Jump · Massé · Break bên trái.",preferredStyle:.actionSheet)
        for role in 0...2 {
            let cue=CueBag.cue(role)
            let action=UIAlertAction(title:CueLook.roles[role]+": "+cue.title,style:.default){[weak self]_ in self?.openLibrary(initialTab:1)}
            action.setValue(cue.iconImage(size:CGSize(width:56,height:14)),forKey:"image")
            sheet.addAction(action)
        }
        sheet.addAction(UIAlertAction(title:"＋ Thêm cơ vào bao…",style:.default){[weak self]_ in self?.openLibrary(initialTab:1)})
        sheet.addAction(UIAlertAction(title:"Đổi bao (Thi đấu / Luyện tập / Dự phòng)…",style:.default){[weak self]_ in self?.openLibrary(initialTab:2)})
        sheet.addAction(UIAlertAction(title:"Thông số gậy (vật lý)…",style:.default){[weak self]_ in self?.equipment()})
        sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel))
        presentSheet(sheet,source:quickTable ?? menuButton)
    }
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
            UserDefaults.standard.set(self.engine.settings,forKey:Prefs.physics)
            self.table.selectCue(values["cueType"]?.intValue ?? 0)
            self.table.cueElevation=(values["experimental3D"]?.boolValue ?? false) ? (values["cueElevationDegrees"]?.doubleValue ?? 0):0
            self.guideDirty=true;self.syncQuickRail()
        }
        let navigation=UINavigationController(rootViewController:controller)
        navigation.modalPresentationStyle = .fullScreen
        present(navigation,animated:true)
    }
    func chooseClothColor(){
        let sheet=UIAlertController(title:"Màu nỉ",message:"Chọn màu bàn luyện. Vân nỉ matte và texture vẫn được giữ.",preferredStyle:.actionSheet)
        for (index,item) in TableScene.clothColors.enumerated(){sheet.addAction(UIAlertAction(title:item.0,style:.default){[weak self]_ in UserDefaults.standard.set(index,forKey:Prefs.clothTintIndex);self?.table.setClothColor(index)})}
        sheet.addAction(UIAlertAction(title:"Theo mẫu bàn đang chọn",style:.default){[weak self]_ in UserDefaults.standard.removeObject(forKey:Prefs.clothTintIndex);self?.table.setClothColor(nil)})
        sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));presentSheet(sheet,source:menuButton)
    }
    func presentSheet(_ sheet:UIAlertController,source:UIView?=nil){
        sheet.overrideUserInterfaceStyle = .dark   // 0.30b: readable over the bright table (owner: menu text washed out)
        sheet.popoverPresentationController?.sourceView=source ?? view
        sheet.popoverPresentationController?.sourceRect=source?.bounds ?? CGRect(x:view.bounds.midX,y:view.bounds.midY,width:1,height:1)
        present(sheet,animated:true)
    }
    func beginDrill(_ index:Int,guided:Bool){
        RecentPlay.saveDrill(index)   // 0.46: "Tiếp tục" ở Sảnh
        if testRun != nil {endTestRun(cancelled:true)}   // 0.47: leaving a test for a drill ends the test
        challengePlaying=nil   // 0.47 M6: a challenge is set again right after, by enterChallengeCode
        if let previous=guidedCoachBefore{coaching=previous;guidedCoachBefore=nil}
        if guided{guidedCoachBefore=coaching;coaching=true;cardOn=true}   // 0.44: a guided lesson shows its brief/grade
        if shotKind != 0 && !Drill.all[index].id.hasPrefix("trick-") {chooseShotKind(0)}   // 0.50: a saved Jump/Break/Massé cue made drills miss (found with the puzzle reference stroke)
        loadDrill(index);applyCoachVisibility()
        lessonActive=Drill.all[index].level>0 || (FeatureFlags.chapters && Chapters.locate(Drill.all[index].id) != nil);lessonScores=[];lessonPasses=0   // 0.47 M0: every ladder drill (also "Cú đầu tiên") is a 5-shot round
        if lessonActive {scoreLabel.text="Lượt 5 cú · 0 / 5";notifyStatus(String(format:L10n.tr("Bài tập: %@ · cần đạt %d/5 cú"),Drill.all[index].title,Drill.all[index].passMade))}
    }
    func chooseDrill(){
        guard matchAllowsEditing else{return}
        guard !shotActive,replayIndex==nil else{return}
        if FeatureFlags.chapters {   // 0.47 M0: chapters, tips, ladder, exam
            let vc=ChaptersController(style:.insetGrouped)
            vc.load={[weak self]index in self?.beginDrill(index,guided:false)}
            vc.guidedLoad={[weak self]index in self?.beginDrill(index,guided:true)}
            vc.exam={[weak self]n in self?.startChapterExam(n)}
            present(UINavigationController(rootViewController:vc),animated:true);return
        }
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
                    let message=hit ? String(format:"Đã tìm góc trong mô phỏng: %lld băng → bi %lld, %.1f m/s.\nX %+.0f / Y %+.0f %% bán kính.\n\nTốc độ tham chiếu từ cú trước; lực cú vuốt tiếp theo có thể khác. Kết quả phụ thuộc thông số bàn; chưa xác nhận độ chính xác ngoài thực tế.",rails,target,speed,x*100,y*100):"Chưa tìm được góc ở lực và ép phê hiện tại trong phạm vi tìm kiếm. Thử đổi lực hoặc điểm chạm; điều này không chứng minh cú đánh bất khả thi."
                    let alert=UIAlertController(title:hit ? "Đã cập nhật góc ngắm":"Chưa tìm được lời giải",message:message,preferredStyle:.alert)
                    alert.addAction(UIAlertAction(title:"Đã hiểu",style:.default));self.presentSheet(alert)
                }
            }
        }
    }
    func help(){
        let message="Giữ B: khóa hướng. Ngón khác kéo lùi rồi đẩy tới: tốc độ vuốt quyết định lực. Buông B để hủy. C: bật/tắt toàn bộ trợ giúp. Ngang: ngắm, dọc: nâng mắt, hai ngón: quan sát. Bi đang chạy: kéo hoặc dùng hai ngón để quan sát, chụm để zoom; camera giữ góc đang chọn. Góc điện ảnh chỉ có khi xem lại. Chạm + Bi thêm từng bi, giữ để xếp ngẫu nhiên.\n\nÂm thanh thu thật: bsumusictech, Za-Games, mccarthy@bedmas.com, AmberdeMeillon (CC0). ‘Pool Ball in pocket.wav’ — jtroan, CC BY 3.0, freesound.org/people/jtroan/sounds/241373/ ; creativecommons.org/licenses/by/3.0/ . Đã cắt, đổi mono/PCM, chỉnh gain và fade. Bản dùng từ HQ MP3 preview."
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
    func savedLayouts()->[Layout]{guard let data=UserDefaults.standard.data(forKey:Prefs.layouts) else{return []};return (try? JSONDecoder().decode([Layout].self,from:data)) ?? []}
    func saveLayout(){
        let a=UIAlertController(title:"Tên thế bi",message:nil,preferredStyle:.alert);a.addTextField{$0.placeholder="Ví dụ: Kick 3 băng góc dài"}
        a.addAction(UIAlertAction(title:"Lưu",style:.default){[weak self,weak a]_ in
            guard let self=self else{return};var list=self.savedLayouts();list.append(Layout(name:a?.textFields?.first?.text?.isEmpty==false ? a!.textFields!.first!.text!:"Thế bi \(list.count+1)",balls:self.balls,angle:self.angle))
            if let data=try? JSONEncoder().encode(list){UserDefaults.standard.set(data,forKey:Prefs.layouts)};self.statusLabel.text="Đã lưu thế bi"
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
        for(i,l) in savedLayouts().enumerated(){a.addAction(UIAlertAction(title:l.name,style:.destructive){[weak self]_ in guard let self=self else{return};var list=self.savedLayouts();list.remove(at:i);if let d=try? JSONEncoder().encode(list){UserDefaults.standard.set(d,forKey:Prefs.layouts)}})}
        a.addAction(UIAlertAction(title:"Hủy",style:.cancel));presentSheet(a,source:layoutButton)
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
        guard let data=UserDefaults.standard.data(forKey:Prefs.practiceHistory) else{return []}
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
        UserDefaults.standard.set(highGraphics,forKey:Prefs.highGraphics)
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
    /// 0.44.1 (owner): the "Chẩn đoán độ mượt" numbers for the last shot — opened straight from Tuỳ chỉnh (no Hình ảnh
    /// sheet first) and copied from the main Menu ("Sao chép số đo cú vừa đánh").
    func smoothnessReport()->String {
        let values=displayDurations.sorted(),count=values.count
        let render=table.pacer.diagnostics, intervals=render.intervals.sorted()
        func summary(_ v:[Double])->String {
        guard !v.isEmpty else{return "chưa có dữ liệu"}
        return String(format:"%lld khung · p50 %.2f · p95 %.2f · max %.2f ms",v.count,v[v.count/2]*1000,v[min(v.count-1,Int(Double(v.count)*0.95))]*1000,(v.last ?? 0)*1000)
        }
        let pr=shotProfile
        func ms(_ v:[Double])->String {
        let v=v.sorted();guard !v.isEmpty else{return "—"}
        return String(format:"p50 %.2f · p95 %.2f · max %.2f",v[v.count/2]*1000,v[min(v.count-1,Int(Double(v.count)*0.95))]*1000,(v.last ?? 0)*1000)
        }
        let budget=1000.0/Double(pr.frameRate)   // 0.44.1: the rate the shot was struck at
        let over=pr.tick.filter{$0*1000>budget*0.8}.count
        var lines:[String]=[]
        lines.append("Tần số lúc đánh: \(pr.frameRate) Hz\n")
        lines.append("Cập nhật app: "+summary(values)+"\nRender SceneKit: "+summary(intervals)+String(format:"\n%lld/%lld khung thiếu mẫu · mẫu trễ nhất %.2f ms · đệm %.2f ms",render.starvedFrames,render.sampledFrames,render.maximumSampleAge*1000,render.interval*1000))
        lines.append("\nĐồng hồ SceneKit − hiện tại (ms): "+ms(render.clockOffsets))
        lines.append("\nLượt vẽ SceneKit (luồng render, ms): "+ms(render.renderPass))   // 0.45 M1
        if let c=CameraSmoothness048.last {   // 0.48 M4: smoothness of the camera seen in the last replay (cuts excluded)
            lines.append("\nTốc độ góc máy xem lại vừa rồi (°/s): p95 "+String(format:"%.0f",c.p95)+" · max "+String(format:"%.0f",c.peak)+" · kế hoạch p95 "+String(format:"%.0f",c.planP95)+" / max "+String(format:"%.0f",c.planPeak)+" · bi chính thấy "+String(format:"%.0f",c.visible*100)+"% · \(c.samples) mẫu")
        }
        lines.append("\n\nCPU luồng chính mỗi khung (ms):\nVật lý: "+ms(pr.physics)+"\nGhi xem lại: "+ms(pr.record)+"\nSự kiện/âm: "+ms(pr.events)+"\nCảnh 3D: "+ms(pr.scene)+"\nCả tick: "+ms(pr.tick))
        lines.append(String(format:"\n%lld/%lld khung dùng quá 80%% ngân sách %.1f ms\nBố cục UIKit giữa cú: %lld lượt · dựng lại phím: %lld · mẫu xem lại: %lld",over,pr.tick.count,budget,pr.layoutPasses,pr.hudRelayouts,pr.recordedSamples))
        lines.append("\nA/B: trạng thái 5 Hz cũ "+(Self.legacyStatusAB ? "BẬT":"tắt")+" · xem lại không quay chậm "+(Self.replayNoSlowAB ? "BẬT":"tắt"))
        let message=count==0 ? "Đánh một cú trước để đo nhịp trên thiết bị.":lines.joined()
        return message
    }
    func showSmoothnessDiagnostics(){
        let message=smoothnessReport()
        let alert=UIAlertController(title:"Chẩn đoán độ mượt",message:message,preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:Self.legacyStatusAB ? "A/B: tắt trạng thái 5 Hz cũ":"A/B: bật lại trạng thái 5 Hz cũ (để so)",style:.default){_ in
        UserDefaults.standard.set(!Self.legacyStatusAB,forKey:Prefs.diagLegacyStatus)})
        alert.addAction(UIAlertAction(title:Self.replayNoSlowAB ? "A/B: xem lại có quay chậm tự động":"A/B: xem lại 1× không quay chậm",style:.default){_ in
        UserDefaults.standard.set(!Self.replayNoSlowAB,forKey:Prefs.diagReplayNoSlow)})
        alert.addAction(UIAlertAction(title:"Sao chép số đo",style:.default){_ in UIPasteboard.general.string=message})
        alert.addAction(UIAlertAction(title:"Đóng",style:.cancel));topPresenter.present(alert,animated:true)
    }
    func copySmoothnessReport(){
        UIPasteboard.general.string=smoothnessReport()
        notifyStatus(displayDurations.isEmpty ? "Chưa có cú để đo":"Đã sao chép số đo cú vừa đánh")
    }
    func graphics(){
        let a=UIAlertController(title:"Hình ảnh · Premium Classic",message:"Mặc định Cân bằng: giảm tải GPU; tự giảm chất lượng khi máy nóng. Chất lượng cao tăng độ nét và bóng. Thử trên máy thật để chọn phù hợp.",preferredStyle:.actionSheet)
        a.addAction(UIAlertAction(title:highGraphics ? "✓ Cao cấp":"Cao cấp",style:.default){[weak self]_ in self?.highGraphics=true;self?.applyGraphics()})
        a.addAction(UIAlertAction(title:highGraphics ? "Cân bằng":"✓ Cân bằng",style:.default){[weak self]_ in self?.highGraphics=false;self?.applyGraphics()})
        for item in [("Tối",-1.25),("Dịu · mặc định",-0.95),("Sáng",-0.65)] {
            a.addAction(UIAlertAction(title:item.0,style:.default){[weak self]_ in
                self?.table.camera.camera?.exposureOffset=CGFloat(item.1)
                UserDefaults.standard.set(item.1,forKey:Prefs.exposure)
            })
        }
        if Prefs.lab {   // 0.46 M2: FPS / diagnostics only with Phòng thí nghiệm on
            a.addAction(UIAlertAction(title:"Hiện FPS / thống kê render",style:.default){[weak self]_ in self?.scn.showsStatistics.toggle()})
            a.addAction(UIAlertAction(title:"Nhịp hiển thị cú vừa đánh",style:.default){[weak self]_ in self?.showSmoothnessDiagnostics()})
        }
        a.addAction(UIAlertAction(title:"Khôi phục góc máy",style:.default){[weak self]_ in self?.table.orbit=0;self?.table.zoom=1;self?.table.aimPitch=TableScene.defaultAimPitch
            UserDefaults.standard.removeObject(forKey:Prefs.aimCameraPitch);UserDefaults.standard.removeObject(forKey:Prefs.aimCameraZoom)})
        if !shotActive,replayIndex==nil {
            a.addAction(UIAlertAction(title:"Mở cảnh studio 15 bi",style:.default){[weak self]_ in self?.loadShowcase()})
            if Prefs.lab {a.addAction(UIAlertAction(title:"Kiểm tra lăn · 0.5 m/s",style:.default){[weak self]_ in self?.rollingCheck()})}
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
            UserDefaults.standard.set(settings,forKey:Prefs.physics);UserDefaults.standard.set(sensitivity,forKey:Prefs.sensitivity)
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
