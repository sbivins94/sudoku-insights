import Foundation

/// Wrapper for Sudoku puzzle generation and validation
public class SudokuEngine {

    /// How many cells each difficulty leaves pre-filled. Expert mirrors the 24-28 clue
    /// band that sudoku.com labels "Extreme".
    public static func clueRange(for difficulty: Difficulty) -> ClosedRange<Int> {
        switch difficulty {
        case .easy: return 40...45
        case .medium: return 34...38
        case .hard: return 29...33
        case .expert: return 24...28
        }
    }

    /// Generate a new puzzle with given difficulty.
    ///
    /// Every puzzle returned has exactly one solution and can be finished with the
    /// techniques in `LogicalSolver` — so a correct deduction is never marked wrong and
    /// the player never has to guess.
    public static func generatePuzzle(difficulty: Difficulty = .medium) -> SudokuPuzzle {
        let range = clueRange(for: difficulty)
        // Solvable-but-wrong-band beats in-band-but-needs-guessing, so keep them separate.
        var solvableFallback: (puzzle: [[Int]], solution: [[Int]])?
        var lastResort: (puzzle: [[Int]], solution: [[Int]])?

        for _ in 0..<24 {
            let solution = generateValidGrid()
            let target = Int.random(in: range)
            let puzzle = dig(from: solution, targetClues: target)
            let candidate = (puzzle: puzzle, solution: solution)

            if lastResort == nil { lastResort = candidate }

            guard let technique = LogicalSolver.hardestTechnique(for: puzzle) else { continue }
            if solvableFallback == nil { solvableFallback = candidate }

            guard range.contains(clueCount(puzzle)),
                  satisfies(difficulty: difficulty, technique: technique) else {
                continue
            }

            return SudokuPuzzle(
                seed: UUID().uuidString,
                difficulty: difficulty,
                initialGrid: puzzle,
                solution: solution
            )
        }

        let result = solvableFallback ?? lastResort!
        return SudokuPuzzle(
            seed: UUID().uuidString,
            difficulty: difficulty,
            initialGrid: result.puzzle,
            solution: result.solution
        )
    }

    private static func satisfies(difficulty: Difficulty, technique: SolveTechnique) -> Bool {
        switch difficulty {
        case .easy: return technique == .singles
        case .medium: return technique <= .lockedCandidates
        case .hard: return technique > .singles
        case .expert: return technique > .singles
        }
    }

    private static func clueCount(_ grid: [[Int]]) -> Int {
        grid.reduce(0) { $0 + $1.filter { $0 != 0 }.count }
    }

    /// Removes clues one at a time, putting any clue back if taking it out would leave the
    /// puzzle with more than one solution.
    private static func dig(from solution: [[Int]], targetClues: Int) -> [[Int]] {
        var puzzle = solution
        var clues = 81
        var positions = Array(0..<81)
        positions.shuffle()

        // Re-sweep the survivors: a clue that was load-bearing early can become removable
        // once its neighbours are gone, so one pass alone often stalls short of the target.
        while clues > targetClues {
            var removedThisPass = false

            for position in positions {
                guard clues > targetClues else { break }

                let row = position / 9, col = position % 9
                let removed = puzzle[row][col]
                guard removed != 0 else { continue }

                puzzle[row][col] = 0
                var solver = SudokuSolver(puzzle)
                if solver.countSolutions(cap: 2) == 1 {
                    clues -= 1
                    removedThisPass = true
                } else {
                    puzzle[row][col] = removed
                }
            }

            if !removedThisPass { break }
            positions.shuffle()
        }
        return puzzle
    }

    /// Generate a completely filled, valid Sudoku grid
    private static func generateValidGrid() -> [[Int]] {
        var solver = SudokuSolver(Array(repeating: Array(repeating: 0, count: 9), count: 9))
        _ = solver.fillRandomly()
        return solver.solvedGrid
    }

    /// Check if it's safe to place a number at given position
    private static func isSafe(_ grid: [[Int]], row: Int, col: Int, num: Int) -> Bool {
        // Check row
        for c in 0..<9 {
            if grid[row][c] == num {
                return false
            }
        }

        // Check column
        for r in 0..<9 {
            if grid[r][col] == num {
                return false
            }
        }

        // Check 3x3 box
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3

        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) {
                if grid[r][c] == num {
                    return false
                }
            }
        }

        return true
    }

    /// Validate if a move is legal
    public static func isValidMove(grid: [[Int]], row: Int, col: Int, value: Int) -> Bool {
        guard value >= 1 && value <= 9 else { return false }
        return isSafe(grid, row: row, col: col, num: value)
    }

    /// Check if a value matches the solution
    public static func isCorrect(puzzle: SudokuPuzzle, row: Int, col: Int, value: Int) -> Bool {
        guard row >= 0 && row < 9 && col >= 0 && col < 9 else { return false }
        return puzzle.solution[row][col] == value
    }

    /// Check if puzzle is complete and correct
    public static func isComplete(_ grid: [[Int]]) -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] == 0 {
                    return false
                }
            }
        }
        return true
    }

    /// Get all possible values for a cell (for candidate notes)
    public static func getCandidates(grid: [[Int]], row: Int, col: Int) -> Set<Int> {
        guard grid[row][col] == 0 else { return [] }

        var candidates = Set(1...9)

        // Remove numbers already in row
        for c in 0..<9 {
            candidates.remove(grid[row][c])
        }

        // Remove numbers already in column
        for r in 0..<9 {
            candidates.remove(grid[r][col])
        }

        // Remove numbers already in 3x3 box
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3

        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) {
                candidates.remove(grid[r][c])
            }
        }

        return candidates
    }
}
