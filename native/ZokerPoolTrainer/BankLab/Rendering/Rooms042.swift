import SceneKit
import UIKit

/// 0.42 (owner acceptance 0.41, items 1–2): ten detailed rooms. Every room carries the embossed "ZOKER POOL" brand
/// and the Z logo on a feature wall, and the suitable rooms hang 4–6 of the owner's photos (Assets ZWall01…15) under
/// picture lights. All static decor is still merged into one node by `selectSpace`, so detail costs draw calls only
/// per material, not per object. Room shell: floor at y = −0.79, side walls x = ±4, end walls z = ±4.7.
extension TableScene {
    static let spaces042=["Club (mặc định)","Trong nhà","Sân vườn","Cung điện","Hoàng gia","Thi đấu quốc tế","Club cổ điển","Phòng VIP Zoker","Sân thượng đêm","Hầm đá"]

    // MARK: brand

    /// Stylised slanted Z (the mark on the owner's championship photos), unit height, centred.
    static func zMarkPath()->UIBezierPath {
        let p=UIBezierPath()
        let pts:[CGPoint]=[CGPoint(x:-0.40,y:0.50),CGPoint(x:0.60,y:0.50),CGPoint(x:0.52,y:0.33),CGPoint(x:-0.10,y:-0.33),CGPoint(x:0.48,y:-0.33),
                           CGPoint(x:0.40,y:-0.50),CGPoint(x:-0.60,y:-0.50),CGPoint(x:-0.52,y:-0.33),CGPoint(x:-0.32,y:-0.33),CGPoint(x:0.30,y:0.33),CGPoint(x:-0.48,y:0.33)]
        p.move(to:pts[0]);for q in pts.dropFirst(){p.addLine(to:q)};p.close();p.flatness=0.002
        return p
    }
    /// The Z logo, extruded, `height` metres tall, facing +z of its parent orientation.
    func zLogo(height:CGFloat,material:SCNMaterial)->SCNNode {
        let shape=SCNShape(path:Self.zMarkPath(),extrusionDepth:0.25);shape.chamferRadius=0.03;shape.chamferMode = .front
        shape.materials=[material]
        let n=SCNNode(geometry:shape);n.scale=SCNVector3(Float(height),Float(height),Float(height))
        return n
    }
    /// Embossed "ZOKER POOL" letters on a dark plate with a Z logo at the left and a warm wash light strip below.
    /// `p` is the plate centre on the wall, `yaw` turns the group to face into the room.
    func brandWall(_ p:SCNVector3,yaw:Float,width:CGFloat=2.6,plate:SCNMaterial?=nil,letters:SCNMaterial?=nil){
        let group=SCNNode();group.position=p;group.eulerAngles.y=yaw;scene.rootNode.addChildNode(group)
        let face=letters ?? premiumMaterial("ChampagneGold")
        let back=plate ?? mat(UIColor(white:0.035,alpha:1),roughness:0.35,metal:0.3)
        let h=width*0.24
        _=box(width,h,0.035,SCNVector3(0,0,0),back,chamfer:0.012,parent:group)
        _=box(width+0.04,0.012,0.045,SCNVector3(0,Float(h/2),0.004),face,chamfer:0.003,parent:group)
        _=box(width+0.04,0.012,0.045,SCNVector3(0,Float(-h/2),0.004),face,chamfer:0.003,parent:group)
        let logo=zLogo(height:h*0.72,material:face);logo.position=SCNVector3(Float(-width/2+h*0.55),0,0.02);group.addChildNode(logo)
        let text=SCNText(string:"ZOKER POOL",extrusionDepth:0.25)
        text.font=UIFont(name:"AvenirNext-HeavyItalic",size:1) ?? UIFont.systemFont(ofSize:1,weight:.black)
        text.flatness=0.02;text.chamferRadius=0.035;text.materials=[face]
        let t=SCNNode(geometry:text);let (lo,hi)=t.boundingBox
        let textWidth=CGFloat(hi.x-lo.x),textHeight=CGFloat(hi.y-lo.y)
        let s=Float(min((width-h*1.35)/max(textWidth,0.01),h*0.62/max(textHeight,0.01)))
        t.scale=SCNVector3(s,s,s*0.25)
        t.pivot=SCNMatrix4MakeTranslation((lo.x+hi.x)/2,(lo.y+hi.y)/2,0)
        t.position=SCNVector3(Float(h*0.35),0,0.02);group.addChildNode(t)
        // wash light strip under the plate (emission only)
        _=box(width*0.9,0.012,0.03,SCNVector3(0,Float(-h/2)-0.03,0.05),emissive(.rgb(0xFFE6B8),.rgb(0xFFD08A)),chamfer:0,parent:group)
    }

    // MARK: photos

