import UIKit

extension UIColor {
    static let ink=UIColor(red:0.050,green:0.062,blue:0.078,alpha:0.97)
    static let mint=UIColor(red:0.72,green:0.83,blue:0.77,alpha:1)
}
enum MenuSkin {
    static let wood:UIImage? = {
        guard let data=NSDataAsset(name:"WalnutAlbedo")?.data,let image=UIImage(data:data) else{return nil}
        let format=UIGraphicsImageRendererFormat();format.scale=1
        return UIGraphicsImageRenderer(size:CGSize(width:640,height:100),format:format).image{c in
            image.draw(in:CGRect(x:0,y:0,width:640,height:100))
            UIColor(red:0.08,green:0.025,blue:0.006,alpha:0.22).setFill()
            c.fill(CGRect(x:0,y:0,width:640,height:100))
        }
    }()
    static let gold=UIColor(red:0.94,green:0.76,blue:0.43,alpha:1)
    /// 0.41 (owner): menus open inside a wooden frame; each section has its own deep, muted tone.
    static let frameWood:UIColor = wood.map{UIColor(patternImage:$0)} ?? UIColor(red:0.24,green:0.13,blue:0.06,alpha:1)
    static let tones:[UIColor]=[UIColor(red:0.07,green:0.15,blue:0.12,alpha:1),   // rừng thông · hình ảnh / bàn
                                UIColor(red:0.07,green:0.10,blue:0.18,alpha:1),   // xanh đêm · ngắm
                                UIColor(red:0.16,green:0.10,blue:0.07,alpha:1),   // nâu gỗ trầm · phím
                                UIColor(red:0.12,green:0.10,blue:0.17,alpha:1),   // tím than · vật lý
                                UIColor(red:0.17,green:0.07,blue:0.09,alpha:1),   // đỏ rượu · máy / âm thanh
                                UIColor(red:0.09,green:0.11,blue:0.13,alpha:1)]   // xám đá · hệ thống
    /// Puts `content` inside a wood frame of `width` points on `host` (host shows the wood, content the tone).
    static func frame(_ host:UIView,content:UIView,width:CGFloat=10,tone:UIColor=MenuSkin.tones[5],radius:CGFloat=14){
        host.backgroundColor=frameWood
        content.backgroundColor=tone;content.layer.cornerRadius=radius;content.layer.cornerCurve = .continuous
        content.layer.borderWidth=1;content.layer.borderColor=gold.withAlphaComponent(0.45).cgColor;content.clipsToBounds=true
        _=width
    }
    /// A section button in a muted tone instead of the wood image (distinct per section).
    static func tone(_ button:UIButton,_ tone:UIColor){
        guard var c=button.configuration else{return}
        c.background.image=nil;c.baseBackgroundColor=tone;c.background.backgroundColor=tone
        c.background.strokeColor=gold.withAlphaComponent(0.35);button.configuration=c
    }
}
extension UIButton {
    static func lab(_ title:String,action:@escaping()->Void)->UIButton {
        let b=UIButton(type:.system);var c=UIButton.Configuration.filled()
        c.title=title;c.baseBackgroundColor=UIColor(red:0.20,green:0.11,blue:0.055,alpha:1)
        c.baseForegroundColor=UIColor(red:0.98,green:0.92,blue:0.79,alpha:1)
        c.background.image=MenuSkin.wood;c.background.imageContentMode = .scaleAspectFill
        c.cornerStyle = .medium;c.contentInsets=NSDirectionalEdgeInsets(top:12,leading:12,bottom:12,trailing:12)
        c.background.strokeColor=MenuSkin.gold.withAlphaComponent(0.5);c.background.strokeWidth=1
        let symbols:[(String,String)]=[("Bài tập","scope"),("Bài học","book.closed"),("Thế bi","square.grid.2x2"),
            ("Hiệu chỉnh","slider.horizontal.3"),("Hình ảnh","sparkles"),("Trên cao","viewfinder"),
            ("Dự báo","point.topleft.down.curvedto.point.bottomright.up"),("Đặt bi","hand.draw"),
            ("Lùi cú","arrow.uturn.backward"),("Làm lại","arrow.clockwise"),("Xem lại","play.circle"),
            ("Đánh thử","target"),("Ép phê","circle.dotted"),("Vệt bi","point.3.connected.trianglepath.dotted"),
            ("Cách điều khiển","hand.point.up.left"),("Đóng","xmark")]
        c.image=UIImage(systemName:symbols.first{title.hasPrefix($0.0)}?.1 ?? "circle.fill")
        c.preferredSymbolConfigurationForImage=UIImage.SymbolConfiguration(pointSize:16,weight:.medium)
        c.imagePadding=8
        c.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer { a in var a=a;a.font=UIFont.systemFont(ofSize:12,weight:.semibold);return a }
        b.configuration=c;b.accessibilityLabel=title
        b.configurationUpdateHandler={button in button.alpha=button.isEnabled ? (button.isHighlighted ? 0.65:1):0.35}
        b.addAction(UIAction{_ in action()},for:.touchUpInside);return b
    }
}
final class SpinPad:UIControl {
    var side=0.0,top=0.0
    var maximumOffset=0.7 {didSet{select(side:side,top:top)}}
    /// 0.35 (owner): jump cue — the upper half is locked (a jump needs a centre/low hit with the elevated cue).
    var maxTop=1.0 {didSet{if top>maxTop{select(side:side,top:maxTop)}else{setNeedsDisplay()}}}
    var changed:((Double,Double)->Void)?
    /// Điểm chạm có với tới được không (cơ phải qua được băng khi bi cái gần băng). nil = mọi điểm.
    var reachable:((Double,Double)->Bool)? {didSet{setNeedsDisplay()}}
    /// Đưa điểm không với tới về điểm gần nhất phía trên (giữ ngang), như ngoài đời chỉ đánh được phần trên bi.
    var clampTop:((Double,Double)->Double)?
    var expandedChanged:((Bool)->Void)?
    private var finger:UITouch?
    private var origin=CGPoint.zero
    private var initialSide=0.0,initialTop=0.0
    override init(frame:CGRect){super.init(frame:frame);isMultipleTouchEnabled=false;isAccessibilityElement=true;accessibilityLabel="Điểm chạm đầu cơ";accessibilityHint="Giữ để phóng to. Kéo ngón để chỉnh chính xác; buông để thu nhỏ.";backgroundColor = .clear}
    required init?(coder:NSCoder){fatalError()}
    override func draw(_ rect:CGRect){
        guard let ctx=UIGraphicsGetCurrentContext() else{return}
        let r=min(bounds.width,bounds.height)*0.43,c=CGPoint(x:bounds.midX,y:bounds.midY)
        let circle=CGRect(x:c.x-r,y:c.y-r,width:2*r,height:2*r)
        ctx.setShadow(offset:CGSize(width:0,height:3),blur:8,color:UIColor.black.cgColor)
        UIColor(white:0.94,alpha:1).setFill();ctx.fillEllipse(in:circle);ctx.setShadow(offset:.zero,blur:0)
        ctx.saveGState();ctx.addEllipse(in:circle);ctx.clip()
        if let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[UIColor.white.cgColor,UIColor(white:0.89,alpha:1).cgColor,UIColor(white:0.46,alpha:1).cgColor] as CFArray,locations:[0,0.55,1]){
            ctx.drawRadialGradient(gradient,startCenter:CGPoint(x:c.x-r*0.32,y:c.y-r*0.36),startRadius:0,endCenter:c,endRadius:r*1.15,options:[])
        }
        if let reachable=reachable {
            // Vùng bị băng che: tô xám sọc để thấy ngay phần bi không đánh tới được.
            ctx.saveGState();ctx.addEllipse(in:circle);ctx.clip()
            UIColor(white:0.18,alpha:0.62).setFill()
            let cells=22,cell=2*r/CGFloat(cells)
            for i in 0..<cells {for j in 0..<cells {
                let x=(CGFloat(i)+0.5)*cell-r,y=(CGFloat(j)+0.5)*cell-r
                if !reachable(Double(x/r),Double(-y/r)) {ctx.fill(CGRect(x:c.x+x-cell/2,y:c.y+y-cell/2,width:cell+0.5,height:cell+0.5))}
            }}
            ctx.restoreGState()
        }
        ctx.restoreGState()
        let detailed=bounds.width>110
        func label(_ title:String,_ point:CGPoint,_ size:CGFloat,_ color:UIColor){
            let attrs:[NSAttributedString.Key:Any]=[.font:UIFont.monospacedDigitSystemFont(ofSize:size,weight:.semibold),.foregroundColor:color]
            let text=title as NSString,sz=text.size(withAttributes:attrs)
            text.draw(at:CGPoint(x:point.x-sz.width/2,y:point.y-sz.height/2),withAttributes:attrs)
        }
        // Fractions of ball radius, viewed from the cue butt toward the ball.
        for fraction in [0.25,0.50,maximumOffset] {
            let radius=r*CGFloat(fraction)
            ctx.setStrokeColor((fraction==maximumOffset ? UIColor.systemOrange:UIColor.darkGray).withAlphaComponent(0.65).cgColor)
            ctx.setLineWidth(fraction==maximumOffset ? 1.5:0.7)
            ctx.setLineDash(phase:0,lengths:fraction==maximumOffset ? [3,2]:[])
            ctx.strokeEllipse(in:CGRect(x:c.x-radius,y:c.y-radius,width:2*radius,height:2*radius))
        }
        ctx.setLineDash(phase:0,lengths:[])
        ctx.setStrokeColor(UIColor.darkGray.withAlphaComponent(0.45).cgColor);ctx.setLineWidth(0.7)
        for i in 0..<12 {
            let a=CGFloat(i)*CGFloat.pi/6
            let inner:CGFloat=i%3==0 ? 0:0.76
            ctx.move(to:CGPoint(x:c.x+cos(a)*r*inner,y:c.y+sin(a)*r*inner))
            ctx.addLine(to:CGPoint(x:c.x+cos(a)*r*0.89,y:c.y+sin(a)*r*0.89))
        }
        ctx.strokePath()
        if detailed {
            for (title,x,y) in [("CU-LÊ",0.0,-0.91),("TRÔ",0.0,0.91),("T",-0.9,0.0),("P",0.9,0.0)] {
                label(title,CGPoint(x:c.x+CGFloat(x)*r,y:c.y+CGFloat(y)*r),8,.darkGray)
            }
            label("25",CGPoint(x:c.x+r*0.25,y:c.y-r*0.10),7,.darkGray)
            label("50",CGPoint(x:c.x+r*0.5,y:c.y-r*0.10),7,.darkGray)
        }
        if maxTop<1 {
            ctx.saveGState();ctx.addEllipse(in:circle);ctx.clip()
            UIColor(white:0.05,alpha:0.55).setFill();ctx.fill(CGRect(x:circle.minX,y:circle.minY,width:circle.width,height:circle.height/2-CGFloat(maxTop)*r))
            ctx.restoreGState()
            if detailed {label("JUMP · KHOÁ NỬA TRÊN",CGPoint(x:c.x,y:c.y-r*0.5),8,.white)}
        }
        let p=CGPoint(x:c.x+CGFloat(side)*r,y:c.y-CGFloat(top)*r)
        ctx.setStrokeColor(UIColor.systemRed.cgColor);ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in:CGRect(x:p.x-7,y:p.y-7,width:14,height:14))
        UIColor.systemRed.setFill();ctx.fillEllipse(in:CGRect(x:p.x-2.5,y:p.y-2.5,width:5,height:5))
        if detailed {
            label(String(format:"X %+.0f · Y %+.0f %%R",side*100,top*100),CGPoint(x:c.x,y:bounds.maxY-6),9,.white)
        }
    }

    private func apply(_ touch:UITouch){
        let p=touch.location(in:self),r=Double(min(bounds.width,bounds.height)*0.43)
        var x=initialSide+Double(p.x-origin.x)/r,y=initialTop-Double(p.y-origin.y)/r
        let length=hypot(x,y);if length>maximumOffset{x*=maximumOffset/length;y*=maximumOffset/length}
        if hypot(x,y)<0.045{x=0;y=0}
        y=min(y,maxTop)
        if let reachable=reachable,!reachable(x,y),let clampTop=clampTop {y=min(maxTop,clampTop(x,y))}
        side=x;top=y;accessibilityValue=String(format:"Ngang %.0f%%, dọc %.0f%%",x*100,y*100)
        changed?(x,y);setNeedsDisplay()
    }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?){
        guard isEnabled,finger==nil,let t=touches.first else{return}
        finger=t;initialSide=side;initialTop=top
        expandedChanged?(true)
        // Read the origin AFTER expansion, so the value never jumps as the pad grows.
        origin=t.location(in:self);setNeedsDisplay()
    }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?){
        guard isEnabled,let t=finger,touches.contains(t) else{return};apply(t)
    }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?){
        if let t=finger,touches.contains(t){collapse()}
    }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?){collapse()}
    override var isEnabled:Bool {didSet{if !isEnabled{collapse()}}}
    func collapse(){guard finger != nil else{return};finger=nil;expandedChanged?(false)}
    func reset(){side=0;top=0;accessibilityValue="Ngang 0%, dọc 0%";changed?(0,0);setNeedsDisplay()}
    func select(side:Double,top:Double){
        let length=hypot(side,top),scale=length>maximumOffset ? maximumOffset/length:1
        self.side=side*scale;self.top=min(top*scale,maxTop)
        if let reachable=reachable,!reachable(self.side,self.top),let clampTop=clampTop {self.top=min(maxTop,clampTop(self.side,self.top))}
        accessibilityValue=String(format:"Ngang %.0f%% bán kính, dọc %.0f%% bán kính",self.side*100,self.top*100);changed?(self.side,self.top);setNeedsDisplay()
    }
}
// A separate control owns the holding finger. It never toggles a latched state.
final class HoldLockControl:UIControl {
    var heldChanged:((Bool)->Void)?
    private var finger:UITouch?
    override init(frame:CGRect){
        super.init(frame:frame);backgroundColor = .clear
        isMultipleTouchEnabled=false;isExclusiveTouch=false
        isAccessibilityElement=true;accessibilityLabel="Giữ để khóa hướng"
        accessibilityHint="Giữ ngón này; dùng ngón khác vuốt cơ trên bàn. Buông để mở khóa."
    }
    required init?(coder:NSCoder){fatalError()}
    override var isEnabled:Bool {didSet{if !isEnabled{releaseHold()};setNeedsDisplay()}}
    override func draw(_ rect:CGRect){
        guard let ctx=UIGraphicsGetCurrentContext() else{return}
        let held=finger != nil
        // 0.36 (owner): B is a square key next to the round effect ball.
        let square=UIBezierPath(roundedRect:bounds.insetBy(dx:4,dy:4),cornerRadius:10)
        ctx.setFillColor(UIColor(white:held ? 0.8:0.10,alpha:held ? 0.30:0.32).cgColor)
        ctx.addPath(square.cgPath);ctx.fillPath()
        ctx.setStrokeColor(UIColor.rgb(0xEAC583).withAlphaComponent(isEnabled ? (held ? 0.75:0.40):0.1).cgColor)
        ctx.setLineWidth(1.2);ctx.addPath(square.cgPath);ctx.strokePath()
        let ink=UIColor.rgb(0xEAC583).withAlphaComponent(isEnabled ? (held ? 1:0.80):0.18)
        let caption="B" as NSString
        let attributes:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:bounds.height*0.46,weight:.bold),.foregroundColor:ink]
        let size=caption.size(withAttributes:attributes)
        caption.draw(at:CGPoint(x:bounds.midX-size.width/2,y:bounds.midY-size.height/2),withAttributes:attributes)
    }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?){
        guard isEnabled,finger==nil,let touch=touches.first else{return}
        finger=touch;setNeedsDisplay();heldChanged?(true)
    }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?){
        if let touch=finger,touches.contains(touch){releaseHold()}
    }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?){releaseHold()}
    func releaseHold(){
        guard finger != nil else{return}
        finger=nil;setNeedsDisplay();heldChanged?(false)
    }
}

