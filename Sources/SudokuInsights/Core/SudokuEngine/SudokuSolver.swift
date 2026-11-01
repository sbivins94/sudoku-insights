import Foundation

/// Bit i represents the digit i, so masks use bits 1...9.
private let allCandidates = 0b11_1111_1110

/// The human solving techniques the generator knows how to apply, ordered by how hard
/// they are to spot. A puzzle's difficulty is the hardest technique it forces you to use.
public enum SolveTechnique: Int, Comparable, Sendable {
    case singles
    case lockedCandidates
    case nakedSubsets
    case hiddenSubsets
    case xWing

    public static func < (lhs: SolveTechnique, rhs: SolveTechnique) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The 27 units (9 rows, 9 columns, 9 boxes) every constraint is expressed over.
let sudokuUnits: [[(row: Int, col: Int)]] = {
    var units: [[(row: Int, col: Int)]] = []
    for r in 0..<9 { units.append((0..<9).map { (r, $0) }) }
    for c in 0..<9 { units.append((0..<9).map { ($0, c) }) }
    for box in 0..<9 {
        let br = (box / 3) * 3, bc = (box % 3) * 3
        units.append((0..<9).map { (br + $0 / 3, bc + $0 % 3) })
    }
    return units
}()

/// Constraint-propagating backtracker. Picks the most constrained cell first, which keeps
/// proving uniqueness cheap even on sparse grids.
struct SudokuSolver {
    private var grid: [[Int]]
    private var rows = [Int](repeating: 0, count: 9)
    private var cols = [Int](repeating: 0, count: 9)
    private var boxes = [Int](repeating: 0, count: 9)

    init(_ grid: [[Int]]) {
        self.grid = grid
        for r in 0..<9 {
            for c in 0..<9 where grid[r][c] != 0 {
                place(r, c, grid[r][c])
            }
        }
    }

    private mutating func place(_ r: Int, _ c: Int, _ value: Int) {
        let bit = 1 << value
        rows[r] |= bit
        cols[c] |= bit
        boxes[(r / 3) * 3 + c / 3] |= bit
    }

    private mutating func unplace(_ r: Int, _ c: Int, _ value: Int) {
        let bit = 1 << value
        rows[r] ^= bit
        cols[c] ^= bit
        boxes[(r / 3) * 3 + c / 3] ^= bit
    }

    private func candidateMask(_ r: Int, _ c: Int) -> Int {
        ~(rows[r] | cols[c] | boxes[(r / 3) * 3 + c / 3]) & allCandidates
    }

    /// Number of distinct solutions, stopping as soon as `cap` is reached.
    mutating func countSolutions(cap: Int = 2) -> Int {
        var target = (row: -1, col: -1, mask: 0, count: 10)

        for r in 0..<9 {
            for c in 0..<9 where grid[r][c] == 0 {
                let mask = candidateMask(r, c)
                let count = mask.nonzeroBitCount
                if count < target.count {
                    target = (r, c, mask, count)
                    if count <= 1 { break }
                }
            }
            if target.count <= 1 { break }
        }

        guard target.row >= 0 else { return 1 }
        guard target.count > 0 else { return 0 }

        var total = 0
        var mask = target.mask
        while mask != 0 {
            let bit = mask & -mask
            mask ^= bit
            let value = bit.trailingZeroBitCount

            grid[target.row][target.col] = value
            place(target.row, target.col, value)

            total += countSolutions(cap: cap - total)

            grid[target.row][target.col] = 0
            unplace(target.row, target.col, value)

            if total >= cap { return total }
        }
        return total
    }

    /// Fills the grid in place, trying digits in random order so generated grids vary.
    mutating func fillRandomly() -> Bool {
        var target = (row: -1, col: -1, mask: 0, count: 10)

        for r in 0..<9 {
            for c in 0..<9 where grid[r][c] == 0 {
                let mask = candidateMask(r, c)
                let count = mask.nonzeroBitCount
                if count < target.count {
                    target = (r, c, mask, count)
                    if count <= 1 { break }
                }
            }
            if target.count <= 1 { break }
        }

        guard target.row >= 0 else { return true }

        var values: [Int] = []
        var mask = target.mask
        while mask != 0 {
            let bit = mask & -mask
            mask ^= bit
            values.append(bit.trailingZeroBitCount)
        }
        values.shuffle()

        for value in values {
            grid[target.row][target.col] = value
            place(target.row, target.col, value)

            if fillRandomly() { return true }

            grid[target.row][target.col] = 0
            unplace(target.row, target.col, value)
        }
        return false
    }

    var solvedGrid: [[Int]] { grid }
}

/// Solves using only human techniques, reporting the hardest one it needed. Returns nil if
/// the puzzle stalls — meaning it can't be finished without guessing, so we never ship it.
struct LogicalSolver {
    private var candidates: [[Int]]
    private var grid: [[Int]]
    private var remaining: Int

