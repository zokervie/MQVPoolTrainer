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
        // 0.39 (owner: tip too thick, no dome). The kit's leather tip is an 8 mm flat cylinder; real installed tips are
        // ~4.5 mm with a dime/nickel dome (radius ~9.5 mm). The kit tip is dropped (domeTip() replaces it) and the
        // ferrule is stretched up to meet the shorter tip: y -0.024…-0.008 → -0.024…-0.0045.
        for i in stride(from:0,to:mesh.vertices.count,by:3){
            var y=mesh.vertices[i+1];let r=(mesh.vertices[i]*mesh.vertices[i]+mesh.vertices[i+2]*mesh.vertices[i+2]).squareRoot()
            if r<0.0065 && y > -0.0241 && y <= -0.0079 {y = -0.024+(y+0.024)*(0.0195/0.016)}
            vertices.append(SCNVector3(mesh.vertices[i],y,mesh.vertices[i+2]));normals.append(SCNVector3(mesh.normals[i],mesh.normals[i+1],mesh.normals[i+2]))}
        for i in stride(from:0,to:mesh.uv.count,by:2){uv.append(CGPoint(x:CGFloat(mesh.uv[i]),y:CGFloat(mesh.uv[i+1])))}
        let kept=mesh.names.indices.filter{mesh.names[$0] != "Tip"}
        let elements=kept.map{SCNGeometryElement(indices:mesh.elements[$0],primitiveType:.triangles)}
        let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:elements)
        geometry.materials=kept.map{mesh.names[$0]}.map{name in
            let made:SCNMaterial={switch name {
            case "Carbon":return lacquer(premiumMaterial("CueCarbon"),0.30)
            case "Maple":return lacquer(premiumMaterial("CueMaple"),0.26)
            case "Ebony":return lacquer(premiumMaterial("CueEbony"),0.22)
            case "Wrap":return premiumMaterial("CueWrapBlack")
            case "Gold":let m=premiumMaterial("ChampagneGold");m.roughness.contents=0.22;m.metalness.contents=1.0;return m
            case "Ferrule":return mat(.rgb(0xE8DFCB),roughness:0.28)
            default:return mat(.rgb(0x163D57),roughness:0.88)
            }}();made.name=name;return made
        }
        premiumCueCache[id]=geometry;return geometry
    }
    /// Clear lacquer over a PBR base: the kit maps stay as the base layer.
    private func lacquer(_ m:SCNMaterial,_ roughness:CGFloat)->SCNMaterial{
        m.roughness.contents=roughness;m.clearCoat.contents=0.85;m.clearCoatRoughness.contents=0.07
        return m
    }
    private var meshes:[String:MeshData]=[:]
    let scene=SCNScene(),camera=SCNNode()
    private let targetRoot=SCNNode(),tableRoot=SCNNode(),cueShadow=SCNNode()
    private var tableRails:[[String:NSNumber]]=[]
    private var look=TableLook.selected
    private var clothTintIndex:Int?
    private var cueLookID=""
    private var cueShadowKey:[Float]=[]
    private let roomRoot=SCNNode()
    private(set) var space=UserDefaults.standard.object(forKey:"tableSpace034") as? Int ?? 0
    private let ballRoot=SCNNode(),guideRoot=SCNNode(),trailRoot=SCNNode(),cueRoot=SCNNode(),numberRoot=SCNNode()
    private var nodes:[Int:SCNNode]=[:],contactShadows:[Int:SCNNode]=[:]
    /// 0.39: render-clock interpolation of moving balls (see FramePacer). Set `presentAt` (CADisplayLink.targetTimestamp)
    /// before update/replay from the frame tick; nil = place nodes directly (editing, placement, idle).
    let pacer=FramePacer()
    var presentAt:Double?
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
    static let pocketFloor:Float = -0.122
    private static let pocketCenters:[SIMD2<Float>]=[
        SIMD2(-0.67,-1.305),SIMD2(0.67,-1.305),SIMD2(-0.706,0),
        SIMD2(0.706,0),SIMD2(-0.67,1.305),SIMD2(0.67,1.305)]
    /// Vận tốc ngang ước lượng từ khung trước (m/s) để bi giữ đà khi rơi vào lỗ.
    private var lastPlanar:[Int:SIMD2<Float>]=[:],planarVelocity:[Int:SIMD2<Float>]=[:]
    static let pocketFallDuration=0.90
    private var light:SCNLight!
    private var highDetail=false
    var usesHighDetail:Bool{highDetail}
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
    var spectatorPivot=false
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
    /// 0.21: cloth / ball wear (Thư viện). Old cloth adds ball tracks, spot burns and chalk; old balls lose gloss.
    private(set) var oldCloth=UserDefaults.standard.bool(forKey:"clothWear021")
    private(set) var oldBalls=UserDefaults.standard.bool(forKey:"ballWear021")
    private var feltNapCache:[Bool:UIImage]=[:]
    private var feltNapImage:UIImage{if let i=feltNapCache[oldCloth]{return i};let i=feltNap(old:oldCloth);feltNapCache[oldCloth]=i;return i}
    private weak var bedMaterial:SCNMaterial?
    func setClothWear(old:Bool){oldCloth=old;UserDefaults.standard.set(old,forKey:"clothWear021");bedMaterial?.multiply.contents=feltNapImage;bedMaterial?.setValue(NSNumber(value:old ? 1.0:0.0),forKey:"clothAge")}
    func setBallWear(old:Bool){oldBalls=old;UserDefaults.standard.set(old,forKey:"ballWear021");for g in cachedBallGeometry.values{if let m=g.firstMaterial{applyBallFinish(m)}}}
    /// Phenolic ball: semi-matte body under a thin, very smooth lacquer -> one small, sharp highlight instead of a broad
    /// glare over the top half (0.20 used roughness .27 + 8% emission). Old balls: worn lacquer, slight yellowing.
    private func applyBallFinish(_ m:SCNMaterial){
        m.emission.contents=UIColor.black;m.emission.intensity=0
        if oldBalls{
            // 0.39 (owner: old balls should be dull, cloudy, with chalk marks). Worn lacquer = almost no clear coat and a
            // rough body; a cloudy, slightly yellowed multiply with blue chalk smudges and fine scuffs.
            m.roughness.contents=0.74;m.clearCoat.contents=0.06;m.clearCoatRoughness.contents=0.55
            m.multiply.contents=Self.oldBallWear;m.multiply.wrapS = .repeat;m.multiply.wrapT = .repeat
        }
        else{
            // 0.37 (owner, 3rd time "bi chói"): the lit top clipped to white. Lower albedo, a thinner and softer lacquer so the
            // numbers/stripes keep detail; "Độ chói bi" (Tuỳ chỉnh) scales albedo AND lacquer together.
            let t=Self.tune(Self.tuneBall)
            m.roughness.contents=0.55;m.clearCoat.contents=min(1,0.28*t);m.clearCoatRoughness.contents=0.20
            m.multiply.contents=UIColor(white:min(1,0.68*t),alpha:1)
        }
    }
    /// Large-scale worsted nap streaks, soft mottling and cushion-side falloff.
    /// UV covers the 1.615 x 2.895 m footprint once (generate_table_mesh.py), so
    /// this layer never tiles; the fine weave remains in the kit felt maps.
    /// Large-scale layer over the whole bed (UV covers the 1.615 x 2.895 m footprint once; bed spans u .107-.893,
    /// v .061-.939). 0.21: no more long painted streaks (they read as smears). New cloth: faint low-frequency mottling
    /// and cushion-side falloff only. Old cloth: whole cloth a little duller, burnished ball tracks from the break area
    /// to the six pockets and along the rails, burns on the head/foot spots, chalk dust at the pockets.
    /// 0.33: close-up cloth fibres. A world-space fibre map (~11 mm tile, fibres ~0.3 mm) perturbs the normal and
    /// albedo only when a pixel covers < ~0.9 mm of cloth, i.e. when the camera is near — from afar the cloth stays smooth
    /// (no shimmering). Applied to the bed and the rail cloth.
    static let fiberMap:UIImage={
        let size=CGSize(width:512,height:512)
        return UIGraphicsImageRenderer(size:size).image{ctx in
            UIColor(white:0.5,alpha:1).setFill();ctx.fill(CGRect(origin:.zero,size:size))
            var seed:UInt64=0x2545F4914F6CDD1D
            func rnd()->CGFloat{seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;return CGFloat(seed%10000)/10000}
            ctx.cgContext.setLineCap(.round)
            for _ in 0..<5200 {
                let x=rnd()*size.width,y=rnd()*size.height,len=10+rnd()*36,a=(rnd()-0.5)*0.9   // mostly along the nap
                let shade=rnd()<0.5 ? UIColor(white:0.30+rnd()*0.15,alpha:0.55):UIColor(white:0.62+rnd()*0.2,alpha:0.55)
                ctx.cgContext.setStrokeColor(shade.cgColor);ctx.cgContext.setLineWidth(3+rnd()*5)
                for dx in [-size.width,0,size.width]{for dy in [-size.height,0,size.height]{
                    ctx.cgContext.move(to:CGPoint(x:x+dx,y:y+dy));ctx.cgContext.addLine(to:CGPoint(x:x+dx+sin(a)*len,y:y+dy+cos(a)*len));ctx.cgContext.strokePath()}}
            }
        }
    }()
    func applyFiberDetail(_ m:SCNMaterial){
        let fibres=SCNMaterialProperty(contents:Self.fiberMap)
        fibres.wrapS = .repeat;fibres.wrapT = .repeat;fibres.minificationFilter = .linear;fibres.magnificationFilter = .linear;fibres.mipFilter = .linear
        m.setValue(fibres,forKey:"fiberMap");m.setValue(NSNumber(value:Double(Self.tune(Self.tuneWeave))),forKey:"fiberStrength")   // 0.38: Tuỳ chỉnh · độ rõ vân nỉ
        m.setValue(NSNumber(value:oldCloth ? 1.0:0.0),forKey:"clothAge")   // 0.40b: new cloth = crisp threads, old = fuzz over the weave
        m.setValue(NSNumber(value:Double(Self.weavePitchMetres)),forKey:"weavePitch")   // 0.40c: Tuỳ chỉnh · độ thô sợi
        m.shaderModifiers=[.surface:"""
        #pragma arguments
        float fiberStrength;
        float clothAge;
        float weavePitch;
        texture2d<float> fiberMap;
        #pragma body
        constexpr sampler fs(filter::linear, mip_filter::linear, address::repeat);
        float3 wp = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
        float3 nw = (scn_frame.inverseViewTransform * float4(_surface.normal, 0.0)).xyz;
        float2 plane = abs(nw.y) > 0.6 ? wp.xz : float2(wp.x + wp.z, wp.y);
        float2 uv = plane * float2(62.0, 62.0);   // 0.39: finer fibre tile (16 mm), fibres ~0.1-0.25 mm
        float fw = length(fwidth(plane));
        float fiberW = fiberStrength * (1.0 + 1.3 * clothAge) * saturate(1.0 - fw / 0.0014);   // worn cloth: pilled fuzz
        if (fiberW > 0.001) {
            float e = 1.5 / 512.0;
            float h0 = fiberMap.sample(fs, uv).r;
            float hx = fiberMap.sample(fs, uv + float2(e, 0.0)).r;
            float hy = fiberMap.sample(fs, uv + float2(0.0, e)).r;
            _surface.normal = normalize(_surface.normal + fiberW * 2.0 * ((h0 - hx) * _surface.tangent + (h0 - hy) * _surface.bitangent));
            _surface.diffuse.rgb *= 1.0 + fiberW * 0.38 * (h0 - 0.5);
        }
        // 0.39 (owner: threads too big and flat -> fake). Real worsted tournament cloth has ~0.55 mm thread pitch; 2.2 mm
        // read as a printed zig-zag. Now 0.6 mm plain weave, every thread with its own thickness/brightness (hash per
        // crossing) so rows never line up, a twisted-yarn striation along each thread, and dark gaps between threads
        // (ambient occlusion) for depth. Still fades before 3 px/thread, so no moire at distance.
        // 0.40c (owner: "zoom vào sợi quá nhỏ"): thread pitch is a Tuỳ chỉnh value (default 1.0 mm, real worsted
        // 0.55–0.7 mm reads too fine on a phone) and the weave now appears from ~2.2 px per thread (was ~3 px).
        float2 wv = plane / max(weavePitch, 0.0004);
        // 0.40b (owner photos, 60/40 wool-nylon "300" speed cloth): up close every thread reads as a rounded grain with a
        // dark gap — stronger relief and gaps than 0.39; worn cloth keeps only ~40 % of it under the fuzz.
        float weaveW = fiberStrength * (1.0 - 0.6 * clothAge) * saturate((0.45 - length(fwidth(wv))) / 0.17);
        if (weaveW > 0.001) {
            float2 cell = floor(wv), f = fract(wv);
            float odd = fmod(abs(cell.x + cell.y), 2.0);
            float hcell = fract(sin(dot(cell, float2(127.1, 311.7))) * 43758.5453);
            float hrow = fract(sin(cell.y * 91.7 + 13.1) * 24634.63), hcol = fract(sin(cell.x * 57.3 + 7.7) * 13758.37);
            float warp = pow(sin(3.14159 * f.x), 0.55 + 0.45 * hcol), weft = pow(sin(3.14159 * f.y), 0.55 + 0.45 * hrow);
            float hw = mix(warp * (0.65 + 0.35 * weft), weft * (0.65 + 0.35 * warp), odd);
            float twist = 0.5 + 0.5 * sin(6.2832 * (mix(f.y, f.x, odd) * 3.0 + mix(f.x, f.y, odd) * 1.2 + hcell));
            float gap = saturate(min(sin(3.14159 * f.x), sin(3.14159 * f.y)) * 3.0);
            _surface.diffuse.rgb *= 1.0 + weaveW * (0.50 * (hw - 0.55) + 0.12 * (hcell - 0.5) + 0.08 * (twist - 0.5));
            _surface.diffuse.rgb *= mix(1.0, 0.64 + 0.36 * gap, weaveW);
            float gx = (1.0 - odd) * cos(3.14159 * f.x) + odd * 0.25 * (twist - 0.5), gy = odd * cos(3.14159 * f.y) + (1.0 - odd) * 0.25 * (twist - 0.5);
            _surface.normal = normalize(_surface.normal + weaveW * 1.3 * (gx * _surface.tangent + gy * _surface.bitangent));
        }
        _surface.roughness = 1.0;   // 0.37: worsted cloth has no sheen; a sliding highlight made the bands move/flicker
        """,.fragment:"""
        // 0.37: the dark cloth under one spot light is a very slow gradient: 8-bit output shows ~28 red levels across
        // the table -> concentric bands. Triangular sub-step noise (< 1 output level) turns steps into a smooth ramp.
        float3 dp = floor(_surface.position * 2600.0);
        float n1 = fract(sin(dot(dp, float3(12.9898, 78.233, 37.719))) * 43758.5453);
        float n2 = fract(sin(dot(dp, float3(39.346, 11.135, 83.155))) * 24634.6345);
        _output.color.rgb *= 1.0 + (n1 + n2 - 1.0) * 0.018;
        """]
    }
    // 0.36 Tuỳ chỉnh (menu): user multipliers, 1 = default.
    static let tuneBall="tuneBall036",tuneCloth="tuneCloth036",tuneLight="tuneLight036",tuneDiamond="tuneDiamond036",tuneShadow="tuneShadow037"
    // 0.38 Tuỳ chỉnh: weave clarity, aim-line colour (index) and thickness.
    static let tuneWeave="tuneWeave038",tuneGuideColor="tuneGuideColor038",tuneGuideWidth="tuneGuideWidth038"
    /// 0.40c Tuỳ chỉnh · độ thô sợi nỉ (mm per thread), 0.6 (real worsted) … 1.6 (coarse, reads at a glance).
    static let tuneWeavePitch="tuneWeavePitch040"
    static var weavePitchMetres:Float{Float(Tuning.value(tuneWeavePitch,1.0))/1000}
    static let guideColors:[(String,UIColor)]=[("Trắng",UIColor(white:1,alpha:0.88)),("Vàng",UIColor.rgb(0xF2D06B)),("Xanh lá",UIColor.rgb(0x5BE3A0)),("Đỏ",UIColor.rgb(0xFF6B5B)),("Xanh dương",UIColor.rgb(0x6BB8FF))]
    static var guideColor:UIColor{let i=UserDefaults.standard.integer(forKey:tuneGuideColor);return guideColors[max(0,min(guideColors.count-1,i))].1}
    /// 0.38: guide fades with skill (controller sets it from the recent pass rate).
    var guideOpacity:CGFloat=1{didSet{guideRoot.opacity=guideOpacity;for n in aimGuideNodes{n.opacity=guideOpacity}}}
    static func tune(_ key:String)->CGFloat{CGFloat(UserDefaults.standard.object(forKey:key) as? Double ?? 1)}
    func applyTuning(){
        light.intensity=52*Self.tune(Self.tuneLight)
        light.shadowColor=UIColor(white:0,alpha:min(0.9,0.50*Self.tune(Self.tuneShadow)))
        contactShadows.values.forEach{$0.opacity=min(1,Self.tune(Self.tuneShadow))*(Self.realShadows ? 0.75:1)}
        applyQuality()   // 0.39: "Bóng bi thật" switch takes effect at once (quality key includes it)
        // 0.38: aim line colour / thickness live
        let w=Float(Self.tune(Self.tuneGuideWidth))
        for (k,n) in aimGuideNodes.enumerated(){if k<3{n.geometry?.firstMaterial?.diffuse.contents = k==0 ? Self.guideColor:(k==1 ? UIColor.rgb(0xEAC583).withAlphaComponent(0.9):UIColor(white:1,alpha:0.38));(n.geometry as? SCNBox)?.length=CGFloat(0.0024*w)}}
        for g in cachedBallGeometry.values{if let m=g.firstMaterial{applyBallFinish(m)}}
        selectTable(look)
    }
    private func feltNap(old:Bool)->UIImage {
        texture(CGSize(width:1024,height:2048)){c in
            let ctx=c.cgContext,w:CGFloat=1024,h:CGFloat=2048
            UIColor(white:old ? 0.93:1,alpha:1).setFill();c.fill(CGRect(x:0,y:0,width:w,height:h))
            var seed:UInt64=old ? 0x01D_C10F:0x5EED_F17
            func random()->CGFloat{seed=seed &* 6364136223846793005 &+ 1442695040888963407;return CGFloat((seed>>33)%10_000)/10_000}
            for _ in 0..<70 {
                let r=90+random()*220
                UIColor(white:0.955+random()*0.04,alpha:0.06).setFill()
                ctx.fillEllipse(in:CGRect(x:random()*w-r,y:random()*h-r,width:r*2,height:r*2))
            }
            func P(_ u:CGFloat,_ v:CGFloat)->CGPoint{CGPoint(x:u*w,y:v*h)}
            if old {
                // 0.39 (owner: old cloth looked machine-drawn — straight streaks to the pockets). Real wear, from photos of
                // club cloth: (1) dense tiny pale specks where the break is played and the rack sits — jump/massé tip and
                // ball impacts lift the nap there most; (2) a broad, wandering, faint burnish along the head-to-foot
                // spot line and a softer one close to each long rail; (3) sparse random specks everywhere; (4) a rack
                // triangle ghost and small darker spot burns; (5) a little chalk-blue dust near the jaws. 1 px ≈ 1.4 mm.
                let pockets=[P(0.107,0.061),P(0.893,0.061),P(0.107,0.5),P(0.893,0.5),P(0.107,0.939),P(0.893,0.939)]
                func gauss()->CGFloat{(random()+random()+random()+random()-2)*0.87}
                func speck(_ x:CGFloat,_ y:CGFloat,_ r:CGFloat,_ alpha:CGFloat){
                    UIColor(white:1,alpha:alpha).setFill()
                    let a=random()*CGFloat.pi,e=1+random()*1.4   // slightly elongated, random direction
                    ctx.saveGState();ctx.translateBy(x:x,y:y);ctx.rotate(by:a);ctx.fillEllipse(in:CGRect(x:-r*e,y:-r,width:2*r*e,height:2*r));ctx.restoreGState()
                }
                // (2) wandering burnish: many low-alpha soft dabs along a noisy path, never a ruled line.
                func lane(_ from:CGPoint,_ to:CGPoint,width:CGFloat,alpha:CGFloat){
                    var wobble:CGFloat=0
                    for k in 0..<160 {
                        let t=CGFloat(k)/159;wobble=wobble*0.92+gauss()*3
                        let x=from.x+(to.x-from.x)*t+wobble,y=from.y+(to.y-from.y)*t
                        let r=width*(0.6+random()*0.5)
                        UIColor(white:1,alpha:alpha*(0.5+random())).setFill();ctx.fillEllipse(in:CGRect(x:x-r,y:y-r*1.6,width:2*r,height:3.2*r))
                    }
                }
                lane(P(0.5,0.20),P(0.5,0.80),width:34,alpha:0.018)
                for u in [CGFloat(0.13),0.87] {lane(P(u,0.10),P(u,0.47),width:16,alpha:0.014);lane(P(u,0.53),P(u,0.90),width:16,alpha:0.014)}
                // (1) break / rack clusters: cue-ball zone behind the head string spread across the width, rack zone at the foot spot.
                for _ in 0..<1400 {speck(w*0.5+gauss()*w*0.16,P(0,0.255).y+gauss()*h*0.035,0.6+random()*1.3,0.18+random()*0.30)}
                for _ in 0..<1700 {speck(w*0.5+gauss()*w*0.09,P(0,0.735).y+gauss()*h*0.045,0.6+random()*1.4,0.18+random()*0.32)}
                // (3) sparse random specks over the whole bed, a few larger "jump" marks.
                for _ in 0..<1100 {speck(P(0.11+random()*0.78,0).x,P(0,0.065+random()*0.87).y,0.5+random()*1.0,0.10+random()*0.22)}
                for _ in 0..<40 {speck(P(0.15+random()*0.70,0).x,P(0,0.12+random()*0.76).y,2+random()*2.5,0.16+random()*0.14)}
                // (4) rack ghost: the triangle's apex and edges press the nap; spot burns are small and darker.
                let apex=P(0.5,0.719),side:CGFloat=230
                UIColor(white:1,alpha:0.06).setStroke();ctx.setLineWidth(5)
                ctx.move(to:apex);ctx.addLine(to:CGPoint(x:apex.x-side/2,y:apex.y+side*0.866));ctx.addLine(to:CGPoint(x:apex.x+side/2,y:apex.y+side*0.866));ctx.closePath();ctx.strokePath()
                for spot in [P(0.5,0.281),P(0.5,0.719)] {
                    UIColor(white:0.70,alpha:0.45).setFill();ctx.fillEllipse(in:CGRect(x:spot.x-6,y:spot.y-6,width:12,height:12))
                    for _ in 0..<30 {let r=1+random()*2;UIColor(white:0.82,alpha:0.25).setFill();ctx.fillEllipse(in:CGRect(x:spot.x+gauss()*9-r,y:spot.y+gauss()*9-r,width:2*r,height:2*r))}
                }
                // (5) chalk dust near the jaws only, faint and irregular.
                for pocket in pockets { for _ in 0..<18 {
                    let a=random()*CGFloat.pi*2,d=25+random()*70,r=1+random()*3
                    UIColor(red:0.80,green:0.86,blue:0.96,alpha:0.12+random()*0.16).setFill()
                    ctx.fillEllipse(in:CGRect(x:pocket.x+cos(a)*d-r,y:pocket.y+sin(a)*d-r,width:r*2,height:r*2))
                }}
            }
            let colors=[UIColor(white:0,alpha:0).cgColor,UIColor(white:0,alpha:0.18).cgColor] as CFArray
            if let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0.55,1]){
                ctx.saveGState();ctx.translateBy(x:w/2,y:h/2);ctx.scaleBy(x:1,y:h/w*0.98)
                ctx.drawRadialGradient(g,startCenter:.zero,startRadius:0,endCenter:.zero,endRadius:w*0.52,options:[.drawsAfterEndLocation])
                ctx.restoreGState()
            }
        }
    }
    static let oldBallWear:UIImage={
        UIGraphicsImageRenderer(size:CGSize(width:256,height:128)).image{c in
            let ctx=c.cgContext
            UIColor(red:0.86,green:0.84,blue:0.78,alpha:1).setFill();c.fill(CGRect(x:0,y:0,width:256,height:128))
            var seed:UInt64=0xB411_01D0
            func rnd()->CGFloat{seed=seed &* 6364136223846793005 &+ 1442695040888963407;return CGFloat((seed>>33)%10_000)/10_000}
            for _ in 0..<26 {let r=4+rnd()*14;UIColor(white:0.80+rnd()*0.12,alpha:0.35).setFill();ctx.fillEllipse(in:CGRect(x:rnd()*256-r,y:rnd()*128-r,width:2*r,height:2*r))}   // cloudy
            for _ in 0..<7 {let r=3+rnd()*7;UIColor(red:0.62,green:0.74,blue:0.98,alpha:0.55).setFill();ctx.fillEllipse(in:CGRect(x:rnd()*256-r,y:rnd()*128-r*0.6,width:2*r,height:1.2*r))}   // chalk smudges
            ctx.setLineCap(.round)
            for _ in 0..<60 {UIColor(white:0.72,alpha:0.35).setStroke();ctx.setLineWidth(0.6);let x=rnd()*256,y=rnd()*128,a=rnd()*6.28,l=3+rnd()*10;ctx.move(to:CGPoint(x:x,y:y));ctx.addLine(to:CGPoint(x:x+cos(a)*l,y:y+sin(a)*l));ctx.strokePath()}   // scuffs
        }
    }()
    static let colors:[UIColor] = [UIColor(white:0.96,alpha:1),UIColor(red:0.98,green:0.65,blue:0.025,alpha:1),UIColor(red:0.025,green:0.14,blue:0.62,alpha:1),UIColor(red:0.74,green:0.025,blue:0.045,alpha:1),UIColor(red:0.26,green:0.045,blue:0.42,alpha:1),UIColor(red:0.96,green:0.24,blue:0.025,alpha:1),UIColor(red:0.015,green:0.30,blue:0.14,alpha:1),UIColor(red:0.36,green:0.025,blue:0.055,alpha:1),UIColor(white:0.012,alpha:1)]
    /// 0.40b (owner: colour swatches like the cloth sample card). First four = the common "300" speed-cloth card
    /// (green, electric blue, red, black — ASSUMED sRGB from the owner's photo); then the 0.3x club colours.
    static let clothColors:[(String,UIColor)]=[("Xanh lá",.rgb(0x149A57)),("Xanh dương",.rgb(0x1C6FC8)),("Đỏ",.rgb(0xA8153F)),("Đen",.rgb(0x1E1F22)),
        ("Xanh tournament",.rgb(0x17685F)),("Xanh navy",.rgb(0x143F78)),("Xanh sáng",.rgb(0x2387A5)),("Đỏ burgundy",.rgb(0x783B42)),("Tím mận",.rgb(0x49354F))]
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
        // 0.33 (owner: "quá sáng chói"): darker, filmic — lower exposure, gentle contrast, deeper vignette.
        camera.camera?.wantsExposureAdaptation=false;camera.camera?.exposureOffset = -2.0   // 0.36: CI shot of Z-Max cloth read 198/255 (reference ~125)
        camera.camera?.contrast=0.10;camera.camera?.saturation=1.04
        camera.camera?.bloomIntensity=0;camera.camera?.bloomThreshold=1.8
        camera.camera?.vignettingIntensity=0.32;camera.camera?.vignettingPower=0.9
        scene.lightingEnvironment.contents=environment;scene.lightingEnvironment.intensity=0.34
        numberRoot.isHidden=true
        tableRails=rails;buildLights();frontFill(scene.rootNode);selectTable(look);scene.rootNode.addChildNode(roomRoot);selectSpace(space);buildCue();quality(false)
    }
    func quality(_ high:Bool) {
        highDetail=high
        applyQuality()
    }
    /// Render cost only. The controller keeps the authoritative physics step and
    /// interpolation independent of thermal quality changes.
    /// 0.37: 0 full, 1 fewer shadow samples, 2 minimum — raised by the controller when frames are missed.
    private(set) var performanceLevel=0
    func setPerformanceLevel(_ level:Int){let l=max(0,min(2,level));guard l != performanceLevel else{return};performanceLevel=l;applyQuality()}
    func setThermalState(_ state:ProcessInfo.ThermalState){
        guard state != thermalState else{return};thermalState=state;applyQuality()
    }
    private func applyQuality(){
        let constrained=thermalState == .serious || thermalState == .critical
        let warm=thermalState == .fair
        let key="\(highDetail)-\(thermalState.rawValue)-\(performanceLevel)-\(Self.realShadows)"
        guard qualityKey != key else{return};qualityKey=key
        ballSegmentCount=constrained ? 24:(highDetail && !warm ? 64:48)
        for geometry in cachedBallGeometry.values{geometry.segmentCount=ballSegmentCount}
        // 0.39 (owner: cue shadow jagged, ball shadow not round/soft; floor streaks flicker; "the 0.19 build's ball
        // shadows were clear and beautiful"). 0.19 = balls only in the shadow map, wide radius, light shadow colour, 8 taps.
        // Now: ONLY balls cast (the thin cue aliased into a saw-tooth — it has its own soft projected shadow; floor/walls/
        // table never cast, so no acne stripes), 2048 map, radius 4, 8 taps on capable devices. Tuỳ chỉnh → Hình ảnh →
        // "Bóng bi thật" turns it off on weak/hot phones (the round contact shadow under each ball stays either way).
        let real=Self.realShadows && !constrained
        for node in nodes.values{node.castsShadow=real}
        scene.rootNode.enumerateHierarchy{node,_ in if node.parent !== ballRoot && node !== ballRoot {node.castsShadow=false}}
        tableRoot.enumerateHierarchy{node,_ in node.castsShadow=false}   // 0.37: table self-shadow = acne stripes on rail/apron + GPU cost
        roomRoot.enumerateHierarchy{node,_ in node.castsShadow=false}
        // 0.40b (owner photo: a ball's shadow on the FLOOR under the table). The table never casts (acne stripes), so the
        // ball shadows went straight through the slate onto the floor. An invisible slab just under the cloth casts into
        // the shadow map only: the floor gets the table's shadow, the cloth (above the slab) is never self-shadowed.
        if shadowOccluder.parent==nil {scene.rootNode.addChildNode(shadowOccluder)}
        shadowOccluder.castsShadow=real
        camera.camera?.screenSpaceAmbientOcclusionIntensity=0   // 0.35: full-screen SSAO pass removed (heat); contact shadows do the grounding
        camera.camera?.screenSpaceAmbientOcclusionRadius=0.035
        camera.camera?.screenSpaceAmbientOcclusionBias=0.003
        let size:CGFloat=constrained ? 512:(warm || performanceLevel>=2 ? 1024:2048)
        light.shadowMapSize=CGSize(width:size,height:size)
        #if targetEnvironment(simulator)
        light.shadowSampleCount=2   // CI Simulator GPU is very slow; 6–8 samples starved the runner (run 42514806011)
        #else
        light.shadowSampleCount=constrained || performanceLevel>=2 ? 2:(performanceLevel==0 && !warm ? 8:4)   // 0.39: only balls cast now, 8 taps are cheap again
        #endif
        light.castsShadow=real
    }
    private lazy var shadowOccluder:SCNNode = {
        // Bed + rails + wood (≈0.17 m each side), 4 cm thick, top 1.5 cm below the cloth.
        let g=SCNBox(width:1.27+0.36,height:0.04,length:2.54+0.36,chamferRadius:0)
        let m=SCNMaterial();m.colorBufferWriteMask=[];m.writesToDepthBuffer=false;m.readsFromDepthBuffer=false
        m.lightingModel = .constant;g.materials=[m]
        let n=SCNNode(geometry:g);n.name="shadow-occluder";n.position=SCNVector3(0,-0.035,0);return n
    }()
    static var realShadows:Bool{UserDefaults.standard.object(forKey:"tuneRealShadow039") as? Bool ?? true}
    private func mat(_ color:UIColor,roughness:CGFloat=0.6,metal:CGFloat=0)->SCNMaterial {
        let m=SCNMaterial();m.lightingModel = .physicallyBased;m.diffuse.contents=color
        m.roughness.contents=roughness;m.metalness.contents=metal
        m.shaderModifiers=[.fragment:Self.ditherModifier]   // 0.39: no 8-bit bands on any large flat surface (floors, runner, walls)
        return m
    }
    private func box(_ w:CGFloat,_ h:CGFloat,_ l:CGFloat,_ p:SCNVector3,_ material:SCNMaterial,chamfer:CGFloat=0.004,parent:SCNNode?=nil)->SCNNode {
        let g=SCNBox(width:w,height:h,length:l,chamferRadius:chamfer)
        g.chamferSegmentCount=3;g.materials=[material]
        let n=SCNNode(geometry:g);n.position=p;(parent ?? scene.rootNode).addChildNode(n);return n
    }
    private func buildLights(){
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient
        ambient.light?.color=UIColor(red:0.95,green:0.90,blue:0.82,alpha:1);ambient.light?.intensity=72
        scene.rootNode.addChildNode(ambient)
        // Emit below the visible fixture, so its housing does not block the key light.
        let key=SCNNode();key.position=SCNVector3(0,2.30,0);light=SCNLight();light.type = .spot
        light.intensity=52*Self.tune(Self.tuneLight);light.temperature=5000;light.spotInnerAngle=42;light.spotOuterAngle=112   // 0.35b: cooler LED like the reference club, less glare
        light.castsShadow=true;light.shadowMode = .forward;light.shadowRadius=3.0   // 0.39: 0.19-style soft round penumbra; 0.40b: 4 → 3 (owner: "mềm nhưng rõ, không lem")
        light.shadowColor=UIColor(white:0,alpha:min(0.9,0.50*Self.tune(Self.tuneShadow)));light.shadowBias=0.002
        key.name="premium-club-key";key.light=light;key.look(at:SCNVector3(0,0,0),up:SCNVector3(0,0,1),localFront:SCNVector3(0,0,-1));scene.rootNode.addChildNode(key)
        for x:Float in [-2.2,2.2]{
            let fill=SCNNode();fill.position=SCNVector3(x,1.7,0.8);fill.light=SCNLight();fill.light?.type = .omni
            fill.light?.intensity=24;fill.light?.temperature=4500
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
            // 0.36b ROOT CAUSE of "cloth near white / colour ignored" since 0.35b: UIGraphicsImageRendererContext.fill(_:)
            // draws with .copy (UIRectFill), ignoring setBlendMode — the whole texture became one flat grey, no hue, no
            // weave. Blend modes must be passed to fill(_:blendMode:). Albedo luminance = 0.80 × the chosen colour's.
            clothImage.draw(in:rect)
            var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0;color.getRed(&r,green:&g,blue:&b,alpha:&a)
            let base=max(0.05,Self.luminance(clothImage))
            let desired=max(0.04,min(0.9,(0.2126*r+0.7152*g+0.0722*b)*0.80*Self.tune(Self.tuneCloth)))
            if desired>base {UIColor(white:1,alpha:(desired-base)/(1-base)).setFill();c.fill(rect,blendMode:.normal)}
            color.setFill();c.fill(rect,blendMode:.color)
            if desired<base {UIColor(white:desired/base,alpha:1).setFill();c.fill(rect,blendMode:.multiply)}
        }
    }
    /// Average sRGB luminance of an image (1×1 resample).
    static func luminance(_ image:UIImage)->CGFloat{
        var px=[UInt8](repeating:0,count:4)
        guard let cg=image.cgImage,let ctx=CGContext(data:&px,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue) else{return 0.5}
        ctx.interpolationQuality = .medium;ctx.draw(cg,in:CGRect(x:0,y:0,width:1,height:1))
        return (0.2126*CGFloat(px[0])+0.7152*CGFloat(px[1])+0.0722*CGFloat(px[2]))/255
    }
    private func buildTable(_ rails:[[String:NSNumber]]){
        // 0.35 (owner: rail geometry may be shared, but colour and MATERIAL follow each brand): finish per model family.
        // Gloss lacquer: Z-Ra (Rasson OX / Acurra / Victory), Z-Di Smart, Z-Pr ARC; matte powder-coat: Z-Br Black Wolf;
        // brushed metal: Z-Max, Z-Pr APEX; satin: the rest. Wood tables keep the walnut maps tinted to the cabinet colour.
        let gloss:Set<String>=["ox","acurra","victory","smart","arc","zbarpro"],matte:Set<String>=["blackwolf","blackwolfpro","zbar"],brushed:Set<String>=["zmax","apex","tournament"]
        let graphite=look.wood ? premiumMaterial("WalnutDark"):mat(.rgb(look.cabinet),roughness:gloss.contains(look.id) ? 0.22:(matte.contains(look.id) ? 0.78:(brushed.contains(look.id) ? 0.38:0.5)),metal:brushed.contains(look.id) ? 0.35:0.08)
        if !look.wood && gloss.contains(look.id) {graphite.clearCoat.contents=0.8;graphite.clearCoatRoughness.contents=0.08}
        if look.wood {
            graphite.multiply.contents=UIColor.rgb(look.cabinet).blended(0.55)   // 0.35: brand wood tone (was one walnut for all)
            graphite.normal.contents=materialMap("PC_WalnutDark_normal"){self.clothNormal()};graphite.normal.intensity=0.08
            graphite.roughness.contents=materialMap("PC_WalnutDark_roughness"){self.clothNormal()}
            for channel in [graphite.diffuse,graphite.normal,graphite.roughness]{channel.minificationFilter = .linear;channel.mipFilter = .linear;channel.maxAnisotropy=16}
            graphite.clearCoat.contents=0.6;graphite.clearCoatRoughness.contents=0.12
        }
        // 0.39 (owner: the metal band around the table looks alien — real tables do not have it). The deck-edge band and
        // every base accent now use the cabinet finish itself, a touch darker and satin: the shape stays (shadow line,
        // foot plates) but there is no bright metal anywhere on the table body.
        let edge=(graphite.copy() as? SCNMaterial) ?? graphite
        edge.multiply.contents=(look.wood ? UIColor.rgb(look.cabinet).blended(0.55):UIColor.white).withAlphaComponent(1)
        edge.diffuse.intensity=0.82;edge.metalness.contents=look.wood ? 0:0.10;edge.clearCoat.contents=0
        let clothColor=clothTintIndex.map{Self.clothColors[$0].1} ?? .rgb(look.cloth)
        let cloth=mat(clothColor,roughness:0.97)
        cloth.diffuse.contents=clothAlbedo(clothColor)
        cloth.normal.contents=normalImage;cloth.normal.intensity=0.5
        applyFiberDetail(cloth)
        cloth.roughness.contents=materialMap("PC_FeltEmerald_roughness",fallback:{self.texture(CGSize(width:8,height:8)){c in UIColor(white:0.94,alpha:1).setFill();c.fill(CGRect(x:0,y:0,width:8,height:8))}});cloth.metalness.contents=0
        for channel in [cloth.diffuse,cloth.normal,cloth.roughness]{
            channel.wrapS = .repeat;channel.wrapT = .repeat
            // 0.21: the kit felt is a twill tile; at 1 tile per metre each twill rib was 2-4 cm wide and read as long
            // diagonal smears. Real worsted cloth has ~1 mm ribs: 24 tiles per metre (tile ~4 cm). Mip + 16x anisotropic
            // filtering average it out at distance, so the weave shows only close to the camera, as on a real table.
            channel.contentsTransform=SCNMatrix4MakeScale(1.615*24,2.895*24,1)
            channel.minificationFilter = .linear;channel.magnificationFilter = .linear
            channel.mipFilter = .linear;channel.maxAnisotropy=16
        }
        let bedCloth=cloth.copy() as! SCNMaterial
        bedCloth.multiply.contents=feltNapImage;bedCloth.multiply.wrapS = .clamp;bedCloth.multiply.wrapT = .clamp
        bedCloth.multiply.contentsTransform=SCNMatrix4Identity;bedCloth.multiply.mipFilter = .linear
        bedMaterial=bedCloth
        addMesh("bed",material:bedCloth)
        addMesh("deck",material:graphite)
        addMesh("trim",material:edge)
        // Split rails leave visible pocket apertures; apron is below the playing bed.
        for side:Float in [-1,1]{
            // Split cabinet panels around all six wells; continuous panels
            // previously appeared as wooden bars inside the pocket apertures.
            for z:Float in [-0.655,0.655]{_=box(0.10,0.21,1.01,SCNVector3(side*0.755,-0.16,z),graphite,chamfer:0.016)}
            _=box(1.03,0.21,0.10,SCNVector3(0,-0.16,side*1.3645),graphite,chamfer:0.016)
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
        for side:Float in [-1,1]{apronLogo(side)}
        // 0.37: the 1.5 mm cabinet joint strips were sub-pixel (vertical flicker bands on the apron) — removed.
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
        tableRoot.enumerateHierarchy{node,_ in node.castsShadow=false}   // 0.37: only balls/cue cast (acne stripes)
    }
    func setClothColor(_ index:Int?){clothTintIndex=index.map{max(0,min(Self.clothColors.count-1,$0))};selectTable(look)}
    private func buildBase(shell:SCNMaterial,trim:SCNMaterial){
        let dark=mat(UIColor(white:0.07,alpha:1),roughness:0.75)
        func beam(_ a:SCNVector3,_ b:SCNVector3,_ width:CGFloat,_ depth:CGFloat,_ material:SCNMaterial){
            let av=SIMD3<Float>(a.x,a.y,a.z),bv=SIMD3<Float>(b.x,b.y,b.z),d=bv-av
            let n=box(width,CGFloat(simd_length(d)),depth,SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2),material,chamfer:0.016)
            n.simdOrientation=simd_quatf(from:SIMD3(0,1,0),to:simd_normalize(d))
        }
        // 0.35 (owner: tables differ only by colour): three cabinet families, visible from the aim view and overview.
        if look.base==6 { // Bar-box: one solid body down to a plinth, coin door on the foot end.
            _=box(1.50,0.485,2.70,SCNVector3(0,-0.5075,0),shell,chamfer:0.03)
            _=box(1.58,0.05,2.78,SCNVector3(0,-0.735,0),dark,chamfer:0.012)
            _=box(0.34,0.17,0.014,SCNVector3(0,-0.43,1.357),trim,chamfer:0.01)
            _=box(0.16,0.022,0.006,SCNVector3(0,-0.40,1.366),dark,chamfer:0.003)
            for side:Float in [-1,1]{_=box(0.006,0.012,2.6,SCNVector3(side*0.753,-0.30,0),trim,chamfer:0.002)}
            return
        }
        if look.wood && [1,2,5].contains(look.base) { // Classic: skirt with a bead moulding and corner posts.
            for side:Float in [-1,1]{
                _=box(0.06,0.07,2.5,SCNVector3(side*0.79,-0.30,0),shell,chamfer:0.02)
                _=box(0.012,0.012,2.5,SCNVector3(side*0.822,-0.268,0),trim,chamfer:0.004)
                _=box(1.3,0.07,0.06,SCNVector3(0,-0.30,side*1.40),shell,chamfer:0.02)
                _=box(1.3,0.012,0.012,SCNVector3(0,-0.268,side*1.432),trim,chamfer:0.004)
            }
            for x:Float in [-0.80,0.80]{for z:Float in [-1.41,1.41]{_=box(0.13,0.30,0.13,SCNVector3(x,-0.21,z),shell,chamfer:0.03)}}
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
        // 0.40c (owner photo: cushions looked like puffy pillows). A real cushion is a rubber wedge under tight cloth: a
        // small rounded nose (~3 mm), then a STRAIGHT top sloping ~7° up to the wooden rail cap (deck starts 52 mm
        // behind the nose at 47 mm), and an undercut face back to the bed. The old profile bulged 19 mm over 5 cm and
        // floated 7 mm above the bed, leaving a lit sliver under the nose.
        let profile:[SIMD2<Float>]=[SIMD2(0,0.03629025),SIMD2(0.0007,0.0377),SIMD2(0.0022,0.0388),
            SIMD2(0.0045,0.0395),SIMD2(0.012,0.0405),SIMD2(0.030,0.0428),SIMD2(0.048,0.0452),
            SIMD2(0.053,0.0462),SIMD2(0.053,0.004),SIMD2(0.048,0.0005),SIMD2(0.014,0.0005),
            SIMD2(0.006,0.017),SIMD2(0.0015,0.030)]
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
        addCushionShade(points,rail:rail)
    }
    /// Shade levels for the cushion contact shadow: 1 on the long straights, rising towards the pocket jaws.
    private static let shadeLevels:[Float]=[1.0,1.22,1.45,1.7,1.95]
    private lazy var shadeMaterials:[SCNMaterial]=Self.shadeLevels.map{k in
        let m=SCNMaterial();m.lightingModel = .constant;m.blendMode = .alpha;m.writesToDepthBuffer=false;m.isDoubleSided=true
        // v: 0 under the cushion (occluded) · 0.35 nose line · 1 end of the soft falloff on the cloth.
        m.diffuse.contents=texture(CGSize(width:4,height:128),opaque:false){c in
            for y in 0..<128 {
                let v=Double(y)/127
                let a=v<0.35 ? 0.58:0.42*pow(1-(v-0.35)/0.65,2.0)
                UIColor.black.withAlphaComponent(CGFloat(min(0.95,a*Double(k)))).setFill();c.fill(CGRect(x:0,y:y,width:4,height:1))
            }}
        m.diffuse.wrapS = .clamp;m.diffuse.wrapT = .clamp;m.diffuse.minificationFilter = .linear;m.diffuse.mipFilter = .linear
        return m
    }
    /// 0.40c (owner: cushion shadow looked odd; wants it darker at the pockets so the opening reads on long shots).
    /// The contact shadow follows the real cushion line — straights AND jaw facings — from under the overhanging
    /// nose (fully occluded) to a soft 2.6 cm falloff on the cloth, and darkens towards each pocket mouth, framing the
    /// opening. Replaces the six 0.40b strips, which stopped short of the jaws and left a lit sliver under the nose.
    private func addCushionShade(_ points:[SIMD2<Float>],rail:Int){
        guard points.count>1 else{return}
        let outside:[SIMD2<Float>]=[SIMD2(-1,0),SIMD2(1,0),SIMD2(0,-1),SIMD2(0,1)]
        var dense:[SIMD2<Float>]=[points[0]]
        for i in 1..<points.count{
            let a=points[i-1],b=points[i],n=max(1,Int(ceil(simd_distance(a,b)/0.03)))
            for k in 1...n{dense.append(a+(b-a)*Float(k)/Float(n))}
        }
        func outward(_ a:SIMD2<Float>,_ b:SIMD2<Float>)->SIMD2<Float>{
            let d=simd_normalize(b-a);var n=SIMD2(d.y,-d.x);if simd_dot(n,outside[rail])<0{n = -n};return n
        }
        var miters:[SIMD2<Float>]=[]
        for i in dense.indices{
            let prev=outward(dense[max(0,i-1)],dense[max(1,i)]),next=outward(dense[min(i,dense.count-2)],dense[min(i+1,dense.count-1)])
            miters.append((prev+next)/max(0.5,1+simd_dot(prev,next)))
        }
        let pockets:[SIMD2<Float>]=[SIMD2(-0.67,-1.305),SIMD2(0.67,-1.305),SIMD2(-0.706,0),SIMD2(0.706,0),SIMD2(-0.67,1.305),SIMD2(0.67,1.305)]
        let under:Float=0.014,band:Float=0.026,y:Float=0.0011
        var buckets=[[SCNVector3]](repeating:[],count:Self.shadeLevels.count),coords=[[CGPoint]](repeating:[],count:Self.shadeLevels.count)
        for i in 0..<(dense.count-1){
            let mid=(dense[i]+dense[i+1])/2
            let d=pockets.map{simd_distance($0,mid)}.min() ?? 1
            let level=min(Self.shadeLevels.count-1,max(0,Int(((0.24-d)/0.16*Float(Self.shadeLevels.count-1)).rounded())))
            for (a,b,va,vb) in [(under,Float(0),0.0,0.35),(Float(0),-band,0.35,1.0)]{
                let p0=dense[i]+miters[i]*a,p1=dense[i+1]+miters[i+1]*a,p2=dense[i+1]+miters[i+1]*b,p3=dense[i]+miters[i]*b
                buckets[level]+=[SCNVector3(p0.x,y,p0.y),SCNVector3(p1.x,y,p1.y),SCNVector3(p2.x,y,p2.y),SCNVector3(p3.x,y,p3.y)]
                coords[level]+=[CGPoint(x:0,y:va),CGPoint(x:1,y:va),CGPoint(x:1,y:vb),CGPoint(x:0,y:vb)]
            }
        }
        for level in buckets.indices where !buckets[level].isEmpty{
            var indices:[Int32]=[]
            for q in 0..<(buckets[level].count/4){let b=Int32(q*4);indices+=[b,b+1,b+2,b,b+2,b+3]}
            let g=SCNGeometry(sources:[SCNGeometrySource(vertices:buckets[level]),SCNGeometrySource(textureCoordinates:coords[level])],
                              elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
            g.materials=[shadeMaterials[level]]
            let n=SCNNode(geometry:g);n.name="cushion-shade";n.castsShadow=false;n.renderingOrder=1
            scene.rootNode.addChildNode(n)
        }
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
        // 0.40b (owner: balls must stack in the pocket in arrival order, not all vanish at the bottom). A real drop pocket
        // cup is ~12 cm deep and ~18 cm wide (MEASURED on common club tables, ±2 cm; ASSUMED for the virtual WPA table):
        // three balls fit on the floor, the next three rest in the hollows above, the 7th+ show in the throat.
        let profile:[(radius:Float,y:Float)]=[(aperture-0.0002,0),(0.056,-0.022),(0.088,-0.055),(0.094,-0.090),(0.090,Self.pocketFloor)]
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
        let floor=SCNCylinder(radius:0.090,height:0.002);floor.materials=[leather]
        let floorNode=SCNNode(geometry:floor);floorNode.name="pocket-floor";floorNode.position=SCNVector3(x,Self.pocketFloor-0.001,z)
        scene.rootNode.addChildNode(floorNode)
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
    // ---- 0.34 không gian bàn ----------------------------------------------------------------------------------------
    static let spaces=["Club (mặc định)","Trong nhà","Ngoài trời","Cung điện","Hoàng gia","Thi đấu quốc tế","Club cổ điển"]
    /// Rebuilds the surroundings only (table, balls and table lights stay). Every room node lives under roomRoot.
    func selectSpace(_ k:Int){
        space=max(0,min(Self.spaces.count-1,k));UserDefaults.standard.set(space,forKey:"tableSpace034")
        roomRoot.childNodes.forEach{$0.removeFromParentNode()}
        let before=Set(scene.rootNode.childNodes.map{ObjectIdentifier($0)})
        switch space {
        case 1: buildHome()
        case 2: buildOutdoor()
        case 3: buildPalace()
        case 4: buildRoyal()
        case 5: buildArena()
        case 6: buildRoom()
        default: buildClub()
        }
        for node in scene.rootNode.childNodes where !before.contains(ObjectIdentifier(node)) && node !== roomRoot {roomRoot.addChildNode(node)}
    }
    /// Rectangular lamp over the table (visual; the table light itself is in buildLights).
    private func tableFixture(){
        let frame=mat(UIColor(white:0.09,alpha:1),roughness:0.3,metal:0.7)
        for x:Float in [-0.47,0.47]{_ = box(0.045,0.035,2.10,SCNVector3(x,2.45,0),frame)}
        for z:Float in [-1.03,1.03]{_ = box(0.98,0.035,0.045,SCNVector3(0,2.45,z),frame)}
        let diffuser=mat(UIColor(white:0.9,alpha:1));diffuser.emission.contents=UIColor(white:0.85,alpha:1)
        for x:Float in [-0.25,0.25]{_ = box(0.13,0.015,1.88,SCNVector3(x,2.43,0),diffuser)}
    }
    private func roomLamp(_ p:SCNVector3,_ intensity:CGFloat,_ kelvin:CGFloat,end:CGFloat=5){
        let lamp=SCNNode();lamp.light=SCNLight();lamp.light?.type = .omni;lamp.light?.intensity=intensity;lamp.light?.temperature=kelvin
        lamp.light?.castsShadow=false;lamp.light?.attenuationStartDistance=0.3;lamp.light?.attenuationEndDistance=end;lamp.position=p;scene.rootNode.addChildNode(lamp)
    }
    private func emissive(_ c:UIColor,_ glow:UIColor)->SCNMaterial{let m=mat(c,roughness:0.6);m.emission.contents=glow;return m}
    /// 0.39 (owner: the floor shows flickering stripes like the cloth did). Two causes, both fixed: the floor/walls cast
    /// and received the key-light shadow map (acne; shadow map now off and non-ball nodes never cast), and big smooth
    /// dark gradients band in 8-bit — same sub-level dithering as the cloth.
    static let ditherModifier="""
    float3 dp = floor(_surface.position * 2600.0);
    float n1 = fract(sin(dot(dp, float3(12.9898, 78.233, 37.719))) * 43758.5453);
    float n2 = fract(sin(dot(dp, float3(39.346, 11.135, 83.155))) * 24634.6345);
    _output.color.rgb *= 1.0 + (n1 + n2 - 1.0) * 0.018;
    """
    private func shell(floor:SCNMaterial,wall:SCNMaterial,height:Float=3.5){
        for m in [floor,wall] where m.shaderModifiers?[.fragment]==nil {m.shaderModifiers=[.fragment:Self.ditherModifier]}
        _=box(9,0.08,10,SCNVector3(0,-0.79,0),floor,chamfer:0)
        for side:Float in [-1,1]{
            _=box(0.09,CGFloat(height),10,SCNVector3(side*4,height/2-0.8,0),wall,chamfer:0)
            _=box(8,CGFloat(height),0.09,SCNVector3(0,height/2-0.8,side*4.7),wall,chamfer:0)
        }
    }
    /// Club like the owner's reference photo: grey textured walls, a wood-slat feature wall with warm LED strip,
    /// dark carpet, rectangular LED panels, neighbouring tables.
    private func buildClub(){
        tableFixture()
        scene.background.contents=UIColor(red:0.02,green:0.022,blue:0.026,alpha:1)
        let carpet=mat(UIColor(red:0.10,green:0.105,blue:0.115,alpha:1),roughness:0.98)
        let wall=mat(UIColor(red:0.33,green:0.34,blue:0.37,alpha:1),roughness:0.95);wall.normal.contents=normalImage;wall.normal.intensity=0.35
        wall.normal.wrapS = .repeat;wall.normal.wrapT = .repeat;wall.normal.contentsTransform=SCNMatrix4MakeScale(6,6,1)
        shell(floor:carpet,wall:wall,height:3.2)
        let ceiling=mat(UIColor(white:0.55,alpha:1),roughness:0.9);_=box(8,0.04,9.4,SCNVector3(0,2.42,0),ceiling,chamfer:0)
        let slat=premiumMaterial("WalnutDark")
        for i in 0..<28 {_=box(0.07,3.1,0.06,SCNVector3(-3.0+Float(i)*0.22,0.75,-4.62),slat,chamfer:0.004)}
        _=box(0.03,3.1,0.03,SCNVector3(-3.25,0.75,-4.6),emissive(.rgb(0xF2A65A),.rgb(0xE0903F)),chamfer:0)
        let panel=emissive(UIColor(white:0.95,alpha:1),UIColor(white:0.9,alpha:1))
        for x:Float in [-2.6,2.6]{for z:Float in [-3,0,3]{_=box(0.6,0.02,0.6,SCNVector3(x,2.39,z),panel,chamfer:0)}}
        for x:Float in [-2.6,2.6]{for z:Float in [-2.8,2.8]{neighbourTable(SCNVector3(x,0,z))}}
        roomLamp(SCNVector3(-2.6,2.2,0),30,5200,end:6);roomLamp(SCNVector3(2.6,2.2,0),30,5200,end:6);roomLamp(SCNVector3(-3,1.4,-4.3),14,2900,end:3)
    }
    private func neighbourTable(_ p:SCNVector3){
        let black=mat(UIColor(white:0.05,alpha:1),roughness:0.35),grey=mat(.rgb(0x6e767d),roughness:0.97),alu=mat(.rgb(0xc4c9cd),roughness:0.35,metal:0.8)
        _=box(1.55,0.18,2.85,SCNVector3(p.x,-0.10,p.z),black,chamfer:0.02)
        _=box(1.40,0.012,2.70,SCNVector3(p.x,0.0,p.z),grey,chamfer:0.004)
        _=box(1.58,0.02,2.88,SCNVector3(p.x,-0.005,p.z),alu,chamfer:0.006)
        for dx:Float in [-0.6,0.6]{for dz:Float in [-1.2,1.2]{_=box(0.14,0.6,0.14,SCNVector3(p.x+dx,-0.48,p.z+dz),black,chamfer:0.02)}}
    }
    /// Home: warm oak floor, cream walls, a sofa and a window of daylight.
    private func buildHome(){
        tableFixture()
        scene.background.contents=UIColor(red:0.05,green:0.045,blue:0.04,alpha:1)
        let floor=mat(.white,roughness:0.55);floor.diffuse.contents=woodTexture(light:true)
        floor.diffuse.wrapS = .repeat;floor.diffuse.wrapT = .repeat;floor.diffuse.contentsTransform=SCNMatrix4MakeScale(5,6,1)
        shell(floor:floor,wall:mat(.rgb(0xd9cfbf),roughness:0.9),height:2.9)
        _=box(8,0.04,9.4,SCNVector3(0,2.08,0),mat(UIColor(white:0.92,alpha:1)),chamfer:0)
        let sofa=mat(.rgb(0x5a4a3c),roughness:0.95)
        _=box(2.4,0.45,0.85,SCNVector3(0,-0.52,3.9),sofa,chamfer:0.08);_=box(2.4,0.55,0.22,SCNVector3(0,-0.2,4.25),sofa,chamfer:0.08)
        _=box(2.2,1.4,0.04,SCNVector3(3.95,0.7,0),emissive(UIColor(red:0.75,green:0.85,blue:0.95,alpha:1),UIColor(red:0.55,green:0.65,blue:0.75,alpha:1)),chamfer:0)
        _=box(1.6,0.9,0.05,SCNVector3(0,0.9,-4.62),emissive(.rgb(0x2a2f36),.rgb(0x101418)),chamfer:0.01)   // TV / painting
        roomLamp(SCNVector3(3.4,1.2,0),45,6500,end:5);roomLamp(SCNVector3(-2.5,1.8,2.5),20,3000,end:4)
    }
    /// Outdoors: wooden deck, low glass rail, sky and sun.
    private func buildOutdoor(){
        scene.background.contents=UIColor(red:0.42,green:0.62,blue:0.86,alpha:1)
        let deck=mat(.white,roughness:0.7);deck.diffuse.contents=woodTexture(light:true)
        deck.diffuse.wrapS = .repeat;deck.diffuse.wrapT = .repeat;deck.diffuse.contentsTransform=SCNMatrix4MakeScale(6,8,1)
        _=box(9,0.08,10,SCNVector3(0,-0.79,0),deck,chamfer:0)
        _=box(40,0.02,40,SCNVector3(0,-0.9,0),mat(.rgb(0x4f7a3a),roughness:1),chamfer:0)   // lawn beyond the deck
        let glass=mat(UIColor(white:0.9,alpha:0.25),roughness:0.05);glass.transparency=0.25
        for side:Float in [-1,1]{_=box(0.03,0.9,10,SCNVector3(side*4.4,-0.3,0),glass,chamfer:0);_=box(8.8,0.9,0.03,SCNVector3(0,-0.3,side*5),glass,chamfer:0)}
        for z:Float in [-4,4]{for x:Float in [-3.8,3.8]{let pot=mat(.rgb(0x3c5f2c),roughness:0.95);let n=SCNNode(geometry:SCNSphere(radius:0.45));n.geometry?.materials=[pot];n.position=SCNVector3(x,-0.3,z);scene.rootNode.addChildNode(n)}}
        let sun=SCNNode();sun.light=SCNLight();sun.light?.type = .directional;sun.light?.intensity=170;sun.light?.temperature=5600
        sun.eulerAngles=SCNVector3(-1.0,0.6,0);scene.rootNode.addChildNode(sun)
    }
    /// Palace: white marble floor, columns, gold mouldings, chandeliers.
    private func buildPalace(){
        tableFixture()
        scene.background.contents=UIColor(red:0.08,green:0.07,blue:0.06,alpha:1)
        let marble=mat(UIColor(white:0.58,alpha:1),roughness:0.25);marble.normal.contents=normalImage;marble.normal.intensity=0.05
        shell(floor:marble,wall:mat(.rgb(0x8f826c),roughness:0.7),height:4.5)
        let gold=premiumMaterial("ChampagneGold")
        for side:Float in [-1,1]{
            for z:Float in [-3.6,-1.2,1.2,3.6]{let c=SCNCylinder(radius:0.18,height:4.4);c.radialSegmentCount=48;c.materials=[mat(UIColor(white:0.70,alpha:1),roughness:0.35)]
                let n=SCNNode(geometry:c);n.position=SCNVector3(side*3.5,1.4,z);scene.rootNode.addChildNode(n)
                _=box(0.5,0.12,0.5,SCNVector3(side*3.5,3.55,z),gold,chamfer:0.02);_=box(0.5,0.12,0.5,SCNVector3(side*3.5,-0.7,z),gold,chamfer:0.02)}
            _=box(8,0.08,0.06,SCNVector3(0,2.6,side*4.62),gold,chamfer:0.01)
        }
        for z:Float in [-2.2,2.2]{
            let crystal=emissive(UIColor(white:1,alpha:1),.rgb(0xfff2d0))
            for k in 0..<10 {let a=Float(k)/10*Float.pi*2;let n=SCNNode(geometry:SCNSphere(radius:0.04));n.geometry?.materials=[crystal];n.position=SCNVector3(cos(a)*0.35,2.9,z+sin(a)*0.35);scene.rootNode.addChildNode(n)}
            _=box(0.8,0.04,0.8,SCNVector3(0,3.05,z),gold,chamfer:0.02);roomLamp(SCNVector3(0,2.9,z),20,3400,end:6)
        }
    }
    /// Royal: deep red carpet, dark carved panels, gold trims, crest, warm sconces.
    private func buildRoyal(){
        tableFixture()
        scene.background.contents=UIColor(red:0.03,green:0.015,blue:0.012,alpha:1)
        let carpet=mat(.rgb(0x5a0f14),roughness:0.97),panel=premiumMaterial("WalnutDark"),gold=premiumMaterial("ChampagneGold")
        shell(floor:carpet,wall:panel,height:3.8)
        for side:Float in [-1,1]{
            for x:Float in [-3,-1.5,0,1.5,3]{_=box(1.2,1.6,0.03,SCNVector3(x,0.4,side*4.62),panel,chamfer:0.02);_=box(1.24,0.03,0.04,SCNVector3(x,1.22,side*4.6),gold,chamfer:0.003);_=box(1.24,0.03,0.04,SCNVector3(x,-0.42,side*4.6),gold,chamfer:0.003)}
            for z:Float in [-3,0,3]{_=box(0.04,0.4,0.2,SCNVector3(side*3.93,1.3,z),gold,chamfer:0.01);roomLamp(SCNVector3(side*3.7,1.4,z),12,2600,end:3)}
        }
        let crest=SCNNode(geometry:SCNCylinder(radius:0.4,height:0.03));crest.geometry?.materials=[gold];crest.eulerAngles.x = .pi/2;crest.position=SCNVector3(0,1.8,-4.6);scene.rootNode.addChildNode(crest)
        _=box(2.4,0.02,5.6,SCNVector3(0,-0.745,0),mat(.rgb(0x7a1a1f),roughness:0.95),chamfer:0)   // runner under the table
    }
    /// International arena: dark venue, spotlight on the table, LED boards, tiered seating, scoreboard screen.
    private func buildArena(){
        tableFixture()
        scene.background.contents=UIColor(red:0.005,green:0.006,blue:0.01,alpha:1)
        let floor=mat(.rgb(0x15233a),roughness:0.8)
        _=box(14,0.08,16,SCNVector3(0,-0.79,0),floor,chamfer:0)
        let seat=mat(.rgb(0x1a1d24),roughness:0.9)
        for tier in 0..<5 {let t=Float(tier)
            for side:Float in [-1,1]{_=box(0.9,0.35,12,SCNVector3(side*(4.2+t*0.9),-0.6+t*0.35,0),seat,chamfer:0.01);_=box(10,0.35,0.9,SCNVector3(0,-0.6+t*0.35,side*(5.4+t*0.9)),seat,chamfer:0.01)}}
        let led=emissive(.rgb(0x0b1f3a),.rgb(0x1d6fd6))
        for side:Float in [-1,1]{_=box(0.05,0.35,6,SCNVector3(side*3.3,-0.55,0),led,chamfer:0);_=box(5,0.35,0.05,SCNVector3(0,-0.55,side*4.3),led,chamfer:0)}
        _=box(3.2,1.2,0.08,SCNVector3(0,3.0,-6.5),emissive(.rgb(0x101010),.rgb(0x2a2a2a)),chamfer:0.02)
        let spot=SCNNode();spot.light=SCNLight();spot.light?.type = .spot;spot.light?.intensity=320;spot.light?.temperature=5000
        spot.light?.spotInnerAngle=30;spot.light?.spotOuterAngle=55;spot.position=SCNVector3(0,4.2,0);spot.eulerAngles.x = -.pi/2;scene.rootNode.addChildNode(spot)
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
        // Warm, visible club backdrop instead of an unlit empty horizon.
        let panel=premiumMaterial("WalnutDark")
        let brass=premiumMaterial("ChampagneGold")
        let glow=mat(.rgb(0xDAB876),roughness:0.7);glow.emission.contents=UIColor.rgb(0x997344)
        for side:Float in [-1,1]{
            _=box(7.8,0.9,0.035,SCNVector3(0,-0.28,side*4.63),panel,chamfer:0.003)
            _=box(7.8,0.012,0.045,SCNVector3(0,0.18,side*4.60),brass,chamfer:0.001)
            for x:Float in [-2.6,-1.3,0,1.3,2.6]{
                _=box(0.028,0.76,0.04,SCNVector3(x,-0.27,side*4.59),brass,chamfer:0.002)
            }
            for x:Float in [-2.4,2.4]{
                _=box(0.20,0.50,0.045,SCNVector3(x,0.85,side*4.58),brass,chamfer:0.015)
                _=box(0.13,0.40,0.06,SCNVector3(x,0.85,side*4.54),glow,chamfer:0.02)
                let lamp=SCNNode();lamp.light=SCNLight();lamp.light?.type = .omni
                lamp.light?.intensity=18;lamp.light?.temperature=3200;lamp.light?.castsShadow=false
                lamp.light?.attenuationStartDistance=0.2;lamp.light?.attenuationEndDistance=4
                lamp.position=SCNVector3(x,0.9,side*4.2);scene.rootNode.addChildNode(lamp)
            }
        }
        // Rectangular light fixture and matching reflection cards in environment map.
        let frame=mat(UIColor(white:0.09,alpha:1),roughness:0.3,metal:0.7)
        for x:Float in [-0.47,0.47]{_ = box(0.045,0.035,2.10,SCNVector3(x,2.45,0),frame)}
        for z:Float in [-1.03,1.03]{_ = box(0.98,0.035,0.045,SCNVector3(0,2.45,z),frame)}
        let diffuser=mat(UIColor(white:0.9,alpha:1));diffuser.emission.contents=UIColor(white:0.85,alpha:1)
        for x:Float in [-0.25,0.25]{_ = box(0.13,0.015,1.88,SCNVector3(x,2.43,0),diffuser)}
    }
    /// 0.35: Massé uses the playing cue but is drawn in its own colours, so each of the four cue icons looks different.
    var masseLook=false
    func selectCue(_ type:Int){
        let next=max(0,min(2,type)),appearance=CueBag.cue(type),key=appearance.id+(masseLook && next==0 ? "-masse":"")
        if cueType==next && cueLookID==key && !cueRoot.childNodes.isEmpty{return}
        cueType=next;cueRoot.childNodes.forEach{$0.removeFromParentNode()};buildCue();cueLookID=key
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
        if let base=premiumCue(appearance.id),let geometry=base.copy() as? SCNGeometry{
            // 0.35 (owner: the cue must change look with the cue chosen): the kit meshes share one set of wood/carbon
            // maps, so every cue looked the same. Tint butt/forearm with the cue's colour and the rings with its accent.
            let masse=masseLook && cueType==0
            let body=UIColor.rgb(masse ? 0x6a1820:appearance.color),trim=UIColor.rgb(masse ? 0xd0d4d8:appearance.accent)
            geometry.materials=base.materials.map{source in
                let m=(source.copy() as? SCNMaterial) ?? source
                switch source.name {
                case "Ebony","Carbon":m.multiply.contents=body
                case "Wrap":m.multiply.contents=body.withAlphaComponent(1).blended(0.35)
                case "Gold":m.multiply.contents=trim
                default:break
                }
                return m
            }
            let node=SCNNode(geometry:geometry);node.name="premium-cue-"+appearance.id;node.castsShadow=false
            if cueType==1 {node.scale=SCNVector3(1,0.72,1)}   // jump cue is short (1.044 m), as the clearance model assumes
            cueRoot.addChildNode(node)
            cueRoot.addChildNode(domeTip(scale:cueType==1 ? 0.72:1,kind:cueType))
            return
        }
        let scale:CGFloat=cueType==1 ? 0.72:(cueType==2 ? 1.015:1.0)
        // Local +Y points to the tip; full 1.45 m cue, separate leather/ferrule/shaft/joint/wrap/butt.
        func section(_ start:CGFloat,_ length:CGFloat,_ tipRadius:CGFloat,_ buttRadius:CGFloat,_ material:SCNMaterial){
            let g=SCNCone(topRadius:tipRadius,bottomRadius:buttRadius,height:length*scale);g.radialSegmentCount=48;g.materials=[material]
            let node=SCNNode(geometry:g);node.position.y = -Float((start+length/2)*scale);node.castsShadow=false;cueRoot.addChildNode(node)
        }
        let maple=mat(appearance.carbon ? UIColor(white:0.12,alpha:1):UIColor.white,roughness:0.42)
        if !appearance.carbon {maple.diffuse.contents=woodTexture(light:true)}
        let ebony=mat(.rgb(masseLook && cueType==0 ? 0x6a1820:appearance.color),roughness:0.30)
        let ring=mat(.rgb(appearance.accent),roughness:0.3,metal:0.5)
        cueRoot.addChildNode(domeTip(scale:1,kind:cueType))
        section(0.0045,0.0165,0.0059,0.0060,mat(UIColor(red:0.93,green:0.91,blue:0.81,alpha:1),roughness:0.23))
        section(0.021,0.704,0.006,0.0105,maple)
        section(0.725,0.025,0.0105,0.0107,ring)
        section(0.75,0.23,0.0107,0.013,ebony)
        let wrap=mat(UIColor(white:0.07,alpha:1),roughness:0.88);wrap.normal.contents=normalImage;wrap.normal.intensity=0.08
        section(0.98,0.30,0.013,0.0142,wrap)
        section(1.28,0.155,0.0142,0.0147,ebony)
        section(1.435,0.005,0.0147,0.0147,ring)
        section(1.44,0.010,0.0147,0.0147,mat(.black))
    }
    /// 0.39: leather tip, 12.2 mm diameter, 4.5 mm tall, domed to a 9.5 mm radius (between "dime" and "nickel"),
    /// apex at local y = 0 (the contact point used by cuePose). Lathe mesh with true dome normals, chalk-blue leather.
    static let tipDomeRadius:Float=0.0095,tipRadius:Float=0.0061
    /// 0.41 (owner): jump and break cues have HARD phenolic tips — milky white (break) or solid black (jump), glossy,
    /// never chalk-blue leather; their dome is flatter (harder tips are shaped to a larger radius).
    private func domeTip(scale:Float,kind:Int=0)->SCNNode{
        let rd=kind==0 ? Self.tipDomeRadius:0.0125,rt=Self.tipRadius,sag=rd-(rd*rd-rt*rt).squareRoot(),bottom:Float = -0.0045
        var profile:[(r:Float,y:Float,nr:Float,ny:Float)]=[(0,0,0,1)]
        for k in 1...10 {let r=rt*Float(k)/10,y = -(rd-(rd*rd-r*r).squareRoot());profile.append((r,y,r/rd,(rd+y)/rd))}
        profile.append((rt,-sag,1,0));profile.append((rt,bottom,1,0));profile.append((0,bottom,0,-1))
        var v:[SCNVector3]=[],n:[SCNVector3]=[],idx:[Int32]=[];let seg=40
        for i in 0...seg {let a=Float(i)/Float(seg)*2*Float.pi,c=cos(a),s=sin(a)
            for q in profile {v.append(SCNVector3(q.r*c,q.y,q.r*s));n.append(SCNVector3(q.nr*c,q.ny,q.nr*s))}}
        let m=Int32(profile.count)
        for i in 0..<Int32(seg){for j in 0..<(m-1){let a=i*m+j,b=a+m;idx+=[a,b,a+1,a+1,b,b+1]}}
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:v),SCNGeometrySource(normals:n)],elements:[SCNGeometryElement(indices:idx,primitiveType:.triangles)])
        let leather:SCNMaterial
        if kind==2 {
            leather=mat(UIColor(red:0.94,green:0.93,blue:0.89,alpha:1),roughness:0.16)   // milky phenolic
            leather.clearCoat.contents=0.9;leather.clearCoatRoughness.contents=0.05
            leather.transparency=0.9;leather.transparencyMode = .dualLayer
        }else if kind==1 {
            leather=mat(UIColor(white:0.06,alpha:1),roughness:0.2);leather.clearCoat.contents=0.8;leather.clearCoatRoughness.contents=0.06
        }else{leather=mat(.rgb(0x1E4F6E),roughness:0.92)}
        leather.isDoubleSided=true;g.materials=[leather]
        let node=SCNNode(geometry:g);node.name="cue-tip";node.castsShadow=false;node.scale=SCNVector3(1,scale,1);return node
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
            // Dark warm club room; the bright fixture cards on the ceiling face
            // remain, so balls/lacquer keep crisp highlights without flat fill.
            let top:CGFloat=face==2 ? 0.16:0.12,bottom:CGFloat=face==3 ? 0.05:0.07
            let colors=[UIColor(red:top*1.10,green:top,blue:top*0.82,alpha:1).cgColor,UIColor(red:bottom*1.12,green:bottom,blue:bottom*0.80,alpha:1).cgColor] as CFArray
            if let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,1]){
                ctx.drawLinearGradient(g,start:CGPoint(x:0,y:0),end:CGPoint(x:0,y:512),options:[])
            }
            if face==2 {
                ctx.setShadow(offset:.zero,blur:24,color:UIColor(white:0.85,alpha:1).cgColor)
                UIColor(white:0.96,alpha:1).setFill()
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
    /// 0.39 (owner: ball shadow must be round, soft and smooth): two Gaussian layers in units of the ball radius R —
    /// a dark core where the ball nearly touches the cloth (σ≈0.55R) and a wide penumbra from the lamp's size (σ≈1.3R) —
    /// faded to exactly zero at the plane edge (2.2R). Built per pixel with sub-level noise in alpha, so the dark-on-dark
    /// gradient has no 8-bit rings.
    private func contactShadowTexture()->UIImage{
        let n=256,half=Double(n)/2
        var bytes=[UInt8](repeating:0,count:n*n*4)
        var seed:UInt64=0x9E3779B97F4A7C15
        func noise()->Double{seed=seed &* 6364136223846793005 &+ 1442695040888963407;return Double((seed>>33)%10_000)/10_000}
        for y in 0..<n{for x in 0..<n{
            let dx=(Double(x)+0.5-half)/half*2.2,dy=(Double(y)+0.5-half)/half*2.2,r=(dx*dx+dy*dy).squareRoot()
            let edge=max(0,1-pow(r/2.2,4))
            let a=(0.80*exp(-r*r/(2*0.55*0.55))+0.34*exp(-r*r/(2*1.3*1.3)))*edge
            let v=min(255,max(0,a*255+(noise()+noise()-1)))
            let k=(y*n+x)*4;bytes[k+3]=UInt8(v)   // premultiplied black: rgb 0
        }}
        let space=CGColorSpaceCreateDeviceRGB()
        guard let provider=CGDataProvider(data:Data(bytes) as CFData),
              let image=CGImage(width:n,height:n,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:n*4,space:space,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent)
        else{return UIImage()}
        return UIImage(cgImage:image)
    }
    private func diamond(_ p:SCNVector3,shortRail:Bool=false){
        let t=Float(Self.tune(Self.tuneDiamond)),long:Float=0.028*t,wide:Float=0.013*t   // 0.36: Tuỳ chỉnh · độ nổi kim cương
        let dx=shortRail ? long/2:wide/2,dz=shortRail ? wide/2:long/2
        let vertices=[SCNVector3(-dx,0,0),SCNVector3(0,0,-dz),SCNVector3(dx,0,0),SCNVector3(0,0,dz)]
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:Array(repeating:SCNVector3(0,1,0),count:4))],elements:[SCNGeometryElement(indices:[Int32(0),1,2,0,2,3],primitiveType:.triangles)])
        let m=mat(.rgb(0xF6F0E2),roughness:0.22,metal:0);m.isDoubleSided=true;m.emission.contents=UIColor(red:0.30,green:0.29,blue:0.27,alpha:1);m.emission.intensity=CGFloat(max(0.3,min(3,t*t)))
        m.clearCoat.contents=1;m.clearCoatRoughness.contents=0.05;g.materials=[m]
        let n=SCNNode(geometry:g);n.position=p;n.name="rail-sight";n.castsShadow=false;scene.rootNode.addChildNode(n)
        let inlay=SCNNode(geometry:g.copy() as? SCNGeometry);inlay.geometry?.materials=[mat(.rgb(0x1A0E07),roughness:0.5)]
        inlay.scale=SCNVector3(1.45,1,1.45);inlay.position.y = -0.0004;inlay.castsShadow=false;n.addChildNode(inlay)
        n.position.y += 0.0008
    }
    /// 0.34: brand wordmark on each long apron, toward the foot end, as on the owner's reference table.
    private func apronLogo(_ side:Float){
        let g=SCNPlane(width:0.34,height:0.11),m=SCNMaterial();m.lightingModel = .physicallyBased;m.roughness.contents=0.5
        m.diffuse.contents=texture(CGSize(width:1024,height:330)){c in
            UIColor.clear.setFill();c.fill(CGRect(x:0,y:0,width:1024,height:330))
            let style=NSMutableParagraphStyle();style.alignment = .center
            let base=UIFont.systemFont(ofSize:178,weight:.black);let font=base.fontDescriptor.withSymbolicTraits(.traitItalic).map{UIFont(descriptor:$0,size:178)} ?? base
            (self.look.brand.uppercased() as NSString).draw(in:CGRect(x:0,y:0,width:1024,height:230),withAttributes:[.font:font,.foregroundColor:UIColor(white:0.96,alpha:1),.paragraphStyle:style,.kern:6])
            ("B I L L I A R D S" as NSString).draw(in:CGRect(x:0,y:236,width:1024,height:80),withAttributes:[.font:UIFont.systemFont(ofSize:54,weight:.semibold),.foregroundColor:UIColor(white:0.9,alpha:1),.paragraphStyle:style])
        }
        m.transparencyMode = .aOne;m.isDoubleSided=false
        g.materials=[m];let n=SCNNode(geometry:g);n.name="apron-logo";n.castsShadow=false
        n.position=SCNVector3(side*0.8115,-0.165,0.62);n.eulerAngles.y = side>0 ? .pi/2 : -.pi/2;scene.rootNode.addChildNode(n)
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
        applyBallFinish(material)
        sphere.materials=[material];cachedBallGeometry[id]=sphere;return sphere
    }
    private lazy var ballShadowGeometry:SCNPlane = {
        let plane=SCNPlane(width:CGFloat(radius*4.4),height:CGFloat(radius*4.4)),material=SCNMaterial()   // 0.39: ±2.2 R, see contactShadowTexture
        material.lightingModel = .constant;material.diffuse.contents=shadowTexture;material.diffuse.mipFilter = .linear
        material.writesToDepthBuffer=false;material.readsFromDepthBuffer=true;material.blendMode = .alpha
        plane.materials=[material];return plane
    }()
    /// 0.39: the contact shadow sits where the key lamp (2.30 m over the table centre) projects the ball centre, so it
    /// leans slightly outward towards the rails like a real overhead light, and drifts away as a jumped ball rises.
    private func shadowCenter(_ planar:SIMD2<Float>,_ height:Double?)->SIMD3<Float>{
        let h=Float(radius)+Float(height ?? 0),f=2.30/max(0.3,2.30-h)
        return SIMD3<Float>(planar.x*f,0.001,planar.y*f)
    }
    private func setPosition(_ position:SCNVector3,on node:SCNNode){
        let old=node.position
        if old.x != position.x || old.y != position.y || old.z != position.z{node.position=position}
    }
    // ---- 0.28: racking intro (owner request: 3-5 s at the start of each game; hands/rack only, no 3D person) ----
    private let introRoot=SCNNode()
    private var introDone:(()->Void)?
    var rackIntroPlaying:Bool{introDone != nil}
    /// Wooden triangle drops over loosely placed balls, the balls are pushed tight into the final rack positions
    /// (exactly the solver's layout), the triangle lifts off. ~3.4 s; skipRackIntro() ends it at once.
    func playRackIntro(_ balls:[BallState],completion:@escaping ()->Void){
        skipRackIntro();introDone=completion
        if introRoot.parent==nil{scene.rootNode.addChildNode(introRoot)}
        let objects=balls.filter{$0.id>0 && !$0.sunk}
        guard !objects.isEmpty else{finishRackIntro();return}
        ballRoot.isHidden=true
        let r=Float(radius),cx=objects.map{Float($0.x)}.reduce(0,+)/Float(objects.count),cy=objects.map{Float($0.y)}.reduce(0,+)/Float(objects.count)
        var seed:UInt64=0x5AC4
        func jitter()->Float{seed=seed &* 6364136223846793005 &+ 1442695040888963407;return Float(Int((seed>>33)%2001)-1000)/1000}
        for b in balls where !b.sunk {
            let node=SCNNode(geometry:ballGeometry(b.id));node.eulerAngles=SCNVector3(0.18,0.6,0.2)
            let target=SCNVector3(Float(b.x),r,Float(b.y))
            if b.id==0{node.position=target;introRoot.addChildNode(node);continue}
            // loose start: spread 0-2 cm outward from the rack centre plus a little noise (hand-placed)
            let dx=Float(b.x)-cx,dy=Float(b.y)-cy,len=max(0.001,sqrt(dx*dx+dy*dy))
            let spread:Float=0.012+0.008*abs(jitter())
            node.position=SCNVector3(Float(b.x)+dx/len*spread+0.004*jitter(),r,Float(b.y)+dy/len*spread+0.004*jitter())
            introRoot.addChildNode(node)
            let tighten=SCNAction.move(to:target,duration:0.9);tighten.timingMode = .easeInEaseOut
            node.runAction(.sequence([.wait(duration:0.9),tighten]))
        }
        // triangle: three wooden bars around the rack, built from the actual rack extent
        let xs=objects.map{Float($0.x)},ys=objects.map{Float($0.y)}
        let minX=xs.min()!-r-0.006,maxX=xs.max()!+r+0.006,minY=ys.min()!-r-0.006,maxY=ys.max()!+r+0.006
        let apexAtLow=abs(ys.min()!-cy)>abs(ys.max()!-cy)   // apex = the single-ball row
        let apexRowY:Float=apexAtLow ? ys.min()!:ys.max()!
        var apexX:Float=cx
        for b in objects where abs(Float(b.y)-apexRowY)<0.01 {apexX=Float(b.x)}
        let apex=SIMD2<Float>(apexX,apexAtLow ? minY-r*0.8:maxY+r*0.8)
        let baseY=apexAtLow ? maxY:minY
        let corners=[apex,SIMD2<Float>(minX-r*0.5,baseY),SIMD2<Float>(maxX+r*0.5,baseY)]
        let wood=premiumMaterial("WalnutDark")
        let triangle=SCNNode()
        for i in 0..<3 {
            let a=corners[i],b=corners[(i+1)%3],mid=(a+b)/2,d=b-a,length=simd_length(d)
            let bar=SCNNode(geometry:SCNBox(width:CGFloat(length)+0.02,height:0.026,length:0.016,chamferRadius:0.004))
            bar.geometry?.materials=[wood];bar.position=SCNVector3(mid.x,0.013,mid.y);bar.eulerAngles.y = -atan2(d.y,d.x)
            triangle.addChildNode(bar)
        }
        triangle.position=SCNVector3(0,0.30,0);triangle.opacity=0;introRoot.addChildNode(triangle)
        let drop=SCNAction.group([.move(to:SCNVector3(0,0,0),duration:0.7),.fadeIn(duration:0.4)]);drop.timingMode = .easeOut
        let push=SCNAction.sequence([.moveBy(x:0,y:0,z:CGFloat(apexAtLow ? 0.008:-0.008),duration:0.45),.moveBy(x:0,y:0,z:CGFloat(apexAtLow ? -0.008:0.008),duration:0.45)])
        let lift=SCNAction.group([.move(by:SCNVector3(0,0.35,0),duration:0.8),.fadeOut(duration:0.8)]);lift.timingMode = .easeIn
        triangle.runAction(.sequence([drop,.wait(duration:0.2),push,.wait(duration:0.35),lift])){[weak self] in DispatchQueue.main.async{self?.finishRackIntro()}}
    }
    func skipRackIntro(){if introDone != nil{finishRackIntro()}}
    private func finishRackIntro(){
        introRoot.childNodes.forEach{$0.removeAllActions();$0.removeFromParentNode()}
        ballRoot.isHidden=false
        let done=introDone;introDone=nil;done?()
    }

    /// True while balls are in motion under pacing (live shot, replay, guest playout). Set by the controller.
    var pacingOwner:(()->Bool)?
    func update(_ balls:[BallState],dt:Double){
        SCNTransaction.begin();SCNTransaction.animationDuration=0;SCNTransaction.disableActions=true
        defer{SCNTransaction.commit()}
        let pacedAt:Double? = FramePacer.enabled ? presentAt:nil
        // 0.39d ROOT CAUSE (live only): any update outside the display tick during motion — refresh() from a key,
        // the spin pad, a score/turn change — used to CLEAR the pacer. The next frame then snapped to the newest sample
        // (jump) and held it while history refilled (repeat): a visible hitch exactly when the player touches anything.
        // Replay never calls refresh mid-motion, so it stayed smooth. While balls move the pacer owns them; an off-tick
        // update may change shadows/opacity but never their transforms.
        let pacerOwns = pacedAt==nil && pacer.isActive && (pacingOwner?() ?? false)
        if pacedAt==nil && !pacerOwns {pacer.clear()}
        let ids=Set(balls.map{$0.id})
        for id in Array(nodes.keys) where !ids.contains(id){
            pacer.remove(id)
            nodes.removeValue(forKey:id)?.removeFromParentNode()
            contactShadows.removeValue(forKey:id)?.removeFromParentNode()
            restOrientations.removeValue(forKey:id);falling.removeValue(forKey:id);settledPocketNodes.remove(id)
            lastPlanar.removeValue(forKey:id);planarVelocity.removeValue(forKey:id)
        }
        for b in balls{
            let node:SCNNode
            if let old=nodes[b.id]{node=old}else{
                node=SCNNode(geometry:ballGeometry(b.id));node.name="ball_\(b.id)"
                node.castsShadow=Self.realShadows && thermalState != .serious && thermalState != .critical
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
                pacer.remove(b.id)
                if falling[b.id]==nil{
                    let previous=lastPlanar[b.id]
                    // 0.39d (code audit): while the pacer draws 1.5 frames behind the solver, start the fall from where
                    // the ball is SHOWN, not from the newest solver sample — otherwise it skips forward as it drops.
                    let shown=SIMD2<Float>(node.simdPosition.x,node.simdPosition.z)
                    let from=pacer.isActive && node.simdPosition.y>0 ? shown:(previous ?? planar)
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
            if !pacerOwns {lastPlanar[b.id]=planar}
            let ballAt=SIMD3<Float>(planar.x,Float(radius)+Float(b.height ?? 0),planar.y)
            if pacedAt==nil && !pacerOwns {setPosition(SCNVector3(ballAt),on:node)}
            if let shadow=contactShadows[b.id]{
                if shadow.isHidden{shadow.isHidden=false}
                if pacedAt==nil && !pacerOwns {setPosition(SCNVector3(shadowCenter(planar,b.height)),on:shadow)}
                let height=Float(b.height ?? 0)
                let shade=CGFloat(max(0.05,1.0/(1+height*13)))*min(1,Self.tune(Self.tuneShadow))*(Self.realShadows ? 0.75:1)   // 0.39: map shadow adds the penumbra
                if shadow.opacity != shade{shadow.opacity=shade}
                let spread:Float=0.92+height*1.6
                if shadow.scale.x != spread{shadow.scale=SCNVector3(spread,spread,spread)}
            }
            // Reflection XY -> XZ maps quaternion axis (x,y,z) to (-x,-z,-y).
            if let x=b.qx,let y=b.qy,let z=b.qz,let w=b.qw {
                let physical=simd_quatf(ix:Float(-x),iy:Float(-z),iz:Float(-y),r:Float(w))
                let rest=restOrientations[b.id] ?? simd_quatf(angle:0,axis:SIMD3<Float>(0,1,0))
                let orientation=physical*rest
                if let t=pacedAt {
                    pacer.push(id:b.id,node:node,shadow:contactShadows[b.id],time:t,position:ballAt,orientation:orientation,shadowAt:shadowCenter(planar,b.height),spin:SIMD3<Float>(Float(-b.wx),Float(-b.spin),Float(-b.wy)))   // same axis map as the quaternion
                }else if !pacerOwns && node.simdOrientation.vector != orientation.vector{node.simdOrientation=orientation}
            }else if let t=pacedAt {
                pacer.push(id:b.id,node:node,shadow:contactShadows[b.id],time:t,position:ballAt,orientation:node.simdOrientation,shadowAt:shadowCenter(planar,b.height))
            }
        }
    }
    /// Call before loading a layout, starting another replay or seeking. Already
    /// sunk initial-state balls park immediately on the next update.
    func resetPocketPresentation(){
        pacer.clear() // Layout/seek must not blend with an old shot.
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
        // 0.40b: arrival order stacks like a real cup — 3 balls in a triangle on the floor, the next 3 in the hollows
        // above (rotated 60°), then the throat. The triangle is turned toward the table so the top layer stays visible.
        let slot=max(0,min(15,state.slot)),layer=min(2,slot/3),ring=slot%3
        let r=Float(radius),spacing=2*r+0.0008
        let circum=spacing/Float(3).squareRoot()                       // triangle centre → ball centre
        let rise=(spacing*spacing-circum*circum).squareRoot()          // hollow-to-hollow height between layers
        let inward=atan2(-center.y,-center.x)                          // toward the table centre
        let parkingAngle=inward+Float(ring)*2*Float.pi/3+(layer%2==1 ? Float.pi/3:0)+(slot>=9 ? 0.4:0)
        let parking=SIMD2<Float>(cos(parkingAngle),sin(parkingAngle))*(layer==2 ? circum*0.6:circum)
        let floorHeight:Float = Self.pocketFloor+r+0.0005+Float(layer)*rise
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
    func replay(_ from:[BallState],to:[BallState],fraction:Double,span:Double=0){
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
                var q=simd_slerp(qa,qb,Float(t))
                // 0.35: a fast ball turns > 180° between 30 Hz samples, so a shortest-path slerp spun it backwards in
                // slow motion. Integrate the recorded angular velocity (same left-multiplied world-frame convention
                // as Physics.cpp rotate) and spread the small end-point residual over the interval.
                let w=SIMD3<Float>(Float((a.wx+b.wx)/2),Float((a.wy+b.wy)/2),Float((a.spin+b.spin)/2)),mag=simd_length(w)
                if span>0 && mag*Float(span)>0.2 {
                    let axis=w/mag,full=Float(span)*mag
                    let end=simd_quatf(angle:full,axis:axis)*qa
                    let residual=qb*end.inverse
                    q=simd_normalize(simd_slerp(simd_quatf(angle:0,axis:SIMD3<Float>(0,0,1)),residual,Float(t))*simd_quatf(angle:full*Float(t),axis:axis)*qa)
                }
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
        let fieldOfView:Float = cameraMode==2 ? Float(UserDefaults.standard.object(forKey:"tuneAimFOV038") as? Double ?? 38):46   // 0.38: Tuỳ chỉnh · góc nhìn ngắm
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
            // 0.29 (owner): zoom slides the eye along ONE fixed axis through the cue ball, and the cue ball stays at
            // the centre of the screen at every zoom (was: look 0.75 m past it, so it drifted when zooming).
            target=SIMD3<Float>(Float(c.x),Float(radius),Float(c.y))
        }else{
            // 0.29: watching the opponent orbits a FIXED pivot (table centre), not a moving shot frame.
            let bounds=spectatorPivot ? SIMD4<Float>(-0.78,0.78,-1.43,1.43):(focusBounds ?? SIMD4<Float>(-0.78,0.78,-1.43,1.43))
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
    private func cuePose(_ c:BallState,angle:Double,side:Double,top:Double)->(contact:SIMD3<Float>,axis:SIMD3<Float>,tipBack:Float){
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
        // Rear-hand point remains fixed while the selected tip point moves: it sets the HORIZONTAL stroke direction.
        let pivot=center-axis*(cueType==1 ? 0.80:1.12)
        let raw=contact-pivot,flatLength=sqrt(raw.x*raw.x+raw.z*raw.z)
        let flat=flatLength>1e-6 ? SIMD3<Float>(raw.x/flatLength,0,raw.z/flatLength):d
        // 0.35 (owner: the cue still goes through the ball and the table). The pitch is the selected elevation, not the
        // pivot→tip line: a high tip no longer tilts the butt down into the rail, and a low tip on a level cue gets the
        // tiny lift that keeps the 14.7 mm butt above the cloth.
        let length:Float=cueType==1 ? 1.044:1.45
        let lift=asin(max(0,min(0.5,(0.0150-contact.y)/length)))
        let pitch=max(elevation,lift)
        // 0.39: domed tip (radius Rd) on the ball (radius R) with the apex on the contact: the dome clears the ball once
        // stood off by the largest overlap of the tilted ball surface and the dome, max over ρ ≤ tip radius of
        // ρ·tanθ − ρ²(1/R+1/Rd)/2  (θ = angle between the cue and the surface normal). Much less than the old flat r·tanθ.
        let s2=min(Float(0.95),x*x+y*y),tanT=sqrt(s2)/sqrt(1-s2),k=1/Float(radius)+1/(cueType==0 ? Self.tipDomeRadius:Float(0.0125))
        let rho=min(Self.tipRadius,tanT/k),tipBack=max(0,rho*tanT-rho*rho*k/2)
        return (contact,simd_normalize(flat*cos(pitch)-SIMD3<Float>(0,1,0)*sin(pitch)),tipBack)
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
        cueRoot.simdPosition=pose.contact-pose.axis*(Float(0.003+pull*0.16)+pose.tipBack)
        cueRoot.simdOrientation=simd_quatf(from:SIMD3(0,1,0),to:pose.axis)
        if ProcessInfo.processInfo.arguments.contains("--visual-qa"){
            let tip=cueRoot.convertPosition(SCNVector3(0,Float(0.003+pull*0.16)+pose.tipBack,0),to:nil)
            precondition(simd_distance(SIMD3(tip.x,tip.y,tip.z),pose.contact)<0.00001,"Cue geometry must reach selected surface contact")
        }
        updateCueShadow()
    }
    /// 0.39 (owner: with the cue ball near a rail the raised cue hides the line of aim and the object ball): fade the cue
    /// to a ghost while — on screen — it covers the aim line in front of the cue ball (first 1.2 m) or the object ball.
    /// Views where the line is visible keep a solid cue. Pure screen-space test, so it works for any camera/elevation.
    private var cueFade:Float=1
    func updateCueFade(view:SCNView,cue:BallState?,angle:Double,target:SIMD2<Float>?,dt:Double){
        var want:Float=1
        if Tuning.flag("tuneCueFade039",true),!cueRoot.isHidden,let c=cue {
            func screen(_ p:SIMD3<Float>)->SIMD3<Float>{let v=view.projectPoint(SCNVector3(p));return SIMD3<Float>(v.x,v.y,v.z)}
            let length:Float=cueType==1 ? 1.044:1.45
            let tipW=cueRoot.convertPosition(SCNVector3(0,0,0),to:nil)
            let tip=screen(SIMD3(tipW.x,tipW.y,tipW.z))
            // 0.40b (owner photo: aim view, solid black cue over the object ball): in the low aim view the butt is BEHIND
            // the camera and its projection is garbage, so the old test never fired. Use the farthest cue point that is
            // still in front of the camera.
            var buttW=tipW
            for along in stride(from:Float(0.05),through:length*0.7,by:0.05){
                let w=cueRoot.convertPosition(SCNVector3(0,-along,0),to:nil);let q=screen(SIMD3(w.x,w.y,w.z))
                if q.z>0&&q.z<1 {buttW=w} else {break}
            }
            let butt=screen(SIMD3(buttW.x,buttW.y,buttW.z))
            let right=simd_normalize(simd_cross(SIMD3<Float>(0,1,0),simd_normalize(SIMD3(buttW.x-tipW.x,buttW.y-tipW.y,buttW.z-tipW.z))+SIMD3(0.0001,0,0)))
            let edge=screen(SIMD3(tipW.x,tipW.y,tipW.z)+right*0.009)
            let halfWidth=max(4,simd_distance(SIMD2(edge.x,edge.y),SIMD2(tip.x,tip.y)))+6
            let a=SIMD2(tip.x,tip.y),b=SIMD2(butt.x,butt.y),ab=b-a,len2=max(1,simd_length_squared(ab))
            let start=SIMD3<Float>(Float(c.x),Float(radius),Float(c.y)),d=SIMD3<Float>(Float(cos(angle)),0,Float(sin(angle)))
            var points:[SIMD3<Float>]=stride(from:Float(0.08),through:1.2,by:0.08).map{start+d*$0}
            if let t=target {points.append(SIMD3(t.x,Float(radius),t.y))}
            var hidden=0
            for p in points {
                let q=screen(p);guard q.z>0,q.z<1 else{continue}
                let u=max(0,min(1,simd_dot(SIMD2(q.x,q.y)-a,ab)/len2)),closest=a+ab*u
                let depth=tip.z+(butt.z-tip.z)*u   // cue in front of the point?
                if simd_distance(SIMD2(q.x,q.y),closest)<halfWidth && depth<q.z {hidden+=1}
            }
            // Owner 12/11: "đừng trong quá, vừa thấy để ngắm bi đích là được" → a see-through but still visible cue.
            if hidden>=2 || !(tip.z>0&&tip.z<1) {want=Float(Tuning.value("tuneCueGhost040",0.42))}
        }
        let k=Float(min(1,dt*10));cueFade+=(want-cueFade)*k
        if abs(cueRoot.opacity-CGFloat(cueFade))>0.004 {cueRoot.opacity=CGFloat(cueFade)}
    }
    private lazy var cueShadowMaterial:SCNMaterial = {
        let m=SCNMaterial();m.lightingModel = .constant;m.blendMode = .alpha
        m.writesToDepthBuffer=false;m.isDoubleSided=true
        // x: across the shadow (soft gaussian edge); y: height of the cue above the cloth (0 = touching, 1 = 30 cm) —
        // a raised cue throws a fainter, wider shadow.
        m.diffuse.contents=texture(CGSize(width:128,height:32),opaque:false){c in
            for y in 0..<32 {let lift=Double(y)/31
                for x in 0..<128 {let u=(Double(x)-63.5)/(22+14*lift);let a=0.26*(1-0.65*lift)*exp(-u*u/2)
                    UIColor.black.withAlphaComponent(CGFloat(a)).setFill();c.fill(CGRect(x:x,y:y,width:1,height:1))}}
        };m.diffuse.mipFilter = .linear;m.diffuse.minificationFilter = .linear   // 0.39: no saw-tooth when the cue shadow is thin on screen
        return m
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
        // 0.40b (owner: cue shadow smeared / broken into pieces). It was 64 separate quads whose edges did not meet
        // (each had its own width), so seams and gaps showed. Now ONE continuous strip: shared vertices, width and
        // softness growing with the cue's height above the cloth (penumbra), fading as it rises; clipped to the bed.
        for i in 0...64 {
            let t=length*Float(i)/64,w=cueRoot.convertPosition(SCNVector3(0,-t,0),to:nil)
            let a=project(t)
            guard abs(a.x)<0.625,abs(a.z)<1.26 else{if !vertices.isEmpty{break};continue}
            let ahead=project(min(length,t+0.02)),behind=project(max(0,t-0.02))
            let d=ahead-behind;guard simd_length(d)>0.00001 else{continue}
            let h=max(0,w.y)
            let side=simd_normalize(SIMD3(-d.z,0,d.x))*(0.011+Float(i)/64*0.010+h*0.06)
            vertices.append(SCNVector3(a.x-side.x,a.y,a.z-side.z));vertices.append(SCNVector3(a.x+side.x,a.y,a.z+side.z))
            let fade=CGFloat(min(1,h/0.30));uv += [CGPoint(x:0,y:fade),CGPoint(x:1,y:fade)]
        }
        if vertices.count>=4 {for k in 0..<(vertices.count/2-1){let b=Int32(2*k);indices += [b,b+1,b+3,b,b+3,b+2]}}
        else {vertices.removeAll()}
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
    // 0.36 "Điểm ngắm": analytic aim guide, updated every frame (no async simulation, no 0.3 s throttle).
    // Cue line to the ghost ball, ghost ring, object-ball direction, cue-ball tangent (stun) line.
    private lazy var aimGuideNodes:[SCNNode] = {
        let line=SCNMaterial();line.lightingModel = .constant;line.diffuse.contents=UIColor(white:1,alpha:0.85);line.writesToDepthBuffer=false
        let object=line.copy() as! SCNMaterial;object.diffuse.contents=UIColor.rgb(0xEAC583).withAlphaComponent(0.9)
        let tangent=line.copy() as! SCNMaterial;tangent.diffuse.contents=UIColor(white:1,alpha:0.38)
        var made:[SCNNode]=[]
        line.diffuse.contents=Self.guideColor
        let w=0.0024*Self.tune(Self.tuneGuideWidth)
        for m in [line,object,tangent]{let g=SCNBox(width:1,height:0.0005,length:w,chamferRadius:0);g.materials=[m];let n=SCNNode(geometry:g);n.isHidden=true;n.renderingOrder=5;scene.rootNode.addChildNode(n);made.append(n)}
        let ring=SCNTorus(ringRadius:radius,pipeRadius:0.0011);ring.materials=[line];ring.ringSegmentCount=48
        let r=SCNNode(geometry:ring);r.isHidden=true;r.renderingOrder=5;scene.rootNode.addChildNode(r);made.append(r)
        return made
    }()
    private func segment(_ n:SCNNode,_ a:SIMD2<Float>,_ b:SIMD2<Float>){
        let d=b-a,l=simd_length(d);guard l>0.002 else{n.isHidden=true;return}
        n.isHidden=false;n.position=SCNVector3((a.x+b.x)/2,0.0035,(a.y+b.y)/2);n.scale=SCNVector3(l,1,1);n.eulerAngles=SCNVector3(0,atan2(-d.y,d.x),0)
    }
    /// Planar table coordinates (x across, y along). nil hides the guide.
    func aimGuide(cue:SIMD2<Float>?,ghost:SIMD2<Float> = .zero,object:SIMD2<Float>? = nil,objectEnd:SIMD2<Float>? = nil,tangentEnd:SIMD2<Float>? = nil,ringVisible:Bool = false){
        SCNTransaction.begin();SCNTransaction.disableActions=true;defer{SCNTransaction.commit()}
        let n=aimGuideNodes
        guard let cue=cue else{for x in n{x.isHidden=true};return}
        segment(n[0],cue,ghost)
        if let o=object,let e=objectEnd{segment(n[1],o,e)}else{n[1].isHidden=true}
        if let t=tangentEnd{segment(n[2],ghost,t)}else{n[2].isHidden=true}
        n[3].isHidden = !ringVisible;n[3].position=SCNVector3(ghost.x,0.0035,ghost.y)
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
                let width:SIMD3<Float> = unit*Float(0.0011*Self.tune(Self.tuneGuideWidth))
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
            material.diffuse.contents=id==0 ? Self.guideColor.withAlphaComponent(0.6):UIColor(red:0.95,green:0.60,blue:0.10,alpha:0.65)
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

private extension UIColor {
    /// Mix toward white: 0 = white, 1 = the colour itself (keeps a tint subtle on the wrap).
    func blended(_ amount:CGFloat)->UIColor{
        var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0;getRed(&r,green:&g,blue:&b,alpha:&a)
        return UIColor(red:1-(1-r)*amount,green:1-(1-g)*amount,blue:1-(1-b)*amount,alpha:1)
    }
}
