import Foundation

/// One tracked statistic: how to compute it over a set of games, how to render it, and
/// what it means. Defining metrics as data keeps the panel and the drill-in view in sync.
public struct InsightMetric: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let explanation: String
    /// True when a smaller number is a better performance, which flips trend coloring.
    public let lowerIsBetter: Bool

    private let computation: @Sendable ([GameRecord]) -> Double?
    private let formatter: @Sendable (Double) -> String

    public init(
        id: String,
        title: String,
        explanation: String,
        lowerIsBetter: Bool,
        computation: @escaping @Sendable ([GameRecord]) -> Double?,
        formatter: @escaping @Sendable (Double) -> String
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.lowerIsBetter = lowerIsBetter
        self.computation = computation
        self.formatter = formatter
    }

    public func value(for records: [GameRecord]) -> Double? {
        guard !records.isEmpty else { return nil }
        return computation(records)
    }

    public func formatted(_ value: Double) -> String { formatter(value) }

    public func formattedValue(for records: [GameRecord]) -> String {
        guard let value = value(for: records) else { return "—" }
        return formatter(value)
    }
}

private func mean(_ records: [GameRecord], _ each: (GameRecord) -> Double) -> Double? {
    guard !records.isEmpty else { return nil }
    return records.reduce(0) { $0 + each($1) } / Double(records.count)
}

private func ratio(_ records: [GameRecord], numerator: (GameMetrics) -> Int, denominator: (GameMetrics) -> Int) -> Double? {
    let top = records.reduce(0) { $0 + numerator($1.metrics) }
    let bottom = records.reduce(0) { $0 + denominator($1.metrics) }
    guard bottom > 0 else { return nil }
    return Double(top) / Double(bottom)
}

private func secondsString(_ value: Double) -> String {
    if value >= 60 {
        let minutes = Int(value) / 60
        let seconds = Int(value) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    return String(format: "%.1fs", value)
}

private func percentString(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

public extension InsightMetric {
    static let averageTime = InsightMetric(
        id: "averageTime",
        title: "Avg time",
        explanation: "How long you take to finish a puzzle, start to last digit. Puzzles you abandon aren't counted.",
        lowerIsBetter: true,
        computation: { mean($0) { $0.duration } },
        formatter: secondsString
    )

    static let secondsPerCell = InsightMetric(
        id: "secondsPerCell",
        title: "Sec / cell",
        explanation: "Average gap between one correct digit and the next. This is your solving rhythm — it climbs when you're stuck hunting for the next move.",
        lowerIsBetter: true,
        computation: { records in
            let total = records.reduce(0.0) { $0 + $1.metrics.timeBetweenPlacements }
            let gaps = records.reduce(0) { $0 + $1.metrics.placementGaps }
            guard gaps > 0 else { return nil }
            return total / Double(gaps)
        },
        formatter: secondsString
    )

    static let errorsPerGame = InsightMetric(
        id: "errorsPerGame",
        title: "Mistakes / game",
        explanation: "Digits you entered that didn't match the solution, averaged per puzzle.",
        lowerIsBetter: true,
        computation: { mean($0) { Double($0.metrics.errors) } },
        formatter: { String(format: "%.1f", $0) }
    )

    static let notesPerGame = InsightMetric(
        id: "notesPerGame",
        title: "Notes / game",
        explanation: "How many pencil marks you write per puzzle. Higher isn't worse — it shows how much you lean on notes rather than holding candidates in your head.",
        lowerIsBetter: false,
        computation: { mean($0) { Double($0.metrics.notesAdded) } },
        formatter: { String(format: "%.0f", $0) }
    )

    static let noteAccuracy = InsightMetric(
        id: "noteAccuracy",
        title: "Note accuracy",
        explanation: "Share of your pencil marks that were actually possible in that cell. A low score means you're noting candidates that the row, column or box already rules out.",
        lowerIsBetter: false,
        computation: {
            ratio($0, numerator: { $0.notesAdded - $0.incorrectNotes }, denominator: { $0.notesAdded })
        },
        formatter: percentString
    )

    static let wastedTapRate = InsightMetric(
        id: "wastedTapRate",
        title: "Wasted taps",
        explanation: "Share of your cell taps that landed somewhere nothing could be entered — a given clue, or a cell you'd already solved. A proxy for hunting around the board.",
        lowerIsBetter: true,
        computation: {
            ratio($0, numerator: { $0.unproductiveTaps }, denominator: { $0.cellTaps })
        },
        formatter: percentString
    )

    static let wastedTapsPerGame = InsightMetric(
        id: "wastedTapsPerGame",
        title: "Wasted / game",
        explanation: "The raw count of those dead-end taps per puzzle. Unlike the percentage, this grows with how long you search, not just how often.",
        lowerIsBetter: true,
        computation: { mean($0) { Double($0.metrics.unproductiveTaps) } },
        formatter: { String(format: "%.0f", $0) }
    )

    static let all: [InsightMetric] = [
        .averageTime,
        .secondsPerCell,
        .errorsPerGame,
        .notesPerGame,
        .noteAccuracy,
        .wastedTapRate,
        .wastedTapsPerGame
    ]
}

/// Time buckets for the drill-in trend chart, mirroring the Apple Health day/week/month
/// switcher.
public enum TrendRange: String, CaseIterable, Identifiable, Sendable {
    case day = "D"
    case week = "W"
    case month = "M"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .day: return "Daily"
        case .week: return "Weekly"
        case .month: return "Monthly"
        }
    }

    /// How many buckets back the chart shows.
    public var bucketCount: Int {
        switch self {
        case .day: return 14
        case .week: return 12
        case .month: return 12
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }

    func startOfBucket(for date: Date, calendar: Calendar) -> Date {
        switch self {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }
}

public struct TrendPoint: Identifiable, Sendable {
    public let id = UUID()
    public let bucketStart: Date
    public let value: Double?
    public let gameCount: Int
}

public enum TrendBuilder {
    /// Buckets records into the trailing window for `range` and evaluates `metric` in each.
    /// Empty buckets are kept so gaps in play are visible rather than compressed away.
    public static func series(
        metric: InsightMetric,
        records: [GameRecord],
        range: TrendRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TrendPoint] {
        let currentBucket = range.startOfBucket(for: now, calendar: calendar)

        var starts: [Date] = []
        for offset in stride(from: range.bucketCount - 1, through: 0, by: -1) {
            if let start = calendar.date(byAdding: range.component, value: -offset, to: currentBucket) {
                starts.append(range.startOfBucket(for: start, calendar: calendar))
            }
        }

        var grouped: [Date: [GameRecord]] = [:]
        for record in records {
            let bucket = range.startOfBucket(for: record.completedAt, calendar: calendar)
            grouped[bucket, default: []].append(record)
        }

        return starts.map { start in
            let bucketRecords = grouped[start] ?? []
            return TrendPoint(
                bucketStart: start,
                value: metric.value(for: bucketRecords),
                gameCount: bucketRecords.count
            )
        }
    }
}
