import Foundation

/// 0.58 — a small QR encoder (byte mode, error correction M, versions 1–5, mask 0) so the flyer PDF needs NO CoreImage / GPU.
/// CI evidence (run 170): the only process that loaded CoreImage (CIQRCodeGenerator → CIContext.createCGImage) never finished the
/// render in 85 s on the GPU-less runner, so flyerBytes stayed 0. Verified against CIDetector in Tests/QRCodeTests.swift (Mac only).
struct QRCode {
    let size: Int
    private(set) var modules: [[Bool]]   // [row][column], true = dark
    static let capacity: [(total: Int, ec: Int, blocks: Int)] = [(26, 10, 1), (44, 16, 1), (70, 26, 1), (100, 18, 2), (134, 24, 2)]   // V1…V5, level M
    private static let align: [[Int]] = [[], [6, 18], [6, 22], [6, 26], [6, 30]]

    init?(_ text: String) {
        let bytes = Array(text.utf8)
        guard let v = (0..<Self.capacity.count).first(where: { bytes.count <= (Self.capacity[$0].total - Self.capacity[$0].ec * Self.capacity[$0].blocks) - 2 }) else { return nil }
        let cap = Self.capacity[v], version = v + 1, dataWords = cap.total - cap.ec * cap.blocks
        // bit stream: mode 0100, count (8 bits), bytes, terminator, pad
        var bits: [Bool] = []
        func put(_ value: Int, _ n: Int) { for i in stride(from: n - 1, through: 0, by: -1) { bits.append((value >> i) & 1 == 1) } }
        put(0b0100, 4); put(bytes.count, 8); for b in bytes { put(Int(b), 8) }
        put(0, min(4, dataWords * 8 - bits.count)); while bits.count % 8 != 0 { bits.append(false) }
        var data = stride(from: 0, to: bits.count, by: 8).map { i in (0..<8).reduce(0) { $0 << 1 | (bits[i + $1] ? 1 : 0) } }
        var pad = [0xEC, 0x11]; while data.count < dataWords { data.append(pad[0]); pad.reverse() }
        // Reed–Solomon per block, then interleave
        let per = dataWords / cap.blocks
        let blocks = (0..<cap.blocks).map { Array(data[$0 * per ..< ($0 + 1) * per]) }
        let ecs = blocks.map { Self.reedSolomon($0, cap.ec) }
        var final: [Int] = []
        for i in 0..<per { for b in blocks { final.append(b[i]) } }
        for i in 0..<cap.ec { for e in ecs { final.append(e[i]) } }
        // matrix
        let N = 17 + 4 * version; self.size = N
        var m = [[Bool?]](repeating: [Bool?](repeating: nil, count: N), count: N)
        func finder(_ r: Int, _ c: Int) {
            for dr in -1...7 { for dc in -1...7 { let rr = r + dr, cc = c + dc; guard rr >= 0, rr < N, cc >= 0, cc < N else { continue }
                m[rr][cc] = (0...6).contains(dr) && (0...6).contains(dc) && (dr == 0 || dr == 6 || dc == 0 || dc == 6 || ((2...4).contains(dr) && (2...4).contains(dc))) } }
        }
        finder(0, 0); finder(0, N - 7); finder(N - 7, 0)
        for i in 8..<(N - 8) { m[6][i] = i % 2 == 0; m[i][6] = i % 2 == 0 }
        let pos = Self.align[v]
        for r in pos { for c in pos { if (r == 6 && c == 6) || (r == 6 && c == pos.last!) || (r == pos.last! && c == 6) { continue }
            for dr in -2...2 { for dc in -2...2 { m[r + dr][c + dc] = max(abs(dr), abs(dc)) != 1 } } } }
        m[N - 8][8] = true   // dark module
        var reserved = m.map { $0.map { $0 != nil } }
        for i in 0..<9 { reserved[8][i] = true; reserved[i][8] = true }
        for i in 0..<8 { reserved[8][N - 1 - i] = true; reserved[N - 1 - i][8] = true }
        // data, zig-zag from the bottom right, mask 0: (row + col) even flips
        var dataBits: [Bool] = []; for w in final { for i in stride(from: 7, through: 0, by: -1) { dataBits.append((w >> i) & 1 == 1) } }
        var k = 0, up = true, col = N - 1
        while col > 0 {
            if col == 6 { col -= 1 }
            for step in 0..<N { let row = up ? N - 1 - step : step
                for c in [col, col - 1] where !reserved[row][c] { var bit = k < dataBits.count ? dataBits[k] : false; k += 1; if (row + c) % 2 == 0 { bit.toggle() }; m[row][c] = bit } }
            up.toggle(); col -= 2
        }
        // format info: level M (00) + mask 0 (000), BCH(15,5), xor 0x5412
        var f = 0
        var rem = 0 << 10
        for i in stride(from: 14, through: 10, by: -1) { if (rem >> i) & 1 == 1 { rem ^= 0x537 << (i - 10) } }
        f = ((0 << 10) | rem) ^ 0x5412
        func fb(_ i: Int) -> Bool { (f >> i) & 1 == 1 }
        for i in 0...5 { m[i][8] = fb(i) }; m[7][8] = fb(6); m[8][8] = fb(7); m[8][7] = fb(8)
        for i in 9...14 { m[8][14 - i] = fb(i) }
        for i in 0...7 { m[8][N - 1 - i] = fb(i) }
        for i in 8...14 { m[N - 15 + i][8] = fb(i) }
        modules = m.map { $0.map { $0 ?? false } }
    }

    private static let exp: [Int] = { var e = [Int](repeating: 0, count: 512), x = 1; for i in 0..<255 { e[i] = x; x <<= 1; if x & 0x100 != 0 { x ^= 0x11D } }; for i in 255..<512 { e[i] = e[i - 255] }; return e }()
    private static let log: [Int] = { var l = [Int](repeating: 0, count: 256); for i in 0..<255 { l[exp[i]] = i }; return l }()
    private static func mul(_ a: Int, _ b: Int) -> Int { a == 0 || b == 0 ? 0 : exp[log[a] + log[b]] }
    private static func reedSolomon(_ data: [Int], _ n: Int) -> [Int] {
        var gen = [1]
        for i in 0..<n { var next = [Int](repeating: 0, count: gen.count + 1); for (j, g) in gen.enumerated() { next[j] ^= g; next[j + 1] ^= mul(g, exp[i]) }; gen = next }
        var rem = [Int](repeating: 0, count: n)
        for d in data { let factor = d ^ rem[0]; rem.removeFirst(); rem.append(0); for i in 0..<n { rem[i] ^= mul(gen[i + 1], factor) } }
        return rem
    }
}
