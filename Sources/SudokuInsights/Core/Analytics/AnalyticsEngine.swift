import Foundation

/// Main analytics engine for processing gameplay telemetry
public class AnalyticsEngine {
    private let session: GameSession
    private let tapEvents: [TapEvent]
    
    public init(session: GameSession) {
        self.session = session
        self.tapEvents = session.tapEvents
    }
    
    /// Generate complete analytics report
    public func generateReport() -> AnalyticsReport {
        let totalMoves = calculateTotalMoves()
        let timeToSolve = calculateTimeToSolve()
        let errorRate = calculateErrorRate()
        let strategyProfile = classifyStrategy()
        let heatmap = generateHeatmap()
        
        return AnalyticsReport(
            sessionID: session.id,
            difficulty: session.puzzle.difficulty,
            totalMoves: totalMoves,
            timeToSolve: timeToSolve,
            errorRate: errorRate,
            strategyProfile: strategyProfile,
            heatmap: heatmap
        )
    }
    
    // MARK: - Private Analytics Methods
    
    private func calculateTotalMoves() -> Int {
        return tapEvents.filter { $0.action == .enterValue }.count
    }
    
    private func calculateTimeToSolve() -> TimeInterval? {
        guard session.isCompleted, let endTime = session.endTime else { return nil }
        return endTime.timeIntervalSince(session.startTime)
    }
    
    /// Calculate error rate (errors / total moves)
    private func calculateErrorRate() -> Double {
        let totalMoves = calculateTotalMoves()
        guard totalMoves > 0 else { return 0.0 }
        
        let eraseEvents = tapEvents.filter { $0.action == .erase }.count
        return Double(eraseEvents) / Double(totalMoves)
    }
    
    /// Classify user's solving strategy
    private func classifyStrategy() -> StrategyProfile {
        let selectEvents = tapEvents.filter { $0.action == .selectCell }.count
        let enterEvents = tapEvents.filter { $0.action == .enterValue }.count
        let noteEvents = tapEvents.filter { $0.action == .noteMode }.count
        let eraseEvents = tapEvents.filter { $0.action == .erase }.count
        
        let totalEvents = tapEvents.count
        guard totalEvents > 0 else {
            return StrategyProfile(primary: .logicalSolver, confidence: 0.5)
        }
        
        let selectRatio = Double(selectEvents) / Double(totalEvents)
        let enterRatio = Double(enterEvents) / Double(totalEvents)
        let noteRatio = Double(noteEvents) / Double(totalEvents)
        let errorRatio = Double(eraseEvents) / Double(totalEvents)
        
        // Simple heuristic classification
        if noteRatio > 0.3 {
            return StrategyProfile(primary: .candidateBuilder, secondary: .scanner, confidence: 0.8)
        } else if errorRatio > 0.25 {
            return StrategyProfile(primary: .brutForcer, secondary: .scanner, confidence: 0.7)
        } else if selectRatio > 0.5 && enterRatio < 0.3 {
            return StrategyProfile(primary: .scanner, secondary: .logicalSolver, confidence: 0.75)
        } else {
            return StrategyProfile(primary: .logicalSolver, secondary: nil, confidence: 0.85)
        }
    }
    
    /// Generate heatmap of cell interactions
    private func generateHeatmap() -> HeatmapGrid {
        var heatmap = emptyHeatmap()
        
        for event in tapEvents {
            let row = min(max(event.row, 0), 8)
            let col = min(max(event.col, 0), 8)
            heatmap[row][col] += 1
        }
        
        return heatmap
    }
    
    // MARK: - Derived Metrics
    
    /// Calculate average time per correct move
    public func averageTimePerMove() -> TimeInterval {
        let moveTimes = tapEvents
            .filter { $0.action == .enterValue }
            .map { $0.timestamp }
        
        guard moveTimes.count > 1 else { return 0 }
        
        var intervals: [TimeInterval] = []
        for i in 1..<moveTimes.count {
            intervals.append(moveTimes[i] - moveTimes[i - 1])
        }
        
        return intervals.isEmpty ? 0 : intervals.reduce(0, +) / Double(intervals.count)
    }
    
    /// Find longest inactivity period (stuck moment)
    public func longestInactivityPeriod() -> TimeInterval {
        guard tapEvents.count > 1 else { return 0 }
        
        var maxGap: TimeInterval = 0
        for i in 1..<tapEvents.count {
            let gap = tapEvents[i].timestamp - tapEvents[i - 1].timestamp
            maxGap = max(maxGap, gap)
        }
        
        return maxGap
    }
}
