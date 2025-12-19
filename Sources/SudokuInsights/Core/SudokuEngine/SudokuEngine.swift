import Foundation

/// Wrapper for Sudoku puzzle generation and validation
public class SudokuEngine {

    /// Generate a new puzzle with given difficulty
    public static func generatePuzzle(difficulty: Difficulty = .medium) -> SudokuPuzzle {
        // Generate a complete valid Sudoku grid
        let solution = generateValidGrid()

        // Remove cells based on difficulty to create the puzzle
        let initialGrid = createPuzzle(from: solution, difficulty: difficulty)

        return SudokuPuzzle(
            seed: UUID().uuidString,
            difficulty: difficulty,
            initialGrid: initialGrid,
            solution: solution
        )
    }

    /// Generate a completely filled, valid Sudoku grid
    private static func generateValidGrid() -> [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)

        // Fill diagonal 3x3 boxes first (they don't affect each other)
        fillDiagonalBoxes(&grid)

        // Fill remaining cells using backtracking
        _ = solveGrid(&grid)

        return grid
    }

    /// Fill the three diagonal 3x3 boxes
    private static func fillDiagonalBoxes(_ grid: inout [[Int]]) {
        for box in 0..<3 {
            fillBox(&grid, box: box, rowOffset: box * 3, colOffset: box * 3)
        }
    }

    /// Fill a single 3x3 box with random valid numbers
    private static func fillBox(_ grid: inout [[Int]], box: Int, rowOffset: Int, colOffset: Int) {
        var numbers = Array(1...9)
        numbers.shuffle()

        var index = 0
        for row in 0..<3 {
            for col in 0..<3 {
                grid[rowOffset + row][colOffset + col] = numbers[index]
                index += 1
            }
        }
    }

    /// Create puzzle by removing cells from solution based on difficulty
    private static func createPuzzle(from solution: [[Int]], difficulty: Difficulty) -> [[Int]] {
        var puzzle = solution

        // Number of cells to remove based on difficulty
        let cellsToRemove: Int
        switch difficulty {
        case .easy: cellsToRemove = 30
        case .medium: cellsToRemove = 40
        case .hard: cellsToRemove = 50
        case .expert: cellsToRemove = 60
        }

        // Randomly remove cells
        var positions = (0..<81).map { $0 }
        positions.shuffle()

        for i in 0..<cellsToRemove {
            let position = positions[i]
            let row = position / 9
            let col = position % 9
            puzzle[row][col] = 0
        }

        return puzzle
    }

    /// Solve a Sudoku grid using backtracking
    private static func solveGrid(_ grid: inout [[Int]]) -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] == 0 {
                    for num in 1...9 {
                        if isSafe(grid, row: row, col: col, num: num) {
                            grid[row][col] = num
                            if solveGrid(&grid) {
                                return true
                            }
                            grid[row][col] = 0
                        }
                    }
                    return false
                }
            }
        }
        return true
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
