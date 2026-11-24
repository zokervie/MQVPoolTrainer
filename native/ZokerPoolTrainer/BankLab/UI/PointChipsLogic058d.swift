import Foundation

enum PointChips {
    /// Provisional score = last settled score + face value of every object ball that left the table since that score was settled.
    static func shown(settled: Int, sunkNow: Set<Int>, sunkAtSettle: Set<Int>, shooting: Bool) -> Int {
        guard shooting else { return settled }
        return settled + sunkNow.subtracting(sunkAtSettle).filter { (1...15).contains($0) }.reduce(0, +)
    }
    static let floatSeconds = 0.6
}
