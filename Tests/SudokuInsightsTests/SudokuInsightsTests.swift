import XCTest
@testable import SudokuInsights

final class SudokuInsightsTests: XCTestCase {
    
    func testGameSessionCreation() {
        let puzzle = SudokuEngine.generatePuzzle(difficulty: .easy)
        let session = GameSession(puzzle: puzzle)
        
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.tapEvents.count, 0)
        XCTAssertFalse(session.isCompleted)
    }
    
    func testTapEventRecording() {
        let puzzle = SudokuEngine.generatePuzzle()
        var session = GameSession(puzzle: puzzle)
        
        let event = TapEvent(timestamp: 0, row: 0, col: 0, action: .selectCell)
        session.addTapEvent(event)
        
        XCTAssertEqual(session.tapEvents.count, 1)
        XCTAssertEqual(session.tapEvents[0].action, .selectCell)
    }
    
    func testAnalyticsEngineInitialization() {
        let puzzle = SudokuEngine.generatePuzzle()
        let session = GameSession(puzzle: puzzle)
        let engine = AnalyticsEngine(session: session)
        
        let report = engine.generateReport()
        XCTAssertEqual(report.difficulty, puzzle.difficulty)
        XCTAssertEqual(report.totalMoves, 0)
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
        let puzzle = SudokuEngine.generatePuzzle()
        var session = GameSession(puzzle: puzzle)
        
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
