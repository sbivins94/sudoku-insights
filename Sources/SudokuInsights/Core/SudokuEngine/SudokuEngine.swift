import Foundation

/// Wrapper for Sudoku puzzle generation and validation
public class SudokuEngine {
    
    /// Generate a new puzzle with given difficulty
    public static func generatePuzzle(difficulty: Difficulty = .medium) -> SudokuPuzzle {
        // TODO: Integrate with SwiftSuDoKu library for real puzzle generation
        // For now, return a hardcoded sample puzzle
        
        let sampleInitial = [
            [5, 3, 0, 0, 7, 0, 0, 0, 0],
            [6, 0, 0, 1, 9, 5, 0, 0, 0],
            [0, 9, 8, 0, 0, 0, 0, 6, 0],
            [8, 0, 0, 0, 6, 0, 0, 0, 3],
            [4, 0, 0, 8, 0, 3, 0, 0, 1],
            [7, 0, 0, 0, 2, 0, 0, 0, 6],
            [0, 6, 0, 0, 0, 0, 2, 8, 0],
            [0, 0, 0, 4, 1, 9, 0, 0, 5],
            [0, 0, 0, 0, 8, 0, 0, 7, 9],
        ]
        
        let sampleSolution = [
            [5, 3, 4, 6, 7, 8, 9, 1, 2],
            [6, 7, 2, 1, 9, 5, 3, 4, 8],
            [1, 9, 8, 3, 4, 2, 5, 6, 7],
            [8, 5, 9, 7, 6, 1, 4, 2, 3],
            [4, 2, 6, 8, 5, 3, 7, 9, 1],
            [7, 1, 3, 9, 2, 4, 8, 5, 6],
            [9, 6, 1, 5, 3, 7, 2, 8, 4],
            [2, 8, 7, 4, 1, 9, 6, 3, 5],
            [3, 4, 5, 2, 8, 6, 1, 7, 9],
        ]
        
        return SudokuPuzzle(
            seed: UUID().uuidString,
            difficulty: difficulty,
            initialGrid: sampleInitial,
            solution: sampleSolution
        )
    }
    
    /// Validate if a move is legal
    public static func isValidMove(grid: [[Int]], row: Int, col: Int, value: Int) -> Bool {
        // Check row
        if grid[row].contains(value) {
            return false
        }
        
        // Check column
        for r in 0..<9 {
            if grid[r][col] == value {
                return false
            }
        }
        
        // Check 3x3 box
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        
        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) {
                if grid[r][c] == value {
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Check if a value matches the solution
    public static func isCorrect(puzzle: SudokuPuzzle, row: Int, col: Int, value: Int) -> Bool {
        guard row >= 0 && row < 9 && col >= 0 && col < 9 else { return false }
        return puzzle.solution[row][col] == value
    }
}