// Transparent, full-screen second-finger surface, enabled only while lock is held.
final class StrokePad:UIControl {
    var shot:((Double)->Void)?
    var pullChanged:((Double)->Void)?
    /// 0.41: every finger sample (point in this view, live stroke speed 0…8 before the power scale, forward?).
    var track:((CGPoint,Double,Bool)->Void)?
    private(set) var lastPoint:CGPoint = .zero
    var sensitivity=1.0
    private var finger:UITouch?
    private var start:CGFloat=0,furthest:CGFloat=0,previous:CGFloat=0,fired=false
    private var samples:[(TimeInterval,CGFloat)]=[]
    override init(frame:CGRect){super.init(frame:frame);backgroundColor = .clear;isMultipleTouchEnabled=false;isExclusiveTouch=false;accessibilityLabel="Vuốt cơ trên bàn"}
    required init?(coder:NSCoder){fatalError()}
    override var isEnabled:Bool {didSet{if !isEnabled{cancelStroke()}}}
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?){
        guard isEnabled,finger==nil,let t=touches.first else{return}
        finger=t;start=t.location(in:self).y;furthest=start;previous=start;fired=false;samples=[(t.timestamp,start)]
    }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?){
        guard isEnabled,!fired,let t=finger,touches.contains(t) else{return}
        for sample in event?.coalescedTouches(for:t) ?? [t] {
            guard !fired else{break}
            let point=sample.location(in:self),y=point.y,time=sample.timestamp
            if let last=samples.last,time<=last.0{continue}
            furthest=max(furthest,y);samples.append((time,y));samples.removeAll{time-$0.0>0.085}   // 0.30: wider window = smoother speed estimate
            pullChanged?(max(0,min(1,Double((y-start)/110))))
            lastPoint=point
            if let track=track {
                let live=liveSpeed()
                track(point,live > 0 ? BLStrokeSpeed(live,Double(min(bounds.width,bounds.height)),sensitivity):0,live > 0)
            }
            let crosses=previous>start && y<=start
            previous=y
            guard furthest-start>14,crosses,samples.count>=3 else{continue}
            // Least-squares slope of observed timestamps, not callback frequency.
            let t0=samples[0].0,count=Double(samples.count)
            let mt=samples.reduce(0.0){$0+($1.0-t0)}/count
            let my=samples.reduce(0.0){$0+Double($1.1)}/count
            var numerator=0.0,denominator=0.0
            for (stamp,point) in samples{let d=stamp-t0-mt;numerator+=d*(Double(point)-my);denominator+=d*d}
            guard denominator>1e-10 else{continue}
            let speed=max(0,-numerator/denominator)
            guard speed>0.01 else{continue}
            let edge=Double(min(bounds.width,bounds.height))
            fired=true;shot?(BLStrokeSpeed(Double(speed),edge,sensitivity));pullChanged?(0);return
        }
    }
    /// Forward finger speed (pt/s, > 0 when pushing toward the ball) by the same least-squares fit as the shot.
    private func liveSpeed()->Double{
        guard samples.count>=3 else{return 0}
        let t0=samples[0].0,count=Double(samples.count)
        let mt=samples.reduce(0.0){$0+($1.0-t0)}/count,my=samples.reduce(0.0){$0+Double($1.1)}/count
        var numerator=0.0,denominator=0.0
        for (stamp,point) in samples{let d=stamp-t0-mt;numerator+=d*(Double(point)-my);denominator+=d*d}
        return denominator>1e-10 ? max(0,-numerator/denominator):0
    }
    /// 0.30b: called when the stroke finger lifts; false = no shot fired (the controller unlocks).
    var released:((Bool)->Void)?
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?){if let t=finger,touches.contains(t){let didFire=fired;cancelStroke();released?(didFire)}}
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?){cancelStroke()}
    func cancelStroke(){finger=nil;samples=[];fired=false;pullChanged?(0)}
}

