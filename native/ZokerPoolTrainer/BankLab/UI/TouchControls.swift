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
        if let reachable=reachable,!reachable(x,y),let clampTop=clampTop {y=clampTop(x,y)}
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
        self.side=side*scale;self.top=top*scale
        if let reachable=reachable,!reachable(self.side,self.top),let clampTop=clampTop {self.top=clampTop(self.side,self.top)}
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
        let circle=bounds.insetBy(dx:5,dy:5)
        ctx.setFillColor(UIColor(white:held ? 0.8:0.10,alpha:held ? 0.28:0.20).cgColor)
        ctx.fillEllipse(in:circle)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(isEnabled ? (held ? 0.65:0.24):0.1).cgColor)
        ctx.setLineWidth(1);ctx.strokeEllipse(in:circle)
        // 0.16: biểu tượng ổ khoá + chữ "GIỮ" thay chữ "B" (hành vi giữ-để-khoá không đổi).
        let ink=UIColor.white.withAlphaComponent(isEnabled ? (held ? 0.95:0.70):0.18)
        let symbol=UIImage(systemName:held ? "lock.fill":"lock.open",withConfiguration:UIImage.SymbolConfiguration(pointSize:20,weight:.semibold))?
            .withTintColor(ink,renderingMode:.alwaysOriginal)
        let caption=(held ? "B · VUỐT" : "B · GIỮ") as NSString
        let attributes:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:10,weight:.bold),.foregroundColor:ink,.kern:0.6]
        let captionSize=caption.size(withAttributes:attributes)
        if let symbol=symbol {
            let total=symbol.size.height+2+captionSize.height
            symbol.draw(at:CGPoint(x:bounds.midX-symbol.size.width/2,y:bounds.midY-total/2))
            caption.draw(at:CGPoint(x:bounds.midX-captionSize.width/2,y:bounds.midY-total/2+symbol.size.height+2),withAttributes:attributes)
        }
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
            let y=sample.location(in:self).y,time=sample.timestamp
            if let last=samples.last,time<=last.0{continue}
            furthest=max(furthest,y);samples.append((time,y));samples.removeAll{time-$0.0>0.060}
            pullChanged?(max(0,min(1,Double((y-start)/110))))
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
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?){if let t=finger,touches.contains(t){cancelStroke()}}
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?){cancelStroke()}
    func cancelStroke(){finger=nil;samples=[];fired=false;pullChanged?(0)}
}

/// Độ dốc cơ 0–90°: kéo lên/xuống; con trỏ là hình cây cơ nhỏ nằm ngang ở 0°, chéo ở 45°, dựng đứng ở 90°.
final class ElevationPad:UIControl {
    static let maximum=90.0
    var degrees:Double=0 {didSet{accessibilityValue="\(Int(degrees)) độ";setNeedsDisplay()}}
    var changed:((Double)->Void)?
    override init(frame:CGRect){super.init(frame:frame);backgroundColor = .clear;isAccessibilityElement=true;accessibilityLabel="Độ dốc cơ";accessibilityTraits = .adjustable}
    required init?(coder:NSCoder){fatalError()}
    override func draw(_ rect:CGRect){
        guard let ctx=UIGraphicsGetCurrentContext() else{return}
        let track=CGRect(x:bounds.midX-2,y:22,width:4,height:bounds.height-42)
        UIColor.white.withAlphaComponent(0.14).setFill();UIBezierPath(roundedRect:track,cornerRadius:2).fill()
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor);ctx.setLineWidth(1)
        for tick in stride(from:0,through:90,by:45){let ty=track.maxY-CGFloat(tick)/CGFloat(Self.maximum)*track.height;ctx.move(to:CGPoint(x:bounds.midX-9,y:ty));ctx.addLine(to:CGPoint(x:bounds.midX+9,y:ty))}
        ctx.strokePath()
        // Hình cây cơ: đầu cơ chạm bi nhỏ, thân cơ quay theo góc dốc.
        let y=track.maxY-CGFloat(degrees/Self.maximum)*track.height
        let ball=CGPoint(x:bounds.midX+7,y:y+6),radius:CGFloat=4.5
        let theta=CGFloat(degrees*Double.pi/180)
        let tip=CGPoint(x:ball.x-radius*cos(theta)-1,y:ball.y-radius*sin(theta)-1)
        let length:CGFloat=24
        let butt=CGPoint(x:tip.x-length*cos(theta),y:tip.y-length*sin(theta))
        let alpha:CGFloat=isTracking ? 0.95:0.7
        UIColor.white.withAlphaComponent(alpha).setFill();ctx.fillEllipse(in:CGRect(x:ball.x-radius,y:ball.y-radius,width:2*radius,height:2*radius))
        ctx.setLineCap(.round)
        ctx.setStrokeColor(UIColor(red:0.86,green:0.70,blue:0.45,alpha:alpha).cgColor);ctx.setLineWidth(3.2)
        ctx.move(to:butt);ctx.addLine(to:CGPoint(x:(tip.x+butt.x)/2,y:(tip.y+butt.y)/2));ctx.strokePath()
        ctx.setStrokeColor(UIColor(white:0.95,alpha:alpha).cgColor);ctx.setLineWidth(2.2)
        ctx.move(to:CGPoint(x:(tip.x+butt.x)/2,y:(tip.y+butt.y)/2));ctx.addLine(to:tip);ctx.strokePath()
        let attrs:[NSAttributedString.Key:Any]=[.font:UIFont.monospacedDigitSystemFont(ofSize:11,weight:.medium),.foregroundColor:UIColor.white.withAlphaComponent(0.75)]
        let text="\(Int(degrees))°" as NSString,sz=text.size(withAttributes:attrs);text.draw(at:CGPoint(x:bounds.midX-sz.width/2,y:2),withAttributes:attrs)
    }
    private func set(_ p:CGPoint){degrees=(max(0,min(Self.maximum,Double((bounds.height-20-p.y)/(bounds.height-42))*Self.maximum))).rounded();changed?(degrees)}
    override func beginTracking(_ touch:UITouch,with event:UIEvent?)->Bool{guard isEnabled else{return false};set(touch.location(in:self));return true}
    override func continueTracking(_ touch:UITouch,with event:UIEvent?)->Bool{set(touch.location(in:self));return true}
    override func endTracking(_ touch:UITouch?,with event:UIEvent?){setNeedsDisplay()}
    override func accessibilityIncrement(){degrees=min(Self.maximum,degrees+5);changed?(degrees)}
    override func accessibilityDecrement(){degrees=max(0,degrees-5);changed?(degrees)}
}


