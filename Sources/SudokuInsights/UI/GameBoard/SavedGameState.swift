import Foundation

public struct SavedGameState: Codable {
    public let difficulty: Difficulty
    public let board: [[Int]]
    public let initialBoard: [[Int]]
    public let solution: [[Int]]
    public let notes: [[Set<Int>]]
    public let elapsedTime: TimeInterval
    public let errorCount: Int
    public let timestamp: Date
    /// Optional so a save written before metrics existed still decodes rather than
    /// throwing away the player's in-progress game.
    public let metrics: GameMetrics?

    public init(
        difficulty: Difficulty,
        board: [[Int]],
        initialBoard: [[Int]],
        solution: [[Int]],
        notes: [[Set<Int>]],
        elapsedTime: TimeInterval,
        errorCount: Int,
        timestamp: Date,
        metrics: GameMetrics? = nil
    ) {
        self.difficulty = difficulty
        self.board = board
        self.initialBoard = initialBoard
        self.solution = solution
        self.notes = notes
        self.elapsedTime = elapsedTime
        self.errorCount = errorCount
        self.timestamp = timestamp
        self.metrics = metrics
    }
}
