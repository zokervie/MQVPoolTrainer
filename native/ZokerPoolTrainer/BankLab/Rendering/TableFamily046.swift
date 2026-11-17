import SceneKit
import UIKit

/// 0.46 M3 — table bodies per family, built in code (no external models). The bed, cushions, pockets and sights above
/// y = −0.055 m stay the shared 9 ft WPA mesh; everything here is below the rail: skirt details and the base.
/// Cabinet frame (outer skirt): x ±0.80 m, z ±1.44 m, from y −0.055 to −0.325; floor at y −0.80 (as before 0.46).
extension TableScene {
    static let familyFloor:Float = -0.80
    static let familySkirtBottom:Float = -0.325

    private func node(_ g:SCNGeometry,_ p:SCNVector3,_ m:SCNMaterial)->SCNNode {
        g.materials=[m];let n=SCNNode(geometry:g);n.position=p;scene.rootNode.addChildNode(n);return n
    }
    /// Round tube between two points (steel legs, beads).
    @discardableResult
    func familyTube(_ a:SIMD3<Float>,_ b:SIMD3<Float>,radius:CGFloat,_ m:SCNMaterial)->SCNNode {
        let d=b-a,len=simd_length(d)
        let g=SCNCylinder(radius:radius,height:CGFloat(len));g.radialSegmentCount=32
        let n=node(g,SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2),m)
        n.simdOrientation=simd_quatf(from:SIMD3(0,1,0),to:simd_normalize(d))
        return n
    }
    func familyMetal(_ look:TableLook)->SCNMaterial {
        let m=mat(.rgb(look.trim),roughness:0.36,metal:0.85);m.clearCoat.contents=0;return m
    }

    /// Skirt details: corner caps (metal / wood blocks), carved bead along the skirt foot.
    func buildFamilySkirtDetail(_ look:TableLook,shell:SCNMaterial,trim:SCNMaterial){
        let f=look.family,bottom=Self.familySkirtBottom
        switch f.cornerCaps {
        case 1:   // Arena: brushed metal corner caps wrapping the skirt corners
            let metal=familyMetal(look)
            for x:Float in [-1,1]{for z:Float in [-1,1]{
                _=box(0.07,0.275,0.07,SCNVector3(x*0.772,-0.19,z*1.412),metal,chamfer:0.004)
            }}
        case 2:   // Heritage / Club: proud wood corner blocks
            for x:Float in [-1,1]{for z:Float in [-1,1]{
                _=box(0.10,0.285,0.10,SCNVector3(x*0.765,-0.19,z*1.405),shell,chamfer:0.012)
                if f == .heritage {   // turned rosette on each block's end face
                    let r=SCNCylinder(radius:0.026,height:0.012);r.radialSegmentCount=32
                    let n=node(r,SCNVector3(x*0.765,-0.17,z*1.457),trim);n.eulerAngles.x = .pi/2
                }
            }}
        default: break
        }
        if f.bead {   // simple carved bead: half-round mouldings at the skirt foot (+ a second one high on Heritage)
            let levels:[Float]=f == .heritage ? [bottom+0.008,-0.075]:[bottom+0.008]
            for y in levels {for s:Float in [-1,1]{
                familyTube(SIMD3(s*0.801,y,-1.40),SIMD3(s*0.801,y,1.40),radius:0.011,shell)
                familyTube(SIMD3(-0.76,y,s*1.441),SIMD3(0.76,y,s*1.441),radius:0.011,shell)
            }}
        }
    }

    /// Base per family: 0 square box legs · 1 turned legs · 2 steel A-frames · 3 twin pedestals.
    func buildFamilyBase(_ look:TableLook,shell:SCNMaterial,trim:SCNMaterial){
        let floor=Self.familyFloor,top=Self.familySkirtBottom
        let foot=mat(UIColor(white:0.05,alpha:1),roughness:0.6)
        switch look.family {
        case .arena:
            // Square box legs, flush with the metal corner caps, metal foot band + levelling pad.
            let metal=familyMetal(look),h=top-floor-0.03
            for x:Float in [-1,1]{for z:Float in [-1,1]{
                let leg=taperedLeg(top:SIMD2(0.23,0.23),bottom:SIMD2(0.21,0.21),height:h,material:shell)
                leg.position=SCNVector3(x*0.69,top-h/2,z*1.33);scene.rootNode.addChildNode(leg)
                _=box(0.215,0.035,0.215,SCNVector3(x*0.69,floor+0.045,z*1.33),metal,chamfer:0.004)
                _=box(0.19,0.03,0.19,SCNVector3(x*0.69,floor+0.015,z*1.33),foot,chamfer:0.004)
            }}
        case .heritage:
            // Turned round legs: square block, collar with brass ring, vase, bulb, taper, foot.
            for x:Float in [-1,1]{for z:Float in [-1,1]{
                let cx=x*0.69,cz=z*1.33
                _=box(0.17,0.10,0.17,SCNVector3(cx,top-0.05,cz),shell,chamfer:0.01)
                let collar=SCNCylinder(radius:0.085,height:0.03);collar.radialSegmentCount=48;_=node(collar,SCNVector3(cx,top-0.115,cz),shell)
                let ring=SCNTorus(ringRadius:0.085,pipeRadius:0.007);ring.ringSegmentCount=48;_=node(ring,SCNVector3(cx,top-0.13,cz),trim)
                let vase=SCNCone(topRadius:0.065,bottomRadius:0.10,height:0.12);vase.radialSegmentCount=48;_=node(vase,SCNVector3(cx,top-0.19,cz),shell)
                let bulb=SCNSphere(radius:0.105);bulb.segmentCount=48;_=node(bulb,SCNVector3(cx,top-0.29,cz),shell)
                let taper=SCNCone(topRadius:0.085,bottomRadius:0.05,height:0.12)   // ends on the pad at the floor;taper.radialSegmentCount=48;_=node(taper,SCNVector3(cx,top-0.40,cz),shell)
                let pad=SCNCylinder(radius:0.06,height:0.015);pad.radialSegmentCount=40;_=node(pad,SCNVector3(cx,floor+0.0075,cz),foot)
            }}
        case .loft:
            // Steel tube A-frames at each end, foot rail, one long stretcher; mounting plates under the cabinet.
            let steel=familyMetal(look),r:CGFloat=0.024
            for z:Float in [-1.02,1.02]{
                _=box(0.56,0.02,0.14,SCNVector3(0,top-0.01,z),steel,chamfer:0.004)
                for s:Float in [-1,1]{familyTube(SIMD3(s*0.22,top-0.02,z),SIMD3(s*0.64,floor+0.03,z),radius:r,steel)}
                familyTube(SIMD3(-0.68,floor+0.03,z),SIMD3(0.68,floor+0.03,z),radius:r,steel)   // foot rail
                familyTube(SIMD3(-0.475,-0.60,z),SIMD3(0.475,-0.60,z),radius:r*0.8,steel)        // A crossbar (meets the legs)
                for s:Float in [-1,1]{_=box(0.06,0.012,0.08,SCNVector3(s*0.66,floor+0.006,z),foot,chamfer:0.003)}
            }
            familyTube(SIMD3(0,-0.60,-1.02),SIMD3(0,-0.60,1.02),radius:r,steel)                   // stretcher
        case .club:
            // Twin pedestals: capital, column with trim inlay, broad plinth; low stretcher between them.
            for z:Float in [-0.95,0.95]{
                _=box(0.64,0.05,0.42,SCNVector3(0,top-0.025,z),shell,chamfer:0.012)
                let colTop=top-0.05,colBottom=floor+0.10
                _=box(0.44,CGFloat(colTop-colBottom),0.30,SCNVector3(0,(colTop+colBottom)/2,z),shell,chamfer:0.02)
                for s:Float in [-1,1]{_=box(0.30,0.012,0.004,SCNVector3(0,(colTop+colBottom)/2,z+s*0.151),trim,chamfer:0.002)}
                _=box(1.20,0.08,0.46,SCNVector3(0,floor+0.06,z),shell,chamfer:0.02)
                _=box(1.22,0.02,0.48,SCNVector3(0,floor+0.01,z),foot,chamfer:0.006)
            }
            _=box(0.16,0.10,1.60,SCNVector3(0,floor+0.20,0),shell,chamfer:0.016)
        }
    }
}