    private static var photoCache:[Int:SCNMaterial]=[:]
    func photoMaterial(_ k:Int)->SCNMaterial {
        if let m=Self.photoCache[k]{return m}
        let m=SCNMaterial();m.lightingModel = .physicallyBased
        let image=UIImage(named:String(format:"ZWall%02d",max(1,min(15,k))))
        m.diffuse.contents=image ?? UIColor(white:0.3,alpha:1);m.emission.contents=image;m.emission.intensity=0.32
        m.roughness.contents=0.45;m.metalness.contents=0.0;m.diffuse.mipFilter = .linear;m.diffuse.maxAnisotropy=4
        Self.photoCache[k]=m;return m
    }
    /// One framed photo (the frame is part of the image) with a shadow board behind and a brass picture light above.
    func hangPhoto(_ k:Int,_ p:SCNVector3,yaw:Float,size:CGFloat=0.95,lamp:SCNMaterial?=nil){
        let group=SCNNode();group.position=p;group.eulerAngles.y=yaw;scene.rootNode.addChildNode(group)
        _=box(size+0.03,size+0.03,0.02,SCNVector3(0,-0.01,-0.012),mat(UIColor(white:0.02,alpha:1),roughness:0.9),chamfer:0.004,parent:group)
        let plane=SCNPlane(width:size,height:size);plane.materials=[photoMaterial(k)]
        let n=SCNNode(geometry:plane);n.position=SCNVector3(0,0,0.002);group.addChildNode(n)
        let brass=lamp ?? premiumMaterial("ChampagneGold")
        _=box(0.03,0.03,0.12,SCNVector3(0,Float(size/2)+0.06,0.05),brass,chamfer:0.004,parent:group)
        _=box(size*0.55,0.035,0.05,SCNVector3(0,Float(size/2)+0.08,0.11),brass,chamfer:0.008,parent:group)
        _=box(size*0.5,0.008,0.02,SCNVector3(0,Float(size/2)+0.06,0.12),emissive(.rgb(0xFFEBC4),.rgb(0xFFD99A)),chamfer:0,parent:group)
    }
    /// Photos along a side wall (x = side·3.9x), centred, facing into the room.
    func sideGallery(_ photos:[Int],side:Float,y:Float=0.95,size:CGFloat=0.95,from z0:Float = -3.0,to z1:Float=3.0,lamp:SCNMaterial?=nil){
        guard !photos.isEmpty else {return}
        for (i,k) in photos.enumerated(){
            let t=photos.count==1 ? 0.5:Float(i)/Float(photos.count-1)
            hangPhoto(k,SCNVector3(side*3.93,y,z0+(z1-z0)*t),yaw:side>0 ? -Float.pi/2:Float.pi/2,size:size,lamp:lamp)
        }
    }
    /// Photos along an end wall (z = side·4.6x).
    func endGallery(_ photos:[Int],side:Float,y:Float=0.95,size:CGFloat=0.95,from x0:Float = -2.4,to x1:Float=2.4,lamp:SCNMaterial?=nil){
        for (i,k) in photos.enumerated(){
            let t=photos.count==1 ? 0.5:Float(i)/Float(photos.count-1)
            hangPhoto(k,SCNVector3(x0+(x1-x0)*t,y,side*4.63),yaw:side>0 ? Float.pi:0,size:size,lamp:lamp)
        }
    }

    // MARK: shared props

