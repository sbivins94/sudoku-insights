import Foundation

/// Represents a single tap event during gameplay
public struct TapEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: TimeInterval
    public let row: Int
    public let col: Int
    public let action: TapAction
    
    public init(timestamp: TimeInterval, row: Int, col: Int, action: TapAction) {
        self.id = UUID()
        self.timestamp = timestamp
        self.row = row
        self.col = col
        self.action = action
    }
}

/// Types of actions a user can perform
public enum TapAction: String, Codable {
    case selectCell
    case enterValue
    case erase
    case noteMode
    case undo
    case redo
}

/// Represents difficulty level
public enum Difficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard
    case expert
}

/// Represents a Sudoku puzzle
public struct SudokuPuzzle: Codable, Identifiable {
    public let id: UUID
    public let seed: String
    public let difficulty: Difficulty
    public let initialGrid: [[Int]]
    public let solution: [[Int]]
    public let createdAt: Date
    
    public init(seed: String, difficulty: Difficulty, initialGrid: [[Int]], solution: [[Int]]) {
        self.id = UUID()
        self.seed = seed
        self.difficulty = difficulty
        self.initialGrid = initialGrid
        self.solution = solution
        self.createdAt = Date()
    }
}

/// Represents the current state of a Sudoku board
public struct SudokuBoard: Codable {
    public var grid: [[Int]]
    public var notes: [[Set<Int>]]  // Candidate notes for each cell
    
    public init(grid: [[Int]]) {
        self.grid = grid
        // Initialize empty notes for all cells
        self.notes = Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
    }
    
    /// Toggle a note in a specific cell
    public mutating func toggleNote(row: Int, col: Int, value: Int) {
        guard row >= 0 && row < 9 && col >= 0 && col < 9 else { return }
        guard value >= 1 && value <= 9 else { return }
        
        if notes[row][col].contains(value) {
            notes[row][col].remove(value)
        } else {
            notes[row][col].insert(value)
        }
    }
    
    /// Clear all notes from a specific cell
    public mutating func clearNotes(row: Int, col: Int) {
        guard row >= 0 && row < 9 && col >= 0 && col < 9 else { return }
        notes[row][col].removeAll()
    }
    
    /// Create a sample board for testing
    public static func createSampleBoard() -> SudokuBoard {
        let grid: [[Int]] = [
            [5, 3, 0, 0, 7, 0, 0, 0, 0],
            [6, 0, 0, 1, 9, 5, 0, 0, 0],
            [0, 9, 8, 0, 0, 0, 0, 6, 0],
            [8, 0, 0, 0, 6, 0, 0, 0, 3],
            [4, 0, 0, 8, 0, 3, 0, 0, 1],
            [7, 0, 0, 0, 2, 0, 0, 0, 6],
            [0, 6, 0, 0, 0, 0, 2, 8, 0],
            [0, 0, 0, 4, 1, 9, 0, 0, 5],
            [0, 0, 0, 0, 8, 0, 0, 7, 9]
        ]
        return SudokuBoard(grid: grid)
    }
}

/// Represents a complete game session
public struct GameSession: Codable, Identifiable {
    public var id: String
    public var difficulty: Difficulty
    public var startTime: Date
    public var endTime: Date?
    public var tapEvents: [TapEvent]
    public var isCompleted: Bool
    public var initialBoard: SudokuBoard
    public var currentBoard: SudokuBoard
    
    public init(id: String, difficulty: Difficulty, startTime: Date, initialBoard: SudokuBoard) {
        self.id = id
        self.difficulty = difficulty
        self.startTime = startTime
        self.endTime = nil
        self.tapEvents = []
        self.isCompleted = false
        self.initialBoard = initialBoard
        self.currentBoard = initialBoard
    }
    
    public mutating func addTapEvent(_ event: TapEvent) {
        tapEvents.append(event)
    }
    
    public mutating func complete() {
        endTime = Date()
        isCompleted = true
    }
    
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
}
