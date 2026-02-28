import XCTest
@testable import SudokuInsights
import Combine

final class AppViewModelTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    }
    
    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        super.tearDown()
    }
    
    // MARK: - Timer Tests
    
    func testTimerInitialization() {
        let viewModel = AppViewModel()
        XCTAssertEqual(viewModel.elapsedTime, 0)
        XCTAssertEqual(viewModel.formattedTime, "00:00")
    }
    
    func testFormattedTimeCorrectly() {
        let viewModel = AppViewModel()
        viewModel.elapsedTime = 0
        XCTAssertEqual(viewModel.formattedTime, "00:00")
        
        viewModel.elapsedTime = 65 // 1 minute 5 seconds
        XCTAssertEqual(viewModel.formattedTime, "01:05")
        
        viewModel.elapsedTime = 3661 // 1 hour 1 minute 1 second
        XCTAssertEqual(viewModel.formattedTime, "61:01")
    }
    
    func testGameResetClearsTimer() {
        let viewModel = AppViewModel()
        viewModel.elapsedTime = 120
        
        viewModel.startNewGame(difficulty: .easy)
        XCTAssertEqual(viewModel.elapsedTime, 0)
    }
    
    // MARK: - Error Tracking Tests
    
    func testErrorCountInitialization() {
        let viewModel = AppViewModel()
        XCTAssertEqual(viewModel.errorCount, 0)
    }
    
    func testErrorTrackingOnIncorrectEntry() {
        let viewModel = AppViewModel()
        let initialErrorCount = viewModel.errorCount
        
        // Select a cell
        viewModel.boardViewModel.selectedCell = (row: 0, col: 2)
        
        // Enter an incorrect number (solution at [0,2] is 4)
        viewModel.handleKeyPress(1) // Wrong number
        
        XCTAssertEqual(viewModel.errorCount, initialErrorCount + 1)
    }
    
    func testCorrectEntryDoesntIncrementErrors() {
        let viewModel = AppViewModel()
        let initialErrorCount = viewModel.errorCount
        
        // Solution at [0,0] is 5
        viewModel.boardViewModel.selectedCell = (row: 0, col: 0)
        viewModel.handleKeyPress(5) // Correct number
        
        XCTAssertEqual(viewModel.errorCount, initialErrorCount)
    }
    
    func testErrorCountResetOnNewGame() {
        let viewModel = AppViewModel()
        viewModel.errorCount = 5
        
        viewModel.startNewGame(difficulty: .medium)
        XCTAssertEqual(viewModel.errorCount, 0)
    }
    
    // MARK: - Candidate Tracking Tests
    
    func testAvailableCandidatesInitialization() {
        let viewModel = AppViewModel()
        XCTAssertEqual(viewModel.availableCandidates.count, 9)
        for i in 1...9 {
            XCTAssertTrue(viewModel.availableCandidates.contains(i))
        }
    }
    
    func testCandidateClearedWhenAllPlaced() {
        let viewModel = AppViewModel()
        
        // Place all 9 correct instances of number 5
        // The sample board has 5s at specific positions in the solution
        // We need to fill in all the missing 5s
        for row in 0..<9 {
            for col in 0..<9 {
                if viewModel.currentSession.solution[row][col] == 5 {
                    viewModel.currentSession.currentBoard.grid[row][col] = 5
                }
            }
        }
        
        viewModel.validateBoard()
        
        // 5 should be removed from available candidates
        XCTAssertFalse(viewModel.availableCandidates.contains(5))
    }
    
    // MARK: - Note Clearing Tests
    
    func testNotesClearedWhenCorrectNumberEntered() {
        let viewModel = AppViewModel()
        
        // Add notes to multiple cells in a row/column/box
        viewModel.currentSession.currentBoard.notes[0][0].insert(5)
        viewModel.currentSession.currentBoard.notes[0][3].insert(5)
        viewModel.currentSession.currentBoard.notes[3][0].insert(5)
        viewModel.currentSession.currentBoard.notes[1][1].insert(5) // Same 3x3 box
        
        // Place a correct 5
        viewModel.boardViewModel.selectedCell = (row: 0, col: 0)
        viewModel.handleKeyPress(5)
        
        // All related notes containing 5 should be cleared
        XCTAssertFalse(viewModel.currentSession.currentBoard.notes[0][3].contains(5))
        XCTAssertFalse(viewModel.currentSession.currentBoard.notes[3][0].contains(5))
        XCTAssertFalse(viewModel.currentSession.currentBoard.notes[1][1].contains(5))
    }
    
    // MARK: - Win Detection Tests
    
    func testGameNotCompleteInitially() {
        let viewModel = AppViewModel()
        XCTAssertFalse(viewModel.isGameComplete)
    }
    
    func testGameCompletionDetection() {
        let viewModel = AppViewModel()
        
        // Fill the board with the solution
        for row in 0..<9 {
            for col in 0..<9 {
                viewModel.currentSession.currentBoard.grid[row][col] = viewModel.currentSession.solution[row][col]
            }
        }
        
        viewModel.checkGameCompletion()
        XCTAssertTrue(viewModel.isGameComplete)
    }
    
    func testIncompleteGameNotMarkedComplete() {
        let viewModel = AppViewModel()
        
        // Fill board with solution except one cell
        for row in 0..<9 {
            for col in 0..<9 {
                if row == 0 && col == 0 {
                    viewModel.currentSession.currentBoard.grid[row][col] = 0 // Leave empty
                } else {
                    viewModel.currentSession.currentBoard.grid[row][col] = viewModel.currentSession.solution[row][col]
                }
            }
        }
        
        viewModel.checkGameCompletion()
        XCTAssertFalse(viewModel.isGameComplete)
    }
    
    // MARK: - Persistence Tests
    
    func testCompletionTimeSavedToUserDefaults() {
        let viewModel = AppViewModel()
        viewModel.elapsedTime = 120
        viewModel.saveCompletionTime()
        
        let key = "completionTimes_medium"
        let savedTimes = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        
        XCTAssertTrue(savedTimes.contains(120))
    }
    
    func testAverageTimeCalculation() {
        let viewModel = AppViewModel()
        
        // Save multiple completion times
        UserDefaults.standard.set([60.0, 90.0, 120.0], forKey: "completionTimes_medium")
        
        let average = viewModel.averageTimeForDifficulty()
        XCTAssertNotNil(average)
        XCTAssertEqual(average, 90.0)
    }
    
    func testAverageTimeNilWhenNoGames() {
        let viewModel = AppViewModel()
        UserDefaults.standard.removeObject(forKey: "completionTimes_medium")
        
        let average = viewModel.averageTimeForDifficulty()
        XCTAssertNil(average)
    }
    
    func testFormattedTimeInterval() {
        let viewModel = AppViewModel()
        
        XCTAssertEqual(viewModel.formattedTimeInterval(0), "00:00")
        XCTAssertEqual(viewModel.formattedTimeInterval(65), "01:05")
        XCTAssertEqual(viewModel.formattedTimeInterval(3661), "61:01")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteGameFlow() {
        let viewModel = AppViewModel()
        
        // Game starts in correct state
        XCTAssertFalse(viewModel.isGameComplete)
        XCTAssertEqual(viewModel.errorCount, 0)
        XCTAssertEqual(viewModel.elapsedTime, 0)
        
        // Fill board with solution
        for row in 0..<9 {
            for col in 0..<9 {
                viewModel.currentSession.currentBoard.grid[row][col] = viewModel.currentSession.solution[row][col]
            }
        }
        
        // Complete the game
        viewModel.validateBoard()
        viewModel.checkGameCompletion()
        
        // Verify final state
        XCTAssertTrue(viewModel.isGameComplete)
        XCTAssertEqual(viewModel.availableCandidates.count, 0) // All numbers placed
    }
    
    func testNewGameResetsAllState() {
        let viewModel = AppViewModel()
        
        // Modify state
        viewModel.elapsedTime = 300
        viewModel.errorCount = 5
        viewModel.isGameComplete = true
        viewModel.availableCandidates.remove(5)
        viewModel.invalidCells.insert("0,0")
        viewModel.correctCells.insert("0,1")
        
        // Reset with new game
        viewModel.startNewGame(difficulty: .hard)
        
        // Verify all state is reset
        XCTAssertEqual(viewModel.elapsedTime, 0)
        XCTAssertEqual(viewModel.errorCount, 0)
        XCTAssertFalse(viewModel.isGameComplete)
        XCTAssertEqual(viewModel.availableCandidates.count, 9)
        XCTAssertTrue(viewModel.invalidCells.isEmpty)
        XCTAssertTrue(viewModel.correctCells.isEmpty)
    }
}
