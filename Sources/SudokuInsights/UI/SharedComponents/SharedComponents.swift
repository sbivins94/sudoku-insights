import Foundation

// MARK: - Shared UI Components
// TODO: Implement reusable UI components
// - Difficulty selector
// - Loading spinner
// - Statistics card
// - Heatmap visualization

public struct DifficultySelector {
    /// Component for selecting puzzle difficulty
    public init() {}
}

public struct StatisticsCard {
    /// Component for displaying a single statistic
    public init(title: String, value: String) {}
}

public struct HeatmapVisualization {
    /// Component for visualizing interaction heatmap
    public init(heatmap: HeatmapGrid) {}
}
