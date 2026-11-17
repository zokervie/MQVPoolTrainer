import UIKit
import SceneKit

struct TableLook {
    let id:String,name:String,base:Int
    let cabinet:UInt32,cloth:UInt32,trim:UInt32
    let wood:Bool
    var title:String {name}
    // 0.44.1 (review: store-review risk): one Zoker name per table, no maker codes, no maker links in the app (the
    // reference list stays in Docs/NGUON-MAU-BAN-CO.md). `id` unchanged so saved choices survive. "Z-Max Pro" = the
    // owner's reference club table (black cabinet, silver-grey cloth, brushed aluminium caps) and the default.
    static let all:[TableLook] = [
        .init(id:"zmax",name:"Z-Max Pro 9 ft",base:0,cabinet:0x0e0f11,cloth:0x6e767d,trim:0xc4c9cd,wood:false),
        .init(id:"apex",name:"Z-Onyx Pro",base:0,cabinet:0x20252b,cloth:0x237f92,trim:0xb8bec3,wood:false),
        .init(id:"arc",name:"Z-Onyx Wave",base:4,cabinet:0xe2ddd2,cloth:0x377a8e,trim:0x41494d,wood:false),
        .init(id:"gc7",name:"Z-Regent 7",base:1,cabinet:0x67513e,cloth:0x267e84,trim:0xc3c4c1,wood:true),
        .init(id:"gc6",name:"Z-Regent 6",base:1,cabinet:0x71462c,cloth:0x287d67,trim:0xb4b8ba,wood:true),
        .init(id:"blackwolf",name:"Z-Night",base:0,cabinet:0x28282a,cloth:0x2e728d,trim:0x55595c,wood:false),
        .init(id:"blackwolfpro",name:"Z-Night Pro",base:0,cabinet:0x181e24,cloth:0x277f91,trim:0x9dabb0,wood:false),
        .init(id:"allenton",name:"Z-Manor",base:2,cabinet:0x482615,cloth:0x12695D,trim:0xEAC583,wood:true),
        .init(id:"glenwood",name:"Z-Lodge",base:5,cabinet:0x7b5032,cloth:0x80504b,trim:0xa88d60,wood:true),
        .init(id:"oakland",name:"Z-Oak II",base:2,cabinet:0x503728,cloth:0x366c5a,trim:0x998b70,wood:true),
        .init(id:"sanibel",name:"Z-Coast",base:3,cabinet:0x9b8a71,cloth:0x67858b,trim:0x494744,wood:true),
        .init(id:"canton",name:"Z-Loft",base:3,cabinet:0x6e4933,cloth:0x3e6b75,trim:0x343231,wood:true),
        .init(id:"botanic",name:"Z-Garden",base:5,cabinet:0x776951,cloth:0x526d57,trim:0x494940,wood:true),
        .init(id:"proam",name:"Z-Arena",base:0,cabinet:0x493127,cloth:0x267ca1,trim:0x8a6f49,wood:true),
        .init(id:"professional",name:"Z-Arena Classic",base:2,cabinet:0x604332,cloth:0x29864c,trim:0xa08c6c,wood:true),
        .init(id:"smart",name:"Z-Arena Lite",base:0,cabinet:0x24282d,cloth:0x297e9c,trim:0x72777a,wood:false),
        .init(id:"ox",name:"Z-Titan",base:3,cabinet:0x25282e,cloth:0x287b94,trim:0x8b949a,wood:false),
        .init(id:"victory",name:"Z-Vanguard II",base:4,cabinet:0xd4d7d5,cloth:0x33828e,trim:0x60686d,wood:false),
        .init(id:"acurra",name:"Z-Vector",base:3,cabinet:0x33383d,cloth:0x377f99,trim:0xbdc2c6,wood:false),
        .init(id:"tournament",name:"Z-Tour Pro",base:4,cabinet:0x38332f,cloth:0x2d7d96,trim:0x94918a,wood:false),
        .init(id:"champion",name:"Z-Grand III",base:1,cabinet:0x775136,cloth:0x31795b,trim:0xaaa49c,wood:true),
        // 0.35: bar-box bodies (solid cabinet to the floor, coin door) — Zoker designs; the bed stays the 9 ft physics bed.
        .init(id:"zbar",name:"Z-Bar Classic · mặt 9 ft",base:6,cabinet:0x1b1d20,cloth:0x7a2529,trim:0xb9bdc1,wood:false),
        .init(id:"zbaroak",name:"Z-Bar Oak · mặt 9 ft",base:6,cabinet:0x6a4a30,cloth:0x2f6e4a,trim:0xc8b27a,wood:true),
        .init(id:"zbarpro",name:"Z-Bar Pro · mặt 9 ft",base:6,cabinet:0x26292e,cloth:0x2a6fa8,trim:0x9aa3aa,wood:false),
    ]
    static var selected:TableLook {
        // 0.34: make the owner's reference table the default once, then respect later choices
        if !UserDefaults.standard.bool(forKey:"tableDefault034"){UserDefaults.standard.set(true,forKey:"tableDefault034");UserDefaults.standard.set("zmax",forKey:"tableLook015")}
        return all.first{$0.id==UserDefaults.standard.string(forKey:"tableLook015")} ?? all[0]
    }
}
struct CueLook {
    let id:String,name:String,role:Int
    let color:UInt32,accent:UInt32
    let carbon:Bool
    /// 0.44 (owner item 18): the 10 "Zoker-" designs — butt inlay (0 none · 1 points · 2 stone ovals · 3 diamonds ·
    /// 4 waves · 5 scales), inlay and stone colours, tip and ferrule colours, and the printed model ("Zoker IGNITE").
    /// 0.44.1: no two-letter maker codes; every cue has its own short Zoker name.
    var inlay=0,inlayColor:UInt32=0xEDE6D2,stone:UInt32=0x2FA59A,tip:UInt32=0x1E4F6E,ferrule:UInt32=0xEDE8CF,code=""
    var title:String {name}
    /// Short name for the cue keys and the bag ("Ignite", "Nordic"…).
    var short:String {name.components(separatedBy:" ").first ?? name}
    var printed:String {code.isEmpty ? "Zoker":"Zoker "+code}
    static let roles=["Đánh","Jump","Phá"]
    /// Classic cue-making motifs (points, stone inlays, pearl windows…) — names and marks are Zoker's own.
    static let designs044:[CueLook] = [
        .init(id:"zmz01",name:"Ignite Maple",role:0,color:0x17120f,accent:0xd9c79a,carbon:false,inlay:1,inlayColor:0xE8D6A8,stone:0xE8D6A8,tip:0x5A3A22,ferrule:0xF1ECDD,code:"IGNITE"),
        .init(id:"zmc02",name:"Star Burl",role:0,color:0x6B4A2E,accent:0xC9A55A,carbon:false,inlay:2,inlayColor:0x101010,stone:0x22B5A8,tip:0x1E4F6E,ferrule:0xF4F0E4,code:"STAR"),
        .init(id:"zjb03",name:"Blackwood Points",role:0,color:0x6E3B22,accent:0xC0C4C8,carbon:false,inlay:1,inlayColor:0x0B0B0B,stone:0xC0C4C8,tip:0x24201C,ferrule:0xEDE6D2,code:"BLACKWOOD"),
        .init(id:"zlu04",name:"Royal Malachite",role:0,color:0x0E0F10,accent:0xC8A04A,carbon:false,inlay:3,inlayColor:0xC8A04A,stone:0x1F8A55,tip:0x7A1E1E,ferrule:0xF2EEE2,code:"ROYAL"),
        .init(id:"zvk05",name:"Nordic Ice",role:2,color:0xE9EDF0,accent:0x2D6FD6,carbon:false,inlay:3,inlayColor:0x2D6FD6,stone:0x5FA8FF,tip:0xF2F2F0,ferrule:0x1A1C20,code:"NORDIC"),
        .init(id:"zsc06",name:"Classic Rosewood",role:0,color:0x5A1F14,accent:0xEDE3C8,carbon:false,inlay:1,inlayColor:0xF0E7CF,stone:0x0E0E0E,tip:0x3A2A1C,ferrule:0xF4F0E6,code:"CLASSIC"),
        .init(id:"zmu07",name:"Crimson Wave",role:0,color:0x8A1622,accent:0xD9B24C,carbon:false,inlay:4,inlayColor:0xD9B24C,stone:0xF2E6C4,tip:0x1E4F6E,ferrule:0xF3EFE3,code:"CRIMSON"),
        .init(id:"zps08",name:"Onyx Pearl",role:0,color:0x0A0A0B,accent:0xBFC6CC,carbon:true,inlay:2,inlayColor:0xBFC6CC,stone:0x9FD6D2,tip:0x1C2A3A,ferrule:0x0F0F10,code:"ONYX"),
        .init(id:"zpe09",name:"Tigerwood Pro",role:2,color:0x9A5A22,accent:0x111111,carbon:false,inlay:1,inlayColor:0x151210,stone:0xF0A33A,tip:0xF2F2EE,ferrule:0x161616,code:"TIGERWOOD"),
        .init(id:"zld10",name:"Carbon Dragon",role:1,color:0x0C0C0E,accent:0xC2272D,carbon:true,inlay:5,inlayColor:0xC2272D,stone:0xF26A3A,tip:0x101010,ferrule:0x1A1A1A,code:"DRAGON"),
    ]
    static let all:[CueLook] = base044+designs044
    private static let base044:[CueLook] = [
        .init(id:"p3",name:"Obsidian",role:0,color:0x25272b,accent:0xc6bca0,carbon:true),
        .init(id:"air",name:"Glide Jump",role:1,color:0x155c65,accent:0xc5c8c9,carbon:true),
        .init(id:"bk",name:"Thunder Break",role:2,color:0x23262a,accent:0xc7ad43,carbon:true),
        .init(id:"svb",name:"Slate",role:0,color:0x66605c,accent:0xe0d7bb,carbon:true),
        .init(id:"propel",name:"Lift Jump",role:1,color:0x6c2529,accent:0xb7bbbd,carbon:true),
        .init(id:"breach",name:"Ram Break",role:2,color:0x543826,accent:0xa7976b,carbon:true),
        .init(id:"ec9",name:"Walnut",role:0,color:0x563b28,accent:0xd5d1bf,carbon:false),
        .init(id:"ad3",name:"Skyline Jump",role:1,color:0x242b2c,accent:0xbcc8c3,carbon:true),
        .init(id:"pbg",name:"Granite Break",role:2,color:0x252c29,accent:0x9ca68c,carbon:true),
        .init(id:"zplay",name:"Maple",role:0,color:0x5d3224,accent:0xd7b676,carbon:false),
        .init(id:"zjump",name:"Jump Classic",role:1,color:0x18515a,accent:0xb5b9bc,carbon:false),
        .init(id:"zbreak",name:"Break Classic",role:2,color:0x322b26,accent:0xb29b70,carbon:false)
    ]
    /// 0.44: small horizontal picture of THIS cue (butt colour + inlay, wrap, shaft, ferrule, tip) for the cue keys.
    func iconImage(size:CGSize=CGSize(width:44,height:12))->UIImage {
        UIGraphicsImageRenderer(size:size).image{c in
            let w=size.width,h=size.height,mid=h/2
            func seg(_ x0:CGFloat,_ x1:CGFloat,_ r0:CGFloat,_ r1:CGFloat,_ colour:UIColor){
                let p=UIBezierPath();p.move(to:CGPoint(x:x0,y:mid-r0));p.addLine(to:CGPoint(x:x1,y:mid-r1));p.addLine(to:CGPoint(x:x1,y:mid+r1));p.addLine(to:CGPoint(x:x0,y:mid+r0));p.close()
                colour.setFill();p.fill()
            }
            let butt=UIColor.rgb(color)
            seg(0,w*0.10,h*0.40,h*0.39,butt)
            seg(w*0.10,w*0.28,h*0.39,h*0.37,UIColor(white:0.08,alpha:1))          // wrap
            seg(w*0.28,w*0.48,h*0.37,h*0.31,butt)                                  // forearm
            if inlay>0 {UIColor.rgb(inlay==2 || inlay==3 ? stone:inlayColor).setFill()
                for k in 0..<3 {let x=w*(0.31+0.05*CGFloat(k));c.cgContext.fillEllipse(in:CGRect(x:x,y:mid-h*0.12,width:w*0.03,height:h*0.24))}}
            seg(w*0.48,w*0.50,h*0.31,h*0.31,UIColor.rgb(accent))                   // joint ring
            seg(w*0.50,w*0.93,h*0.27,h*0.17,carbon ? UIColor(white:0.15,alpha:1):UIColor.rgb(0xE6CFA0))   // shaft
            seg(w*0.93,w*0.97,h*0.17,h*0.17,UIColor.rgb(ferrule))
            seg(w*0.97,w,h*0.17,h*0.16,UIColor.rgb(tip))
        }.withRenderingMode(.alwaysOriginal)
    }
}
enum CueBag {
    static let names=["Thi đấu","Luyện tập","Dự phòng"]
    static var active:Int {
        get {min(2,max(0,UserDefaults.standard.integer(forKey:"activeBag015")))}
        set {UserDefaults.standard.set(min(2,max(0,newValue)),forKey:"activeBag015")}
    }
    static func cue(_ role:Int)->CueLook {
        let r=min(2,max(0,role)),fallback=CueLook.all[active*3+r]
        let id=UserDefaults.standard.string(forKey:"cueBag015.\(active).\(r)")
        return CueLook.all.first{$0.id==id && $0.role==r} ?? fallback
    }
    static func put(_ cue:CueLook){UserDefaults.standard.set(cue.id,forKey:"cueBag015.\(active).\(cue.role)")}
}
extension UIColor {
    static func rgb(_ hex:UInt32)->UIColor {UIColor(red:CGFloat((hex>>16)&255)/255,green:CGFloat((hex>>8)&255)/255,blue:CGFloat(hex&255)/255,alpha:1)}
}
final class EquipmentLibraryController:UIViewController,UITableViewDataSource,UITableViewDelegate {
    var changed:((Int?)->Void)?
    var initialTab=0
    private let table:TableScene
    private let list=UITableView(frame:.zero,style:.insetGrouped),preview=SCNView(),note=UILabel()
    private let tabs=UISegmentedControl(items:["\(TableLook.all.count) bàn","\(CueLook.all.count) cơ","3 bao cơ"])
    private var chosenCue=CueBag.cue(0)
    init(table:TableScene){self.table=table;super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError()}
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override func viewDidLoad(){
        super.viewDidLoad();overrideUserInterfaceStyle = .dark;title="Thư viện bàn & bao cơ";view.backgroundColor = .ink
        navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Xong",style:.done,target:self,action:#selector(close))
        tabs.selectedSegmentTintColor = .mint
        tabs.setTitleTextAttributes([.foregroundColor:UIColor.white],for:.normal)
        tabs.setTitleTextAttributes([.foregroundColor:UIColor.ink],for:.selected)
        let bar=UINavigationBarAppearance();bar.configureWithOpaqueBackground();bar.backgroundColor = .ink;bar.titleTextAttributes=[.foregroundColor:UIColor.white]
        navigationController?.navigationBar.standardAppearance=bar;navigationController?.navigationBar.scrollEdgeAppearance=bar;navigationController?.navigationBar.compactAppearance=bar
        tabs.selectedSegmentIndex=initialTab;tabs.addAction(UIAction{[weak self]_ in self?.refresh()},for:.valueChanged)
        for v in [tabs,list,preview,note]{v.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(v)}
        list.dataSource=self;list.delegate=self;list.backgroundColor = .clear
        preview.backgroundColor = .clear;preview.allowsCameraControl=true;preview.autoenablesDefaultLighting=false
        preview.antialiasingMode = .multisampling4X;preview.isPlaying=true
        note.numberOfLines=0;note.font = .systemFont(ofSize:11);note.textColor = .mint
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),tabs.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:12),tabs.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-12),
            list.topAnchor.constraint(equalTo:tabs.bottomAnchor,constant:8),list.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor),list.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor),list.widthAnchor.constraint(equalTo:view.widthAnchor,multiplier:0.47),
            preview.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor),preview.topAnchor.constraint(equalTo:tabs.bottomAnchor,constant:8),preview.trailingAnchor.constraint(equalTo:list.leadingAnchor),preview.bottomAnchor.constraint(equalTo:note.topAnchor,constant:-4),
            note.leadingAnchor.constraint(equalTo:preview.leadingAnchor,constant:12),note.trailingAnchor.constraint(equalTo:preview.trailingAnchor,constant:-10),note.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-8),note.heightAnchor.constraint(equalToConstant:62)])
        refresh()
    }
    private func refresh(){
        list.reloadData()
        if tabs.selectedSegmentIndex==0 {
            preview.scene=table.tablePreviewScene()
            note.text=TableLook.selected.title+"\nDựng tham khảo · xoay để xem. Tất cả dùng sân tập 9 ft; hình học và thông số hãng chưa được tái tạo chính xác."
        }else{
            preview.scene=table.cuePreviewScene()
            note.text="Bao \(CueBag.names[CueBag.active]) · chọn cơ để đưa vào đúng ngăn Đánh / Jump / Phá.\nMẫu dựng tham khảo; vật lý dùng ba cấu hình chung của Zoker."
        }
    }
    func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int {[TableLook.all.count,CueLook.all.count,CueBag.names.count][tabs.selectedSegmentIndex]}
    func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        let cell=UITableViewCell(style:.subtitle,reuseIdentifier:nil);cell.backgroundColor=UIColor(white:0.12,alpha:1)
        cell.textLabel?.textColor = .white;cell.detailTextLabel?.textColor = .mint;cell.textLabel?.font = .systemFont(ofSize:13,weight:.medium)
        cell.detailTextLabel?.font = .systemFont(ofSize:11);cell.detailTextLabel?.numberOfLines=2
        let i=indexPath.row
        if tabs.selectedSegmentIndex==0 {
            let item=TableLook.all[i];cell.textLabel?.text=item.title
            cell.detailTextLabel?.text="Bản dựng tham khảo · xem 3D";cell.imageView?.image=tableIcon(item)
            cell.accessoryType=item.id==TableLook.selected.id ? .checkmark:.none
        }else if tabs.selectedSegmentIndex==1 {
            let item=CueLook.all[i];cell.textLabel?.text=item.title+(item.code.isEmpty ? "":" · in "+item.printed)
            cell.detailTextLabel?.text=CueLook.roles[item.role]+" · chạm để mang vào bao "+CueBag.names[CueBag.active]+" (ngăn "+CueLook.roles[item.role]+")"
            cell.accessoryType=CueBag.cue(item.role).id==item.id ? .checkmark:.none
            cell.imageView?.image=item.iconImage(size:CGSize(width:64,height:14))   // 0.44: the cue itself, not a symbol
        }else{
            cell.textLabel?.text=CueBag.names[i];cell.detailTextLabel?.text="Ba ngăn: Đánh · Jump · Phá"
            cell.imageView?.image=UIImage(systemName:"bag");cell.imageView?.tintColor = .mint;cell.accessoryType=i==CueBag.active ? .checkmark:.none
        };return cell
    }
    func tableView(_ tableView:UITableView,didSelectRowAt indexPath:IndexPath){
        let i=indexPath.row
        if tabs.selectedSegmentIndex==0 {let look=TableLook.all[i];UserDefaults.standard.set(look.id,forKey:"tableLook015");table.selectTable(look);changed?(nil)}
        else if tabs.selectedSegmentIndex==1 {chosenCue=CueLook.all[i];CueBag.put(chosenCue);table.selectCue(chosenCue.role);changed?(chosenCue.role)}
        else {CueBag.active=i;table.selectCue(0);changed?(0)}
        refresh()
    }
    private func tableIcon(_ item:TableLook)->UIImage {
        UIGraphicsImageRenderer(size:CGSize(width:62,height:40)).image{c in
            UIColor.rgb(item.cabinet).setFill();UIBezierPath(roundedRect:CGRect(x:1,y:1,width:60,height:38),cornerRadius:5).fill()
            UIColor.rgb(item.cloth).setFill();UIBezierPath(roundedRect:CGRect(x:7,y:6,width:48,height:28),cornerRadius:3).fill()
            UIColor.black.setFill();for x in [8,31,54]{for y in [6,34]{c.cgContext.fillEllipse(in:CGRect(x:x-2,y:y-2,width:4,height:4))}}
        }
    }
    @objc private func close(){preview.isPlaying=false;dismiss(animated:true)}
}
