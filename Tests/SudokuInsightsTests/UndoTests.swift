import XCTest
@testable import SudokuInsights

@MainActor
final class UndoTests: XCTestCase {
    private func makeGame() async -> (SharedAppViewModel, (row: Int, col: Int)) {
        let vm = SharedAppViewModel()
        vm.startNewGame(difficulty: .medium)
        while vm.isGeneratingPuzzle { await Task.yield() }

        for row in 0..<9 {
            for col in 0..<9 {
                if vm.currentSession.initialBoard.grid[row][col] == 0 {
                    vm.boardViewModel.selectedCell = (row, col)
                    return (vm, (row, col))
                }
            }
        }
        fatalError("puzzle had no empty cells")
    }

    func testUndoIsUnavailableOnAFreshGame() async {
        let (vm, _) = await makeGame()
        XCTAssertFalse(vm.canUndo)

        vm.undo()
        XCTAssertFalse(vm.canUndo)
    }

    func testUndoRevertsAValueEntry() async {
        let (vm, cell) = await makeGame()

        vm.handleKeyPress(5)
        XCTAssertEqual(vm.currentSession.currentBoard.grid[cell.row][cell.col], 5)
        XCTAssertTrue(vm.canUndo)

        vm.undo()
        XCTAssertEqual(vm.currentSession.currentBoard.grid[cell.row][cell.col], 0)
        XCTAssertFalse(vm.canUndo)
    }

    func testUndoRevertsANoteToggle() async {
        let (vm, cell) = await makeGame()
        vm.isNoteTakingMode = true

        vm.handleKeyPress(3)
        XCTAssertTrue(vm.currentSession.currentBoard.notes[cell.row][cell.col].contains(3))

        vm.undo()
        XCTAssertFalse(vm.currentSession.currentBoard.notes[cell.row][cell.col].contains(3))
    }

    func testUndoRestoresNotesClearedByAValueEntry() async {
        let (vm, cell) = await makeGame()

        vm.isNoteTakingMode = true
        vm.handleKeyPress(4)
        vm.handleKeyPress(7)
        vm.isNoteTakingMode = false

        let notesBefore = vm.currentSession.currentBoard.notes[cell.row][cell.col]
        XCTAssertEqual(notesBefore, [4, 7])

        vm.handleKeyPress(vm.currentSession.solution[cell.row][cell.col])
        XCTAssertTrue(vm.currentSession.currentBoard.notes[cell.row][cell.col].isEmpty)

        vm.undo()
        XCTAssertEqual(vm.currentSession.currentBoard.notes[cell.row][cell.col], notesBefore)
        XCTAssertEqual(vm.currentSession.currentBoard.grid[cell.row][cell.col], 0)
    }

    func testSuccessiveUndosRevertMovesInReverseOrder() async {
        let (vm, first) = await makeGame()

        var cells: [(row: Int, col: Int)] = []
        for row in 0..<9 {
            for col in 0..<9 where vm.currentSession.initialBoard.grid[row][col] == 0 {
                cells.append((row, col))
                if cells.count == 3 { break }
            }
            if cells.count == 3 { break }
        }
        XCTAssertEqual(cells.first?.row, first.row)

        for (index, cell) in cells.enumerated() {
            vm.boardViewModel.selectedCell = cell
            vm.handleKeyPress(index + 1)
        }

        for (index, cell) in cells.enumerated().reversed() {
            XCTAssertEqual(vm.currentSession.currentBoard.grid[cell.row][cell.col], index + 1)
            vm.undo()
            XCTAssertEqual(vm.currentSession.currentBoard.grid[cell.row][cell.col], 0)
        }

        XCTAssertFalse(vm.canUndo)
    }

    func testUndoRestoresTheErrorCount() async {
        let (vm, cell) = await makeGame()
        let solution = vm.currentSession.solution[cell.row][cell.col]
        let wrong = solution == 9 ? 1 : solution + 1

        XCTAssertEqual(vm.errorCount, 0)
        vm.handleKeyPress(wrong)
        XCTAssertEqual(vm.errorCount, 1)

        vm.undo()
        XCTAssertEqual(vm.errorCount, 0)
    }

    func testStartingANewGameClearsUndoHistory() async {
        let (vm, _) = await makeGame()
        vm.handleKeyPress(5)
        XCTAssertTrue(vm.canUndo)

        vm.startNewGame(difficulty: .easy)
        XCTAssertFalse(vm.canUndo)
    }

    func testDeletingAnEmptyCellDoesNotCreateAnUndoStep() async {
        let (vm, _) = await makeGame()

        vm.handleDelete()
        XCTAssertFalse(vm.canUndo)
    }
}
