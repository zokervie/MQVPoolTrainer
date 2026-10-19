// Cảnh 3D: bàn, bi, cơ, đường ngắm, nhãn nút, camera 2D/3D.
import * as THREE from 'three';
import { RoomEnvironment } from '../vendor/RoomEnvironment.js';
import { R, L, W, CUSHIONS, POCKETS } from './table.js';
import { DIAMOND_OFF, railPoint } from './systems.js';
import { ballTexture, clothTexture, woodTexture, textTexture } from './textures.js';

const CUSH_BACK = 0.05;      // độ dày băng tính từ mũi băng
const RAIL_W = 0.115;        // bề rộng mặt gỗ
const WOOD_TOP = 0.047;
const CUSH_TOP = 0.044;

export const CLOTH_COLORS = { blue: '#1f5d9e', green: '#1d6e45', teal: '#156b70', red: '#8e2430', grey: '#5d6670' };

export class Scene3D {
  constructor(canvas) {
    this.canvas = canvas;
    const r = this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    r.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    r.shadowMap.enabled = true;
    r.shadowMap.type = THREE.PCFShadowMap;
    r.toneMapping = THREE.ACESFilmicToneMapping;
    r.toneMappingExposure = 1.05;
    r.outputColorSpace = THREE.SRGBColorSpace;

    const s = this.scene = new THREE.Scene();
    s.background = new THREE.Color('#10161c');
    s.fog = new THREE.Fog('#10161c', 6, 14);
    const pm = new THREE.PMREMGenerator(r);
    s.environment = pm.fromScene(new RoomEnvironment(), 0.04).texture;
    s.environmentIntensity = 0.55;

    this.persp = new THREE.PerspectiveCamera(45, 1, 0.02, 40);
    this.ortho = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 20);
    this.ortho.position.set(0, 6, 0);
    this.mode = '3d';
    this.portrait = false;

    // camera quỹ đạo quanh bi cái
    this.cam = { yaw: 0, pitch: 0.32, dist: 1.0, target: new THREE.Vector3(), overview: 0 };
    this.camCur = { pos: new THREE.Vector3(-2, 1.5, 0), look: new THREE.Vector3() };