/// 0.30 độ dốc cơ 0–90° dạng quạt (owner: "hình quạt nằm vừa vặn trên bánh răng"). Tâm quạt ở góc dưới phía
/// ngoài (trái với tay phải), chạm/kéo theo góc = độ dốc (BLFanDegrees). Kim là cây cơ nhỏ; phóng to khi chạm.
final class ElevationPad:UIControl {
    static let maximum=90.0
    var degrees:Double=0 {didSet{accessibilityValue="\(Int(degrees)) độ";setNeedsDisplay()}}
    var leftHanded=false {didSet{if leftHanded != oldValue{setNeedsDisplay()}}}
    /// 0.37 (owner): the least elevation that keeps the cue above the rail / balls behind, updated live while aiming.
    /// The needle shows max(degrees, minimum) — the cue really is raised — and the forced zone is shaded red.
    var minimum:Double=0 {didSet{if abs(minimum-oldValue)>0.05{accessibilityValue="\(Int(shown)) độ";setNeedsDisplay()}}}
    var shown:Double{max(degrees,minimum)}
    var changed:((Double)->Void)?
    override init(frame:CGRect){super.init(frame:frame);backgroundColor = .clear;isAccessibilityElement=true;accessibilityLabel="Độ dốc cơ";accessibilityIdentifier="ElevationFan";accessibilityTraits = .adjustable;contentMode = .redraw}
    required init?(coder:NSCoder){fatalError()}
    private var pivot:CGPoint{CGPoint(x:leftHanded ? bounds.maxX-4:bounds.minX+4,y:bounds.maxY-4)}
    private var radius:CGFloat{min(bounds.width,bounds.height)-8}
    private func point(_ deg:Double,_ r:CGFloat)->CGPoint{let a=CGFloat(deg*Double.pi/180);return CGPoint(x:pivot.x+(leftHanded ? -1:1)*r*cos(a),y:pivot.y-r*sin(a))}
    override func draw(_ rect:CGRect){
        guard let ctx=UIGraphicsGetCurrentContext() else{return}
        let r=radius,p=pivot
        // fan body
        let fan=UIBezierPath();fan.move(to:p);fan.addLine(to:point(0,r))
        fan.addArc(withCenter:p,radius:r,startAngle:leftHanded ? .pi:0,endAngle:-.pi/2,clockwise:leftHanded);fan.close()
        UIColor(white:0.04,alpha:0.30).setFill();fan.fill()
        UIColor.white.withAlphaComponent(0.16).setStroke();fan.lineWidth=0.8;fan.stroke()
        // filled sector up to the current elevation
        if degrees>0.5 {
            let on=UIBezierPath();on.move(to:p);on.addLine(to:point(0,r))
            on.addArc(withCenter:p,radius:r,startAngle:leftHanded ? .pi:0,endAngle:leftHanded ? .pi+CGFloat(degrees*Double.pi/180):-CGFloat(degrees*Double.pi/180),clockwise:leftHanded);on.close()
            UIColor.rgb(0xEAC583).withAlphaComponent(0.22).setFill();on.fill()
        }
        if minimum>degrees+0.5 {   // forced by the rail / a ball behind
            let f=UIBezierPath();f.move(to:p);f.addLine(to:point(degrees,r))
            f.addArc(withCenter:p,radius:r,startAngle:leftHanded ? .pi+CGFloat(degrees*Double.pi/180):-CGFloat(degrees*Double.pi/180),endAngle:leftHanded ? .pi+CGFloat(minimum*Double.pi/180):-CGFloat(minimum*Double.pi/180),clockwise:leftHanded);f.close()
            UIColor(red:0.95,green:0.35,blue:0.25,alpha:0.30).setFill();f.fill()
        }
        // ticks every 15°, longer at 0/45/90 (jump 45, massé 60+)
        ctx.setLineWidth(1)
        for tick in stride(from:0,through:90,by:15){
            let long=tick%45==0,a=point(Double(tick),r-(long ? 9:5)),b=point(Double(tick),r)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(tick==60 ? 0.55:0.32).cgColor);ctx.move(to:a);ctx.addLine(to:b);ctx.strokePath()
        }
        // needle = small cue
        let alpha:CGFloat=isTracking ? 0.98:0.78
        let tip=point(shown,r*0.18),butt=point(shown,r*0.92),mid=CGPoint(x:(tip.x+butt.x)/2,y:(tip.y+butt.y)/2)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(UIColor(red:0.86,green:0.70,blue:0.45,alpha:alpha).cgColor);ctx.setLineWidth(3.0);ctx.move(to:butt);ctx.addLine(to:mid);ctx.strokePath()
        ctx.setStrokeColor(UIColor(white:0.95,alpha:alpha).cgColor);ctx.setLineWidth(2.0);ctx.move(to:mid);ctx.addLine(to:tip);ctx.strokePath()
        UIColor.white.withAlphaComponent(alpha).setFill();ctx.fillEllipse(in:CGRect(x:p.x-3,y:p.y-3,width:6,height:6))
        let attrs:[NSAttributedString.Key:Any]=[.font:UIFont.monospacedDigitSystemFont(ofSize:11,weight:.semibold),.foregroundColor:UIColor.white.withAlphaComponent(0.85)]
        let text=(minimum>degrees+0.5 ? "↑\(Int(shown.rounded()))°":"\(Int(degrees))°") as NSString,sz=text.size(withAttributes:attrs)
        text.draw(at:CGPoint(x:leftHanded ? bounds.minX+3:bounds.maxX-sz.width-3,y:bounds.minY+2),withAttributes:attrs)
    }
    private func set(_ q:CGPoint){
        // the fan is drawn inset by 4 pt; BLFanDegrees works in the fan's own square
        let w=Double(bounds.width-8),h=Double(bounds.height-8)
        degrees=BLFanDegrees(Double(q.x-4),Double(q.y-4),w,h,leftHanded ? 1:0);changed?(degrees)
    }
    override func beginTracking(_ touch:UITouch,with event:UIEvent?)->Bool{guard isEnabled else{return false};zoomForTouch(true);set(touch.location(in:self));return true}
    override func continueTracking(_ touch:UITouch,with event:UIEvent?)->Bool{set(touch.location(in:self));return true}
    override func endTracking(_ touch:UITouch?,with event:UIEvent?){zoomForTouch(false);setNeedsDisplay()}
    override func cancelTracking(with event:UIEvent?){zoomForTouch(false);setNeedsDisplay()}
    override func accessibilityIncrement(){degrees=min(Self.maximum,degrees+5);changed?(degrees)}
    override func accessibilityDecrement(){degrees=max(0,degrees-5);changed?(degrees)}
}


