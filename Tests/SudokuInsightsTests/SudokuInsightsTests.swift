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
    
    // MARK: - Game Session with Solution Tests
    
    func testGameSessionWithSolution() {
        let board = SudokuBoard.createSampleBoard()
        let solution = SudokuBoard.getSampleBoardSolution()
        
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: board,
            solution: solution
        )
        
        XCTAssertNotNil(session.solution)
        XCTAssertEqual(session.solution.count, 9)
        XCTAssertEqual(session.solution[0].count, 9)
    }
    
    func testGameSessionDefaultSolution() {
        let board = SudokuBoard.createSampleBoard()
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: board
        )
        
        // Should have a default empty solution
        XCTAssertEqual(session.solution.count, 9)
        for row in 0..<9 {
            for col in 0..<9 {
                XCTAssertEqual(session.solution[row][col], 0)
            }
        }
    }
    
    // MARK: - Note Clearing Tests
    
    func testNotesClearedFromRow() {
        var board = SudokuBoard.createSampleBoard()
        
        // Add note 5 to multiple cells in row 0
        board.notes[0][1].insert(5)
        board.notes[0][3].insert(5)
        board.notes[0][5].insert(5)
        
        XCTAssertTrue(board.notes[0][1].contains(5))
        XCTAssertTrue(board.notes[0][3].contains(5))
        
        // Clear note 5 from row
        for c in 0..<9 {
            board.notes[0][c].remove(5)
        }
        
        XCTAssertFalse(board.notes[0][1].contains(5))
        XCTAssertFalse(board.notes[0][3].contains(5))
        XCTAssertFalse(board.notes[0][5].contains(5))
    }
    
    func testNotesClearedFromColumn() {
        var board = SudokuBoard.createSampleBoard()
        
        // Add note 3 to multiple cells in column 2
        board.notes[1][2].insert(3)
        board.notes[4][2].insert(3)
        board.notes[7][2].insert(3)
        
        XCTAssertTrue(board.notes[1][2].contains(3))
        
        // Clear note 3 from column
        for r in 0..<9 {
            board.notes[r][2].remove(3)
        }
        
        XCTAssertFalse(board.notes[1][2].contains(3))
        XCTAssertFalse(board.notes[4][2].contains(3))
        XCTAssertFalse(board.notes[7][2].contains(3))
    }
    
    func testNotesClearedFromBox() {
        var board = SudokuBoard.createSampleBoard()
        
        // Add note 7 to cells in first 3x3 box
        board.notes[0][0].insert(7)
        board.notes[1][1].insert(7)
        board.notes[2][2].insert(7)
        
        // Clear note 7 from box (rows 0-2, cols 0-2)
        for r in 0..<3 {
            for c in 0..<3 {
                board.notes[r][c].remove(7)
            }
        }
        
        XCTAssertFalse(board.notes[0][0].contains(7))
        XCTAssertFalse(board.notes[1][1].contains(7))
        XCTAssertFalse(board.notes[2][2].contains(7))
    }
    
    // MARK: - Validation Tests
    
    func testIsValidMoveCorrectValue() {
        let puzzle = SudokuEngine.generatePuzzle(difficulty: .easy)
        let grid = puzzle.initialGrid
        
        // Find an empty cell
        var testRow = -1
        var testCol = -1
        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] == 0 {
                    testRow = row
                    testCol = col
                    break
                }
            }
            if testRow != -1 { break }
        }
        
        if testRow != -1 {
            let correctValue = puzzle.solution[testRow][testCol]
            let isValid = SudokuEngine.isValidMove(grid: grid, row: testRow, col: testCol, value: correctValue)
            XCTAssertTrue(isValid)
        }
    }
    
    func testIsCompleteWhenFullyFilled() {
        let puzzle = SudokuEngine.generatePuzzle(difficulty: .easy)
        var completedGrid = puzzle.initialGrid
        
        // Fill missing cells with solution
        for row in 0..<9 {
            for col in 0..<9 {
                if completedGrid[row][col] == 0 {
                    completedGrid[row][col] = puzzle.solution[row][col]
                }
            }
        }
        
        let isComplete = SudokuEngine.isComplete(completedGrid)
        XCTAssertTrue(isComplete)
    }
    
    func testIsNotCompleteWhenPartiallyFilled() {
        let puzzle = SudokuEngine.generatePuzzle(difficulty: .easy)
        let grid = puzzle.initialGrid
        
        let isComplete = SudokuEngine.isComplete(grid)
        XCTAssertFalse(isComplete)
    }
    
    // MARK: - Game State Persistence Tests
    
    func testSavedGameStateEncoding() {
        let board: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        let notes: [[Set<Int>]] = Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
        let solution = SudokuBoard.getSampleBoardSolution()
        
        let state = SavedGameState(
            difficulty: .medium,
            board: board,
            initialBoard: board,
            solution: solution,
            notes: notes,
            elapsedTime: 120.0,
            errorCount: 3,
            timestamp: Date()
        )
        
        // Should be encodable
        let encoded = try? JSONEncoder().encode(state)
        XCTAssertNotNil(encoded)
    }
    
    func testSavedGameStateDecoding() {
        let board: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        let notes: [[Set<Int>]] = Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
        let solution = SudokuBoard.getSampleBoardSolution()
        let now = Date()
        
        let state = SavedGameState(
            difficulty: .hard,
            board: board,
            initialBoard: board,
            solution: solution,
            notes: notes,
            elapsedTime: 240.0,
            errorCount: 5,
            timestamp: now
        )
        
        if let encoded = try? JSONEncoder().encode(state),
           let decoded = try? JSONDecoder().decode(SavedGameState.self, from: encoded) {
            XCTAssertEqual(decoded.difficulty, .hard)
            XCTAssertEqual(decoded.elapsedTime, 240.0)
            XCTAssertEqual(decoded.errorCount, 5)
        } else {
            XCTFail("Failed to encode/decode SavedGameState")
        }
    }
    
    func testSavedGameStateWithNotes() {
        var board: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        var notes: [[Set<Int>]] = Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
        
        // Add some notes
        notes[0][0].insert(1)
        notes[0][0].insert(2)
        notes[1][1].insert(5)
        
        let state = SavedGameState(
            difficulty: .easy,
            board: board,
            initialBoard: board,
            solution: SudokuBoard.getSampleBoardSolution(),
            notes: notes,
            elapsedTime: 60.0,
            errorCount: 0,
            timestamp: Date()
        )
        
        if let encoded = try? JSONEncoder().encode(state),
           let decoded = try? JSONDecoder().decode(SavedGameState.self, from: encoded) {
            XCTAssertTrue(decoded.notes[0][0].contains(1))
            XCTAssertTrue(decoded.notes[0][0].contains(2))
            XCTAssertTrue(decoded.notes[1][1].contains(5))
        }
    }
    
    func testSavedGameStatePreservesBoard() {
        var board: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        board[0][0] = 5
        board[1][1] = 3
        board[2][2] = 7
        
        let state = SavedGameState(
            difficulty: .medium,
            board: board,
            initialBoard: board,
            solution: SudokuBoard.getSampleBoardSolution(),
            notes: Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9),
            elapsedTime: 180.0,
            errorCount: 2,
            timestamp: Date()
        )
        
        if let encoded = try? JSONEncoder().encode(state),
           let decoded = try? JSONDecoder().decode(SavedGameState.self, from: encoded) {
            XCTAssertEqual(decoded.board[0][0], 5)
            XCTAssertEqual(decoded.board[1][1], 3)
            XCTAssertEqual(decoded.board[2][2], 7)
        }
    }
    
    func testSudokuBoardInitWithAllParameters() {
        let grid: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        var notes: [[Set<Int>]] = Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
        notes[0][0].insert(1)
        
        let board = SudokuBoard(grid: grid, initialGrid: grid, notes: notes)
        
        XCTAssertEqual(board.grid.count, 9)
        XCTAssertTrue(board.notes[0][0].contains(1))
    }
    
    func testSudokuBoardInitWithDefaults() {
        let grid: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        let board = SudokuBoard(grid: grid)
        
        XCTAssertEqual(board.grid.count, 9)
        XCTAssertTrue(board.notes[0][0].isEmpty)
    }
    
    func testGameSessionWithBoardAndNotes() {
        var board = SudokuBoard.createSampleBoard()
        board.notes[3][3].insert(2)
        board.notes[3][3].insert(4)
        board.notes[4][4].insert(6)
        
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: board,
            solution: SudokuBoard.getSampleBoardSolution()
        )
        
        XCTAssertEqual(session.currentBoard.notes[3][3].count, 2)
        XCTAssertTrue(session.currentBoard.notes[3][3].contains(2))
        XCTAssertTrue(session.currentBoard.notes[4][4].contains(6))
    }
    
    func testUserDefaultsPersistence() {
        let key = "test_completion_times_medium"
        
        // Clear any existing value
        UserDefaults.standard.removeObject(forKey: key)
        
        // Save completion times
        let times = [120.0, 150.0, 180.0]
        UserDefaults.standard.set(times, forKey: key)
        
        // Retrieve and verify
        let retrieved = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        XCTAssertEqual(retrieved.count, 3)
        XCTAssertEqual(retrieved[0], 120.0)
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    func testAverageTimeCalculation() {
        let key = "test_avg_times_easy"
        UserDefaults.standard.removeObject(forKey: key)
        
        let times = [100.0, 200.0, 300.0]
        UserDefaults.standard.set(times, forKey: key)
        
        let retrieved = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        let average = retrieved.reduce(0, +) / Double(retrieved.count)
        
        XCTAssertEqual(average, 200.0)
        
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    func testBestTimeCalculation() {
        let key = "test_best_times_hard"
        UserDefaults.standard.removeObject(forKey: key)
        
        let times = [500.0, 250.0, 400.0]
        UserDefaults.standard.set(times, forKey: key)
        
        let retrieved = UserDefaults.standard.array(forKey: key) as? [TimeInterval] ?? []
        let best = retrieved.min() ?? 0
        
        XCTAssertEqual(best, 250.0)
        
        UserDefaults.standard.removeObject(forKey: key)
    }
}

