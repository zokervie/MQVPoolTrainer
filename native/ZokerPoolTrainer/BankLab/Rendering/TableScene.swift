import UIKit
import SceneKit
import simd

// Metres throughout. Physics rail endpoints are the visible cushion nose.
final class TableScene {
    private struct MeshData:Decodable {
        let vertices:[Float]
        let normals:[Float]
        let uv:[Float]
        let indices:[Int32]
    }
    private struct KitCueMesh:Decodable {
        let vertices:[Float],normals:[Float],uv:[Float]
        let elements:[[Int32]]
        let names:[String]
    }
    private struct KitSights:Decodable {struct Site:Decodable{let x_mm:Float,z_mm:Float};let sites:[Site]}
    private var premiumCueCache:[String:SCNGeometry]=[:]
    private func premiumMaterial(_ name:String)->SCNMaterial {
        let m=mat(.white)
        m.diffuse.contents=materialMap("PC_"+name+"_albedo",fallback:clothTexture)
        m.normal.contents=materialMap("PC_"+name+"_normal",fallback:clothNormal)
        m.roughness.contents=materialMap("PC_"+name+"_roughness",fallback:clothNormal)
        m.metalness.contents=materialMap("PC_"+name+"_metallic",fallback:clothNormal)
        m.normal.intensity=name=="FeltEmerald" ? 0.35:0.18
        for channel in [m.diffuse,m.normal,m.roughness,m.metalness]{channel.wrapS = .repeat;channel.wrapT = .repeat;channel.mipFilter = .linear;channel.maxAnisotropy=8}
        return m
    }
    private func premiumCue(_ id:String)->SCNGeometry? {
        if let cached=premiumCueCache[id]{return cached}
        guard let asset=NSDataAsset(name:"PC_Cue_"+id),let mesh=try? JSONDecoder().decode(KitCueMesh.self,from:asset.data) else{return nil}
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[]
        for i in stride(from:0,to:mesh.vertices.count,by:3){vertices.append(SCNVector3(mesh.vertices[i],mesh.vertices[i+1],mesh.vertices[i+2]));normals.append(SCNVector3(mesh.normals[i],mesh.normals[i+1],mesh.normals[i+2]))}
        for i in stride(from:0,to:mesh.uv.count,by:2){uv.append(CGPoint(x:CGFloat(mesh.uv[i]),y:CGFloat(mesh.uv[i+1])))}
        let elements=mesh.elements.map{SCNGeometryElement(indices:$0,primitiveType:.triangles)}
        let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:elements)
        geometry.materials=mesh.names.map{name in
            switch name {
            case "Carbon":return premiumMaterial("CueCarbon")
            case "Maple":return premiumMaterial("CueMaple")
            case "Ebony":return premiumMaterial("CueEbony")
            case "Wrap":return premiumMaterial("CueWrapBlack")
            case "Gold":return premiumMaterial("ChampagneGold")
            case "Ferrule":return mat(.rgb(0xE8DFCB),roughness:0.28)
            default:return mat(.rgb(0x163D57),roughness:0.88)
            }
        }
        premiumCueCache[id]=geometry;return geometry
    }
    private var meshes:[String:MeshData]=[:]
    let scene=SCNScene(),camera=SCNNode()
    private let targetRoot=SCNNode(),tableRoot=SCNNode(),cueShadow=SCNNode()
    private var tableRails:[[String:NSNumber]]=[]
    private var look=TableLook.selected
    private var clothTintIndex:Int?
    private var cueLookID=""
    private var cueShadowKey:[Float]=[]
    private let ballRoot=SCNNode(),guideRoot=SCNNode(),trailRoot=SCNNode(),cueRoot=SCNNode(),numberRoot=SCNNode()
    private var nodes:[Int:SCNNode]=[:],contactShadows:[Int:SCNNode]=[:]
    private var restOrientations:[Int:simd_quatf]=[:]
    private struct PocketState {
        var time:Double
        let start:SCNVector3
        let velocity:SIMD2<Float>
        let pocket:Int
        let slot:Int
        let orientation:simd_quatf
    }
    private var falling:[Int:PocketState]=[:]
    private var settledPocketNodes=Set<Int>()
    private static let pocketCenters:[SIMD2<Float>]=[
        SIMD2(-0.67,-1.305),SIMD2(0.67,-1.305),SIMD2(-0.706,0),
        SIMD2(0.706,0),SIMD2(-0.67,1.305),SIMD2(0.67,1.305)]
    /// Vận tốc ngang ước lượng từ khung trước (m/s) để bi giữ đà khi rơi vào lỗ.
    private var lastPlanar:[Int:SIMD2<Float>]=[:],planarVelocity:[Int:SIMD2<Float>]=[:]
    static let pocketFallDuration=0.90
    private var light:SCNLight!
    private var highDetail=false
    private var thermalState=ProcessInfo.ThermalState.nominal
    private var qualityKey=""
    private var ballSegmentCount=48
    private var cachedBallTextures:[Int:UIImage]=[:]
    private var cachedBallGeometry:[Int:SCNSphere]=[:]
    private var cachedMaterialMaps:[String:UIImage]=[:]
    private var cachedWood:[Bool:UIImage]=[:]
    private var cachedLabels:[String:UIImage]=[:]
    private var trainingOverlaysHidden=true
    var focusBounds:SIMD4<Float>?
    var placementBlocked=false
    var cameraMode=2 // Aim3D; numeric IDs remain 0=overview, 1=top, 2=aim.
    var zoom:Float=1
    var orbit:Float=0
    var orbitPitch:Float=0.57
    /// Độ cao camera ngắm (rad so với mặt bàn quanh bi cái). 0,325 = góc mặc định cũ; nhỏ nhất gần sát mặt nỉ.
    static let aimPitchRange:ClosedRange<Float> = 0.02...1.25
    static let defaultAimPitch:Float = 0.325
    var aimPitch:Float=TableScene.defaultAimPitch
    /// Độ cao mắt tối thiểu (m, so với mặt nỉ): trên mặt nỉ 2 cm; trên băng/gỗ 0,056 + 0,03.
    static let minAimEyeHeightBed:Float = 0.02
    static let minAimEyeHeightRail:Float = 0.086
    private var lastCameraTarget:SIMD3<Float>?
    var cueType=0
    var cueElevation:Double=0
    /// Góc nghiêng tối thiểu để cơ qua được băng (BLCueMinimumElevation); chỉ ảnh hưởng hình vẽ cây cơ.
    var clearanceElevation:Double=0
    var showNumbers=false // Text-free table in every camera mode.
    private let radius:CGFloat=0.028575
    private lazy var shadowTexture=contactShadowTexture()
    private lazy var clothImage=materialMap("PC_FeltEmerald_albedo",fallback:clothTexture)
    private lazy var normalImage=materialMap("PC_FeltEmerald_normal",fallback:clothNormal)
    private lazy var environment=studioEnvironment()
    static let colors:[UIColor] = [UIColor(white:0.96,alpha:1),UIColor(red:0.98,green:0.65,blue:0.025,alpha:1),UIColor(red:0.025,green:0.14,blue:0.62,alpha:1),UIColor(red:0.74,green:0.025,blue:0.045,alpha:1),UIColor(red:0.26,green:0.045,blue:0.42,alpha:1),UIColor(red:0.96,green:0.24,blue:0.025,alpha:1),UIColor(red:0.015,green:0.30,blue:0.14,alpha:1),UIColor(red:0.36,green:0.025,blue:0.055,alpha:1),UIColor(white:0.012,alpha:1)]
    static let clothColors:[(String,UIColor)]=[("Xanh tournament",.rgb(0x17685F)),("Xanh navy",.rgb(0x143F78)),("Xanh sáng",.rgb(0x2387A5)),("Đỏ burgundy",.rgb(0x783B42)),("Tím mận",.rgb(0x49354F))]
    init(rails:[[String:NSNumber]]) {
        if let asset=NSDataAsset(name:"TableMesh") {
            meshes=(try? JSONDecoder().decode([String:MeshData].self,from:asset.data)) ?? [:]
        }
        scene.background.contents=UIColor(red:0.018,green:0.023,blue:0.031,alpha:1)
        scene.fogColor=UIColor(red:0.025,green:0.032,blue:0.042,alpha:1)
        scene.fogStartDistance=9;scene.fogEndDistance=19
        for root in [targetRoot,tableRoot,cueShadow,ballRoot,guideRoot,trailRoot,cueRoot,numberRoot,camera]{scene.rootNode.addChildNode(root)}
        camera.camera=SCNCamera();camera.camera?.zNear=0.012;camera.camera?.zFar=24
        camera.camera?.fieldOfView=46;camera.camera?.wantsHDR=true
        camera.camera?.wantsExposureAdaptation=false;camera.camera?.exposureOffset = -0.8
        camera.camera?.bloomIntensity=0;camera.camera?.bloomThreshold=1.8
        camera.camera?.vignettingIntensity=0.18;camera.camera?.vignettingPower=0.8
        scene.lightingEnvironment.contents=environment;scene.lightingEnvironment.intensity=1.1
        numberRoot.isHidden=true
        tableRails=rails;buildLights();frontFill(scene.rootNode);selectTable(look);buildRoom();buildCue();quality(false)
    }
    func quality(_ high:Bool) {
        highDetail=high
        applyQuality()
    }
    /// Render cost only. The controller keeps the authoritative physics step and
    /// interpolation independent of thermal quality changes.
    func setThermalState(_ state:ProcessInfo.ThermalState){
        guard state != thermalState else{return};thermalState=state;applyQuality()
    }
    private func applyQuality(){
        let constrained=thermalState == .serious || thermalState == .critical
        let warm=thermalState == .fair
        let key="\(highDetail)-\(thermalState.rawValue)"
        guard qualityKey != key else{return};qualityKey=key
        ballSegmentCount=constrained ? 24:(highDetail && !warm ? 64:48)
        for geometry in cachedBallGeometry.values{geometry.segmentCount=ballSegmentCount}
        for node in nodes.values{node.castsShadow=highDetail && !constrained && !warm}
        camera.camera?.screenSpaceAmbientOcclusionIntensity=highDetail && !constrained && !warm ? 0.12:0
        camera.camera?.screenSpaceAmbientOcclusionRadius=0.035
        camera.camera?.screenSpaceAmbientOcclusionBias=0.003
        let size:CGFloat=constrained ? 512:(highDetail && !warm ? 1536:1024)
        light.shadowMapSize=CGSize(width:size,height:size)
        light.shadowSampleCount=constrained ? 1:(highDetail && !warm ? 8:4)
        light.castsShadow = !constrained
    }
    private func mat(_ color:UIColor,roughness:CGFloat=0.6,metal:CGFloat=0)->SCNMaterial {
        let m=SCNMaterial();m.lightingModel = .physicallyBased;m.diffuse.contents=color
        m.roughness.contents=roughness;m.metalness.contents=metal
        return m
    }
    private func box(_ w:CGFloat,_ h:CGFloat,_ l:CGFloat,_ p:SCNVector3,_ material:SCNMaterial,chamfer:CGFloat=0.004,parent:SCNNode?=nil)->SCNNode {
        let g=SCNBox(width:w,height:h,length:l,chamferRadius:chamfer)
        g.chamferSegmentCount=3;g.materials=[material]
        let n=SCNNode(geometry:g);n.position=p;(parent ?? scene.rootNode).addChildNode(n);return n
    }
    private func buildLights(){
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient
        ambient.light?.color=UIColor(white:0.92,alpha:1);ambient.light?.intensity=150
        scene.rootNode.addChildNode(ambient)
        // Emit below the visible fixture, so its housing does not block the key light.
        let key=SCNNode();key.position=SCNVector3(0,2.30,0);light=SCNLight();light.type = .spot
        light.intensity=520;light.temperature=4700;light.spotInnerAngle=50;light.spotOuterAngle=100
        light.castsShadow=true;light.shadowMode = .forward;light.shadowRadius=3.4
        light.shadowColor=UIColor(white:0,alpha:0.32);light.shadowBias=0.001
        key.name="premium-club-key";key.light=light;key.look(at:SCNVector3(0,0,0),up:SCNVector3(0,0,1),localFront:SCNVector3(0,0,-1));scene.rootNode.addChildNode(key)
        for x:Float in [-2.2,2.2]{
            let fill=SCNNode();fill.position=SCNVector3(x,1.7,0.8);fill.light=SCNLight();fill.light?.type = .omni
            fill.light?.intensity=10;fill.light?.temperature=x>0 ? 4200:7000
            fill.light?.attenuationStartDistance=1;fill.light?.attenuationEndDistance=6
            scene.rootNode.addChildNode(fill)
        }
    }
    private func frontFill(_ parent:SCNNode){
        let fill=SCNNode();fill.light=SCNLight();fill.light?.type = .omni
        fill.light?.intensity=8;fill.light?.temperature=5600
        fill.light?.attenuationStartDistance=1;fill.light?.attenuationEndDistance=6
        fill.position=SCNVector3(0,0.65,-2);parent.addChildNode(fill)
    }
    private func clothAlbedo(_ color:UIColor)->UIImage {
        texture(CGSize(width:2048,height:2048)){c in
            let rect=CGRect(x:0,y:0,width:2048,height:2048)
            clothImage.draw(in:rect);color.setFill();c.cgContext.setBlendMode(.color);c.fill(rect)
        }
    }
    private func buildTable(_ rails:[[String:NSNumber]]){
        let graphite=look.wood ? premiumMaterial("WalnutDark"):mat(.rgb(look.cabinet),roughness:0.5,metal:0.12)
        if look.wood {
            graphite.multiply.contents=UIColor(white:0.95,alpha:1)
            graphite.normal.contents=materialMap("PC_WalnutDark_normal"){self.clothNormal()};graphite.normal.intensity=0.08
            graphite.roughness.contents=materialMap("PC_WalnutDark_roughness"){self.clothNormal()}
            for channel in [graphite.diffuse,graphite.normal,graphite.roughness]{channel.minificationFilter = .linear;channel.mipFilter = .linear;channel.maxAnisotropy=16}
        }
        let edge=premiumMaterial("ChampagneGold")
        edge.multiply.contents=UIColor.rgb(look.trim)
        let clothColor=clothTintIndex.map{Self.clothColors[$0].1} ?? .rgb(look.cloth)
        let cloth=mat(clothColor,roughness:0.97)
        cloth.diffuse.contents=clothAlbedo(clothColor)
        cloth.normal.contents=normalImage;cloth.normal.intensity=0.34
        cloth.roughness.contents=materialMap("PC_FeltEmerald_roughness",fallback:{self.texture(CGSize(width:8,height:8)){c in UIColor(white:0.94,alpha:1).setFill();c.fill(CGRect(x:0,y:0,width:8,height:8))}});cloth.metalness.contents=0
        for channel in [cloth.diffuse,cloth.normal,cloth.roughness]{
            channel.wrapS = .repeat;channel.wrapT = .repeat
            channel.contentsTransform=SCNMatrix4MakeScale(1.615,2.895,1)
            channel.minificationFilter = .linear;channel.magnificationFilter = .linear
            channel.mipFilter = .linear;channel.maxAnisotropy=16
        }
        addMesh("bed",material:cloth)
        addMesh("deck",material:graphite)
        addMesh("trim",material:edge)
        // Split rails leave visible pocket apertures; apron is below the playing bed.
        for side:Float in [-1,1]{
            _=box(0.10,0.21,2.64,SCNVector3(side*0.755,-0.16,0),graphite,chamfer:0.016)
            _=box(1.42,0.21,0.10,SCNVector3(0,-0.16,side*1.3645),graphite,chamfer:0.016)
            _=box(0.009,0.009,2.65,SCNVector3(side*0.803,-0.06,0),edge,chamfer:0.002)
            _=box(1.43,0.009,0.009,SCNVector3(0,-0.06,side*1.443),edge,chamfer:0.002)
        }
        buildCushions(rails,material:cloth)
        for x:Float in [-0.67,0.67]{for z:Float in [-1.305,0,1.305]{
            let sideOffset:Float = z==0 ? (x>0 ? 0.036:-0.036):0
            pocket(x+sideOffset,z)
        }}
        if let asset=NSDataAsset(name:"PC_Diamonds"),let layout=try? JSONDecoder().decode(KitSights.self,from:asset.data){
            for site in layout.sites{diamond(SCNVector3(site.x_mm/1000,0.05615,site.z_mm/1000),shortRail:abs(site.z_mm)>1300)}
        }else{preconditionFailure("Missing Premium Classic diamond layout")}
        brandPlate(SCNVector3(0,-0.15,1.421))
        // Cabinet panel joints and inset foot hardware: visual only, outside the bed.
        let joint=mat(UIColor(white:0.025,alpha:1),roughness:0.7)
        for side:Float in [-1,1]{
            for z:Float in [-0.84,0.84]{
                _=box(0.0015,0.17,0.002,SCNVector3(side*0.8053,-0.16,z),joint,chamfer:0)
            }
            _=box(0.002,0.003,2.48,SCNVector3(side*0.8055,-0.235,0),edge,chamfer:0.0005)
            _=box(1.28,0.003,0.002,SCNVector3(0,-0.235,side*1.415),edge,chamfer:0.0005)
        }
        buildBase(shell:graphite,trim:edge)
        if ProcessInfo.processInfo.arguments.contains("--visual-qa") {
            let sights=scene.rootNode.childNodes.filter{$0.name=="rail-sight"}
            let plates=scene.rootNode.childNodes.filter{$0.name=="table-nameplate"}
            precondition(sights.count==18 && plates.count==1,"WPA reference count")
            for n in sights {
                let p=n.position
                let offset=min(abs(abs(p.x)-0.635),abs(abs(p.z)-1.27))
                precondition(abs(offset-0.0936625)<0.000001,"Sight centre offset")
            }
        }
    }
    func selectTable(_ next:TableLook){
        look=next;tableRoot.childNodes.forEach{$0.removeFromParentNode()}
        let old=Set(scene.rootNode.childNodes.map{ObjectIdentifier($0)})
        buildTable(tableRails)
        for node in scene.rootNode.childNodes where !old.contains(ObjectIdentifier(node)){tableRoot.addChildNode(node)}
    }
    func setClothColor(_ index:Int?){clothTintIndex=index.map{max(0,min(Self.clothColors.count-1,$0))};selectTable(look)}
    private func buildBase(shell:SCNMaterial,trim:SCNMaterial){
        let dark=mat(UIColor(white:0.07,alpha:1),roughness:0.75)
        func beam(_ a:SCNVector3,_ b:SCNVector3,_ width:CGFloat,_ depth:CGFloat,_ material:SCNMaterial){
            let av=SIMD3<Float>(a.x,a.y,a.z),bv=SIMD3<Float>(b.x,b.y,b.z),d=bv-av
            let n=box(width,CGFloat(simd_length(d)),depth,SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2),material,chamfer:0.016)
            n.simdOrientation=simd_quatf(from:SIMD3(0,1,0),to:simd_normalize(d))
        }
        if look.base==1 { // Two broad pedestal columns.
            for z:Float in [-0.87,0.87]{
                _=box(0.72,0.45,0.25,SCNVector3(0,-0.47,z),shell,chamfer:0.065)
                _=box(0.98,0.055,0.34,SCNVector3(0,-0.715,z),trim,chamfer:0.025)
            }
        }else if look.base==3 || look.base==4 { // Cross / V supports.
            for z:Float in [-0.88,0.88]{
                if look.base==3 {
                    beam(SCNVector3(-0.5,-0.71,z),SCNVector3(0.4,-0.24,z),0.13,0.22,shell)
                    beam(SCNVector3(0.5,-0.71,z),SCNVector3(-0.4,-0.24,z),0.13,0.22,shell)
                }else{
                    beam(SCNVector3(0,-0.69,z),SCNVector3(-0.48,-0.25,z),0.19,0.27,shell)
                    beam(SCNVector3(0,-0.69,z),SCNVector3(0.48,-0.25,z),0.19,0.27,shell)
                }
                _=box(1.08,0.045,0.31,SCNVector3(0,-0.72,z),trim,chamfer:0.02)
            }
        }else{
            for x:Float in [-0.56,0.56]{for z:Float in [-0.97,0.97]{
                if look.base==5 {
                    let g=SCNCone(topRadius:0.12,bottomRadius:0.07,height:0.43);g.radialSegmentCount=64;g.materials=[shell]
                    let n=SCNNode(geometry:g);n.position=SCNVector3(x,-0.48,z);scene.rootNode.addChildNode(n)
                }else{
                    let n=box(look.base==2 ? 0.17:0.24,0.44,look.base==2 ? 0.17:0.28,SCNVector3(x,-0.48,z),shell,chamfer:0.035)
                    n.eulerAngles.z=x>0 ? -0.07:0.07
                    if look.base==0{_=box(0.13,0.34,0.009,SCNVector3(x,-0.48,z+(z>0 ? 0.145:-0.145)),trim,chamfer:0.008)}
                }
                let foot=SCNCylinder(radius:0.085,height:0.025);foot.radialSegmentCount=64;foot.materials=[dark]
                let n=SCNNode(geometry:foot);n.position=SCNVector3(x,-0.736,z);scene.rootNode.addChildNode(n)
            }}
        }
        _=box(0.12,0.10,2.04,SCNVector3(0,-0.35,0),shell,chamfer:0.018)
        if ["smart","proam","blackwolfpro","apex"].contains(look.id){
            _=box(0.48,0.10,0.018,SCNVector3(0,-0.15,1.42),dark,chamfer:0.022)
            _=box(0.50,0.008,0.025,SCNVector3(0,-0.20,1.425),trim,chamfer:0.003)
        }
    }
    func tablePreviewScene()->SCNScene {
        let p=SCNScene();p.background.contents=UIColor(red:0.04,green:0.05,blue:0.06,alpha:1)
        p.lightingEnvironment.contents=environment;p.lightingEnvironment.intensity=0.6
        p.rootNode.addChildNode(tableRoot.clone())
        let eye=SCNNode();eye.camera=SCNCamera();eye.camera?.zNear=0.01;eye.camera?.wantsHDR=true;eye.camera?.wantsExposureAdaptation=false;eye.camera?.exposureOffset = -1.25;eye.position=SCNVector3(2.0,1.2,2.4);eye.look(at:SCNVector3(0,-0.2,0));p.rootNode.addChildNode(eye)
        let l=SCNNode();l.light=SCNLight();l.light?.type = .omni;l.light?.intensity=80;l.position=SCNVector3(0,2.8,0);p.rootNode.addChildNode(l)
        let fill=SCNNode();fill.light=SCNLight();fill.light?.type = .ambient;fill.light?.intensity=250;p.rootNode.addChildNode(fill)
        return p
    }
    private func buildCushions(_ rails:[[String:NSNumber]],material:SCNMaterial){
        var edges=rails.map{d in (SIMD2<Float>(d["ax"]!.floatValue,d["ay"]!.floatValue),
            SIMD2<Float>(d["bx"]!.floatValue,d["by"]!.floatValue),d["id"]?.intValue ?? 0)}
        while !edges.isEmpty{
            let first=edges.removeFirst();var points=[first.0,first.1]
            var changed=true
            while changed{
                changed=false
                for i in edges.indices{
                    let edge=edges[i];guard edge.2==first.2 else{continue}
                    if simd_distance(points.last!,edge.0)<0.00001{points.append(edge.1)}
                    else if simd_distance(points.last!,edge.1)<0.00001{points.append(edge.0)}
                    else if simd_distance(points.first!,edge.0)<0.00001{points.insert(edge.1,at:0)}
                    else if simd_distance(points.first!,edge.1)<0.00001{points.insert(edge.0,at:0)}
                    else{continue}
                    edges.remove(at:i);changed=true;break
                }
            }
            cushionPath(points,rail:first.2,material:material)
        }
    }
    private func cushionPath(_ points:[SIMD2<Float>],rail:Int,material:SCNMaterial){
        let outside:[SIMD2<Float>]=[SIMD2(-1,0),SIMD2(1,0),SIMD2(0,-1),SIMD2(0,1)]
        func outward(_ a:SIMD2<Float>,_ b:SIMD2<Float>)->SIMD2<Float>{
            let d=simd_normalize(b-a);var n=SIMD2(d.y,-d.x)
            if simd_dot(n,outside[rail])<0{n = -n};return n
        }
        var miters:[SIMD2<Float>]=[],along:[Float]=[0]
        for i in points.indices{
            let prev=outward(points[max(0,i-1)],points[max(1,i)])
            let next=outward(points[min(i,points.count-2)],points[min(i+1,points.count-1)])
            let sum=prev+next
            miters.append(sum/max(0.5,1+simd_dot(prev,next)))
            if i>0{along.append(along.last!+simd_distance(points[i],points[i-1]))}
        }
        // Nose height = 63.5% of 57.15 mm diameter, matching Config.railHeight = .27.
        // Rounded cloth-covered section; shared smooth normals across the curved nose.
        let profile:[SIMD2<Float>]=[SIMD2(0,0.03629025),SIMD2(0.0006,0.0382),SIMD2(0.0022,0.0405),
            SIMD2(0.006,0.0435),SIMD2(0.014,0.0475),SIMD2(0.030,0.052),SIMD2(0.050,0.055),
            SIMD2(0.053,0.053),SIMD2(0.053,0.010),SIMD2(0.048,0.007),SIMD2(0.012,0.007),
            SIMD2(0.005,0.019),SIMD2(0.001,0.031)]
        var normals2:[SIMD2<Float>]=[],lengths:[Float]=[0]
        for j in 0..<profile.count {
            let prev=profile[(j+profile.count-1)%profile.count],next=profile[(j+1)%profile.count]
            let d=simd_normalize(profile[j]-prev)+simd_normalize(next-profile[j])
            normals2.append(simd_normalize(SIMD2(-d.y,d.x)))
            if j>0{lengths.append(lengths.last!+simd_length(profile[j]-profile[j-1]))}
        }
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
        func addQuad(_ corners:[SCNVector3],_ ns:[SCNVector3],_ coords:[CGPoint]){
            let base=Int32(vertices.count);vertices += corners;normals += ns;uv += coords
            let a=corners[0],b=corners[1],c=corners[2]
            let cross=simd_cross(SIMD3(b.x-a.x,b.y-a.y,b.z-a.z),SIMD3(c.x-a.x,c.y-a.y,c.z-a.z))
            let n=ns[0]
            if simd_dot(cross,SIMD3(n.x,n.y,n.z))>0{indices += [base,base+1,base+2,base,base+2,base+3]}
            else{indices += [base,base+2,base+1,base,base+3,base+2]}
        }
        for i in 0..<(points.count-1){for j in profile.indices{
            let k=(j+1)%profile.count
            let endUV=k==0 ? lengths.last!+simd_length(profile[0]-profile[j]):lengths[k]
            var corners:[SCNVector3]=[],ns:[SCNVector3]=[],coords:[CGPoint]=[]
            for (point,index,v) in [(i,j,lengths[j]),(i+1,j,lengths[j]),(i+1,k,endUV),(i,k,endUV)]{
                let q=points[point]+miters[point]*profile[index].x
                let direction=simd_normalize(miters[point]),n=normals2[index]
                corners.append(SCNVector3(q.x,profile[index].y,q.y))
                ns.append(SCNVector3(direction.x*n.x,n.y,direction.y*n.x))
                coords.append(CGPoint(x:CGFloat(along[point]),y:CGFloat(v)))
            }
            addQuad(corners,ns,coords)
        }}
        // Closed cloth facings at the back of each pocket; no exposed hollow profile.
        let total=profile.reduce(SIMD2<Float>(0,0)){$0+$1}
        let centre=total/Float(profile.count)
        for point in [0,points.count-1]{
            let tangent=point==0 ? simd_normalize(points[0]-points[1]):simd_normalize(points[point]-points[point-1])
            for j in profile.indices{
                let k=(j+1)%profile.count,base=Int32(vertices.count)
                for v in [centre,profile[j],profile[k]]{
                    let q=points[point]+miters[point]*v.x
                    vertices.append(SCNVector3(q.x,v.y,q.y));normals.append(SCNVector3(tangent.x,0,tangent.y))
                    uv.append(CGPoint(x:CGFloat(v.x),y:CGFloat(v.y)))
                }
                let a=vertices[Int(base)],b=vertices[Int(base)+1],c=vertices[Int(base)+2]
                let cross=simd_cross(SIMD3(b.x-a.x,b.y-a.y,b.z-a.z),SIMD3(c.x-a.x,c.y-a.y,c.z-a.z))
                if simd_dot(cross,SIMD3(tangent.x,0,tangent.y))>0{indices += [base,base+1,base+2]}
                else{indices += [base,base+2,base+1]}
            }
        }
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        let m=material.copy() as! SCNMaterial;m.isDoubleSided=true
        for channel in [m.diffuse,m.normal,m.roughness]{channel.contentsTransform=SCNMatrix4MakeScale(1.24,1.24,1)}
        g.materials=[m];scene.rootNode.addChildNode(SCNNode(geometry:g))
    }
    private func pocket(_ x:Float,_ z:Float){
        let segments=96
        let aperture:Float = z==0 ? 0.066:0.074
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
        let outward=simd_normalize(SIMD2(x,z))
        // Height of the back casting blends into the rail; the entry lip stays flush with felt.
        func lipHeight(_ c:Float,_ s:Float)->Float{
            let dot=c*outward.x+s*outward.y
            let t=max(0,min(1,(dot-0.10)/0.65))
            return 0.0004+0.0546*t*t*(3-2*t)
        }
        // A drop pocket is a closed leather basket, wider below the throat.
        // Its floor/volume also contain the parked presentation balls below.
        let profile:[(radius:Float,y:Float)]=[(aperture-0.0002,0),(0.056,-0.025),(0.105,-0.075),(0.115,-0.17),(0.108,-0.25)]
        for i in 0...segments {
            let a=Float(i)/Float(segments)*2*Float.pi,c=cos(a),s=sin(a)
            for (level,ring) in profile.enumerated(){
                let height=level==0 ? lipHeight(c,s):ring.y
                vertices.append(SCNVector3(x+c*ring.radius,height,z+s*ring.radius))
                normals.append(SCNVector3(-c,0.10,-s))
                uv.append(CGPoint(x:CGFloat(i)/24,y:CGFloat(level)*0.6))
            }
            if i<segments{for level in 0..<(profile.count-1){
                let a=Int32(i*profile.count+level),b=a+Int32(profile.count)
                indices += [a,a+1,b,a+1,b+1,b]
            }}
        }
        let leather=premiumMaterial("PocketLeather");leather.isDoubleSided=true
        leather.normal.contents=materialMap("PC_PocketLeather_normal"){self.clothNormal()};leather.normal.intensity=0.20
        leather.normal.wrapS = .repeat;leather.normal.wrapT = .repeat
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        g.materials=[leather];scene.rootNode.addChildNode(SCNNode(geometry:g))
        // A narrow, connected satin casting follows the same lip instead of separate square caps.
        var rim:[SCNVector3]=[],rimNormals:[SCNVector3]=[],rimIndices:[Int32]=[]
        for i in 0...segments{
            let a=Float(i)/Float(segments)*2*Float.pi,c=cos(a),s=sin(a),h=lipHeight(c,s)
            rim += [SCNVector3(x+c*aperture,h,z+s*aperture),SCNVector3(x+c*(aperture+0.006),h,z+s*(aperture+0.006))]
            rimNormals += [SCNVector3(0,1,0),SCNVector3(0,1,0)]
            if i<segments{let j=Int32(i*2);rimIndices += [j,j+2,j+1,j+1,j+2,j+3]}
        }
        let rimGeometry=SCNGeometry(sources:[SCNGeometrySource(vertices:rim),SCNGeometrySource(normals:rimNormals)],elements:[SCNGeometryElement(indices:rimIndices,primitiveType:.triangles)])
        let casting=mat(UIColor(white:0.26,alpha:1),roughness:0.48,metal:0.65);casting.isDoubleSided=true
        rimGeometry.materials=[casting];scene.rootNode.addChildNode(SCNNode(geometry:rimGeometry))
        let bottom=SCNCylinder(radius:0.108,height:0.008);bottom.radialSegmentCount=48;bottom.materials=[mat(.black)]
        let node=SCNNode(geometry:bottom);node.position=SCNVector3(x,-0.255,z);scene.rootNode.addChildNode(node)
    }
    private func addMesh(_ name:String,material:SCNMaterial){
        guard let data=meshes[name] else{assertionFailure("Missing TableMesh asset: "+name);return}
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[]
        for i in stride(from:0,to:data.vertices.count,by:3){
            vertices.append(SCNVector3(data.vertices[i],data.vertices[i+1],data.vertices[i+2]))
            normals.append(SCNVector3(data.normals[i],data.normals[i+1],data.normals[i+2]))
        }
        for i in stride(from:0,to:data.uv.count,by:2){uv.append(CGPoint(x:CGFloat(data.uv[i]),y:CGFloat(data.uv[i+1])))}
        let positionSource=SCNGeometrySource(vertices:vertices)
        let normalSource=SCNGeometrySource(normals:normals)
        let uvSource=SCNGeometrySource(textureCoordinates:uv)
        let element=SCNGeometryElement(indices:data.indices,primitiveType:.triangles)
        let geometry=SCNGeometry(sources:[positionSource,normalSource,uvSource],elements:[element])
        geometry.materials=[material]
        let node=SCNNode(geometry:geometry);node.name="table-"+name;node.castsShadow=true
        scene.rootNode.addChildNode(node)
    }
    private func buildRoom(){
        let charcoal=mat(UIColor(red:0.045,green:0.052,blue:0.064,alpha:1),roughness:0.9)
        let floor=mat(.white,roughness:0.65)
        floor.diffuse.contents=materialMap("PC_WalnutDark_albedo"){self.woodTexture(light:false)}
        floor.normal.contents=materialMap("PC_WalnutDark_normal"){self.clothNormal()};floor.normal.intensity=0.12
        floor.roughness.contents=materialMap("PC_WalnutDark_roughness"){self.clothNormal()}
        floor.multiply.contents=UIColor(white:0.22,alpha:1)
        for channel in [floor.diffuse,floor.normal,floor.roughness]{
            channel.wrapS = .repeat;channel.wrapT = .repeat
            channel.contentsTransform=SCNMatrix4MakeScale(4,5,1);channel.mipFilter = .linear;channel.maxAnisotropy=8
        }
        _=box(9,0.08,10,SCNVector3(0,-0.79,0),floor,chamfer:0)
        for side:Float in [-1,1]{
            _=box(0.09,3.5,10,SCNVector3(side*4,0.95,0),charcoal,chamfer:0)
            _=box(8,3.5,0.09,SCNVector3(0,0.95,side*4.7),charcoal,chamfer:0)
            for z:Float in [-3.5,-2.5,-1.5,-0.5,0.5,1.5,2.5,3.5]{
                _=box(0.035,2.3,0.035,SCNVector3(side*3.94,0.4,z),mat(UIColor(white:0.10,alpha:1)),chamfer:0.002)
            }
            let glow=mat(UIColor(red:0.22,green:0.18,blue:0.11,alpha:1))
            glow.emission.contents=UIColor(red:0.40,green:0.27,blue:0.10,alpha:1)
            _=box(0.025,0.018,8,SCNVector3(side*3.93,1.7,0),glow,chamfer:0)
            _=box(2.5,0.32,0.48,SCNVector3(0,-0.55,side*3.8),mat(UIColor(red:0.13,green:0.075,blue:0.052,alpha:1)),chamfer:0.06)
            _=box(2.5,0.48,0.12,SCNVector3(0,-0.22,side*4.0),mat(UIColor(red:0.10,green:0.055,blue:0.035,alpha:1)),chamfer:0.04)
        }
        // Rectangular light fixture and matching reflection cards in environment map.
        let frame=mat(UIColor(white:0.09,alpha:1),roughness:0.3,metal:0.7)
        for x:Float in [-0.47,0.47]{_ = box(0.045,0.035,2.10,SCNVector3(x,2.45,0),frame)}
        for z:Float in [-1.03,1.03]{_ = box(0.98,0.035,0.045,SCNVector3(0,2.45,z),frame)}
        let diffuser=mat(UIColor(white:0.9,alpha:1));diffuser.emission.contents=UIColor(white:0.85,alpha:1)
        for x:Float in [-0.25,0.25]{_ = box(0.13,0.015,1.88,SCNVector3(x,2.43,0),diffuser)}
    }
    func selectCue(_ type:Int){
        let next=max(0,min(2,type)),appearance=CueBag.cue(type)
        if cueType==next && cueLookID==appearance.id && !cueRoot.childNodes.isEmpty{return}
        cueLookID=appearance.id;cueType=next;cueRoot.childNodes.forEach{$0.removeFromParentNode()};buildCue()
    }
    func cuePreviewScene()->SCNScene {
        let preview=SCNScene();preview.background.contents=UIColor(red:0.04,green:0.06,blue:0.07,alpha:1)
        let model=cueRoot.clone();model.isHidden=false;model.simdPosition = .zero;model.simdOrientation=simd_quatf(angle:0,axis:SIMD3<Float>(0,1,0))
        model.runAction(.repeatForever(.rotateBy(x:0,y:Double.pi*2,z:0,duration:9)))
        preview.rootNode.addChildNode(model)
        let eye=SCNNode();eye.camera=SCNCamera();eye.position=SCNVector3(0.18,-0.62,1.45)
        eye.look(at:SCNVector3(0,-0.60,0));preview.rootNode.addChildNode(eye)
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=260;preview.rootNode.addChildNode(ambient)
        let key=SCNNode();key.light=SCNLight();key.light?.type = .omni;key.light?.intensity=80;key.position=SCNVector3(0.5,0,1);preview.rootNode.addChildNode(key)
        return preview
    }
    private func buildCue(){
        let appearance=CueBag.cue(cueType);cueLookID=appearance.id
        if let geometry=premiumCue(appearance.id){
            let node=SCNNode(geometry:geometry);node.name="premium-cue-"+appearance.id;node.castsShadow=true;cueRoot.addChildNode(node)
            let cap=SCNCylinder(radius:0.006,height:0.0008);cap.materials=[mat(.rgb(0x163D57),roughness:0.9)]
            let tip=SCNNode(geometry:cap);tip.position.y=0;cueRoot.addChildNode(tip)
            return
        }
        let scale:CGFloat=cueType==1 ? 0.72:(cueType==2 ? 1.015:1.0)
        // Local +Y points to the tip; full 1.45 m cue, separate leather/ferrule/shaft/joint/wrap/butt.
        func section(_ start:CGFloat,_ length:CGFloat,_ tipRadius:CGFloat,_ buttRadius:CGFloat,_ material:SCNMaterial){
            let g=SCNCone(topRadius:tipRadius,bottomRadius:buttRadius,height:length*scale);g.radialSegmentCount=48;g.materials=[material]
            let node=SCNNode(geometry:g);node.position.y = -Float((start+length/2)*scale);node.castsShadow=true;cueRoot.addChildNode(node)
        }
        let maple=mat(appearance.carbon ? UIColor(white:0.12,alpha:1):UIColor.white,roughness:0.42)
        if !appearance.carbon {maple.diffuse.contents=woodTexture(light:true)}
        let ebony=mat(.rgb(appearance.color),roughness:0.30)
        let ring=mat(.rgb(appearance.accent),roughness:0.3,metal:0.5)
        section(0,0.004,0.0059,0.0059,mat(UIColor(red:0.07,green:0.23,blue:0.29,alpha:1),roughness:0.88))
        section(0.004,0.017,0.0059,0.0060,mat(UIColor(red:0.93,green:0.91,blue:0.81,alpha:1),roughness:0.23))
        section(0.021,0.704,0.006,0.0105,maple)
        section(0.725,0.025,0.0105,0.0107,ring)
        section(0.75,0.23,0.0107,0.013,ebony)
        let wrap=mat(UIColor(white:0.07,alpha:1),roughness:0.88);wrap.normal.contents=normalImage;wrap.normal.intensity=0.08
        section(0.98,0.30,0.013,0.0142,wrap)
        section(1.28,0.155,0.0142,0.0147,ebony)
        section(1.435,0.005,0.0147,0.0147,ring)
        section(1.44,0.010,0.0147,0.0147,mat(.black))
    }
    private func materialMap(_ name:String,fallback:()->UIImage)->UIImage {
        if let cached=cachedMaterialMaps[name]{return cached}
        guard let asset=NSDataAsset(name:name),let image=UIImage(data:asset.data) else {
            assertionFailure("Missing material map: "+name)
            return fallback()
        }
        let normalized=rgbTexture(image);cachedMaterialMaps[name]=normalized;return normalized
    }
    private func rgbTexture(_ image:UIImage)->UIImage {
        // Normalize imported and UIKit-generated images: UIKit can optimize
        // grayscale procedural textures into unsupported R8Unorm_sRGB too.
        guard let source=image.cgImage else{return image}
        let shrink=min(1.0,2048.0/Double(max(source.width,source.height)))
        let width=max(1,Int((Double(source.width)*shrink).rounded()))
        let height=max(1,Int((Double(source.height)*shrink).rounded()))
        guard let context=CGContext(data:nil,width:width,height:height,
                                    bitsPerComponent:8,bytesPerRow:width*4,
                                    space:CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return image}
        context.interpolationQuality = .high
        context.draw(source,in:CGRect(x:0,y:0,width:width,height:height))
        guard let normalized=context.makeImage() else{return image}
        return UIImage(cgImage:normalized,scale:image.scale,orientation:image.imageOrientation)
    }
    private func texture(_ size:CGSize,opaque:Bool=true,draw:(UIGraphicsImageRendererContext)->Void)->UIImage{
        let f=UIGraphicsImageRendererFormat();f.scale=1;f.opaque=opaque
        return rgbTexture(UIGraphicsImageRenderer(size:size,format:f).image(actions:draw))
    }
    private func studioEnvironment()->[UIImage]{
        var faces:[UIImage] = []
        for face:Int in 0..<6 {
            let image:UIImage = environmentFace(face)
            faces.append(image)
        }
        return faces
    }
    private func environmentFace(_ face:Int)->UIImage {
        texture(CGSize(width:512,height:512)){ c in
            let ctx=c.cgContext
            let top:CGFloat=face==2 ? 0.50:0.34,bottom:CGFloat=face==3 ? 0.20:0.25
            let colors=[UIColor(white:top,alpha:1).cgColor,UIColor(white:bottom,alpha:1).cgColor] as CFArray
            if let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,1]){
                ctx.drawLinearGradient(g,start:CGPoint(x:0,y:0),end:CGPoint(x:0,y:512),options:[])
            }
            if face==2 {
                ctx.setShadow(offset:.zero,blur:24,color:UIColor(white:0.75,alpha:1).cgColor)
                UIColor(white:0.82,alpha:1).setFill()
                for x in [144,324]{UIBezierPath(roundedRect:CGRect(x:x,y:98,width:44,height:316),cornerRadius:20).fill()}
            }
        }
    }
    private func clothTexture()->UIImage{
        texture(CGSize(width:512,height:512)){c in
            UIColor(red:0.025,green:0.22,blue:0.29,alpha:1).setFill();c.fill(CGRect(x:0,y:0,width:512,height:512))
            for y in 0..<512 {for x in stride(from:0,to:512,by:2){
                let horizontal:Int = x*73
                let vertical:Int = y*151
                let crossTerm:Int = (x*y)*7
                let pattern:Int = (horizontal+vertical+crossTerm)%23
                let v:CGFloat = CGFloat(pattern)/CGFloat(2300)
                UIColor(red:0.025+v,green:0.22+v,blue:0.29+v,alpha:1).setFill()
                let pixelX:Int = x+(y%2)
                c.fill(CGRect(x:CGFloat(pixelX),y:CGFloat(y),width:1,height:1))
            }}
        }
    }
    private func clothNormal()->UIImage{
        texture(CGSize(width:128,height:128)){c in
            for y in 0..<128 {for x in 0..<128{
                let phaseX:Double = Double(x)*Double.pi/2.0
                let phaseY:Double = Double(y)*Double.pi/2.0
                let red:CGFloat = 0.5+0.035*CGFloat(sin(phaseX))
                let green:CGFloat = 0.5+0.035*CGFloat(sin(phaseY))
                UIColor(red:red,green:green,blue:0.998,alpha:1).setFill()
                c.fill(CGRect(x:x,y:y,width:1,height:1))
            }}
        }
    }
    private func woodTexture(light:Bool)->UIImage{
        if let cached=cachedWood[light]{return cached}
        let image=texture(CGSize(width:256,height:1024)){c in
            for y in stride(from:0,to:1024,by:2){for x in 0..<256{
                let drift:Double = sin(Double(y)*0.013)*0.8
                let phase:Double = Double(x)*0.18+drift
                let broadGrain:Double = sin(phase)*0.024
                let fineGrain:Double = sin(phase*5.7)*0.007
                let grain:CGFloat = CGFloat(broadGrain+fineGrain)
                let baseRed:CGFloat = light ? 0.75:0.19
                let baseGreen:CGFloat = light ? 0.61:0.105
                let baseBlue:CGFloat = light ? 0.40:0.057
                let red:CGFloat = baseRed+grain
                let green:CGFloat = baseGreen+grain*0.8
                let blue:CGFloat = baseBlue+grain*0.5
                UIColor(red:red,green:green,blue:blue,alpha:1).setFill()
                c.fill(CGRect(x:x,y:y,width:1,height:2))
            }}
        };cachedWood[light]=image;return image
    }
    private func contactShadowTexture()->UIImage{
        texture(CGSize(width:512,height:512),opaque:false){c in
            let colors=[UIColor.black.withAlphaComponent(0.70).cgColor,UIColor.black.withAlphaComponent(0.24).cgColor,UIColor.clear.cgColor] as CFArray
            if let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,0.42,1]){
                c.cgContext.drawRadialGradient(g,startCenter:CGPoint(x:256,y:256),startRadius:0,endCenter:CGPoint(x:256,y:256),endRadius:256,options:[])
            }
        }
    }
    private func diamond(_ p:SCNVector3,shortRail:Bool=false){
        let long:Float=0.028,wide:Float=0.013
        let dx=shortRail ? long/2:wide/2,dz=shortRail ? wide/2:long/2
        let vertices=[SCNVector3(-dx,0,0),SCNVector3(0,0,-dz),SCNVector3(dx,0,0),SCNVector3(0,0,dz)]
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:Array(repeating:SCNVector3(0,1,0),count:4))],elements:[SCNGeometryElement(indices:[Int32(0),1,2,0,2,3],primitiveType:.triangles)])
        let m=mat(UIColor(red:0.96,green:0.94,blue:0.82,alpha:1),roughness:0.28,metal:0.15);m.isDoubleSided=true;m.emission.contents=UIColor(white:0.13,alpha:1);g.materials=[m]
        let n=SCNNode(geometry:g);n.position=p;n.name="rail-sight";n.castsShadow=false;scene.rootNode.addChildNode(n)
    }
    private func brandPlate(_ p:SCNVector3){
        let g=SCNPlane(width:0.22,height:0.038),m=SCNMaterial();m.lightingModel = .constant
        m.diffuse.contents=texture(CGSize(width:1024,height:176)){c in
            UIColor(white:0.045,alpha:1).setFill();c.fill(CGRect(x:0,y:0,width:1024,height:176))
            let style=NSMutableParagraphStyle();style.alignment = .center
            (look.brand.uppercased() as NSString).draw(in:CGRect(x:14,y:12,width:996,height:80),withAttributes:[.font:UIFont.systemFont(ofSize:56,weight:.bold),.foregroundColor:UIColor(red:0.92,green:0.83,blue:0.61,alpha:1),.paragraphStyle:style])
            (look.name as NSString).draw(in:CGRect(x:14,y:100,width:996,height:64),withAttributes:[.font:UIFont.systemFont(ofSize:40,weight:.medium),.foregroundColor:UIColor.white,.paragraphStyle:style])
        };g.materials=[m];let n=SCNNode(geometry:g);n.name="table-nameplate";n.eulerAngles.x = 0;n.position=p;n.castsShadow=false;scene.rootNode.addChildNode(n)
    }
    private func ballTexture(_ id:Int)->UIImage{
        if let cached=cachedBallTextures[id]{return cached}
        let image=texture(CGSize(width:1024,height:512)){c in
            UIColor(white:0.95,alpha:1).setFill();c.fill(CGRect(x:0,y:0,width:1024,height:512))
            if id==0{
                UIColor(red:0.72,green:0.025,blue:0.035,alpha:1).setFill()
                let size=1024.0,angularRadius=0.115,pixelAngle=Double.pi/512
                for row in 0..<512 {
                    let latitude=(0.5-(Double(row)+0.5)/512)*Double.pi
                    for col in 0..<1024 {
                        let longitude=(Double(col)+0.5)/size*2*Double.pi
                        let x=cos(latitude)*cos(longitude),y=sin(latitude),z=cos(latitude)*sin(longitude)
                        let cap=max(abs(x),max(abs(y),abs(z)))
                        let edge=acos(min(1,max(-1,cap)))
                        let coverage=min(1,max(0,(angularRadius+pixelAngle*0.5-edge)/pixelAngle))
                        if coverage>0 { UIColor(red:0.72,green:0.025,blue:0.035,alpha:coverage).setFill();c.cgContext.fill(CGRect(x:col,y:row,width:1,height:1)) }
                    }
                }
            }else{
                TableScene.colors[(id-1)%8+1].setFill()
                c.fill(id>8 ? CGRect(x:0,y:148,width:1024,height:216):CGRect(x:0,y:0,width:1024,height:512))
                for x in [256,768]{
                    // 2:1 equirectangular map: equal texel density per radian at the equator.
                    UIColor(white:0.97,alpha:1).setFill();c.cgContext.fillEllipse(in:CGRect(x:x-54,y:202,width:108,height:108))
                    let s="\(id)" as NSString
                    let attrs:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:65,weight:.heavy),.foregroundColor:UIColor(white:0.025,alpha:1)]
                    let sz=s.size(withAttributes:attrs);s.draw(at:CGPoint(x:CGFloat(x)-sz.width/2,y:256-sz.height/2),withAttributes:attrs)
                }
            }
        };cachedBallTextures[id]=image;return image
    }
    private func ballGeometry(_ id:Int)->SCNSphere{
        if let old=cachedBallGeometry[id]{return old}
        let sphere=SCNSphere(radius:radius);sphere.segmentCount=ballSegmentCount
        let material=mat(.white,roughness:0.27)
        material.diffuse.contents=ballTexture(id);material.diffuse.maxAnisotropy=8
        material.diffuse.mipFilter = .linear;material.diffuse.minificationFilter = .linear
        material.emission.contents=material.diffuse.contents;material.emission.intensity=0.08
        sphere.materials=[material];cachedBallGeometry[id]=sphere;return sphere
    }
    private lazy var ballShadowGeometry:SCNPlane = {
        let plane=SCNPlane(width:0.085,height:0.085),material=SCNMaterial()
        material.lightingModel = .constant;material.diffuse.contents=shadowTexture
        material.writesToDepthBuffer=false;material.readsFromDepthBuffer=true;material.blendMode = .alpha
        plane.materials=[material];return plane
    }()
    private func setPosition(_ position:SCNVector3,on node:SCNNode){
        let old=node.position
        if old.x != position.x || old.y != position.y || old.z != position.z{node.position=position}
    }
    func update(_ balls:[BallState],dt:Double){
        SCNTransaction.begin();SCNTransaction.animationDuration=0;SCNTransaction.disableActions=true
        defer{SCNTransaction.commit()}
        let ids=Set(balls.map{$0.id})
        for id in Array(nodes.keys) where !ids.contains(id){
            nodes.removeValue(forKey:id)?.removeFromParentNode()
            contactShadows.removeValue(forKey:id)?.removeFromParentNode()
            restOrientations.removeValue(forKey:id);falling.removeValue(forKey:id);settledPocketNodes.remove(id)
            lastPlanar.removeValue(forKey:id);planarVelocity.removeValue(forKey:id)
        }
        for b in balls{
            let node:SCNNode
            if let old=nodes[b.id]{node=old}else{
                node=SCNNode(geometry:ballGeometry(b.id));node.name="ball_\(b.id)"
                node.castsShadow=highDetail && thermalState == .nominal
                node.eulerAngles=SCNVector3(0.18,0.6,0.2)
                restOrientations[b.id]=node.simdOrientation
                ballRoot.addChildNode(node);nodes[b.id]=node
                let shadow=SCNNode(geometry:ballShadowGeometry)
                shadow.eulerAngles.x = -.pi/2;shadow.castsShadow=false;shadow.renderingOrder=2
                scene.rootNode.addChildNode(shadow);contactShadows[b.id]=shadow
            }
            let opacity:CGFloat=(b.id==0 && placementBlocked) ? 0.45:1
            if node.opacity != opacity{node.opacity=opacity}
            let planar=SIMD2<Float>(Float(b.x),Float(b.y))
            if b.sunk {
                if falling[b.id]==nil{
                    let previous=lastPlanar[b.id]
                    let from=previous ?? planar
                    let velocity=planarVelocity[b.id] ?? .zero
                    // Classify from the solver's captured position, not the
                    // previous rendered frame: a fast break can travel many
                    // centimetres between frames. Off-table recovery positions
                    // must never acquire a made-pocket presentation.
                    let nearest=Self.pocketCenters.indices.min{
                        simd_distance_squared(Self.pocketCenters[$0],planar)<simd_distance_squared(Self.pocketCenters[$1],planar)
                    } ?? 0
                    // A ball leaving the table is not a potted ball. Hide that
                    // foul presentation rather than moving it into a pocket.
                    let captureRadius:Float = (nearest==2 || nearest==3 ? 0.058:0.066)+0.00001
                    let pocket=simd_distance_squared(Self.pocketCenters[nearest],planar)<captureRadius*captureRadius ? nearest:-1
                    let usedSlots=Set(falling.values.filter{$0.pocket==pocket}.map{$0.slot})
                    // Ball-in-hand can remove the cue ball from the middle of
                    // a basket; counting entries would reuse an occupied slot.
                    let slot=(0..<16).first{!usedSlots.contains($0)} ?? 15
                    let speed=simd_length(velocity)
                    let bounded=speed>4 ? velocity*(4/speed):velocity
                    let time=previous==nil ? Self.pocketFallDuration:0
                    falling[b.id]=PocketState(time:time,start:SCNVector3(from.x,Float(radius),from.y),velocity:bounded,pocket:pocket,slot:slot,orientation:node.simdOrientation)
                }
                if !settledPocketNodes.contains(b.id),let state=falling[b.id]{
                    applyPocketPose(state,to:node)
                    if state.pocket<0 || state.time>=Self.pocketFallDuration{settledPocketNodes.insert(b.id)}
                }
                lastPlanar.removeValue(forKey:b.id);planarVelocity.removeValue(forKey:b.id)
                if let shadow=contactShadows[b.id],!shadow.isHidden{shadow.isHidden=true}
                continue
            }
            // Reset/seek backwards/ball-in-hand returns the solver's live ball
            // immediately; a parked pocket node must never override that state.
            falling.removeValue(forKey:b.id);settledPocketNodes.remove(b.id)
            if node.isHidden{node.isHidden=false}
            if dt.isFinite,dt>0,let previous=lastPlanar[b.id]{planarVelocity[b.id]=(planar-previous)/Float(dt)}
            lastPlanar[b.id]=planar
            setPosition(SCNVector3(planar.x,Float(radius)+Float(b.height ?? 0),planar.y),on:node)
            if let shadow=contactShadows[b.id]{
                if shadow.isHidden{shadow.isHidden=false}
                setPosition(SCNVector3(planar.x,0.001,planar.y),on:shadow)
                let height=Float(b.height ?? 0)
                let shade=CGFloat(max(0.05,1.0/(1+height*13)))
                if shadow.opacity != shade{shadow.opacity=shade}
                let spread:Float=0.92+height*1.6
                if shadow.scale.x != spread{shadow.scale=SCNVector3(spread,spread,spread)}
            }
            // Reflection XY -> XZ maps quaternion axis (x,y,z) to (-x,-z,-y).
            if let x=b.qx,let y=b.qy,let z=b.qz,let w=b.qw {
                let physical=simd_quatf(ix:Float(-x),iy:Float(-z),iz:Float(-y),r:Float(w))
                let rest=restOrientations[b.id] ?? simd_quatf(angle:0,axis:SIMD3<Float>(0,1,0))
                let orientation=physical*rest
                if node.simdOrientation.vector != orientation.vector{node.simdOrientation=orientation}
            }
        }
    }
    /// Call before loading a layout, starting another replay or seeking. Already
    /// sunk initial-state balls park immediately on the next update.
    func resetPocketPresentation(){
        falling.removeAll(keepingCapacity:true)
        settledPocketNodes.removeAll(keepingCapacity:true)
        lastPlanar.removeAll(keepingCapacity:true);planarVelocity.removeAll(keepingCapacity:true)
    }
    var hasActivePocketAnimations:Bool{
        falling.values.contains{$0.pocket>=0 && $0.time<Self.pocketFallDuration}
    }
    private func applyPocketPose(_ state:PocketState,to node:SCNNode){
        guard state.pocket>=0 else{node.isHidden=true;return}
        let center=Self.pocketCenters[state.pocket]
        let start=SIMD2<Float>(state.start.x,state.start.z)
        let offset=start-center
        let cross=offset.x*state.velocity.y-offset.y*state.velocity.x
        let direction:Float=cross<0 ? -1:1
        let progress=Float(min(1,max(0,state.time/Self.pocketFallDuration)))
        let baseAngle=atan2(offset.y,offset.x)
        let turn=direction*Float.pi*3.5*progress
        let phase=baseAngle+turn
        let radial=SIMD2<Float>(cos(phase),sin(phase))
        func smooth(_ x:Float)->Float{let t=min(1,max(0,x));return t*t*(3-2*t)}
        // Seven balls per layer fit the lower basket with a small clearance.
        // Sixteen pool balls need at most three layers, all below the throat.
        let slot=max(0,min(15,state.slot)),layer=slot/7,ring=slot%7
        let spacing=2*Float(radius)+0.001
        let parkingAngle=Float(max(0,ring-1))*Float.pi/3
        let parking=ring==0 ? SIMD2<Float>.zero:SIMD2<Float>(cos(parkingAngle),sin(parkingAngle))*spacing
        let floorHeight:Float = -0.251+Float(radius)+Float(layer)*spacing
        var planar:SIMD2<Float>,height:Float
        if progress<0.30{
            let fraction=smooth(progress/0.30)
            let entry=center+radial*0.022
            planar=start+(entry-start)*fraction
            height=state.start.y+(-0.032-state.start.y)*fraction
        }else{
            let fraction=smooth((progress-0.30)/0.70)
            let spread=smooth((fraction-0.45)/0.55)
            planar=center+radial*(0.022*(1-fraction))+parking*spread
            height = -0.032+(floorHeight+0.032)*fraction
        }
        setPosition(SCNVector3(planar.x,max(floorHeight,height),planar.y),on:node)
        let speed=simd_length(state.velocity)
        let axis=speed>0.0001 ? simd_normalize(SIMD3<Float>(state.velocity.y,0,-state.velocity.x)):SIMD3<Float>(1,0,0)
        let tumble=simd_quatf(angle:speed*Float(state.time)*0.30/Float(radius),axis:axis)
        let swirl=simd_quatf(angle:turn,axis:SIMD3<Float>(0,1,0))
        let orientation=swirl*tumble*state.orientation
        if node.simdOrientation.vector != orientation.vector{node.simdOrientation=orientation}
        node.isHidden=false
    }
    func animatePockets(_ dt:Double){
        guard dt.isFinite,dt>0,hasActivePocketAnimations else{return}
        SCNTransaction.begin();SCNTransaction.animationDuration=0;SCNTransaction.disableActions=true
        defer{SCNTransaction.commit()}
        for id in Array(falling.keys){
            guard var state=falling[id],state.pocket>=0,state.time<Self.pocketFallDuration,let node=nodes[id] else{continue}
            state.time=min(Self.pocketFallDuration,state.time+dt);falling[id]=state
            applyPocketPose(state,to:node)
            if state.time>=Self.pocketFallDuration{settledPocketNodes.insert(id)}
        }
    }
    func replay(_ from:[BallState],to:[BallState],fraction:Double){
        let t=max(0,min(1,fraction))
        let next=Dictionary(uniqueKeysWithValues:to.map{($0.id,$0)})
        let states=from.map{ a -> BallState in
            guard let b=next[a.id],!a.sunk else{return a}
            // Follow the final approach up to the captured position, then start
            // the basket presentation at that snapshot's timestamp. Holding a
            // whole snapshot interval before a pot produces a visible hitch on
            // the 10 Hz LAN stream even when the interpolation clock is smooth.
            if b.sunk && t>=1{return b}
            var state=a
            state.height=(a.height ?? 0)+((b.height ?? 0)-(a.height ?? 0))*t
            state.x=a.x+(b.x-a.x)*t;state.y=a.y+(b.y-a.y)*t
            if let ax=a.qx,let ay=a.qy,let az=a.qz,let aw=a.qw,
               let bx=b.qx,let by=b.qy,let bz=b.qz,let bw=b.qw {
                let qa=simd_quatf(ix:Float(ax),iy:Float(ay),iz:Float(az),r:Float(aw))
                let qb=simd_quatf(ix:Float(bx),iy:Float(by),iz:Float(bz),r:Float(bw))
                let q=simd_slerp(qa,qb,Float(t))
                state.qx=Double(q.imag.x);state.qy=Double(q.imag.y)
                state.qz=Double(q.imag.z);state.qw=Double(q.real)
            }
            return state
        }
        update(states,dt:0)
    }
    func placeCamera(cue:BallState?,angle:Double,aspect:CGFloat,blend:Float=1){
        guard let c=cue else{return}
        let d=SIMD3<Float>(Float(cos(angle)),0,Float(sin(angle)))
        let fieldOfView:Float = cameraMode==2 ? 38:46
        let fov:Float=fieldOfView*Float.pi/180
        let safeAspect:Float = max(0.5,Float(aspect))
        camera.camera?.usesOrthographicProjection=cameraMode==1
        var eye:SIMD3<Float>,target:SIMD3<Float>,up=SCNVector3(0,1,0)
        if cameraMode==1{
            // Half-height scale fits the short side vertically and long side horizontally.
            let halfWidth:Float = 1.50/safeAspect
            let halfHeight:Float = max(0.76,halfWidth)*zoom
            camera.camera?.orthographicScale=Double(halfHeight)
            // Ceiling fixture is at y=2.43–2.47. The old y=4 camera looked
            // through its opaque frame/diffusers, covering the table and balls.
            // Orthographic framing does not require moving above the fixture.
            eye=SIMD3(0,1.8,0);target=SIMD3(0,0,0);up=SCNVector3(cos(orbit),0,sin(orbit))
        }else if cameraMode==2{
            let origin=SIMD3<Float>(Float(c.x),0,Float(c.y))
            // Camera đi trên mặt cầu quanh bi cái: bán kính = khoảng cách cũ (0,46 ; 0,155) × zoom.
            // Pitch mặc định 0,325 rad cho đúng vị trí cũ; kéo ngón dọc để hạ sát mặt bàn hoặc nâng cao.
            let radiusAim:Float = 0.4854*zoom
            var pitch=min(max(aimPitch,TableScene.aimPitchRange.lowerBound),TableScene.aimPitchRange.upperBound)
            // Không để mắt camera chui vào băng/khung gỗ khi bi cái sát băng: nếu mắt nằm ngoài mặt nỉ
            // (|x|>0,635 hoặc |z|>1,27) thì nâng tối thiểu lên trên mặt gỗ (0,056 m) + 3 cm.
            let horizontal=radiusAim*cos(pitch)
            let eyeXZ=SIMD2<Float>(origin.x-d.x*horizontal,origin.z-d.z*horizontal)
            let overBed=abs(eyeXZ.x)<0.635 && abs(eyeXZ.y)<1.27
            let minEyeY:Float = overBed ? TableScene.minAimEyeHeightBed:TableScene.minAimEyeHeightRail
            if radiusAim*sin(pitch)<minEyeY {pitch=asin(min(1,minEyeY/radiusAim))}
            let retreat:SIMD3<Float> = d*(radiusAim*cos(pitch))
            let lift=SIMD3<Float>(0,radiusAim*sin(pitch),0)
            let behind:SIMD3<Float> = origin-retreat
            eye=behind+lift
            let forward:SIMD3<Float> = d*Float(0.75)
            let targetOrigin=SIMD3<Float>(Float(c.x),0.032,Float(c.y))
            target=targetOrigin+forward
        }else{
            let bounds=focusBounds ?? SIMD4<Float>(-0.78,0.78,-1.43,1.43)
            target=SIMD3((bounds.x+bounds.y)/2,0.025,(bounds.z+bounds.w)/2)
            let yaw:Float=orbit+0.20
            let elevation:Float=orbitPitch
            let cosElevation:Float=cos(elevation)
            let backwardX:Float=cos(yaw)*cosElevation
            let backwardY:Float=sin(elevation)
            let backwardZ:Float=sin(yaw)*cosElevation
            let backward=SIMD3<Float>(backwardX,backwardY,backwardZ)
            let worldUp=SIMD3<Float>(0,1,0)
            let cross:SIMD3<Float> = simd_cross(worldUp,backward)
            let right:SIMD3<Float> = simd_normalize(cross)
            let vertical:SIMD3<Float> = simd_cross(backward,right)
            let tanY:Float=tan(fov/2)
            let tanX:Float=tanY*safeAspect
            var distance:Float=1
            // Fit all table corners including feet; avoid cropping with different viewport ratios.
            for x:Float in [bounds.x,bounds.y]{for y:Float in [0,0.18]{for z:Float in [bounds.z,bounds.w]{
                let corner=SIMD3<Float>(x,y,z)
                let delta:SIMD3<Float> = corner-target
                let towards:Float = simd_dot(delta,backward)
                let horizontalSpan:Float = abs(simd_dot(delta,right))
                let verticalSpan:Float = abs(simd_dot(delta,vertical))
                let fitX:Float = towards+horizontalSpan/(tanX*0.66)
                let fitY:Float = towards+verticalSpan/(tanY*0.78)
                distance=max(distance,fitX)
                distance=max(distance,fitY)
            }}}
            let offset:SIMD3<Float> = backward*(distance*zoom)
            target += right*0.15
            eye=target+offset
        }
        // Instant during aim, so the camera never lags behind the chosen direction.
        let fraction=max(0,min(1,blend))
        if let lens=camera.camera {
            lens.fieldOfView += (CGFloat(fieldOfView)-lens.fieldOfView)*CGFloat(fraction)
        }
        if let old=lastCameraTarget,fraction<1 {
            eye=camera.simdPosition+(eye-camera.simdPosition)*fraction
            target=old+(target-old)*fraction
        }
        lastCameraTarget=target
        camera.simdPosition=eye;camera.look(at:SCNVector3(target.x,target.y,target.z),up:up,localFront:SCNVector3(0,0,-1))
    }
    private func cuePose(_ c:BallState,angle:Double,side:Double,top:Double)->(contact:SIMD3<Float>,axis:SIMD3<Float>){
        let d=SIMD3<Float>(Float(cos(angle)),0,Float(sin(angle)))
        let elevation=Float(max(cueElevation,min(clearanceElevation,85))*Double.pi/180)
        let axis=d*cos(elevation)-SIMD3<Float>(0,1,0)*sin(elevation)
        let right=SIMD3<Float>(-d.z,0,d.x)
        let up=d*sin(elevation)+SIMD3<Float>(0,1,0)*cos(elevation)
        let limit:Float=cueElevation>0 ? 0.6:0.7
        var x=Float(side),y=Float(top);let size=sqrt(x*x+y*y)
        if size>limit{x *= limit/size;y *= limit/size}
        let center=SIMD3<Float>(Float(c.x),Float(radius)+Float(c.height ?? 0),Float(c.y))
        let radial:Float=sqrt(max(Float(0),Float(1)-x*x-y*y))
        let lateralOffset: SIMD3<Float> = right*x
        let verticalOffset: SIMD3<Float> = up*y
        let rearOffset: SIMD3<Float> = axis*radial
        let surfaceOffset: SIMD3<Float> = (lateralOffset+verticalOffset-rearOffset)*Float(radius)
        let contact: SIMD3<Float> = center+surfaceOffset
        // Rear-hand point remains fixed while the selected tip point moves.
        let pivot=center-axis*(cueType==1 ? 0.80:1.12)
        return (contact,simd_normalize(contact-pivot))
    }
    func shotAngle(_ c:BallState?,angle:Double,side:Double,top:Double)->Double{
        guard let c=c else{return angle}
        let axis=cuePose(c,angle:angle,side:side,top:top).axis
        return atan2(Double(axis.z),Double(axis.x))
    }
    func showCue(_ c:BallState?,angle:Double,visible:Bool,pull:Double,side:Double=0,top:Double=0){
        cueRoot.isHidden = !visible || c == nil || c?.sunk==true
        cueShadow.isHidden=cueRoot.isHidden
        guard visible,let c=c,!c.sunk else{return}
        let pose=cuePose(c,angle:angle,side:side,top:top)
        cueRoot.simdPosition=pose.contact-pose.axis*Float(0.003+pull*0.16)
        cueRoot.simdOrientation=simd_quatf(from:SIMD3(0,1,0),to:pose.axis)
        if ProcessInfo.processInfo.arguments.contains("--visual-qa"){
            let tip=cueRoot.convertPosition(SCNVector3(0,Float(0.003+pull*0.16),0),to:nil)
            precondition(simd_distance(SIMD3(tip.x,tip.y,tip.z),pose.contact)<0.00001,"Cue geometry must reach selected surface contact")
        }
        updateCueShadow()
    }
    private lazy var cueShadowMaterial:SCNMaterial = {
        let m=SCNMaterial();m.lightingModel = .constant;m.blendMode = .alpha
        m.writesToDepthBuffer=false;m.isDoubleSided=true
        m.diffuse.contents=texture(CGSize(width:128,height:8),opaque:false){c in
            for x in 0..<128 {let u=(Double(x)-63.5)/22;let a=0.22*exp(-u*u/2)
                UIColor.black.withAlphaComponent(CGFloat(a)).setFill();c.fill(CGRect(x:x,y:0,width:1,height:8))}
        };return m
    }()
    private func updateCueShadow(){
        let key=[cueRoot.position.x,cueRoot.position.z,Float(max(cueElevation,clearanceElevation)),cueRoot.rotation.x,cueRoot.rotation.y,cueRoot.rotation.z,cueRoot.rotation.w,Float(cueType)]
        guard key != cueShadowKey else{return};cueShadowKey=key
        var vertices:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
        let length:Float=cueType==1 ? 1.044:1.45
        func project(_ t:Float)->SIMD3<Float>{
            let p=cueRoot.convertPosition(SCNVector3(0,-t,0),to:nil)
            let f:Float=2.30/max(0.15,2.30-p.y)
            return SIMD3(p.x*f,0.0015,p.z*f)
        }
        for i in 0..<64 {
            let a=project(length*Float(i)/64),b=project(length*Float(i+1)/64)
            guard abs(a.x)<0.625,abs(b.x)<0.625,abs(a.z)<1.26,abs(b.z)<1.26 else{continue}
            let d=b-a;guard simd_length(d)>0.00001 else{continue}
            let side=simd_normalize(SIMD3(-d.z,0,d.x))*Float(0.016+Double(i)/64*0.014)
            let base=Int32(vertices.count)
            for q in [a-side,a+side,b+side,b-side]{vertices.append(SCNVector3(q.x,q.y,q.z))}
            uv += [CGPoint(x:0,y:0),CGPoint(x:1,y:0),CGPoint(x:1,y:1),CGPoint(x:0,y:1)]
            indices += [base,base+1,base+2,base,base+2,base+3]
        }
        guard !vertices.isEmpty else{cueShadow.geometry=nil;return}
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        g.materials=[cueShadowMaterial];cueShadow.geometry=g;cueShadow.castsShadow=false;cueShadow.renderingOrder=3
    }
    func guide(_ points:[[String:NSNumber]],visible:Bool){
        guideRoot.childNodes.forEach{$0.removeFromParentNode()};guard visible,points.count>1 else{return}
        let p=points.map{SIMD3<Float>($0["x"]!.floatValue,0.0025,$0["y"]!.floatValue)}
        // One mesh for all dashes; avoids hundreds of sphere nodes/draw calls.
        var v:[SCNVector3]=[],indices:[Int32]=[]
        for i in 1..<p.count{
            let start:SIMD3<Float> = p[i-1]
            let delta:SIMD3<Float> = p[i]-start
            let length:Float = simd_length(delta)
            guard length>0.001 else{continue}
            let d:SIMD3<Float> = delta/length
            let perpendicular=SIMD3<Float>(-d.z,0,d.x)
            let side:SIMD3<Float> = perpendicular*Float(0.00075)
            for distance in stride(from:Float(0),to:length,by:0.032){
                let endDistance:Float = min(length,distance+0.014)
                let startOffset:SIMD3<Float> = d*distance
                let endOffset:SIMD3<Float> = d*endDistance
                let a:SIMD3<Float> = start+startOffset
                let b:SIMD3<Float> = start+endOffset
                let base:Int32 = Int32(v.count)
                let corners:[SIMD3<Float>] = [a-side,a+side,b+side,b-side]
                for q in corners{v.append(SCNVector3(q.x,q.y,q.z))}
                indices += [base,base+1,base+2,base,base+2,base+3]
            }
        }
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:v)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        let m=SCNMaterial();m.lightingModel = .constant;m.diffuse.contents=UIColor(red:0.76,green:0.91,blue:0.88,alpha:0.6);m.isDoubleSided=true;m.writesToDepthBuffer=false
        g.materials=[m];let node=SCNNode(geometry:g);node.castsShadow=false;guideRoot.addChildNode(node)
    }
    // MARK: Nút số kim cương và điểm va băng (chế độ Luyện; ẩn khi đang vuốt cơ)
    private var diamondLabels:SCNNode?
    private var railMarks=SCNNode()
    private func labelImage(_ text:String,size:CGFloat,color:UIColor,background:UIColor?)->UIImage{
        let key="\(text)|\(size)|\(color.description)|\(background?.description ?? "-")"
        if let old=cachedLabels[key]{return old}
        let font=UIFont.systemFont(ofSize:size,weight:.bold)
        let attrs:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:color]
        let textSize=(text as NSString).size(withAttributes:attrs)
        let side=max(textSize.width,textSize.height)+size*0.5
        // A label texture has fixed pixels independent of the phone's 2x/3x
        // display scale; the billboard already has a physical scene size.
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=false
        let image=rgbTexture(UIGraphicsImageRenderer(size:CGSize(width:side,height:side),format:format).image{_ in
            if let background=background {background.setFill();UIBezierPath(ovalIn:CGRect(x:0,y:0,width:side,height:side)).fill()}
            (text as NSString).draw(at:CGPoint(x:(side-textSize.width)/2,y:(side-textSize.height)/2),withAttributes:attrs)
        });cachedLabels[key]=image;return image
    }
    private func billboard(_ image:UIImage,size:CGFloat,at p:SCNVector3)->SCNNode{
        let plane=SCNPlane(width:size,height:size),m=SCNMaterial()
        m.lightingModel = .constant;m.diffuse.contents=image;m.isDoubleSided=true;m.writesToDepthBuffer=false;m.readsFromDepthBuffer=false
        plane.materials=[m];let n=SCNNode(geometry:plane);n.position=p;n.renderingOrder=40;n.castsShadow=false
        n.constraints=[SCNBillboardConstraint()];return n
    }
    /// Số nút: băng dài 0…8 (4 = lỗ giữa), băng ngắn 0…4, đặt ngoài mép gỗ cạnh từng nút.
    var showsDiamondNumbers:Bool=false {didSet{
        if showsDiamondNumbers && diamondLabels==nil {
            let root=SCNNode();root.name="diamond-numbers"
            for i in 0...8 {for side:Float in [-1,1]{
                let z=Float(i)*2.54/8-1.27
                root.addChildNode(billboard(labelImage("\(i)",size:40,color:.white,background:UIColor(white:0,alpha:0.45)),size:0.045,at:SCNVector3(side*0.79,0.075,z)))
            }}
            for i in 0...4 {for side:Float in [-1,1]{
                let x=Float(i)*1.27/4-0.635
                root.addChildNode(billboard(labelImage("\(i)",size:40,color:UIColor(red:1,green:0.85,blue:0.45,alpha:1),background:UIColor(white:0,alpha:0.45)),size:0.045,at:SCNVector3(x,0.075,side*1.425)))
            }}
            scene.rootNode.addChildNode(root);diamondLabels=root
        }
        diamondLabels?.isHidden = trainingOverlaysHidden || !showsDiamondNumbers
    }}
    /// Điểm va băng của cú vừa đánh: vòng tròn đánh số thứ tự trên mũi băng (x, y toạ độ bàn).
    func showRailContacts(_ points:[(x:Double,y:Double)]){
        railMarks.removeFromParentNode();railMarks=SCNNode();railMarks.name="rail-contacts"
        railMarks.isHidden=trainingOverlaysHidden
        for (index,p) in points.prefix(9).enumerated(){
            railMarks.addChildNode(billboard(labelImage("\(index+1)",size:40,color:.black,background:UIColor(red:1,green:0.78,blue:0.2,alpha:0.95)),size:0.04,at:SCNVector3(Float(p.x),0.07,Float(p.y))))
        }
        scene.rootNode.addChildNode(railMarks)
    }
    func setTrainingOverlaysHidden(_ hidden:Bool){
        trainingOverlaysHidden=hidden
        targetRoot.isHidden=hidden;guideRoot.isHidden=hidden;trailRoot.isHidden=hidden
        diamondLabels?.isHidden=hidden || !showsDiamondNumbers;railMarks.isHidden=hidden
    }
    /// Match spectators can choose physical diamond numbers, but never receive
    /// target rings, predictions, trails or coaching contact markers.
    func setCompetitivePresentation(numbers:Bool){
        setTrainingOverlaysHidden(true)
        showsDiamondNumbers=numbers;diamondLabels?.isHidden = !numbers
    }
    func target(_ goal:PracticeGoal?){
        targetRoot.childNodes.forEach{$0.removeFromParentNode()}
        guard let goal=goal,!goal.potOnly else{return}
        let ring=SCNTorus(ringRadius:CGFloat(goal.radius),pipeRadius:0.0016)
        ring.ringSegmentCount=96;ring.pipeSegmentCount=6
        let m=SCNMaterial();m.lightingModel = .constant;m.diffuse.contents=UIColor(red:0.91,green:0.73,blue:0.38,alpha:0.8)
        ring.materials=[m];let n=SCNNode(geometry:ring)
        n.position=SCNVector3(Float(goal.x),0.002,Float(goal.y));n.castsShadow=false;targetRoot.addChildNode(n)
    }
    func prediction(_ samples:[[String:NSNumber]],visible:Bool){
        guideRoot.childNodes.forEach{$0.removeFromParentNode()}
        guard visible else{return}
        var grouped:[Int:[SIMD3<Float>]] = [:]
        for sample in samples {
            guard sample["sunk"]?.boolValue != true else{continue}
            let id=sample["id"]?.intValue ?? 0
            let x=sample["x"]?.floatValue ?? 0
            let z=sample["y"]?.floatValue ?? 0
            grouped[id,default:[]].append(SIMD3<Float>(x,(sample["height"]?.floatValue ?? 0)+0.003,z))
        }
        for (id,points) in grouped where points.count>1 {
            var vertices:[SCNVector3] = []
            var indices:[Int32] = []
            for i in 1..<points.count {
                let a:SIMD3<Float> = points[i-1]
                let b:SIMD3<Float> = points[i]
                let delta:SIMD3<Float> = b-a
                let length:Float = simd_length(delta)
                guard length>0.001 else{continue}
                let perpendicular=SIMD3<Float>(-delta.z,0,delta.x)
                let unit:SIMD3<Float> = perpendicular/length
                let width:SIMD3<Float> = unit*Float(0.0011)
                let corners:[SIMD3<Float>] = [a-width,a+width,b+width,b-width]
                let base=Int32(vertices.count)
                for q in corners{vertices.append(SCNVector3(q.x,q.y,q.z))}
                indices += [base,base+1,base+2,base,base+2,base+3]
            }
            guard !vertices.isEmpty else{continue}
            let source=SCNGeometrySource(vertices:vertices)
            let element=SCNGeometryElement(indices:indices,primitiveType:.triangles)
            let geometry=SCNGeometry(sources:[source],elements:[element])
            let material=SCNMaterial();material.lightingModel = .constant
            material.diffuse.contents=id==0 ? UIColor(white:0.90,alpha:0.55):UIColor(red:0.95,green:0.60,blue:0.10,alpha:0.65)
            material.isDoubleSided=true;material.writesToDepthBuffer=false
            geometry.materials=[material]
            let node=SCNNode(geometry:geometry);node.castsShadow=false;guideRoot.addChildNode(node)
        }
    }
    func trails(_ paths:[Int:[SIMD3<Float>]]){
        trailRoot.childNodes.forEach{$0.removeFromParentNode()}
        for(id,points) in paths where points.count>1{
            let source=SCNGeometrySource(vertices:points.map{SCNVector3($0.x,max(0.003,$0.y),$0.z)})
            var indices:[Int32]=[]
            for i in 1..<points.count{indices += [Int32(i-1),Int32(i)]}
            let g=SCNGeometry(sources:[source],elements:[SCNGeometryElement(indices:indices,primitiveType:.line)])
            let m=SCNMaterial();m.lightingModel = .constant;m.diffuse.contents=id==0 ? UIColor(white:0.94,alpha:0.65):UIColor(red:0.95,green:0.66,blue:0.25,alpha:0.8)
            g.materials=[m];let n=SCNNode(geometry:g);n.castsShadow=false;trailRoot.addChildNode(n)
        }
    }
}
