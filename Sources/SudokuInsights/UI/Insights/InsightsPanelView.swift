import SwiftUI

public struct InsightsPanelView: View {
    let history: [GameRecord]
    let theme: SudokuTheme

    @State private var filter: DifficultyFilter = .all
    @State private var selectedMetric: InsightMetric?

    public init(history: [GameRecord], theme: SudokuTheme) {
        self.history = history
        self.theme = theme
    }

    private var filtered: [GameRecord] {
        guard let difficulty = filter.difficulty else { return history }
        return history.filter { $0.difficulty == difficulty }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if history.isEmpty {
                Text("Finish a game to start collecting stats.")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                filterBar

                if filtered.isEmpty {
                    Text("No \(filter.title.lowercased()) games yet.")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                } else {
                    metricGrid
                }
            }
        }
        .padding(14)
        .background(theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.accent.opacity(0.65), lineWidth: 2)
        )
        .sheet(item: $selectedMetric) { metric in
            InsightDetailView(
                metric: metric,
                history: history,
                initialFilter: filter,
                theme: theme
            )
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundColor(theme.accent)
            Text("INSIGHTS")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.primaryText)
            Spacer()
            if !filtered.isEmpty {
                Text("\(filtered.count) game\(filtered.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DifficultyFilter.allCases) { option in
                    let isSelected = option == filter
                    Button {
                        filter = option
                    } label: {
                        Text(option.title)
                            .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? theme.controlForeground : theme.secondaryText)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(isSelected ? theme.accent : theme.appBackground.opacity(0.6))
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var metricGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(InsightMetric.all) { metric in
                Button {
                    selectedMetric = metric
                } label: {
                    MetricTile(
                        title: metric.title,
                        value: metric.formattedValue(for: filtered),
                        theme: theme
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let theme: SudokuTheme

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
                .foregroundColor(theme.primaryText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.appBackground.opacity(0.6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.cellBorder, lineWidth: 1)
        )
    }
}

public enum DifficultyFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case easy
    case medium
    case hard
    case expert

    public var id: String { rawValue }

    public var title: String {
        self == .all ? "All" : rawValue.capitalized
    }

    public var difficulty: Difficulty? {
        self == .all ? nil : Difficulty(rawValue: rawValue)
    }
}

extension InsightMetric: Equatable {
    public static func == (lhs: InsightMetric, rhs: InsightMetric) -> Bool { lhs.id == rhs.id }
}
