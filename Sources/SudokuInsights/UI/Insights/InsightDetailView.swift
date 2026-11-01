import SwiftUI
import Charts

/// Drill-in for a single stat: what it means, where it sits now, and how it's trended
/// over day/week/month buckets.
public struct InsightDetailView: View {
    let metric: InsightMetric
    let history: [GameRecord]
    let theme: SudokuTheme

    @State private var filter: DifficultyFilter
    @State private var range: TrendRange = .day
    @Environment(\.dismiss) private var dismiss

    public init(
        metric: InsightMetric,
        history: [GameRecord],
        initialFilter: DifficultyFilter,
        theme: SudokuTheme
    ) {
        self.metric = metric
        self.history = history
        self.theme = theme
        _filter = State(initialValue: initialFilter)
    }

    private var filtered: [GameRecord] {
        guard let difficulty = filter.difficulty else { return history }
        return history.filter { $0.difficulty == difficulty }
    }

    private var series: [TrendPoint] {
        TrendBuilder.series(metric: metric, records: filtered, range: range)
    }

    /// The most recent bucket that actually has games, compared against the mean of the
    /// buckets before it — "today versus your priors".
    private var comparison: (latest: Double, prior: Double)? {
        let populated = series.filter { $0.value != nil }
        guard let last = populated.last, let latest = last.value else { return nil }
        let earlier = populated.dropLast().compactMap(\.value)
        guard !earlier.isEmpty else { return nil }
        return (latest, earlier.reduce(0, +) / Double(earlier.count))
    }

    public var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleBar
                    currentValue
                    rangePicker
                    chart
                    explanation
                }
                .padding(20)
            }
        }
    }

    private var titleBar: some View {
        HStack {
            Text(metric.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.primaryText)
            Spacer()
            Button("Done") { dismiss() }
                .foregroundColor(theme.accent)
                .fontWeight(.semibold)
        }
    }

    private var currentValue: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(metric.formattedValue(for: filtered))
                    .font(.system(size: 40, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(theme.primaryText)
                Text(filter == .all ? "all levels" : filter.title.lowercased())
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryText)
            }

            if let comparison {
                let delta = comparison.latest - comparison.prior
                let improved = metric.lowerIsBetter ? delta < 0 : delta > 0
                let magnitude = metric.formatted(abs(delta))

                HStack(spacing: 5) {
                    Image(systemName: delta == 0 ? "equal" : (delta > 0 ? "arrow.up.right" : "arrow.down.right"))
                    Text(delta == 0
                         ? "Even with your average"
                         : "\(magnitude) \(delta > 0 ? "above" : "below") your \(range.label.lowercased()) average")
                }
                .font(.caption)
                .foregroundColor(delta == 0 ? theme.secondaryText : (improved ? theme.enteredDigit : theme.errorDigit))
            }

            difficultyPicker
        }
    }

    private var difficultyPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DifficultyFilter.allCases) { option in
                    let isSelected = option == filter
                    Button { filter = option } label: {
                        Text(option.title)
                            .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? theme.controlForeground : theme.secondaryText)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(isSelected ? theme.accent : theme.cardBackground)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(TrendRange.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 10) {
            if series.allSatisfy({ $0.value == nil }) {
                Text("No games in this window yet.")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart(series) { point in
                    if let value = point.value {
                        BarMark(
                            x: .value("Period", point.bucketStart, unit: range.component),
                            y: .value(metric.title, value)
                        )
                        .foregroundStyle(theme.accent)
                        .cornerRadius(3)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(theme.cellBorder)
                        AxisValueLabel {
                            if let raw = value.as(Double.self) {
                                Text(metric.formatted(raw))
                                    .foregroundColor(theme.secondaryText)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(axisLabel(for: date))
                                    .foregroundColor(theme.secondaryText)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }

            Text(gamesSummary)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
        .padding(14)
        .background(theme.cardBackground)
        .cornerRadius(12)
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What this measures")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(theme.primaryText)
            Text(metric.explanation)
                .font(.callout)
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(metric.lowerIsBetter ? "Lower is better." : "Higher is better.")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(theme.cardBackground)
        .cornerRadius(12)
    }

    private var gamesSummary: String {
        let count = series.reduce(0) { $0 + $1.gameCount }
        let window = "last \(range.bucketCount) \(range == .day ? "days" : (range == .week ? "weeks" : "months"))"
        return "\(count) game\(count == 1 ? "" : "s") in the \(window)"
    }

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch range {
        case .day: formatter.dateFormat = "M/d"
        case .week: formatter.dateFormat = "M/d"
        case .month: formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }
}
