import XCTest
@testable import SudokuInsights

@MainActor
final class EraseTests: XCTestCase {
    private func makeGame() async -> (SharedAppViewModel, empty: (row: Int, col: Int), given: (row: Int, col: Int)) {
        GameHistoryStore.reset()
        let vm = SharedAppViewModel()
        vm.startNewGame(difficulty: .easy)
        while vm.isGeneratingPuzzle { await Task.yield() }

        var empty: (row: Int, col: Int)?
        var given: (row: Int, col: Int)?
        for row in 0..<9 {
            for col in 0..<9 {
                if vm.currentSession.initialBoard.grid[row][col] == 0 {
                    if empty == nil { empty = (row, col) }
                } else if given == nil {
                    given = (row, col)
                }
            }
        }
        return (vm, empty!, given!)
    }

    override func tearDown() {
        GameHistoryStore.reset()
        super.tearDown()
    }

    func testGivenCluesCanNeverBeErased() async {
        let (vm, _, given) = await makeGame()
        let original = vm.currentSession.currentBoard.grid[given.row][given.col]

        XCTAssertFalse(vm.canErase(row: given.row, col: given.col))

        vm.boardViewModel.selectedCell = given
        vm.handleDelete()
        XCTAssertEqual(vm.currentSession.currentBoard.grid[given.row][given.col], original)
    }

    func testAWrongValueCanBeErased() async {
        let (vm, empty, _) = await makeGame()
        vm.boardViewModel.selectedCell = empty

        let answer = vm.currentSession.solution[empty.row][empty.col]
        vm.handleKeyPress(answer == 9 ? 1 : answer + 1)
        XCTAssertTrue(vm.canErase(row: empty.row, col: empty.col))

        vm.handleDelete()
        XCTAssertEqual(vm.currentSession.currentBoard.grid[empty.row][empty.col], 0)
    }

    func testACorrectValueIsLockedIn() async {
        let (vm, empty, _) = await makeGame()
        vm.boardViewModel.selectedCell = empty

        let answer = vm.currentSession.solution[empty.row][empty.col]
        vm.handleKeyPress(answer)
        XCTAssertFalse(vm.canErase(row: empty.row, col: empty.col))

        vm.handleDelete()
        XCTAssertEqual(vm.currentSession.currentBoard.grid[empty.row][empty.col], answer)
    }

    func testNotesAreErasable() async {
        let (vm, empty, _) = await makeGame()
        vm.boardViewModel.selectedCell = empty
        vm.isNoteTakingMode = true

        vm.handleKeyPress(3)
        vm.handleKeyPress(5)
        XCTAssertEqual(vm.currentSession.currentBoard.notes[empty.row][empty.col], [3, 5])
        XCTAssertTrue(vm.canErase(row: empty.row, col: empty.col))

        vm.handleDelete()
        XCTAssertTrue(vm.currentSession.currentBoard.notes[empty.row][empty.col].isEmpty)
    }

    func testAnUntouchedEmptyCellHasNothingToErase() async {
        let (vm, empty, _) = await makeGame()
        XCTAssertFalse(vm.canErase(row: empty.row, col: empty.col))
    }

    func testErasingIsUndoable() async {
        let (vm, empty, _) = await makeGame()
        vm.boardViewModel.selectedCell = empty
        vm.isNoteTakingMode = true
        vm.handleKeyPress(4)

        vm.handleDelete()
        XCTAssertTrue(vm.currentSession.currentBoard.notes[empty.row][empty.col].isEmpty)

        vm.undo()
        XCTAssertEqual(vm.currentSession.currentBoard.notes[empty.row][empty.col], [4])
    }

    func testErasingAWrongValueKeepsTheMistakeOnRecord() async {
        let (vm, empty, _) = await makeGame()
        vm.boardViewModel.selectedCell = empty

        let answer = vm.currentSession.solution[empty.row][empty.col]
        vm.handleKeyPress(answer == 9 ? 1 : answer + 1)
        XCTAssertEqual(vm.errorCount, 1)

        vm.handleDelete()
        XCTAssertEqual(vm.errorCount, 1, "erasing shouldn't rewrite history")
        XCTAssertEqual(vm.currentMetrics.errors, 1)
    }
}