extension UIControl {
    /// 0.22: grow 1.6x while touched (finer finger control, owner request); the bottom edge stays put so the
    /// zoomed control never slides under the screen edge. Touch locations are in local coordinates, so the
    /// same finger travel moves the value 1.6x less = finer.
    func zoomForTouch(_ on:Bool){
        let lift=bounds.height*0.3
        UIView.animate(withDuration:0.12,delay:0,options:[.beginFromCurrentState,.allowUserInteraction]){
            self.transform=on ? CGAffineTransform(translationX:0,y:-lift).scaledBy(x:1.6,y:1.6):.identity
        }
        superview?.bringSubviewToFront(self)
    }
}

/// Relative angle adjustment; no fixed power or angle slider obscures the table.
/// 0.22: horizontal when wider than tall (under the effect ball), vertical otherwise.
final class FineAimWheel:UIControl {
    var changed:((Double)->Void)?
    private var previousY:CGFloat=0,phase:CGFloat=0
    private var horizontal:Bool{bounds.width>bounds.height}
    override init(frame:CGRect){super.init(frame:frame);isAccessibilityElement=true;accessibilityLabel="Bánh xe vi chỉnh góc ngắm";accessibilityTraits = .adjustable;backgroundColor = .clear}
    required init?(coder:NSCoder){fatalError()}
    override func draw(_ rect:CGRect){
        guard let context=UIGraphicsGetCurrentContext() else{return}
        let body=horizontal ? bounds.insetBy(dx:4,dy:6):bounds.insetBy(dx:9,dy:4)
        UIColor(white:0.08,alpha:0.22).setFill();UIBezierPath(roundedRect:body,cornerRadius:10).fill()
        context.saveGState();context.addPath(UIBezierPath(roundedRect:body,cornerRadius:10).cgPath);context.clip()
        let span=horizontal ? bounds.width:bounds.height
        for tick in -2...Int(span/8)+2 {
            let p=CGFloat(tick)*8+phase.truncatingRemainder(dividingBy:8)
            let distance=abs(p-span/2)/max(1,span/2),alpha=max(0,1-distance)*0.32
            context.setStrokeColor(UIColor.white.withAlphaComponent(alpha).cgColor);context.setLineWidth(1)
            if horizontal{context.move(to:CGPoint(x:p,y:body.minY+3));context.addLine(to:CGPoint(x:p,y:body.maxY-3))}
            else{context.move(to:CGPoint(x:body.minX+3,y:p));context.addLine(to:CGPoint(x:body.maxX-3,y:p))}
            context.strokePath()
        }
        context.restoreGState()
        context.setStrokeColor(UIColor.rgb(0xEAC583).withAlphaComponent(isEnabled ? 0.65:0.15).cgColor);context.setLineWidth(2)
        if horizontal{context.move(to:CGPoint(x:bounds.midX,y:body.minY-3));context.addLine(to:CGPoint(x:bounds.midX,y:body.minY+3))}
        else{context.move(to:CGPoint(x:body.minX-3,y:bounds.midY));context.addLine(to:CGPoint(x:body.minX+3,y:bounds.midY))}
        context.strokePath()
    }
    private func coordinate(_ touch:UITouch)->CGFloat{let p=touch.location(in:self);return horizontal ? p.x:p.y}
    override func beginTracking(_ touch:UITouch,with event:UIEvent?)->Bool{guard isEnabled else{return false};zoomForTouch(true);previousY=coordinate(touch);return true}
    override func continueTracking(_ touch:UITouch,with event:UIEvent?)->Bool{let y=coordinate(touch),delta=y-previousY;previousY=y;phase+=delta;changed?(Double(horizontal ? -delta:delta)*0.00065);setNeedsDisplay();return true}
    override func endTracking(_ touch:UITouch?,with event:UIEvent?){zoomForTouch(false)}
    override func cancelTracking(with event:UIEvent?){zoomForTouch(false)}
    override var isEnabled:Bool{didSet{alpha=isEnabled ? 1:0.25}}
    override func accessibilityIncrement(){changed?(0.001)}
    override func accessibilityDecrement(){changed?(-0.001)}
}