    init(_ puzzle: [[Int]]) {
        grid = puzzle
        candidates = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        remaining = 0

        for r in 0..<9 {
            for c in 0..<9 where puzzle[r][c] == 0 {
                remaining += 1
            }
        }
        for r in 0..<9 {
            for c in 0..<9 where grid[r][c] == 0 {
                candidates[r][c] = allCandidates
            }
        }
        for r in 0..<9 {
            for c in 0..<9 where grid[r][c] != 0 {
                eliminateFromPeers(r, c, grid[r][c])
            }
        }
    }

    static func hardestTechnique(for puzzle: [[Int]]) -> SolveTechnique? {
        var solver = LogicalSolver(puzzle)
        return solver.solve()
    }

    private mutating func eliminateFromPeers(_ row: Int, _ col: Int, _ value: Int) {
        let bit = 1 << value
        for c in 0..<9 where grid[row][c] == 0 { candidates[row][c] &= ~bit }
        for r in 0..<9 where grid[r][col] == 0 { candidates[r][col] &= ~bit }
        let br = (row / 3) * 3, bc = (col / 3) * 3
        for r in br..<(br + 3) {
            for c in bc..<(bc + 3) where grid[r][c] == 0 { candidates[r][c] &= ~bit }
        }
    }

    private mutating func assign(_ row: Int, _ col: Int, _ value: Int) {
        grid[row][col] = value
        candidates[row][col] = 0
        remaining -= 1
        eliminateFromPeers(row, col, value)
    }

    private mutating func solve() -> SolveTechnique? {
        var hardest = SolveTechnique.singles

        while remaining > 0 {
            if applySingles() { continue }

            if applyLockedCandidates() {
                hardest = max(hardest, .lockedCandidates)
                continue
            }
            if applyNakedSubsets() {
                hardest = max(hardest, .nakedSubsets)
                continue
            }
            if applyHiddenSubsets() {
                hardest = max(hardest, .hiddenSubsets)
                continue
            }
            if applyXWing() {
                hardest = max(hardest, .xWing)
                continue
            }
            return nil
        }
        return hardest
    }

    /// Naked singles (one candidate left in a cell) and hidden singles (a digit with only
    /// one home in a unit). Both are the baseline "just look at it" moves.
    private mutating func applySingles() -> Bool {
        for r in 0..<9 {
            for c in 0..<9 where grid[r][c] == 0 {
                let mask = candidates[r][c]
                if mask == 0 { return false }
                if mask.nonzeroBitCount == 1 {
                    assign(r, c, mask.trailingZeroBitCount)
                    return true
                }
            }
        }

        for unit in sudokuUnits {
            for value in 1...9 {
                let bit = 1 << value
                var spot: (row: Int, col: Int)?
                var count = 0
                for cell in unit {
                    if grid[cell.row][cell.col] == value { count = 0; break }
                    if candidates[cell.row][cell.col] & bit != 0 {
                        count += 1
                        spot = cell
                        if count > 1 { break }
                    }
                }
                if count == 1, let spot {
                    assign(spot.row, spot.col, value)
                    return true
                }
            }
        }
        return false
    }

    /// Pointing pairs and box/line reduction: a digit confined to one row or column inside
    /// a box can be struck from the rest of that line, and vice versa.
    private mutating func applyLockedCandidates() -> Bool {
        for box in 0..<9 {
            let br = (box / 3) * 3, bc = (box % 3) * 3
            for value in 1...9 {
                let bit = 1 << value
                var rowsSeen = Set<Int>(), colsSeen = Set<Int>()
                var cells: [(row: Int, col: Int)] = []

                for r in br..<(br + 3) {
                    for c in bc..<(bc + 3) where candidates[r][c] & bit != 0 {
                        rowsSeen.insert(r); colsSeen.insert(c); cells.append((r, c))
                    }
                }
                guard !cells.isEmpty else { continue }

                if rowsSeen.count == 1, let row = rowsSeen.first {
                    var changed = false
                    for c in 0..<9 where c < bc || c >= bc + 3 {
                        if candidates[row][c] & bit != 0 { candidates[row][c] &= ~bit; changed = true }
                    }
                    if changed { return true }
                }
                if colsSeen.count == 1, let col = colsSeen.first {
                    var changed = false
                    for r in 0..<9 where r < br || r >= br + 3 {
                        if candidates[r][col] & bit != 0 { candidates[r][col] &= ~bit; changed = true }
                    }
                    if changed { return true }
                }
            }
        }

        for unit in sudokuUnits.prefix(18) {
            for value in 1...9 {
                let bit = 1 << value
                var boxesSeen = Set<Int>()
                var any = false
                for cell in unit where candidates[cell.row][cell.col] & bit != 0 {
                    boxesSeen.insert((cell.row / 3) * 3 + cell.col / 3)
                    any = true
                }
                guard any, boxesSeen.count == 1, let box = boxesSeen.first else { continue }

                let br = (box / 3) * 3, bc = (box % 3) * 3
                var changed = false
                for r in br..<(br + 3) {
                    for c in bc..<(bc + 3) where !unit.contains(where: { $0.row == r && $0.col == c }) {
                        if candidates[r][c] & bit != 0 { candidates[r][c] &= ~bit; changed = true }
                    }
                }
                if changed { return true }
            }
        }
        return false
    }

