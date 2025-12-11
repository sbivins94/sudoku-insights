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

/// Represents a complete game session
public struct GameSession: Codable, Identifiable {
    public let id: UUID
    public let puzzle: SudokuPuzzle
    public var startTime: Date
    public var endTime: Date?
    public var tapEvents: [TapEvent]
    public var isCompleted: Bool
    
    public init(puzzle: SudokuPuzzle) {
        self.id = UUID()
        self.puzzle = puzzle
        self.startTime = Date()
        self.endTime = nil
        self.tapEvents = []
        self.isCompleted = false
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