    func plant(_ p:SCNVector3,scale:Float=1){
        let pot=mat(.rgb(0x2A2622),roughness:0.6),leaf=mat(.rgb(0x2E5A2A),roughness:0.85),leaf2=mat(.rgb(0x3F7434),roughness:0.85)
        let base=SCNNode(geometry:SCNCylinder(radius:CGFloat(0.2*scale),height:CGFloat(0.45*scale)));base.geometry?.materials=[pot]
        base.position=SCNVector3(p.x,-0.79+0.225*scale,p.z);scene.rootNode.addChildNode(base)
        for k in 0..<7 {let a=Float(k)*0.9
            let blob=SCNNode(geometry:SCNSphere(radius:CGFloat((0.16+Float(k%3)*0.04)*scale)));blob.geometry?.materials=[k%2==0 ? leaf:leaf2]
            blob.position=SCNVector3(p.x+cos(a)*0.14*scale,-0.79+(0.62+Float(k%4)*0.14)*scale,p.z+sin(a)*0.14*scale);scene.rootNode.addChildNode(blob)}
    }
    func sofa(_ p:SCNVector3,yaw:Float,width:CGFloat=2.0,material:SCNMaterial){
        let g=SCNNode();g.position=p;g.eulerAngles.y=yaw;scene.rootNode.addChildNode(g)
        _=box(width,0.42,0.85,SCNVector3(0,-0.58,0),material,chamfer:0.07,parent:g)
        _=box(width,0.5,0.2,SCNVector3(0,-0.24,-0.34),material,chamfer:0.07,parent:g)
        for s:Float in [-1,1]{_=box(0.2,0.55,0.85,SCNVector3(s*Float(width/2-0.1),-0.45,0),material,chamfer:0.07,parent:g)}
        let cushion=mat(.rgb(0xC9A86A),roughness:0.8)
        for s:Float in [-0.45,0.45]{_=box(0.38,0.32,0.1,SCNVector3(s*Float(width/2),-0.22,-0.22),cushion,chamfer:0.05,parent:g)}
    }
    func trophyCabinet(_ p:SCNVector3,yaw:Float){
        let g=SCNNode();g.position=p;g.eulerAngles.y=yaw;scene.rootNode.addChildNode(g)
        let wood=premiumMaterial("WalnutDark"),gold=premiumMaterial("ChampagneGold")
        let glass=mat(UIColor(white:0.8,alpha:0.18),roughness:0.05);glass.transparency=0.18
        _=box(1.4,2.1,0.42,SCNVector3(0,0.26,0),wood,chamfer:0.02,parent:g)
        _=box(1.28,1.9,0.02,SCNVector3(0,0.3,0.2),glass,chamfer:0,parent:g)
        for (row,y) in [Float(-0.25),0.3,0.85].enumerated(){
            _=box(1.28,0.02,0.36,SCNVector3(0,y,0.02),glass,chamfer:0,parent:g)
            _=box(1.28,0.01,0.02,SCNVector3(0,y+0.02,0.17),emissive(.rgb(0xFFF1D6),.rgb(0xFFE2A8)),chamfer:0,parent:g)
            for k in 0..<3 {let x=Float(k-1)*0.38
                let cup=SCNNode(geometry:SCNCone(topRadius:0.07,bottomRadius:0.03,height:0.16));cup.geometry?.materials=[gold];cup.position=SCNVector3(x,y+0.17,0);g.addChildNode(cup)
                let stem=SCNNode(geometry:SCNCylinder(radius:0.012,height:0.08));stem.geometry?.materials=[gold];stem.position=SCNVector3(x,y+0.06,0);g.addChildNode(stem)
                let foot=SCNNode(geometry:SCNCylinder(radius:0.045,height:0.025));foot.geometry?.materials=[row==1 && k==1 ? gold:wood];foot.position=SCNVector3(x,y+0.02,0);g.addChildNode(foot)}
        }
    }
    func cueRack(_ p:SCNVector3,yaw:Float,count:Int=8){
        let g=SCNNode();g.position=p;g.eulerAngles.y=yaw;scene.rootNode.addChildNode(g)
        let walnut=premiumMaterial("WalnutDark"),maple=mat(.rgb(0xD9B98A),roughness:0.35),ebony=mat(.rgb(0x15100C),roughness:0.3),ferrule=mat(.rgb(0xF2EEE6),roughness:0.25)
        let w=CGFloat(count)*0.12+0.2
        _=box(w,1.5,0.04,SCNVector3(0,0.55,0),walnut,chamfer:0.01,parent:g)
        _=box(w-0.1,0.05,0.12,SCNVector3(0,-0.12,0.05),walnut,chamfer:0.01,parent:g);_=box(w-0.1,0.05,0.10,SCNVector3(0,1.15,0.04),walnut,chamfer:0.01,parent:g)
        for k in 0..<count {let x=Float(k)*0.12-Float(count-1)*0.06
            let shaft=SCNNode(geometry:SCNCylinder(radius:0.0065,height:1.3));shaft.geometry?.materials=[k%3==0 ? ebony:maple];shaft.position=SCNVector3(x,0.53,0.07);g.addChildNode(shaft)
            let butt=SCNNode(geometry:SCNCylinder(radius:0.0145,height:0.42));butt.geometry?.materials=[k%2==0 ? ebony:walnut];butt.position=SCNVector3(x,0.05,0.07);g.addChildNode(butt)
            let tip=SCNNode(geometry:SCNCylinder(radius:0.0065,height:0.025));tip.geometry?.materials=[ferrule];tip.position=SCNVector3(x,1.19,0.07);g.addChildNode(tip)}
    }
    func downlights(_ xs:[Float],_ zs:[Float],y:Float,warm:Bool=true){
        let m=emissive(UIColor(white:0.9,alpha:1),warm ? UIColor(red:1,green:0.93,blue:0.82,alpha:1):UIColor(white:1,alpha:1))
        for x in xs {for z in zs {let d=SCNNode(geometry:SCNCylinder(radius:0.07,height:0.01));d.geometry?.materials=[m];d.position=SCNVector3(x,y,z);scene.rootNode.addChildNode(d)}}
    }
    func wainscot(height:Float,material:SCNMaterial,trim:SCNMaterial){
        for side:Float in [-1,1]{
            _=box(0.03,CGFloat(height),9.3,SCNVector3(side*3.94,-0.79+height/2,0),material,chamfer:0.004)
            _=box(7.9,CGFloat(height),0.03,SCNVector3(0,-0.79+height/2,side*4.64),material,chamfer:0.004)
            _=box(0.05,0.035,9.3,SCNVector3(side*3.93,-0.79+height,0),trim,chamfer:0.004)
            _=box(7.9,0.035,0.05,SCNVector3(0,-0.79+height,side*4.63),trim,chamfer:0.004)
        }
    }

    // MARK: rooms (1–9; 0 is buildClub, upgraded in place)