    /// Naked pairs/triples: k cells in a unit sharing exactly k candidates lock those
    /// digits away from the rest of the unit.
    private mutating func applyNakedSubsets() -> Bool {
        for unit in sudokuUnits {
            let open = unit.filter { grid[$0.row][$0.col] == 0 }
            guard open.count > 2 else { continue }

            for size in 2...3 {
                for combo in combinations(open, choose: size) {
                    var union = 0
                    for cell in combo { union |= candidates[cell.row][cell.col] }
                    guard union.nonzeroBitCount == size else { continue }

                    var changed = false
                    for cell in open where !combo.contains(where: { $0 == cell }) {
                        if candidates[cell.row][cell.col] & union != 0 {
                            candidates[cell.row][cell.col] &= ~union
                            changed = true
                        }
                    }
                    if changed { return true }
                }
            }
        }
        return false
    }

    /// Hidden pairs/triples: k digits that can only live in k cells of a unit evict every
    /// other candidate from those cells.
    private mutating func applyHiddenSubsets() -> Bool {
        for unit in sudokuUnits {
            let open = unit.filter { grid[$0.row][$0.col] == 0 }
            guard open.count > 2 else { continue }

            var homes: [Int: [(row: Int, col: Int)]] = [:]
            for value in 1...9 {
                let bit = 1 << value
                let spots = open.filter { candidates[$0.row][$0.col] & bit != 0 }
                if !spots.isEmpty { homes[value] = spots }
            }

            for size in 2...3 {
                let values = homes.keys.filter { homes[$0]!.count <= size }.sorted()
                guard values.count >= size else { continue }

                for combo in combinations(values, choose: size) {
                    var cells = Set<String>()
                    var mask = 0
                    for value in combo {
                        mask |= 1 << value
                        for cell in homes[value]! { cells.insert("\(cell.row),\(cell.col)") }
                    }
                    guard cells.count == size else { continue }

                    var changed = false
                    for key in cells {
                        let parts = key.split(separator: ",")
                        let r = Int(parts[0])!, c = Int(parts[1])!
                        if candidates[r][c] & ~mask != 0 {
                            candidates[r][c] &= mask
                            changed = true
                        }
                    }
                    if changed { return true }
                }
            }
        }
        return false
    }

    /// X-Wing: a digit restricted to the same two columns across two rows (or vice versa)
    /// can be eliminated from those columns everywhere else.
    private mutating func applyXWing() -> Bool {
        for value in 1...9 {
            let bit = 1 << value

            for transposed in [false, true] {
                var lines: [Int: [Int]] = [:]
                for a in 0..<9 {
                    var positions: [Int] = []
                    for b in 0..<9 {
                        let r = transposed ? b : a
                        let c = transposed ? a : b
                        if candidates[r][c] & bit != 0 { positions.append(b) }
                    }
                    if positions.count == 2 { lines[a] = positions }
                }

                let keys = lines.keys.sorted()
                for i in 0..<keys.count {
                    for j in (i + 1)..<keys.count {
                        guard lines[keys[i]]! == lines[keys[j]]! else { continue }
                        let positions = lines[keys[i]]!

                        var changed = false
                        for b in positions {
                            for a in 0..<9 where a != keys[i] && a != keys[j] {
                                let r = transposed ? b : a
                                let c = transposed ? a : b
                                if candidates[r][c] & bit != 0 {
                                    candidates[r][c] &= ~bit
                                    changed = true
                                }
                            }
                        }
                        if changed { return true }
                    }
                }
            }
        }
        return false
    }

    private func combinations<T>(_ items: [T], choose k: Int) -> [[T]] {
        guard k <= items.count else { return [] }
        if k == 0 { return [[]] }
        if k == items.count { return [items] }

        var result: [[T]] = []
        var indices = Array(0..<k)
        while true {
            result.append(indices.map { items[$0] })

            var i = k - 1
            while i >= 0 && indices[i] == items.count - k + i { i -= 1 }
            if i < 0 { break }
            indices[i] += 1
            for j in (i + 1)..<k { indices[j] = indices[j - 1] + 1 }
        }
        return result
    }
}

private func == (lhs: (row: Int, col: Int), rhs: (row: Int, col: Int)) -> Bool {
    lhs.row == rhs.row && lhs.col == rhs.col
}
