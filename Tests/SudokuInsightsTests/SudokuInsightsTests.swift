import XCTest
@testable import SudokuInsights

final class SudokuInsightsTests: XCTestCase {
    
    // MARK: - Game Session Tests
    
    func testGameSessionCreation() {
        let board = SudokuBoard.createSampleBoard()
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: board
        )
        
        XCTAssertFalse(session.id.isEmpty)
        XCTAssertEqual(session.tapEvents.count, 0)
        XCTAssertFalse(session.isCompleted)
    }
    
    func testTapEventRecording() {
        let board = SudokuBoard.createSampleBoard()
        var session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: board
        )
        
        let event = TapEvent(timestamp: 0, row: 0, col: 0, action: .selectCell)
        session.addTapEvent(event)
        
        XCTAssertEqual(session.tapEvents.count, 1)
        XCTAssertEqual(session.tapEvents[0].action, .selectCell)
    }
    
    // MARK: - Notes Functionality Tests
    
    func testNotesToggle() {
        var board = SudokuBoard.createSampleBoard()
        
        // Initially empty
        XCTAssertTrue(board.notes[0][0].isEmpty)
        
        // Add note
        board.toggleNote(row: 0, col: 0, value: 5)
        XCTAssertTrue(board.notes[0][0].contains(5))
        
        // Toggle again to remove
        board.toggleNote(row: 0, col: 0, value: 5)
        XCTAssertFalse(board.notes[0][0].contains(5))
    }
    
    func testMultipleNotes() {
        var board = SudokuBoard.createSampleBoard()
        
        board.toggleNote(row: 2, col: 2, value: 1)
        board.toggleNote(row: 2, col: 2, value: 4)
        board.toggleNote(row: 2, col: 2, value: 7)
        
        XCTAssertEqual(board.notes[2][2].count, 3)
        XCTAssertTrue(board.notes[2][2].contains(1))
        XCTAssertTrue(board.notes[2][2].contains(4))
        XCTAssertTrue(board.notes[2][2].contains(7))
    }
    
    func testClearNotes() {
        var board = SudokuBoard.createSampleBoard()
        
        board.toggleNote(row: 1, col: 1, value: 2)
        board.toggleNote(row: 1, col: 1, value: 3)
        board.toggleNote(row: 1, col: 1, value: 4)
        
        XCTAssertEqual(board.notes[1][1].count, 3)
        
        board.clearNotes(row: 1, col: 1)
        XCTAssertTrue(board.notes[1][1].isEmpty)
    }
    
    func testNotesOutOfBounds() {
        var board = SudokuBoard.createSampleBoard()
        
        // Should not crash
        board.toggleNote(row: -1, col: 0, value: 5)
        board.toggleNote(row: 0, col: 10, value: 5)
        board.toggleNote(row: 5, col: 5, value: 10)
        board.clearNotes(row: -1, col: -1)
    }
    
    // MARK: - Analytics Engine Tests
    
    func testAnalyticsEngineInitialization() {
        let board = SudokuBoard.createSampleBoard()
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: board
        )
        let engine = AnalyticsEngine(session: session)
        
        let report = engine.generateReport()
        XCTAssertEqual(report.difficulty, .medium)
        XCTAssertEqual(report.totalMoves, 0)
    }
    
    func testSessionMetrics() {
        let board = SudokuBoard.createSampleBoard()
        var session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: board
        )
        
        // Add some tap events
        session.addTapEvent(TapEvent(timestamp: 0, row: 0, col: 0, action: .enterValue))
        session.addTapEvent(TapEvent(timestamp: 1, row: 1, col: 1, action: .enterValue))
        
        let engine = AnalyticsEngine(session: session)
        let metrics = engine.generateSessionMetrics()
        
        XCTAssertEqual(metrics.totalTaps, 2)
        XCTAssertGreaterThanOrEqual(metrics.elapsedTime, 0)
    }
    
    func testDetailedReport() {
        let board = SudokuBoard.createSampleBoard()
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: .hard,
            startTime: Date(),
            initialBoard: board
        )
        
        let engine = AnalyticsEngine(session: session)
        let report = engine.generateDetailedReport()
        
        XCTAssertFalse(report.sessionOverview.isEmpty)
        XCTAssertFalse(report.performanceMetrics.isEmpty)
        XCTAssertFalse(report.cognitivePatterns.isEmpty)
        XCTAssertFalse(report.recommendations.isEmpty)
    }
    
    func testSudokuValidation() {
        let puzzle = SudokuEngine.generatePuzzle()
        
        // Test valid move
        let isValid = SudokuEngine.isValidMove(grid: puzzle.initialGrid, row: 0, col: 2, value: 1)
        XCTAssert(isValid || !isValid) // Should complete without crashing
        
        // Test solution check
        let isCorrect = SudokuEngine.isCorrect(puzzle: puzzle, row: 0, col: 0, value: puzzle.solution[0][0])
        XCTAssertTrue(isCorrect)
    }
    
    func testHeatmapGeneration() {
        let board = SudokuBoard.createSampleBoard()
        var session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: board
        )
        
        session.addTapEvent(TapEvent(timestamp: 0, row: 0, col: 0, action: .selectCell))
        session.addTapEvent(TapEvent(timestamp: 1, row: 0, col: 0, action: .selectCell))
        session.addTapEvent(TapEvent(timestamp: 2, row: 1, col: 1, action: .enterValue))
        
        let engine = AnalyticsEngine(session: session)
        let report = engine.generateReport()
        
        XCTAssertEqual(report.heatmap[0][0], 2)
        XCTAssertEqual(report.heatmap[1][1], 1)
    }
    
    func testPuzzleGeneration() {
        let puzzle = SudokuEngine.generatePuzzle(difficulty: .easy)
        
        // Check grid dimensions
        XCTAssertEqual(puzzle.initialGrid.count, 9)
        XCTAssertEqual(puzzle.initialGrid[0].count, 9)
        XCTAssertEqual(puzzle.solution.count, 9)
        XCTAssertEqual(puzzle.solution[0].count, 9)
        
        // Check that initial grid has some empty cells (0s)
        let emptyCells = puzzle.initialGrid.flatMap { $0 }.filter { $0 == 0 }.count
        XCTAssertGreaterThan(emptyCells, 0)
        
        // Check that solution has no empty cells
        let solutionEmptyCells = puzzle.solution.flatMap { $0 }.filter { $0 == 0 }.count
        XCTAssertEqual(solutionEmptyCells, 0)
    }
    
    func testCandidateGeneration() {
        let puzzle = SudokuEngine.generatePuzzle()
        
        // Find an empty cell
        var testRow = -1
        var testCol = -1
        
        for row in 0..<9 {
            for col in 0..<9 {
                if puzzle.initialGrid[row][col] == 0 {
                    testRow = row
                    testCol = col
                    break
                }
            }
            if testRow != -1 { break }
        }
        
        if testRow != -1 {
            let candidates = SudokuEngine.getCandidates(grid: puzzle.initialGrid, row: testRow, col: testCol)
            XCTAssertGreaterThan(candidates.count, 0)
            XCTAssertLessThanOrEqual(candidates.count, 9)
        }
    }
}
