import Foundation

/// Classifies user's solving strategy
public enum StrategyType: String, Codable {
    case scanner           // Many cell taps with few inputs
    case candidateBuilder  // Note-mode heavy
    case brutForcer        // High error rate early
    case logicalSolver     // Low error rate, consistent pace
}

/// User's strategy profile derived from gameplay
public struct StrategyProfile: Codable {
    public let primaryStrategy: StrategyType
    public let secondaryStrategy: StrategyType?
    public let confidence: Double // 0.0 to 1.0
    
    public init(primary: StrategyType, secondary: StrategyType? = nil, confidence: Double = 0.75) {
        self.primaryStrategy = primary
        self.secondaryStrategy = secondary
        self.confidence = min(max(confidence, 0.0), 1.0)
    }
}

/// Analytics report for a completed game session
public struct AnalyticsReport: Codable, Identifiable {
    public let id: UUID
    public let sessionID: UUID
    public let difficulty: Difficulty
    public let totalMoves: Int
    public let timeToSolve: TimeInterval?
    public let errorRate: Double
    public let strategyProfile: StrategyProfile
    public let heatmap: HeatmapGrid
    public let generatedAt: Date
    
    public init(
        sessionID: UUID,
        difficulty: Difficulty,
        totalMoves: Int,
        timeToSolve: TimeInterval?,
        errorRate: Double,
        strategyProfile: StrategyProfile,
        heatmap: HeatmapGrid
    ) {
        self.id = UUID()
        self.sessionID = sessionID
        self.difficulty = difficulty
        self.totalMoves = totalMoves
        self.timeToSolve = timeToSolve
        self.errorRate = errorRate
        self.strategyProfile = strategyProfile
        self.heatmap = heatmap
        self.generatedAt = Date()
    }
    
    public var flowStateIndex: Double {
        // Derived metric: consistency in move timing
        // Higher = more steady/flow state
        return 1.0 - (errorRate * 0.5)
    }
}

/// 9x9 heatmap representing interactions per cell
public typealias HeatmapGrid = [[Int]]

/// Helper to create empty heatmap
public func emptyHeatmap() -> HeatmapGrid {
    return Array(repeating: Array(repeating: 0, count: 9), count: 9)
}