    this.buildLights();
    this.buildRoom();
    this.table = new THREE.Group(); s.add(this.table);
    this.setCloth('blue');
    this.ballMeshes = new Map();
    this.ballGeo = new THREE.SphereGeometry(R, 48, 32);
    this.buildCue();
    this.guides = new THREE.Group(); s.add(this.guides);
    this.labels = new THREE.Group(); s.add(this.labels);
    this.zones = new THREE.Group(); s.add(this.zones);
    this.ghost = new THREE.Mesh(this.ballGeo, new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.28, depthWrite: false }));
    this.ghost.visible = false; s.add(this.ghost);
    const ring = new THREE.Mesh(new THREE.RingGeometry(R * 0.96, R * 1.04, 48), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.8, depthWrite: false }));
    ring.rotation.x = -Math.PI / 2; ring.position.y = -R + 0.0015; this.ghost.add(ring);
    this.raycaster = new THREE.Raycaster();
    this.plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -R);
    this.resize();
  }

  // ---------------- dựng cảnh ----------------
  buildLights() {
    const s = this.scene;
    s.add(new THREE.HemisphereLight('#c9d6e3', '#2a1d14', 0.35));
    const key = new THREE.DirectionalLight('#fff4e0', 1.5);
    key.position.set(0.3, 3.2, 0.5);
    key.castShadow = true;
    key.shadow.mapSize.set(2048, 2048);
    const sc = key.shadow.camera; sc.left = -1.6; sc.right = 1.6; sc.top = 1.0; sc.bottom = -1.0; sc.near = 1; sc.far = 5;
    key.shadow.bias = -0.0004; key.shadow.normalBias = 0.01; key.shadow.radius = 4;
    s.add(key);
    for (const x of [-0.85, 0, 0.85]) {
      const p = new THREE.PointLight('#ffe7c2', 0.55, 3.5, 2);
      p.position.set(x, 1.05, 0); s.add(p);
    }
  }

  buildRoom() {
    const s = this.scene;
    // sàn
    const floorTex = woodTexture('#2b211b'); floorTex.repeat.set(10, 10);
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(30, 30), new THREE.MeshStandardMaterial({ map: floorTex, roughness: 0.7, color: '#8a7a6c' }));
    floor.rotation.x = -Math.PI / 2; floor.position.y = -0.78; floor.receiveShadow = true; s.add(floor);
    // đèn bàn
    const lamp = new THREE.Group();
    const shade = new THREE.Mesh(new THREE.BoxGeometry(1.9, 0.07, 0.28), new THREE.MeshStandardMaterial({ color: '#1b2a24', roughness: 0.5, metalness: 0.4 }));
    lamp.add(shade);
    const glow = new THREE.Mesh(new THREE.PlaneGeometry(1.82, 0.22), new THREE.MeshBasicMaterial({ color: '#fff3d6' }));
    glow.rotation.x = Math.PI / 2; glow.position.y = -0.036; lamp.add(glow);
    for (const x of [-0.7, 0.7]) {
      const rod = new THREE.Mesh(new THREE.CylinderGeometry(0.004, 0.004, 2), new THREE.MeshStandardMaterial({ color: '#666', metalness: 0.8, roughness: 0.3 }));
      rod.position.set(x, 1.0, 0); lamp.add(rod);
    }
    lamp.position.set(0, 1.12, 0); s.add(lamp);
    this.lamp = lamp;
  }

  setCloth(name) {
    const col = CLOTH_COLORS[name] || name;
    this.clothColor = col;
    this.table.clear();
    const t = this.table;
    const clothMat = new THREE.MeshStandardMaterial({ color: col, map: clothTexture(), roughness: 0.92, metalness: 0 });
    const cushMat = new THREE.MeshStandardMaterial({ color: new THREE.Color(col).multiplyScalar(0.92), map: clothTexture(), roughness: 0.9 });
    const woodMat = new THREE.MeshPhysicalMaterial({ map: woodTexture('#4a2b17'), color: '#b08a70', roughness: 0.5, clearcoat: 0.35, clearcoatRoughness: 0.35, envMapIntensity: 0.6 });
    const darkWood = new THREE.MeshStandardMaterial({ map: woodTexture('#2e1d12'), roughness: 0.5 });
    const pocketMat = new THREE.MeshBasicMaterial({ color: '#050506', side: THREE.DoubleSide });

    // mặt vải có lỗ
    const HL = L / 2 + CUSH_BACK, HW = W / 2 + CUSH_BACK;
    const cloth = new THREE.Shape();
    cloth.moveTo(-HL, -HW); cloth.lineTo(HL, -HW); cloth.lineTo(HL, HW); cloth.lineTo(-HL, HW); cloth.lineTo(-HL, -HW);
    for (const p of POCKETS) { const h = new THREE.Path(); h.absarc(p.x, -p.z, p.r, 0, Math.PI * 2, true); cloth.holes.push(h); }
    const clothGeo = new THREE.ShapeGeometry(cloth, 48);
    clothGeo.rotateX(-Math.PI / 2);
    // ShapeGeometry dùng (x, y) → sau rotateX(−90°): (x, 0, −y); ta đã đảo dấu z khi dựng nên khớp
    fixUV(clothGeo, HL, HW);
    const clothMesh = new THREE.Mesh(clothGeo, clothMat); clothMesh.receiveShadow = true; t.add(clothMesh);

    // lòng lỗ
    for (const p of POCKETS) {
      const cyl = new THREE.Mesh(new THREE.CylinderGeometry(p.r, p.r * 0.9, 0.16, 40, 1, true), pocketMat);
      cyl.position.set(p.x, -0.08, p.z); t.add(cyl);
      const bottom = new THREE.Mesh(new THREE.CircleGeometry(p.r * 0.9, 32), pocketMat);
      bottom.rotation.x = -Math.PI / 2; bottom.position.set(p.x, -0.16, p.z); t.add(bottom);
    }

    // băng
    for (const s of CUSHIONS) {
      if (s.jaw) continue;
      const jawAt = (pt) => CUSHIONS.find((j) => j.jaw && Math.abs(j.a[0] - pt[0]) < 1e-9 && Math.abs(j.a[1] - pt[1]) < 1e-9);
      const ja = jawAt(s.a), jb = jawAt(s.b);
      const pts = [s.a, s.b, jb ? jb.b : s.b, ja ? ja.b : s.a];
      const sh = new THREE.Shape(pts.map(([x, z]) => new THREE.Vector2(x, -z)));
      const geo = new THREE.ExtrudeGeometry(sh, { depth: CUSH_TOP, bevelEnabled: false });
      geo.rotateX(-Math.PI / 2);
      const m = new THREE.Mesh(geo, cushMat); m.castShadow = true; m.receiveShadow = true; t.add(m);
    }

    // mặt gỗ: hình chữ nhật ngoài – lỗ trong (hợp của khung băng và các lỗ bi)
    const OL = HL + RAIL_W, OW = HW + RAIL_W, rr = 0.05;
    const outer = new THREE.Shape();
    outer.moveTo(-OL + rr, -OW); outer.lineTo(OL - rr, -OW); outer.quadraticCurveTo(OL, -OW, OL, -OW + rr);
    outer.lineTo(OL, OW - rr); outer.quadraticCurveTo(OL, OW, OL - rr, OW); outer.lineTo(-OL + rr, OW);
    outer.quadraticCurveTo(-OL, OW, -OL, OW - rr); outer.lineTo(-OL, -OW + rr); outer.quadraticCurveTo(-OL, -OW, -OL + rr, -OW);
    const inner = new THREE.Path(unionOutline(HL, HW).map(([x, z]) => new THREE.Vector2(x, -z)).reverse());
    outer.holes.push(inner);
    const woodGeo = new THREE.ExtrudeGeometry(outer, { depth: 0.075, bevelEnabled: true, bevelThickness: 0.004, bevelSize: 0.004, bevelSegments: 2, curveSegments: 24 });
    woodGeo.rotateX(-Math.PI / 2); woodGeo.translate(0, WOOD_TOP - 0.075, 0);
    fixUV(woodGeo, OL, OW, 3);
    const wood = new THREE.Mesh(woodGeo, woodMat); wood.castShadow = true; wood.receiveShadow = true; t.add(wood);

    // thân bàn + chân
    const apron = new THREE.Mesh(new THREE.BoxGeometry(2 * OL - 0.05, 0.17, 2 * OW - 0.05), darkWood);
    apron.position.y = WOOD_TOP - 0.075 - 0.085; apron.castShadow = true; t.add(apron);
    for (const sx of [-1, 0, 1]) for (const sz of [-1, 1]) {
      if (sx === 0) continue;
      const leg = new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.62, 0.16), darkWood);
      leg.position.set(sx * (OL - 0.2), -0.47, sz * (OW - 0.18)); leg.castShadow = true; t.add(leg);
    }

    // nút (diamond) xà cừ
    const dmat = new THREE.MeshPhysicalMaterial({ color: '#efe6d0', roughness: 0.2, clearcoat: 1, iridescence: 0.6 });
    const dgeo = new THREE.CircleGeometry(0.0085, 4);
    for (let i = 0; i <= 8; i++) for (const dz of [0, 4]) {
      if (i % 4 === 0) continue;
      const p = railPoint(i, dz); addDiamond(p, dz === 0 ? 0 : 0);
    }
    for (let j = 1; j <= 3; j++) for (const dx of [0, 8]) addDiamond(railPoint(dx, j));
    function addDiamond(p) {
      const m = new THREE.Mesh(dgeo, dmat); m.rotation.x = -Math.PI / 2; m.rotation.z = Math.PI / 4;
      m.scale.set(1, 1.6, 1);
      m.position.set(p.x, WOOD_TOP + 0.0045, p.z); t.add(m);
    }
    // vạch head string nhẹ
    const spot = new THREE.Mesh(new THREE.CircleGeometry(0.008, 20), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.55 }));
    spot.rotation.x = -Math.PI / 2; spot.position.set(L / 4, 0.0008, 0); t.add(spot);
    const spot2 = spot.clone(); spot2.position.x = -L / 4; t.add(spot2);
  }

  buildCue() {
    // cơ dài 1,47 m: đầu cơ ở gốc toạ độ, thân chạy theo +y
    const prof = [];
    const pts = [[0, 0.0062], [0.012, 0.0064], [0.012, 0.0066], [0.035, 0.0066], [0.035, 0.0067], [0.7, 0.0107], [0.71, 0.0118], [0.73, 0.0118], [0.74, 0.0112], [1.0, 0.0128], [1.36, 0.0148], [1.46, 0.0152], [1.47, 0.0]];
    prof.push(new THREE.Vector2(0, 0));
    for (const [y, r] of pts) prof.push(new THREE.Vector2(r, y));
    const geo = new THREE.LatheGeometry(prof, 32);
    // màu theo đoạn bằng vertex colors
    const cols = [], pos = geo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      const y = pos.getY(i);
      let c;
      if (y < 0.012) c = [0.32, 0.5, 0.78];          // đầu cơ (phấn xanh)
      else if (y < 0.035) c = [0.95, 0.94, 0.9];    // ferrule
      else if (y < 0.70) c = [0.9, 0.78, 0.58];     // shaft gỗ phong
      else if (y < 0.74) c = [0.12, 0.12, 0.12];    // khớp nối
      else if (y < 1.0) c = [0.25, 0.12, 0.06];     // đuôi gỗ
      else if (y < 1.36) c = [0.1, 0.1, 0.11];      // quấn tay
      else c = [0.2, 0.09, 0.04];
      cols.push(...c);
    }
    geo.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
    const cue = new THREE.Mesh(geo, new THREE.MeshPhysicalMaterial({ vertexColors: true, roughness: 0.35, clearcoat: 0.8 }));
    cue.castShadow = true;
    this.cue = new THREE.Group();
    this.cueInner = new THREE.Group();
    cue.rotation.x = Math.PI / 2; // trục lathe +y → +z cục bộ (hướng đuôi cơ)
    this.cueInner.add(cue);
    this.cue.add(this.cueInner);
    this.scene.add(this.cue);
  }

  // ---------------- bi ----------------
  syncBalls(balls) {
    const ids = new Set(balls.map((b) => b.id));
    for (const [id, m] of this.ballMeshes) if (!ids.has(id)) { this.scene.remove(m); this.ballMeshes.delete(id); }
    for (const b of balls) {
      let m = this.ballMeshes.get(b.id);
      if (!m) {
        m = new THREE.Mesh(this.ballGeo, new THREE.MeshPhysicalMaterial({
          map: ballTexture(b.id, this.renderer), roughness: 0.12, clearcoat: 1, clearcoatRoughness: 0.04, metalness: 0,
        }));
        m.castShadow = true; m.receiveShadow = false;
        this.scene.add(m); this.ballMeshes.set(b.id, m);
        // xoay ngẫu nhiên để số không quay cùng một hướng
        if (b.id !== 0) { const q = new THREE.Quaternion().setFromEuler(new THREE.Euler(Math.random() * 6, Math.random() * 6, Math.random() * 6)); b.q = [q.x, q.y, q.z, q.w]; }
      }
      m.userData.drop = null;
    }
  }

  updateBalls(balls, dt) {
    for (const b of balls) {
      const m = this.ballMeshes.get(b.id);
      if (!m) continue;
      if (b.pocketed) {
        // hoạt cảnh rơi lỗ
        let d = m.userData.drop;
        const p = POCKETS.find((q) => q.id === b.pocket);
        if (!d) d = m.userData.drop = { t: 0, x: b.dropFrom ? b.dropFrom.x : m.position.x, z: b.dropFrom ? b.dropFrom.z : m.position.z };
        d.t += dt;
        const k = Math.min(1, d.t / 0.35);
        m.position.x = d.x + (p.x - d.x) * k;
        m.position.z = d.z + (p.z - d.z) * k;
        m.position.y = R - 0.13 * k * k;
        m.visible = d.t < 0.6;
      } else {
        m.visible = true;
        m.position.set(b.x, R, b.z);
      }
      m.quaternion.set(b.q[0], b.q[1], b.q[2], b.q[3]);
    }
  }

  // ---------------- cơ & ngắm ----------------
  /** a, b: điểm đánh (theo R), pull: độ lùi cơ (m), elev: góc nâng (rad) */
  setCue(visible, cb, dir, a = 0, b = 0, pull = 0, elev = 0) {
    this.cue.visible = visible && !!cb;
    if (!this.cue.visible) return;
    const vis = Math.max(elev, 0.07); // cơ luôn hơi nâng để không xuyên băng
    const ux = Math.cos(dir), uz = Math.sin(dir);
    const sx = -uz, sz = ux; // bên phải
    const k = Math.sqrt(Math.max(0, 1 - a * a - b * b));
    // điểm chạm trên bi
    const cx = cb.x + (-ux * k + sx * a) * R, cz = cb.z + (-uz * k + sz * a) * R, cy = R + b * R;
    const back = 0.012 + pull;
    this.cue.position.set(cx - ux * back * Math.cos(vis), cy + back * Math.sin(vis), cz - uz * back * Math.cos(vis));
    // trục +z cục bộ của cơ hướng ra sau người chơi và lên trên
    const tail = new THREE.Vector3(-ux * Math.cos(vis), Math.sin(vis), -uz * Math.cos(vis));
    this.cue.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), tail);
  }

  setGhost(p) {
    this.ghost.visible = !!p;
    if (p) this.ghost.position.set(p.x, R, p.z);
  }

  /** paths: [{pts:[[x,z]..], color, width, opacity, dash}] */
  setPaths(paths) {
    for (const c of this.guides.children) { c.geometry.dispose(); c.material.dispose(); }
    this.guides.clear();
    for (const p of paths) {
      if (!p.pts || p.pts.length < 2) continue;
      const geo = ribbon(p.pts, p.width || 0.005, p.dash);
      if (!geo) continue;
      const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: p.color || '#ffffff', transparent: true, opacity: p.opacity ?? 0.9, depthWrite: false }));
      m.position.y = 0.0015 + (p.y || 0);
      m.renderOrder = 5;
      this.guides.add(m);
    }
  }

  setZones(zones) {
    this.zones.clear();
    for (const z of zones) {
      const g = new THREE.Group();
      const fill = new THREE.Mesh(new THREE.CircleGeometry(z.r, 48), new THREE.MeshBasicMaterial({ color: z.color || '#ffd166', transparent: true, opacity: 0.16, depthWrite: false }));
      const ring = new THREE.Mesh(new THREE.RingGeometry(z.r - 0.004, z.r, 64), new THREE.MeshBasicMaterial({ color: z.color || '#ffd166', transparent: true, opacity: 0.9, depthWrite: false }));
      fill.rotation.x = ring.rotation.x = -Math.PI / 2;
      g.add(fill, ring); g.position.set(z.x, 0.0012, z.z); this.zones.add(g);
    }
  }

  /** labels: [{p:{x,z}, text, color, side}] — số nút lên mặt gỗ */
  setLabels(labels) {
    for (const c of this.labels.children) { c.material.map.dispose(); c.material.dispose(); }
    this.labels.clear();
    const geo = new THREE.PlaneGeometry(0.075, 0.075);
    for (const lb of labels) {
      const mat = new THREE.MeshBasicMaterial({ map: textTexture(lb.text, lb.color), transparent: true, depthWrite: false });
      const m = new THREE.Mesh(geo, mat);
      m.rotation.x = -Math.PI / 2;
      let { x, z } = lb.p;
      const o = 0.042;
      if (lb.side === 'top') z -= o; else if (lb.side === 'bottom') z += o; else if (lb.side === 'left') x -= o; else if (lb.side === 'right') x += o;
      else if (lb.side === 'bottom2') z -= DIAMOND_OFF + 0.035; // bên trong mặt vải
      const onWood = lb.side !== 'bottom2';
      m.position.set(x, onWood ? WOOD_TOP + 0.005 : 0.002, z);
      if (lb.side === 'bottom2') m.scale.setScalar(0.75);
      m.renderOrder = 6;
      this.labels.add(m);
    }
    this.orientLabels();
  }

  orientLabels() {
    const rz = this.mode === '2d' && this.portrait ? -Math.PI / 2 : 0;
    for (const m of this.labels.children) m.rotation.z = rz;
  }

  // ---------------- camera ----------------
  setMode(mode) { this.mode = mode; this.lamp.visible = mode !== '2d'; this.orientLabels(); this.resize(); }

  resize() {
    const w = this.canvas.clientWidth || window.innerWidth, h = this.canvas.clientHeight || window.innerHeight;
    this.renderer.setSize(w, h, false);
    this.persp.aspect = w / h; this.persp.updateProjectionMatrix();
    this.portrait = h > w;
    const padL = L + 2 * (CUSH_BACK + RAIL_W) + 0.12, padW = W + 2 * (CUSH_BACK + RAIL_W) + 0.12;
    const tw = this.portrait ? padW : padL, th = this.portrait ? padL : padW;
    const s = Math.max(tw / w, th / h) * 1.04;
    this.ortho.left = -w * s / 2; this.ortho.right = w * s / 2; this.ortho.top = h * s / 2; this.ortho.bottom = -h * s / 2;
    this.ortho.up.set(this.portrait ? -1 : 0, 0, this.portrait ? 0 : -1);
    this.ortho.position.set(0, 6, 0); this.ortho.lookAt(0, 0, 0);
    this.ortho.updateProjectionMatrix();
    this.orientLabels();
  }

  get camera() { return this.mode === '2d' ? this.ortho : this.persp; }

  updateCamera(dt, cb) {
    if (this.mode === '2d') return;
    const c = this.cam;
    const ov = c.overview;
    const tgt = new THREE.Vector3();
    let pos = new THREE.Vector3();
    if (cb) tgt.set(cb.x, R, cb.z); else tgt.set(0, 0, 0);
    // vị trí quỹ đạo quanh bi cái
    const pitch = c.pitch, dist = c.dist;
    const behind = new THREE.Vector3(-Math.cos(c.yaw) * Math.cos(pitch), Math.sin(pitch), -Math.sin(c.yaw) * Math.cos(pitch));
    const look = tgt.clone().add(new THREE.Vector3(Math.cos(c.yaw), 0, Math.sin(c.yaw)).multiplyScalar(0.25 * (1 - pitch / 1.6)));
    pos = tgt.clone().add(behind.multiplyScalar(dist));
    // toàn cảnh khi bi đang chạy
    const ovPos = new THREE.Vector3(-Math.cos(c.yaw) * 1.9, 2.3, -Math.sin(c.yaw) * 1.3);
    const ovLook = new THREE.Vector3(0, 0, 0);
    pos.lerp(ovPos, ov); look.lerp(ovLook, ov);
    const k = 1 - Math.exp(-dt * 7);
    this.camCur.pos.lerp(pos, k); this.camCur.look.lerp(look, k);
    // không chui xuống dưới mặt gỗ
    if (this.camCur.pos.y < 0.09) this.camCur.pos.y = 0.09;
    this.persp.position.copy(this.camCur.pos);
    this.persp.lookAt(this.camCur.look);
  }

  snapCamera(cb) {
    this.camCur.pos.set(0, 3, 0);
    this.updateCamera(10, cb);
  }

  /** Toạ độ màn hình → điểm trên mặt phẳng tâm bi. */
  pick(clientX, clientY) {
    const rect = this.canvas.getBoundingClientRect();
    const v = new THREE.Vector2(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1);
    this.raycaster.setFromCamera(v, this.camera);
    const out = new THREE.Vector3();
    return this.raycaster.ray.intersectPlane(this.plane, out) ? { x: out.x, z: out.z } : null;
  }

  /** Hướng màn hình (để ánh xạ cử chỉ) – trả về toạ độ màn hình của một điểm bàn. */
  project(p) {
    const v = new THREE.Vector3(p.x, R, p.z).project(this.camera);
    const rect = this.canvas.getBoundingClientRect();
    return { x: rect.left + (v.x + 1) / 2 * rect.width, y: rect.top + (1 - v.y) / 2 * rect.height };
  }

  render() { this.renderer.render(this.scene, this.camera); }
}

