import Foundation

/// Raw counters for a single game. Stored as counts rather than averages so new metrics
/// can be derived later from history that's already been collected.
public struct GameMetrics: Codable, Equatable, Sendable {
    public var correctPlacements: Int = 0
    public var errors: Int = 0
    public var notesAdded: Int = 0
    public var incorrectNotes: Int = 0
    public var cellTaps: Int = 0
    public var unproductiveTaps: Int = 0

    /// Wall-clock gap between consecutive correct placements, and how many we saw.
    public var timeBetweenPlacements: TimeInterval = 0
    public var placementGaps: Int = 0

    public init() {}
}

/// One finished game, with when it was finished so insights can be trended over time.
public struct GameRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let difficulty: Difficulty
    public let completedAt: Date
    public let duration: TimeInterval
    public let metrics: GameMetrics

    public init(
        id: UUID = UUID(),
        difficulty: Difficulty,
        completedAt: Date,
        duration: TimeInterval,
        metrics: GameMetrics
    ) {
        self.id = id
        self.difficulty = difficulty
        self.completedAt = completedAt
        self.duration = duration
        self.metrics = metrics
    }
}

public enum GameHistoryStore {
    public static let key = "gameHistory"

    /// Keeps history bounded; far more than enough for monthly trends.
    public static let maxRecords = 500

    public static func load(from defaults: UserDefaults = .standard) -> [GameRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([GameRecord].self, from: data) else {
            return []
        }
        return records
    }

    public static func append(_ record: GameRecord, to defaults: UserDefaults = .standard) -> [GameRecord] {
        var records = load(from: defaults)
        records.append(record)
        if records.count > maxRecords {
            records.removeFirst(records.count - maxRecords)
        }
        save(records, to: defaults)
        return records
    }

    public static func save(_ records: [GameRecord], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }

    public static func reset(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
