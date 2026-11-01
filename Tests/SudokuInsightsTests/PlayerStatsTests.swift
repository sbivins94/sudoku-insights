import XCTest
@testable import SudokuInsights

@MainActor
final class PlayerStatsTests: XCTestCase {
    private func makeGame() async -> (SharedAppViewModel, (row: Int, col: Int)) {
        GameHistoryStore.reset()
        let vm = SharedAppViewModel()
        vm.startNewGame(difficulty: .easy)
        while vm.isGeneratingPuzzle { await Task.yield() }

        for row in 0..<9 {
            for col in 0..<9 where vm.currentSession.initialBoard.grid[row][col] == 0 {
                vm.boardViewModel.selectedCell = (row, col)
                return (vm, (row, col))
            }
        }
        fatalError("puzzle had no empty cells")
    }

    override func tearDown() {
        GameHistoryStore.reset()
        super.tearDown()
    }

    func testCorrectAndIncorrectPlacementsAreCounted() async {
        let (vm, cell) = await makeGame()
        let answer = vm.currentSession.solution[cell.row][cell.col]

        vm.handleKeyPress(answer == 9 ? 1 : answer + 1)
        XCTAssertEqual(vm.currentMetrics.errors, 1)
        XCTAssertEqual(vm.currentMetrics.correctPlacements, 0)

        vm.handleKeyPress(answer)
        XCTAssertEqual(vm.currentMetrics.correctPlacements, 1)
        XCTAssertEqual(vm.currentMetrics.errors, 1)
    }

    func testImpossibleNotesAreFlagged() async {
        let (vm, cell) = await makeGame()
        let answer = vm.currentSession.solution[cell.row][cell.col]
        vm.isNoteTakingMode = true

        vm.handleKeyPress(answer)
        XCTAssertEqual(vm.currentMetrics.notesAdded, 1)
        XCTAssertEqual(vm.currentMetrics.incorrectNotes, 0)

        vm.handleKeyPress(answer == 9 ? 1 : answer + 1)
        XCTAssertEqual(vm.currentMetrics.notesAdded, 2)
        XCTAssertEqual(vm.currentMetrics.incorrectNotes, 1)
    }

    func testRemovingANoteIsNotCountedAsANewNote() async {
        let (vm, cell) = await makeGame()
        let answer = vm.currentSession.solution[cell.row][cell.col]
        vm.isNoteTakingMode = true

        vm.handleKeyPress(answer)
        vm.handleKeyPress(answer) // toggles it back off
        XCTAssertEqual(vm.currentMetrics.notesAdded, 1)
    }

    func testTappingAGivenCellCountsAsUnproductive() async {
        let (vm, _) = await makeGame()

        var given: (row: Int, col: Int)?
        outer: for row in 0..<9 {
            for col in 0..<9 where vm.currentSession.initialBoard.grid[row][col] != 0 {
                given = (row, col)
                break outer
            }
        }
        let target = given!

        vm.recordCellTap(row: target.row, col: target.col)
        XCTAssertEqual(vm.currentMetrics.cellTaps, 1)
        XCTAssertEqual(vm.currentMetrics.unproductiveTaps, 1)
    }

    func testTappingAnEmptyCellIsProductive() async {
        let (vm, cell) = await makeGame()

        vm.recordCellTap(row: cell.row, col: cell.col)
        XCTAssertEqual(vm.currentMetrics.cellTaps, 1)
        XCTAssertEqual(vm.currentMetrics.unproductiveTaps, 0)
    }

    func testStartingANewGameResetsPerGameCounters() async {
        let (vm, cell) = await makeGame()
        vm.handleKeyPress(vm.currentSession.solution[cell.row][cell.col])
        XCTAssertEqual(vm.currentMetrics.correctPlacements, 1)

        vm.startNewGame(difficulty: .easy)
        while vm.isGeneratingPuzzle { await Task.yield() }
        XCTAssertEqual(vm.currentMetrics.correctPlacements, 0)
    }

    func testFinishingAGameAppendsARecord() async {
        let (vm, _) = await makeGame()
        XCTAssertTrue(vm.history.isEmpty)

        vm.elapsedTime = 321
        for row in 0..<9 {
            for col in 0..<9 {
                vm.currentSession.currentBoard.grid[row][col] = vm.currentSession.solution[row][col]
            }
        }
        vm.validateBoard()
        vm.checkGameCompletion()

        XCTAssertEqual(vm.history.count, 1)
        let record = vm.history[0]
        XCTAssertEqual(record.difficulty, .easy)
        XCTAssertEqual(record.duration, 321)
        XCTAssertEqual(GameHistoryStore.load().count, 1)
    }
}