// ---------- tiện ích hình học ----------
function fixUV(geo, hl, hw, rep = 1) {
  const pos = geo.attributes.position, uv = geo.attributes.uv;
  for (let i = 0; i < pos.count; i++) uv.setXY(i, ((pos.getX(i) + hl) / (2 * hl)) * rep, (pos.getZ(i) + hw) / (2 * hw));
  uv.needsUpdate = true;
}

/** Đường bao của (khung băng ∪ các lỗ) bằng lấy mẫu cực quanh tâm bàn. */
function unionOutline(HL, HW) {
  const N = 1440, out = [];
  for (let i = 0; i < N; i++) {
    const th = (i / N) * Math.PI * 2, dx = Math.cos(th), dz = Math.sin(th);
    let t = Math.min(Math.abs(dx) > 1e-9 ? HL / Math.abs(dx) : Infinity, Math.abs(dz) > 1e-9 ? HW / Math.abs(dz) : Infinity);
    for (const p of POCKETS) {
      // giao tia với đường tròn lỗ, lấy giao điểm xa
      const b = dx * p.x + dz * p.z, c = p.x * p.x + p.z * p.z - p.r * p.r, disc = b * b - c;
      if (disc >= 0) { const t2 = b + Math.sqrt(disc); if (t2 > t) t = t2; }
    }
    out.push([dx * t, dz * t]);
  }
  return out;
}

