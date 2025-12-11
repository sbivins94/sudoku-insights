import Foundation

// MARK: - Dashboard View
// TODO: Implement analytics dashboard with Swift Charts
// - Time-to-move histogram
// - Error rate over time
// - Heatmap visualization
// - Session summary statistics

public struct StatsDashboardView {
    /// Main analytics dashboard UI component
    public init() {}
}

// MARK: - Dashboard ViewModel
public class StatsDashboardViewModel {
    public let report: AnalyticsReport
    
    public init(report: AnalyticsReport) {
        self.report = report
    }
    
    /// Get formatted duration string
    public func formattedDuration() -> String {
        guard let duration = report.timeToSolve else { return "Not completed" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Get error percentage
    public func errorPercentage() -> String {
        return String(format: "%.1f%%", report.errorRate * 100)
    }
    
    /// Get strategy description
    public func strategyDescription() -> String {
        return "\(report.strategyProfile.primaryStrategy.rawValue) (confidence: \(Int(report.strategyProfile.confidence * 100))%)"
    }
}