/// 0.46 M3: library icons rendered from the real 3D table (same approach as CueIcon0441), cached in memory and in
/// Caches/table-icons-*.png. nil without Metal (the caller keeps a drawn fallback).
enum TableIcon046 {
    static let version = "046a"
    private static var memory: [String: UIImage] = [:]
    private static let renderer: SCNRenderer? = {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        return SCNRenderer(device: device, options: nil)
    }()
    private static func file(_ key: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("table-icons-" + key + ".png")
    }
    private static func key(_ look: TableLook, _ size: CGSize) -> String { "\(version)-\(look.id)-\(Int(size.width))x\(Int(size.height))" }
    /// Cached icon only (memory or disk) — never renders.
    static func cached(_ look: TableLook, size: CGSize) -> UIImage? {
        let k = key(look, size)
        if let m = memory[k] { return m }
        if let data = try? Data(contentsOf: file(k)), let image = UIImage(data: data, scale: 2) { memory[k] = image; return image }
        return nil
    }
    static func image(_ look: TableLook, table: TableScene, size: CGSize) -> UIImage? {
        if let c = cached(look, size: size) { return c }
        guard let renderer = renderer else { return nil }
        let scene = table.tableStudio(table.tableModel(look))
        let eye = SCNNode(); eye.camera = SCNCamera(); eye.camera?.zNear = 0.05; eye.camera?.zFar = 20; eye.camera?.fieldOfView = 34
        eye.camera?.wantsHDR = true; eye.camera?.wantsExposureAdaptation = false; eye.camera?.exposureOffset = -1.25
        eye.position = SCNVector3(2.9, 1.55, 3.4); eye.look(at: SCNVector3(0, -0.30, 0)); scene.rootNode.addChildNode(eye)
        renderer.scene = scene; renderer.pointOfView = eye
        let raw = renderer.snapshot(atTime: 0, with: CGSize(width: size.width * 2, height: size.height * 2), antialiasingMode: .multisampling4X)
        renderer.scene = nil
        guard let cg = raw.cgImage else { return nil }
        let image = UIImage(cgImage: cg, scale: 2, orientation: .up).withRenderingMode(.alwaysOriginal)
        let k = key(look, size); memory[k] = image
        if let data = image.pngData() { try? data.write(to: file(k), options: .atomic) }
        return image
    }
}