/// Relative angle adjustment; no fixed power or angle slider obscures the table.
final class FineAimWheel:UIControl {
    var changed:((Double)->Void)?
    private var previousY:CGFloat=0,phase:CGFloat=0
    override init(frame:CGRect){super.init(frame:frame);isAccessibilityElement=true;accessibilityLabel="Bánh xe vi chỉnh góc ngắm";accessibilityTraits = .adjustable;backgroundColor = .clear}
    required init?(coder:NSCoder){fatalError()}
    override func draw(_ rect:CGRect){
        guard let context=UIGraphicsGetCurrentContext() else{return}
        let body=bounds.insetBy(dx:9,dy:4)
        UIColor(white:0.08,alpha:0.22).setFill();UIBezierPath(roundedRect:body,cornerRadius:10).fill()
        context.saveGState();context.addPath(UIBezierPath(roundedRect:body,cornerRadius:10).cgPath);context.clip()
        for tick in -2...15 {
            let y=CGFloat(tick)*8+phase.truncatingRemainder(dividingBy:8)
            let distance=abs(y-bounds.midY)/max(1,bounds.height/2),alpha=max(0,1-distance)*0.32
            context.setStrokeColor(UIColor.white.withAlphaComponent(alpha).cgColor);context.setLineWidth(1)
            context.move(to:CGPoint(x:body.minX+3,y:y));context.addLine(to:CGPoint(x:body.maxX-3,y:y));context.strokePath()
        }
        context.restoreGState()
        context.setStrokeColor(UIColor.systemMint.withAlphaComponent(isEnabled ? 0.65:0.15).cgColor);context.setLineWidth(2)
        context.move(to:CGPoint(x:body.minX-3,y:bounds.midY));context.addLine(to:CGPoint(x:body.minX+3,y:bounds.midY));context.strokePath()
    }
    override func beginTracking(_ touch:UITouch,with event:UIEvent?)->Bool{guard isEnabled else{return false};previousY=touch.location(in:self).y;return true}
    override func continueTracking(_ touch:UITouch,with event:UIEvent?)->Bool{let y=touch.location(in:self).y,delta=y-previousY;previousY=y;phase+=delta;changed?(Double(delta)*0.00065);setNeedsDisplay();return true}
    override var isEnabled:Bool{didSet{alpha=isEnabled ? 1:0.25}}
    override func accessibilityIncrement(){changed?(0.001)}
    override func accessibilityDecrement(){changed?(-0.001)}
}