/// 0.41 (owner): a 7-colour power scale (violet = MIN … red = MAX, colours blended), the live number and colour of
/// the stroke, a misty trail along the swipe tinted by its speed, and at the end of the swipe a soft spectrum burst
/// with the final speed — gone a moment later. Display only; Core Animation runs the fades (no per-frame drawing).
final class PowerFX:UIView {
    static let stops:[UIColor]=[UIColor.rgb(0x8B3DFF),UIColor.rgb(0x4F46E5),UIColor.rgb(0x1E90FF),UIColor.rgb(0x22C55E),
                                UIColor.rgb(0xFACC15),UIColor.rgb(0xFF8A00),UIColor.rgb(0xFF2D2D)]
    static func color(_ t:Double)->UIColor{
        let x=max(0,min(1,t))*Double(stops.count-1),i=min(stops.count-2,Int(x)),f=CGFloat(x-Double(i))
        var a:(CGFloat,CGFloat,CGFloat,CGFloat)=(0,0,0,0),b:(CGFloat,CGFloat,CGFloat,CGFloat)=(0,0,0,0)
        stops[i].getRed(&a.0,green:&a.1,blue:&a.2,alpha:&a.3);stops[i+1].getRed(&b.0,green:&b.1,blue:&b.2,alpha:&b.3)
        return UIColor(red:a.0+(b.0-a.0)*f,green:a.1+(b.1-a.1)*f,blue:a.2+(b.2-a.2)*f,alpha:1)
    }
    var maxSpeed=8.0
    var enabled:Bool{UserDefaults.standard.object(forKey:"tunePowerFX041") as? Bool ?? true}
    private let bar=CAGradientLayer(),well=CALayer(),marker=CALayer(),readout=UILabel(),caption=UILabel()
    private var dots:[UIImage]=[]
    private var lastDot:CGPoint?
    private var meterOn=false
    override init(frame:CGRect){
        super.init(frame:frame);isUserInteractionEnabled=false;backgroundColor = .clear
        well.backgroundColor=UIColor(white:0,alpha:0.45).cgColor;well.cornerRadius=8;well.opacity=0
        bar.colors=Self.stops.map{$0.cgColor};bar.startPoint=CGPoint(x:0,y:0.5);bar.endPoint=CGPoint(x:1,y:0.5);bar.cornerRadius=4;bar.opacity=0
        marker.backgroundColor=UIColor.white.cgColor;marker.cornerRadius=2;marker.shadowColor=UIColor.black.cgColor;marker.shadowOpacity=0.7;marker.shadowRadius=3;marker.opacity=0
        for l in [well,bar,marker]{layer.addSublayer(l)}
        readout.font = .monospacedDigitSystemFont(ofSize:15,weight:.heavy);readout.textAlignment = .center;readout.alpha=0
        readout.layer.shadowColor=UIColor.black.cgColor;readout.layer.shadowOpacity=0.9;readout.layer.shadowRadius=3;readout.layer.shadowOffset = .zero
        caption.font = .systemFont(ofSize:9,weight:.bold);caption.textColor=UIColor(white:1,alpha:0.7);caption.alpha=0
        caption.text="MIN · LỰC · MAX";caption.textAlignment = .center
        addSubview(readout);addSubview(caption)
        // 24 tinted soft dots (radial falloff = "mờ sương"), drawn once.
        let format=UIGraphicsImageRendererFormat();format.scale=1
        for k in 0..<24 {
            let c=Self.color(Double(k)/23)
            dots.append(UIGraphicsImageRenderer(size:CGSize(width:64,height:64),format:format).image{ctx in
                let colors=[c.withAlphaComponent(0.85).cgColor,c.withAlphaComponent(0.25).cgColor,c.withAlphaComponent(0).cgColor] as CFArray
                if let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,0.45,1]){
                    ctx.cgContext.drawRadialGradient(g,startCenter:CGPoint(x:32,y:32),startRadius:0,endCenter:CGPoint(x:32,y:32),endRadius:32,options:[])
                }
            })
        }
    }
    required init?(coder:NSCoder){fatalError()}
    private var meterFrame:CGRect{
        // 0.42 (owner 13/11 18:17): in the free space RIGHT of the top scoreboard, clear of the play area.
        let boardHalf=min(bounds.width*0.25,200)+14,left=bounds.midX+boardHalf,right=bounds.maxX-safeAreaInsets.right-14
        let w=max(90,min(right-left,240)),top=safeAreaInsets.top+24
        return CGRect(x:right-w,y:top,width:w,height:8)
    }
    override func layoutSubviews(){
        super.layoutSubviews()
        CATransaction.begin();CATransaction.setDisableActions(true)
        let f=meterFrame;bar.frame=f;well.frame=f.insetBy(dx:-8,dy:-6)
        caption.frame=CGRect(x:f.minX,y:f.maxY+4,width:f.width,height:12)
        CATransaction.commit()
    }
    /// B held: show the scale; released: hide it.
    func showMeter(_ on:Bool){
        guard on != meterOn else{return};meterOn=on && enabled
        let o:Float=meterOn ? 1:0
        for l in [well,bar,marker]{l.opacity=o}
        UIView.animate(withDuration:0.18){self.caption.alpha=self.meterOn ? 1:0;if !self.meterOn{self.readout.alpha=0}}
        lastDot=nil
    }
    /// Live finger sample: speed in m/s (0 while drawing back).
    func track(_ p:CGPoint,speed:Double,forward:Bool){
        guard enabled else{return}
        let t=max(0,min(1,speed/max(0.1,maxSpeed)))
        let f=meterFrame
        CATransaction.begin();CATransaction.setDisableActions(true)
        marker.frame=CGRect(x:f.minX+f.width*CGFloat(t)-2,y:f.minY-5,width:4,height:f.height+10)
        CATransaction.commit()
        if forward && speed>0.05 {
            readout.text=String(format:"%.1f m/s",speed);readout.textColor=Self.color(t)
            readout.sizeToFit();readout.center=CGPoint(x:f.minX+f.width*CGFloat(t),y:f.minY-14);readout.alpha=1
        }
        // misty trail: a soft dot every ~7 pt, tinted by the speed, fading and spreading out
        if let last=lastDot,hypot(p.x-last.x,p.y-last.y)<7 {return}
        lastDot=p
        let dot=CALayer();let size:CGFloat=forward ? 30:22
        dot.contents=dots[min(23,Int(t*23))].cgImage;dot.frame=CGRect(x:p.x-size/2,y:p.y-size/2,width:size,height:size)
        dot.opacity=0;layer.addSublayer(dot)
        fade(dot,from:forward ? 0.75:0.4,scale:1.7,duration:0.6)
    }
    /// Shot fired at `p` with `speed` m/s: spectrum burst + the number at the end of the swipe.
    func fire(_ p:CGPoint,speed:Double){
        guard enabled else{return}
        let t=max(0,min(1,speed/max(0.1,maxSpeed)))
        let ring=CAGradientLayer();ring.type = .conic;ring.colors=(Self.stops+[Self.stops[0]]).map{$0.cgColor}
        ring.startPoint=CGPoint(x:0.5,y:0.5);ring.endPoint=CGPoint(x:0.5,y:0)
        let size:CGFloat=110;ring.frame=CGRect(x:p.x-size/2,y:p.y-size/2,width:size,height:size);ring.cornerRadius=size/2
        let mask=CALayer();mask.frame=ring.bounds;mask.contents=dots[0].cgImage   // soft radial mask: misty, no hard edge
        ring.mask=mask;ring.opacity=0;layer.addSublayer(ring)
        fade(ring,from:0.85,scale:1.5,duration:0.95)
        let label=UILabel();label.text=String(format:"%.1f m/s",speed);label.font = .monospacedDigitSystemFont(ofSize:22,weight:.heavy)
        label.textColor=Self.color(t);label.sizeToFit();label.center=CGPoint(x:p.x,y:p.y-46)
        label.layer.shadowColor=UIColor.black.cgColor;label.layer.shadowOpacity=0.9;label.layer.shadowRadius=4;label.layer.shadowOffset = .zero
        addSubview(label)
        UIView.animate(withDuration:0.95,delay:0.25,options:[.curveEaseOut],animations:{label.alpha=0;label.transform=CGAffineTransform(translationX:0,y:-18)}){_ in label.removeFromSuperview()}
        readout.text=String(format:"%.1f m/s",speed);readout.textColor=Self.color(t)
        lastDot=nil
    }
    private func fade(_ l:CALayer,from:Float,scale:CGFloat,duration:Double){
        CATransaction.begin()
        CATransaction.setCompletionBlock{l.removeFromSuperlayer()}
        let a=CABasicAnimation(keyPath:"opacity");a.fromValue=from;a.toValue=0
        let s=CABasicAnimation(keyPath:"transform.scale");s.fromValue=1;s.toValue=scale
        let g=CAAnimationGroup();g.animations=[a,s];g.duration=duration;g.timingFunction=CAMediaTimingFunction(name:.easeOut)
        g.fillMode = .forwards;g.isRemovedOnCompletion=false
        l.add(g,forKey:"mist")
        CATransaction.commit()
    }
}
