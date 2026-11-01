import XCTest
@testable import SudokuInsights

final class InsightMetricTests: XCTestCase {
    private func record(
        difficulty: Difficulty = .expert,
        daysAgo: Int = 0,
        duration: TimeInterval = 300,
        errors: Int = 2,
        notes: Int = 40,
        incorrectNotes: Int = 4,
        cellTaps: Int = 100,
        unproductiveTaps: Int = 20,
        gapTotal: TimeInterval = 250,
        gaps: Int = 50
    ) -> GameRecord {
        var metrics = GameMetrics()
        metrics.errors = errors
        metrics.notesAdded = notes
        metrics.incorrectNotes = incorrectNotes
        metrics.cellTaps = cellTaps
        metrics.unproductiveTaps = unproductiveTaps
        metrics.timeBetweenPlacements = gapTotal
        metrics.placementGaps = gaps

        let when = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return GameRecord(difficulty: difficulty, completedAt: when, duration: duration, metrics: metrics)
    }

    func testMetricsAreNilWithoutGames() {
        for metric in InsightMetric.all {
            XCTAssertNil(metric.value(for: []), "\(metric.id) should have no value without games")
            XCTAssertEqual(metric.formattedValue(for: []), "—")
        }
    }

    func testAveragesAcrossGames() {
        let records = [record(duration: 200), record(duration: 400)]
        XCTAssertEqual(InsightMetric.averageTime.value(for: records)!, 300, accuracy: 0.001)
    }

    func testSecondsPerCellPoolsGapsRatherThanAveragingAverages() {
        // 250/50 = 5s and 100/100 = 1s; pooled is 350/150, not the 3s mean of the two.
        let records = [
            record(gapTotal: 250, gaps: 50),
            record(gapTotal: 100, gaps: 100)
        ]
        XCTAssertEqual(InsightMetric.secondsPerCell.value(for: records)!, 350.0 / 150.0, accuracy: 0.0001)
    }

    func testNoteAccuracyAndWastedTaps() {
        let records = [record(notes: 40, incorrectNotes: 4)]
        XCTAssertEqual(InsightMetric.noteAccuracy.value(for: records)!, 0.9, accuracy: 0.0001)
        XCTAssertEqual(InsightMetric.noteAccuracy.formattedValue(for: records), "90%")

        XCTAssertEqual(InsightMetric.wastedTapRate.value(for: records)!, 0.2, accuracy: 0.0001)
        XCTAssertEqual(InsightMetric.wastedTapsPerGame.value(for: records)!, 20, accuracy: 0.0001)
    }

    func testNotesPerGameIsTracked() {
        let records = [record(notes: 30), record(notes: 50)]
        XCTAssertEqual(InsightMetric.notesPerGame.value(for: records)!, 40, accuracy: 0.0001)
    }

    func testFastestCellMetricIsGone() {
        XCTAssertFalse(InsightMetric.all.contains { $0.id == "fastestCell" })
        XCTAssertTrue(InsightMetric.all.contains { $0.id == "notesPerGame" })
        XCTAssertTrue(InsightMetric.all.contains { $0.id == "wastedTapsPerGame" })
    }

    func testTrendBucketsRecentDaysAndKeepsGaps() {
        let records = [
            record(daysAgo: 0, duration: 100),
            record(daysAgo: 0, duration: 200),
            record(daysAgo: 3, duration: 600)
        ]
        let series = TrendBuilder.series(metric: .averageTime, records: records, range: .day)

        XCTAssertEqual(series.count, TrendRange.day.bucketCount)
        XCTAssertEqual(series.last?.value, 150) // today's two games averaged
        XCTAssertEqual(series.last?.gameCount, 2)

        let threeDaysAgo = series[series.count - 4]
        XCTAssertEqual(threeDaysAgo.value, 600)

        // The day between is empty and must stay in the series so the gap is visible.
        XCTAssertNil(series[series.count - 2].value)
        XCTAssertEqual(series[series.count - 2].gameCount, 0)
    }

    func testTrendIgnoresGamesOutsideTheWindow() {
        let series = TrendBuilder.series(
            metric: .averageTime,
            records: [record(daysAgo: 400)],
            range: .day
        )
        XCTAssertTrue(series.allSatisfy { $0.value == nil })
    }

    func testDifficultyFilterCoversEveryLevel() {
        for difficulty in Difficulty.allCases {
            let match = DifficultyFilter.allCases.first { $0.difficulty == difficulty }
            XCTAssertNotNil(match, "no filter for \(difficulty.rawValue)")
        }
        XCTAssertNil(DifficultyFilter.all.difficulty)
    }

    func testHistoryStoreRoundTripsAndCaps() {
        let defaults = UserDefaults(suiteName: "InsightMetricTests")!
        defaults.removePersistentDomain(forName: "InsightMetricTests")

        var last: [GameRecord] = []
        for _ in 0..<(GameHistoryStore.maxRecords + 10) {
            last = GameHistoryStore.append(record(), to: defaults)
        }
        XCTAssertEqual(last.count, GameHistoryStore.maxRecords)
        XCTAssertEqual(GameHistoryStore.load(from: defaults).count, GameHistoryStore.maxRecords)

        defaults.removePersistentDomain(forName: "InsightMetricTests")
    }
}