    /// Home: oak floor with a rug, cream walls with white wainscot, family photos, sofa set, bookshelf, window light.
    func buildHome042(){
        tableFixture()
        scene.background.contents=UIColor(red:0.05,green:0.045,blue:0.04,alpha:1)
        scene.fogStartDistance=6;scene.fogEndDistance=16;scene.fogColor=UIColor(red:0.06,green:0.05,blue:0.045,alpha:1)
        let floor=mat(.white,roughness:0.55);floor.diffuse.contents=woodTexture(light:true)
        floor.diffuse.wrapS = .repeat;floor.diffuse.wrapT = .repeat;floor.diffuse.contentsTransform=SCNMatrix4MakeScale(5,6,1)
        shell(floor:floor,wall:mat(.rgb(0xD9CFBF),roughness:0.9),height:2.9)
        _=box(8,0.04,9.4,SCNVector3(0,2.08,0),mat(UIColor(white:0.92,alpha:1)),chamfer:0)
        wainscot(height:0.9,material:mat(.rgb(0xF1ECE2),roughness:0.6),trim:mat(.rgb(0xFFFFFF),roughness:0.4))
        _=box(3.2,0.012,4.4,SCNVector3(0,-0.745,0),mat(.rgb(0x6B4F3A),roughness:0.98),chamfer:0)   // rug
        let fabric=mat(.rgb(0x5A4A3C),roughness:0.95)
        sofa(SCNVector3(0,0,3.85),yaw:Float.pi,width:2.4,material:fabric)
        sofa(SCNVector3(-3.35,0,2.6),yaw:Float.pi/2,width:1.6,material:fabric)
        _=box(1.1,0.4,0.6,SCNVector3(0,-0.59,3.0),premiumMaterial("WalnutDark"),chamfer:0.02)   // coffee table
        // bookshelf on the front wall
        let oak=mat(.rgb(0x8A6A48),roughness:0.6)
        _=box(2.0,2.0,0.35,SCNVector3(-2.4,0.21,-4.45),oak,chamfer:0.01)
        for (r,y) in [Float(-0.45),-0.05,0.35,0.75].enumerated(){
            for k in 0..<12 {let tone=[UIColor.rgb(0x7A2E22),.rgb(0x2E4A6A),.rgb(0xC9A86A),.rgb(0x3D5A3A),.rgb(0xE8E0D0)][(k+r)%5]
                _=box(0.07,CGFloat(0.26+Float((k*7+r)%4)*0.03),0.24,SCNVector3(-3.25+Float(k)*0.15,y+0.15,-4.42),mat(tone,roughness:0.8),chamfer:0.004)}}
        // window with daylight on the right wall
        _=box(0.04,1.5,2.4,SCNVector3(3.95,0.75,-1.2),emissive(UIColor(red:0.75,green:0.85,blue:0.95,alpha:1),UIColor(red:0.6,green:0.7,blue:0.82,alpha:1)),chamfer:0)
        for z:Float in [-2.4,-1.2,0]{_=box(0.06,1.56,0.05,SCNVector3(3.92,0.75,z),mat(.white,roughness:0.4),chamfer:0.004)}
        plant(SCNVector3(3.4,0,-3.9));plant(SCNVector3(-3.4,0,3.9),scale:0.8)
        sideGallery([6,11,3,12],side:-1,y:1.25,size:0.8,from:-3.3,to:0.9)
        brandWall(SCNVector3(1.3,1.35,-4.62),yaw:0,width:2.2,plate:mat(.rgb(0x2B2420),roughness:0.4))
        roomLamp(SCNVector3(3.4,1.2,-1.2),45,6500,end:5);roomLamp(SCNVector3(-2.5,1.8,2.5),20,3000,end:4)
    }
    /// Garden terrace: stone deck, pergola wall with photos under string lights, lawn, hedges and sky.
    func buildGarden042(){
        scene.background.contents=UIColor(red:0.42,green:0.62,blue:0.86,alpha:1)
        scene.fogStartDistance=12;scene.fogEndDistance=40;scene.fogColor=UIColor(red:0.62,green:0.74,blue:0.88,alpha:1)
        let deck=mat(.white,roughness:0.7);deck.diffuse.contents=woodTexture(light:true)
        deck.diffuse.wrapS = .repeat;deck.diffuse.wrapT = .repeat;deck.diffuse.contentsTransform=SCNMatrix4MakeScale(6,8,1)
        _=box(9,0.08,10,SCNVector3(0,-0.79,0),deck,chamfer:0)
        _=box(60,0.02,60,SCNVector3(0,-0.9,0),mat(.rgb(0x4F7A3A),roughness:1),chamfer:0)
        let hedge=mat(.rgb(0x2F5A2A),roughness:0.95)
        for side:Float in [-1,1]{_=box(0.6,0.9,10,SCNVector3(side*5.0,-0.4,0),hedge,chamfer:0.15);_=box(10.6,0.9,0.6,SCNVector3(0,-0.4,side*5.6),hedge,chamfer:0.15)}
        // pergola behind the far end with a stone feature wall carrying the brand and photos
        let stone=mat(.rgb(0xB8AE9C),roughness:0.85),beam=mat(.rgb(0x6B4A2E),roughness:0.7)
        _=box(7.6,2.6,0.25,SCNVector3(0,0.5,-4.75),stone,chamfer:0.02)
        for x:Float in [-3.6,-1.2,1.2,3.6]{_=box(0.16,3.0,0.16,SCNVector3(x,0.7,-3.6),beam,chamfer:0.01)}
        _=box(7.6,0.14,0.18,SCNVector3(0,2.2,-3.6),beam,chamfer:0.01)
        for z:Float in stride(from:-4.6,through:-3.6,by:0.25){_=box(7.4,0.06,0.08,SCNVector3(0,2.3,z),beam,chamfer:0.005)}
        let bulb=emissive(.rgb(0xFFF0C8),.rgb(0xFFD27A))
        for k in 0..<22 {let x = -3.5+Float(k)*0.333;let sag=0.12*sin(Float(k%11)/10*Float.pi)
            let n=SCNNode(geometry:SCNSphere(radius:0.025));n.geometry?.materials=[bulb];n.position=SCNVector3(x,2.1-sag,-3.55);scene.rootNode.addChildNode(n)}
        endGallery([2,9,15,5],side:-1,y:0.55,size:0.85,from:-3.0,to:3.0)
        brandWall(SCNVector3(0,1.55,-4.6),yaw:0,width:2.6)
        for x:Float in [-3.8,3.8]{plant(SCNVector3(x,0,3.8),scale:1.3);plant(SCNVector3(x,0,-2.8),scale:1.1)}
        tableFixture()
        let sun=SCNNode();sun.light=SCNLight();sun.light?.type = .directional;sun.light?.intensity=170;sun.light?.temperature=5600
        sun.eulerAngles=SCNVector3(-1.0,0.6,0);scene.rootNode.addChildNode(sun)
    }
    /// Palace: marble floor with inlay, columns, gold cornice, chandeliers, grand photo gallery.
    func buildPalace042(){
        tableFixture()
        scene.background.contents=UIColor(red:0.08,green:0.07,blue:0.06,alpha:1)
        scene.fogStartDistance=7;scene.fogEndDistance=20;scene.fogColor=UIColor(red:0.09,green:0.08,blue:0.07,alpha:1)
        let marble=mat(UIColor(white:0.62,alpha:1),roughness:0.22);marble.normal.contents=normalImage;marble.normal.intensity=0.05
        shell(floor:marble,wall:mat(.rgb(0x9A8C74),roughness:0.7),height:4.5)
        let gold=premiumMaterial("ChampagneGold")
        _=box(3.4,0.006,5.0,SCNVector3(0,-0.748,0),mat(.rgb(0x3A2E26),roughness:0.25),chamfer:0)    // dark inlay
        _=box(3.6,0.005,5.2,SCNVector3(0,-0.749,0),gold,chamfer:0)
        for side:Float in [-1,1]{
            for z:Float in [-3.9,-1.3,1.3,3.9]{let c=SCNCylinder(radius:0.18,height:4.4);c.radialSegmentCount=48;c.materials=[mat(UIColor(white:0.72,alpha:1),roughness:0.3)]
                let n=SCNNode(geometry:c);n.position=SCNVector3(side*3.6,1.4,z);scene.rootNode.addChildNode(n)
                _=box(0.5,0.14,0.5,SCNVector3(side*3.6,3.55,z),gold,chamfer:0.02);_=box(0.5,0.14,0.5,SCNVector3(side*3.6,-0.7,z),gold,chamfer:0.02)}
            _=box(8,0.1,0.08,SCNVector3(0,3.2,side*4.62),gold,chamfer:0.01);_=box(0.08,0.1,9.3,SCNVector3(side*3.94,3.2,0),gold,chamfer:0.01)
        }
        sideGallery([3,12,14],side:-1,y:1.3,size:1.0,from:-2.6,to:2.6,lamp:gold)
        sideGallery([13,2,6],side:1,y:1.3,size:1.0,from:-2.6,to:2.6,lamp:gold)
        brandWall(SCNVector3(0,2.2,-4.6),yaw:0,width:3.0,plate:mat(.rgb(0x1A1410),roughness:0.3,metal:0.2))
        for z:Float in [-2.2,2.2]{
            let crystal=emissive(UIColor(white:1,alpha:1),.rgb(0xFFF2D0))
            for ring in 0..<2 {let r:Float = ring==0 ? 0.35:0.22,y:Float = ring==0 ? 2.9:2.75
                for k in 0..<12 {let a=Float(k)/12*Float.pi*2;let n=SCNNode(geometry:SCNSphere(radius:0.035));n.geometry?.materials=[crystal];n.position=SCNVector3(cos(a)*r,y,z+sin(a)*r);scene.rootNode.addChildNode(n)}}
            _=box(0.8,0.04,0.8,SCNVector3(0,3.05,z),gold,chamfer:0.02);roomLamp(SCNVector3(0,2.9,z),20,3400,end:6)
        }
    }
    /// Royal: red carpet, carved walnut panels, gold trims, crest with Z, sconces, portrait gallery.
    func buildRoyal042(){
        tableFixture()
        scene.background.contents=UIColor(red:0.03,green:0.015,blue:0.012,alpha:1)
        scene.fogStartDistance=5;scene.fogEndDistance=15;scene.fogColor=UIColor(red:0.04,green:0.02,blue:0.018,alpha:1)
        let carpet=mat(.rgb(0x5A0F14),roughness:0.97),panel=premiumMaterial("WalnutDark"),gold=premiumMaterial("ChampagneGold")
        shell(floor:carpet,wall:panel,height:3.8)
        for side:Float in [-1,1]{
            for x:Float in [-3,-1.5,0,1.5,3]{_=box(1.2,1.0,0.03,SCNVector3(x,-0.2,side*4.62),panel,chamfer:0.02);_=box(1.24,0.03,0.04,SCNVector3(x,0.32,side*4.6),gold,chamfer:0.003);_=box(1.24,0.03,0.04,SCNVector3(x,-0.72,side*4.6),gold,chamfer:0.003)}
            for z:Float in [-3.6,0,3.6]{_=box(0.04,0.4,0.2,SCNVector3(side*3.93,1.75,z),gold,chamfer:0.01);roomLamp(SCNVector3(side*3.7,1.8,z),12,2600,end:3)}
            _=box(0.06,0.06,9.3,SCNVector3(side*3.92,2.9,0),gold,chamfer:0.01)
        }
        sideGallery([12,3,13],side:-1,y:1.0,size:0.95,from:-2.4,to:2.4,lamp:gold)
        sideGallery([1,7],side:1,y:1.0,size:0.95,from:-1.6,to:1.6,lamp:gold)
        let crest=SCNNode(geometry:SCNCylinder(radius:0.45,height:0.03));crest.geometry?.materials=[gold];crest.eulerAngles.x = .pi/2;crest.position=SCNVector3(0,2.4,4.6);scene.rootNode.addChildNode(crest)
        let z=zLogo(height:0.5,material:mat(.rgb(0x5A0F14),roughness:0.4));z.position=SCNVector3(0,2.4,4.55);z.eulerAngles.y = .pi;scene.rootNode.addChildNode(z)
        brandWall(SCNVector3(0,1.3,-4.6),yaw:0,width:2.8)
        _=box(2.4,0.02,5.6,SCNVector3(0,-0.745,0),mat(.rgb(0x7A1A1F),roughness:0.95),chamfer:0)
        _=box(2.5,0.019,5.7,SCNVector3(0,-0.746,0),gold,chamfer:0)
    }
    /// International arena: dark venue, tiered seats with spectators, LED rails, giant screens showing the photos.
    func buildArena042(){
        tableFixture()
        scene.background.contents=UIColor(red:0.005,green:0.006,blue:0.01,alpha:1)
        scene.fogStartDistance=6;scene.fogEndDistance=22;scene.fogColor=UIColor(red:0.006,green:0.008,blue:0.016,alpha:1)
        _=box(14,0.08,16,SCNVector3(0,-0.79,0),mat(.rgb(0x15233A),roughness:0.8),chamfer:0)
        _=box(5.2,0.01,7.0,SCNVector3(0,-0.745,0),mat(.rgb(0x0F1A2E),roughness:0.6),chamfer:0)
        let seat=mat(.rgb(0x1A1D24),roughness:0.9),crowd=[mat(.rgb(0x2B3448),roughness:0.9),mat(.rgb(0x3A2A2A),roughness:0.9),mat(.rgb(0x46484E),roughness:0.9)]
        for tier in 0..<5 {let t=Float(tier)
            for side:Float in [-1,1]{
                _=box(0.9,0.35,12,SCNVector3(side*(4.2+t*0.9),-0.6+t*0.35,0),seat,chamfer:0.01);_=box(10,0.35,0.9,SCNVector3(0,-0.6+t*0.35,side*(5.4+t*0.9)),seat,chamfer:0.01)
                for k in 0..<14 where (k+tier)%3 != 0 {   // spectators as simple heads + torsos (merged, cheap)
                    let z = -5.2+Float(k)*0.8;let m=crowd[(k+tier)%3]
                    _=box(0.32,0.42,0.3,SCNVector3(side*(4.2+t*0.9),-0.2+t*0.35,z),m,chamfer:0.06)
                    let head=SCNNode(geometry:SCNSphere(radius:0.1));head.geometry?.materials=[mat(.rgb(0xC69C7A),roughness:0.8)];head.position=SCNVector3(side*(4.2+t*0.9),0.12+t*0.35,z);scene.rootNode.addChildNode(head)}
            }}
        let led=emissive(.rgb(0x0B1F3A),.rgb(0x1D6FD6)),ledGold=emissive(.rgb(0x2A1E08),.rgb(0xE0A93A))
        for side:Float in [-1,1]{_=box(0.05,0.35,6,SCNVector3(side*3.3,-0.55,0),side<0 ? led:ledGold,chamfer:0);_=box(5,0.35,0.05,SCNVector3(0,-0.55,side*4.3),led,chamfer:0)}
        // giant screens with the photos, brand above the far screen
        for (i,k) in [15,14,2].enumerated(){let x=Float(i-1)*3.4
            _=box(3.2,3.2,0.08,SCNVector3(x,3.0,-7.2),mat(UIColor(white:0.02,alpha:1),roughness:0.3),chamfer:0.02)
            hangPhoto(k,SCNVector3(x,3.0,-7.15),yaw:0,size:3.0,lamp:mat(UIColor(white:0.02,alpha:1)))}
        for (i,k) in [12,9,5].enumerated(){let x=Float(i-1)*3.4
            hangPhoto(k,SCNVector3(x,3.0,7.15),yaw:Float.pi,size:3.0,lamp:mat(UIColor(white:0.02,alpha:1)))}
        brandWall(SCNVector3(0,5.1,-7.1),yaw:0,width:5.0)
        let spot=SCNNode();spot.light=SCNLight();spot.light?.type = .spot;spot.light?.intensity=320;spot.light?.temperature=5000
        spot.light?.spotInnerAngle=30;spot.light?.spotOuterAngle=55;spot.position=SCNVector3(0,4.2,0);spot.eulerAngles.x = -.pi/2;scene.rootNode.addChildNode(spot)
        // lighting truss over the table
        let truss=mat(UIColor(white:0.12,alpha:1),roughness:0.4,metal:0.8)
        for x:Float in [-1.4,1.4]{_=box(0.08,0.08,4.5,SCNVector3(x,3.6,0),truss,chamfer:0.005)}
        for z:Float in [-2.2,2.2]{_=box(2.9,0.08,0.08,SCNVector3(0,3.6,z),truss,chamfer:0.005)}
    }
    /// Classic club (old room 6), now with gallery, cue rack and the brand.
    func buildClassic042(){
        buildRoomBase()
        sideGallery([1,4,8],side:-1,y:1.15,size:0.85,from:-2.6,to:2.6)
        sideGallery([10,7],side:1,y:1.15,size:0.85,from:-1.6,to:1.6)
        cueRack(SCNVector3(2.4,0,-4.55),yaw:0)
        brandWall(SCNVector3(-0.6,1.5,-4.55),yaw:0,width:2.4)
        downlights([-2.8,2.8],[-3.2,0,3.2],y:2.6)
    }
    /// VIP Zoker lounge: black marble floor with gold inlay, leather walls, trophy cabinets, sofas, champagne bar.
    func buildVIP042(){
        tableFixture()
        scene.background.contents=UIColor(red:0.01,green:0.01,blue:0.012,alpha:1)
        scene.fogStartDistance=5;scene.fogEndDistance=15;scene.fogColor=UIColor(red:0.012,green:0.012,blue:0.014,alpha:1)
        let marble=mat(UIColor(white:0.06,alpha:1),roughness:0.12);marble.normal.contents=normalImage;marble.normal.intensity=0.04
        let leather=mat(.rgb(0x15110E),roughness:0.55);leather.normal.contents=normalImage;leather.normal.intensity=0.25
        shell(floor:marble,wall:leather,height:3.3)
        let gold=premiumMaterial("ChampagneGold")
        _=box(8,0.04,9.4,SCNVector3(0,2.5,0),mat(UIColor(white:0.04,alpha:1),roughness:0.4),chamfer:0)
        _=box(3.0,0.004,0.02,SCNVector3(0,-0.748,-2.6),gold,chamfer:0);_=box(3.0,0.004,0.02,SCNVector3(0,-0.748,2.6),gold,chamfer:0)
        _=box(0.02,0.004,5.2,SCNVector3(-1.5,-0.748,0),gold,chamfer:0);_=box(0.02,0.004,5.2,SCNVector3(1.5,-0.748,0),gold,chamfer:0)
        for side:Float in [-1,1]{   // vertical gold fins + cove light
            for z:Float in stride(from:-4.2,through:4.2,by:1.4){_=box(0.03,2.9,0.03,SCNVector3(side*3.93,0.66,z),gold,chamfer:0.004)}
            _=box(0.04,0.02,9.0,SCNVector3(side*3.9,2.42,0),emissive(.rgb(0xFFD68A),.rgb(0xE0A23A)),chamfer:0)
        }
        trophyCabinet(SCNVector3(-2.6,0,-4.35),yaw:0);trophyCabinet(SCNVector3(2.6,0,-4.35),yaw:0)
        brandWall(SCNVector3(0,1.55,-4.6),yaw:0,width:2.6)
        sideGallery([12,13,14],side:-1,y:1.2,size:0.95,from:-2.8,to:2.2,lamp:gold)
        sideGallery([3,7,10],side:1,y:1.2,size:0.95,from:-2.8,to:2.2,lamp:gold)
        let cream=mat(.rgb(0xE9DFCB),roughness:0.6)
        sofa(SCNVector3(-1.2,0,3.9),yaw:Float.pi,width:2.0,material:cream);sofa(SCNVector3(1.2,0,3.9),yaw:Float.pi,width:2.0,material:cream)
        _=box(1.2,0.36,0.6,SCNVector3(0,-0.61,3.0),mat(UIColor(white:0.05,alpha:1),roughness:0.15),chamfer:0.02)
        let bucket=SCNNode(geometry:SCNCylinder(radius:0.1,height:0.2));bucket.geometry?.materials=[gold];bucket.position=SCNVector3(0.3,-0.33,3.0);scene.rootNode.addChildNode(bucket)
        let bottle=SCNNode(geometry:SCNCylinder(radius:0.035,height:0.32));bottle.geometry?.materials=[mat(.rgb(0x10301A),roughness:0.1)];bottle.position=SCNVector3(0.3,-0.17,3.0);scene.rootNode.addChildNode(bottle)
        plant(SCNVector3(3.5,0,4.1));plant(SCNVector3(-3.5,0,4.1))
        downlights([-2.8,0,2.8],[-3.3,-1.1,1.1,3.3],y:2.47)
        roomLamp(SCNVector3(-2.6,1.2,-3.8),10,3000,end:2.5);roomLamp(SCNVector3(2.6,1.2,-3.8),10,3000,end:2.5)
    }
    /// Rooftop at night: deck, glass balustrade, city skyline with lit windows, string lights, lit feature wall.
    func buildRooftop042(){
        scene.background.contents=UIColor(red:0.02,green:0.03,blue:0.07,alpha:1)
        scene.fogStartDistance=8;scene.fogEndDistance=45;scene.fogColor=UIColor(red:0.03,green:0.04,blue:0.09,alpha:1)
        let deck=mat(.white,roughness:0.65);deck.diffuse.contents=woodTexture(light:false)
        deck.diffuse.wrapS = .repeat;deck.diffuse.wrapT = .repeat;deck.diffuse.contentsTransform=SCNMatrix4MakeScale(6,8,1);deck.multiply.contents=UIColor(white:0.5,alpha:1)
        _=box(9,0.08,10,SCNVector3(0,-0.79,0),deck,chamfer:0)
        let glass=mat(UIColor(white:0.9,alpha:0.2),roughness:0.05);glass.transparency=0.2
        for side:Float in [-1,1]{_=box(0.03,1.0,10,SCNVector3(side*4.4,-0.25,0),glass,chamfer:0);_=box(8.8,1.0,0.03,SCNVector3(0,-0.25,5.0),glass,chamfer:0)}
        // skyline: towers with emissive window grids (procedural texture, one material per tone)
        let windows=skylineTexture()
        for k in 0..<26 {let a=Float(k)/26*Float.pi*2;let r:Float=22+Float((k*7)%5)*3
            let h=CGFloat(8+(k*13)%14),w=CGFloat(2.5+Float(k%3))
            let m=SCNMaterial();m.lightingModel = .constant;m.diffuse.contents=windows;m.diffuse.wrapS = .repeat;m.diffuse.wrapT = .repeat
            m.diffuse.contentsTransform=SCNMatrix4MakeScale(Float(w),Float(h)/2,1)
            let n=SCNNode(geometry:SCNBox(width:w,height:h,length:w,chamferRadius:0));n.geometry?.materials=[m]
            n.position=SCNVector3(cos(a)*r,Float(h)/2-3,sin(a)*r);scene.rootNode.addChildNode(n)}
        // feature wall with brand and photos at the far end
        let wall=mat(.rgb(0x1B1F28),roughness:0.6)
        _=box(7.6,3.0,0.25,SCNVector3(0,0.7,-4.75),wall,chamfer:0.02)
        endGallery([2,15,9,5],side:-1,y:0.45,size:0.8,from:-2.9,to:2.9)
        brandWall(SCNVector3(0,1.6,-4.6),yaw:0,width:2.8)
        let bulb=emissive(.rgb(0xFFF0C8),.rgb(0xFFC66A))
        for line in 0..<3 {let z = -3+Float(line)*3
            for k in 0..<24 {let x = -3.9+Float(k)*0.34;let sag=0.25*sin(Float(k)/23*Float.pi)
                let n=SCNNode(geometry:SCNSphere(radius:0.022));n.geometry?.materials=[bulb];n.position=SCNVector3(x,2.6-sag,z);scene.rootNode.addChildNode(n)}}
        for x:Float in [-3.9,3.9]{for z:Float in [-3,0,3]{_=box(0.06,3.4,0.06,SCNVector3(x,0.9,z),mat(UIColor(white:0.1,alpha:1),roughness:0.5,metal:0.6),chamfer:0.004)}}
        plant(SCNVector3(-3.6,0,4.3),scale:1.2);plant(SCNVector3(3.6,0,4.3),scale:1.2)
        tableFixture()
        roomLamp(SCNVector3(0,2.2,0),20,3200,end:6)
        let moon=SCNNode();moon.light=SCNLight();moon.light?.type = .directional;moon.light?.intensity=40;moon.light?.temperature=8000
        moon.eulerAngles=SCNVector3(-0.9,-0.5,0);scene.rootNode.addChildNode(moon)
    }
    /// Stone cellar: vaulted stone walls, barrels, wrought-iron lanterns, rustic photos.
    func buildCellar042(){
        tableFixture()
        scene.background.contents=UIColor(red:0.02,green:0.015,blue:0.01,alpha:1)
        scene.fogStartDistance=4;scene.fogEndDistance=13;scene.fogColor=UIColor(red:0.03,green:0.022,blue:0.015,alpha:1)
        let stone=mat(.white,roughness:0.95);stone.diffuse.contents=stoneTexture()
        stone.diffuse.wrapS = .repeat;stone.diffuse.wrapT = .repeat;stone.diffuse.contentsTransform=SCNMatrix4MakeScale(6,3,1)
        let flag=mat(.white,roughness:0.9);flag.diffuse.contents=stoneTexture();flag.diffuse.wrapS = .repeat;flag.diffuse.wrapT = .repeat
        flag.diffuse.contentsTransform=SCNMatrix4MakeScale(5,6,1);flag.multiply.contents=UIColor(white:0.55,alpha:1)
        shell(floor:flag,wall:stone,height:3.2)
        let oak=mat(.rgb(0x4A3220),roughness:0.8),iron=mat(UIColor(white:0.08,alpha:1),roughness:0.5,metal:0.7)
        for z:Float in stride(from:-4.0,through:4.0,by:2.0){_=box(8,0.18,0.22,SCNVector3(0,2.3,z),oak,chamfer:0.01)}   // ceiling beams
        for side:Float in [-1,1]{for k in 0..<4 {let z=Float(k)*0.75-1.1   // barrel racks along the near-right / far-left walls
            let barrel=SCNNode(geometry:SCNCylinder(radius:0.32,height:0.8));barrel.geometry?.materials=[oak];barrel.eulerAngles.z = .pi/2
            barrel.position=SCNVector3(side*3.45,-0.45,side*(z+2.6));scene.rootNode.addChildNode(barrel)
            for dx:Float in [-0.3,0.3]{let hoop=SCNNode(geometry:SCNTorus(ringRadius:0.325,pipeRadius:0.012));hoop.geometry?.materials=[iron];hoop.eulerAngles.z = .pi/2
                hoop.position=SCNVector3(side*3.45+dx,-0.45,side*(z+2.6));scene.rootNode.addChildNode(hoop)}}}
        sideGallery([1,8],side:-1,y:1.1,size:0.85,from:-3.2,to:-0.8,lamp:iron)
        sideGallery([10,11],side:1,y:1.1,size:0.85,from:0.8,to:3.2,lamp:iron)
        brandWall(SCNVector3(0,1.4,-4.6),yaw:0,width:2.6,plate:oak,letters:premiumMaterial("ChampagneGold"))
        let flame=emissive(.rgb(0xFFB04A),.rgb(0xFF9A2A))
        for side:Float in [-1,1]{for z:Float in [-3.2,0,3.2]{
            _=box(0.12,0.22,0.12,SCNVector3(side*3.85,1.6,z),iron,chamfer:0.01)
            _=box(0.06,0.12,0.06,SCNVector3(side*3.85,1.6,z),flame,chamfer:0.005)
            roomLamp(SCNVector3(side*3.6,1.6,z),9,2200,end:2.6)}}
    }
    /// Night-city window texture for the rooftop skyline.
    func skylineTexture()->UIImage{
        let format=UIGraphicsImageRendererFormat();format.scale=1
        return UIGraphicsImageRenderer(size:CGSize(width:64,height:64),format:format).image{ctx in
            UIColor(red:0.03,green:0.04,blue:0.07,alpha:1).setFill();ctx.fill(CGRect(x:0,y:0,width:64,height:64))
            var seed:UInt32=11;func r()->CGFloat{seed=seed &* 1664525 &+ 1013904223;return CGFloat(seed>>8)/CGFloat(1<<24)}
            for y in stride(from:4,to:64,by:8){for x in stride(from:4,to:64,by:8) where r()>0.45 {
                UIColor(red:1,green:0.78+r()*0.2,blue:0.45+r()*0.3,alpha:0.55+r()*0.45).setFill();ctx.fill(CGRect(x:x,y:y,width:4,height:5))}}
        }
    }
    /// Rough limestone blocks.
    func stoneTexture()->UIImage{
        let format=UIGraphicsImageRendererFormat();format.scale=1
        return UIGraphicsImageRenderer(size:CGSize(width:128,height:128),format:format).image{ctx in
            UIColor(red:0.42,green:0.37,blue:0.31,alpha:1).setFill();ctx.fill(CGRect(x:0,y:0,width:128,height:128))
            var seed:UInt32=5;func r()->CGFloat{seed=seed &* 1664525 &+ 1013904223;return CGFloat(seed>>8)/CGFloat(1<<24)}
            for row in 0..<4 {let y=CGFloat(row)*32;let off:CGFloat = row%2==0 ? 0:24
                for k in -1..<3 {let x=off+CGFloat(k)*48
                    UIColor(white:0.30+r()*0.25,alpha:0.35).setFill();ctx.fill(CGRect(x:x+2,y:y+2,width:44,height:28))}
                UIColor(white:0.12,alpha:0.6).setFill();ctx.fill(CGRect(x:0,y:y,width:128,height:2))}
            for _ in 0..<2500 {UIColor(white:r()*0.6,alpha:0.08).setFill();ctx.fill(CGRect(x:r()*128,y:r()*128,width:1,height:1))}
        }
    }
}