/** Dải phẳng (ribbon) dọc polyline trên mặt bàn; dash: [độ dài nét, khoảng hở]. */
function ribbon(pts, w, dash) {
  const segs = [];
  if (dash) {
    const [on, off] = dash; let acc = 0, draw = true;
    for (let i = 0; i < pts.length - 1; i++) {
      let [ax, az] = pts[i]; const [bx, bz] = pts[i + 1];
      let len = Math.hypot(bx - ax, bz - az);
      const ux = (bx - ax) / (len || 1), uz = (bz - az) / (len || 1);
      while (len > 1e-6) {
        const lim = (draw ? on : off) - acc, step = Math.min(lim, len);
        if (draw) segs.push([[ax, az], [ax + ux * step, az + uz * step]]);
        ax += ux * step; az += uz * step; len -= step; acc += step;
        if (acc >= (draw ? on : off) - 1e-9) { acc = 0; draw = !draw; }
      }
    }
  } else for (let i = 0; i < pts.length - 1; i++) segs.push([pts[i], pts[i + 1]]);
  if (!segs.length) return null;
  const pos = [], idx = [];
  for (const [[ax, az], [bx, bz]] of segs) {
    const len = Math.hypot(bx - ax, bz - az); if (len < 1e-7) continue;
    const nx = (-(bz - az) / len) * w / 2, nz = ((bx - ax) / len) * w / 2;
    const i0 = pos.length / 3;
    pos.push(ax + nx, 0, az + nz, ax - nx, 0, az - nz, bx + nx, 0, bz + nz, bx - nx, 0, bz - nz);
    idx.push(i0, i0 + 2, i0 + 1, i0 + 1, i0 + 2, i0 + 3);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setIndex(idx);
  return g;
}
