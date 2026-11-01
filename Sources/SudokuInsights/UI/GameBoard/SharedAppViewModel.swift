import SwiftUI
import Combine

@MainActor
public class SharedAppViewModel: ObservableObject {
    @Published public var showLandingPage: Bool = true
    @Published public var currentDifficulty: Difficulty = .medium
    @Published public var currentSession: GameSession
    @Published public var boardViewModel: GameBoardViewModel
    @Published public var isNoteTakingMode: Bool = false
    @Published public var invalidCells: Set<String> = []
    @Published public var correctCells: Set<String> = []
    @Published public var availableCandidates: Set<Int> = Set(1...9)
    @Published public var elapsedTime: TimeInterval = 0
    @Published public var errorCount: Int = 0
    @Published public var isGameComplete: Bool = false
    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var isGeneratingPuzzle: Bool = false
    /// Counters for the game in progress; folded into `history` when it's solved.
    @Published public private(set) var currentMetrics = GameMetrics()
    @Published public private(set) var history: [GameRecord] = GameHistoryStore.load()
    @Published public var theme: SudokuTheme = .theme(id: UserDefaults.standard.string(forKey: "selectedTheme") ?? "classic") {
        didSet { UserDefaults.standard.set(theme.id, forKey: "selectedTheme") }
    }

    /// Timestamp of the last correct placement, for the gap-between-cells metric.
    private var lastPlacementAt: Date?

    private var timerCancellable: AnyCancellable?
    private var autoSaveTimer: Timer?
    private let savedGameKey = "savedGameState"

    private struct BoardSnapshot {
        let grid: [[Int]]
        let notes: [[Set<Int>]]
        let errorCount: Int
    }

    private var undoStack: [BoardSnapshot] = []
    private let maxUndoDepth = 200

    public var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public init() {
        let initialPuzzle = SudokuEngine.generatePuzzle(difficulty: .medium)
        let initialBoard = SudokuBoard(grid: initialPuzzle.initialGrid)
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: initialBoard,
            solution: initialPuzzle.solution
        )
        self.currentSession = session
        self.boardViewModel = GameBoardViewModel(session: session)
    }

    // MARK: - Persistence Methods
    public func saveGameState() {
        guard !isGameComplete else { return }

        let state = SavedGameState(
            difficulty: currentDifficulty,
            board: currentSession.currentBoard.grid,
            initialBoard: currentSession.initialBoard.grid,
            solution: currentSession.solution,
            notes: currentSession.currentBoard.notes,
            elapsedTime: elapsedTime,
            errorCount: errorCount,
            timestamp: Date(),
            metrics: currentMetrics
        )

        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: savedGameKey)
        }
    }

    public func loadGameState() -> SavedGameState? {
        guard let data = UserDefaults.standard.data(forKey: savedGameKey),
              let state = try? JSONDecoder().decode(SavedGameState.self, from: data) else {
            return nil
        }
        return state
    }

    public func clearSavedGame() {
        UserDefaults.standard.removeObject(forKey: savedGameKey)
    }

    public func continueLastGame() {
        guard let state = loadGameState() else { return }

        currentDifficulty = state.difficulty

        var board = SudokuBoard(grid: state.board)
        board.notes = state.notes

        let initialBoard = SudokuBoard(grid: state.initialBoard)

        var session = GameSession(
            id: UUID().uuidString,
            difficulty: state.difficulty,
            startTime: Date(),
            initialBoard: initialBoard,
            solution: state.solution
        )
        session.currentBoard = board

        self.currentSession = session
        self.boardViewModel = GameBoardViewModel(session: session)
        self.elapsedTime = state.elapsedTime
        self.errorCount = state.errorCount
        self.isGameComplete = false
        self.invalidCells.removeAll()
        self.correctCells.removeAll()
        clearUndoHistory()
        lastPlacementAt = Date()
        currentMetrics = state.metrics ?? GameMetrics()

        validateBoard()
        startTimer()
        startAutoSave()
        showLandingPage = false
    }

    public func startNewGame(difficulty: Difficulty) {
        guard !isGeneratingPuzzle else { return }

        clearSavedGame()
        currentDifficulty = difficulty
        isGeneratingPuzzle = true
        // Committing to a new game must retire the old one's undo stack immediately —
        // the puzzle arrives later, but undoing into the previous game is never valid.
        clearUndoHistory()

        Task {
            // Generating an expert puzzle means proving uniqueness after every removed
            // clue, which is far too slow to run on the main actor.
            let puzzle = await Task.detached(priority: .userInitiated) {
                SudokuEngine.generatePuzzle(difficulty: difficulty)
            }.value

            isGeneratingPuzzle = false
            begin(puzzle: puzzle, difficulty: difficulty)
        }
    }

    private func begin(puzzle: SudokuPuzzle, difficulty: Difficulty) {
        let board = SudokuBoard(grid: puzzle.initialGrid)
        let solution = puzzle.solution

        let session = GameSession(
            id: UUID().uuidString,
            difficulty: difficulty,
            startTime: Date(),
            initialBoard: board,
            solution: solution
        )

        self.currentSession = session
        self.boardViewModel = GameBoardViewModel(session: session)
        self.elapsedTime = 0
        self.errorCount = 0
        self.isGameComplete = false
        self.invalidCells.removeAll()
        self.correctCells.removeAll()
        self.availableCandidates = Set(1...9)
        clearUndoHistory()
        lastPlacementAt = Date()
        currentMetrics = GameMetrics()

        startTimer()
        startAutoSave()
        showLandingPage = false
    }

    public func returnToMenu() {
        stopTimer()
        stopAutoSave()

        if !isGameComplete {
            saveGameState()
        }

        showLandingPage = true
    }

    private func startTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, !self.isGameComplete else { return }
                self.elapsedTime += 1
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func startAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveGameState()
            }
        }
    }

    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    // MARK: - Undo
    // Snapshots the whole board rather than inverting individual moves: a single entry
    // can cascade (clearing the cell's notes plus every matching note in its row, column
    // and box), and replaying that in reverse is far easier to get wrong.
    private func pushUndoSnapshot() {
        undoStack.append(
            BoardSnapshot(
                grid: currentSession.currentBoard.grid,
                notes: currentSession.currentBoard.notes,
                errorCount: errorCount
            )
        )
        if undoStack.count > maxUndoDepth {
            undoStack.removeFirst(undoStack.count - maxUndoDepth)
        }
        canUndo = true
    }

    public func undo() {
        guard !isGameComplete, let snapshot = undoStack.popLast() else { return }

        currentSession.currentBoard.grid = snapshot.grid
        currentSession.currentBoard.notes = snapshot.notes
        errorCount = snapshot.errorCount
        canUndo = !undoStack.isEmpty

        validateBoard()
    }

    private func clearUndoHistory() {
        undoStack.removeAll()
        canUndo = false
    }

    // MARK: - Game Logic Methods
    public func handleKeyPress(_ value: Int) {
        guard let cell = boardViewModel.selectedCell else { return }
        guard !isGameComplete else { return }

        pushUndoSnapshot()

        if isNoteTakingMode {
            let wasSet = currentSession.currentBoard.notes[cell.row][cell.col].contains(value)
            currentSession.currentBoard.toggleNote(row: cell.row, col: cell.col, value: value)

            if !wasSet {
                recordStats {
                    $0.notesAdded += 1
                    if currentSession.solution[cell.row][cell.col] != value {
                        $0.incorrectNotes += 1
                    }
                }
            }
        } else {
            let isCorrect = currentSession.solution[cell.row][cell.col] == value
            if !isCorrect {
                errorCount += 1
                Haptics.mistake()
            }
            boardViewModel.didEnterValue(value, at: cell.row, col: cell.col)
            currentSession.currentBoard.grid[cell.row][cell.col] = value
            currentSession.currentBoard.clearNotes(row: cell.row, col: cell.col)
            validateBoard()
            if correctCells.contains("\(cell.row),\(cell.col)") {
                clearRelatedNotes(row: cell.row, col: cell.col, value: value)
            }
            recordPlacement(correct: isCorrect)
            checkGameCompletion()
        }
    }

    // MARK: - Insights telemetry

    /// Reloads game history from disk, so the insights panel reflects anything written
    /// since this view model was created.
    public func refreshHistory() {
        history = GameHistoryStore.load()
    }

    private func recordStats(_ mutate: (inout GameMetrics) -> Void) {
        mutate(&currentMetrics)
    }

    private func recordPlacement(correct: Bool) {
        let now = Date()
        recordStats {
            if correct {
                $0.correctPlacements += 1
                if let last = lastPlacementAt {
                    let gap = now.timeIntervalSince(last)
                    $0.timeBetweenPlacements += gap
                    $0.placementGaps += 1
                }
            } else {
                $0.errors += 1
            }
        }
        if correct { lastPlacementAt = now }
    }

    /// A tap is unproductive when the cell can't accept anything — it's a given, or it's
    /// already correct. Those are the taps that show up as hesitation in the insights.
    public func recordCellTap(row: Int, col: Int) {
        let isGiven = currentSession.initialBoard.grid[row][col] != 0
        let isSolved = correctCells.contains("\(row),\(col)")
        recordStats {
            $0.cellTaps += 1
            if isGiven || isSolved { $0.unproductiveTaps += 1 }
        }
    }

    /// Erase only ever undoes the player's own input: a given clue is permanent, and a
    /// digit that matches the solution stays put so the board can't be un-solved.
    public func canErase(row: Int, col: Int) -> Bool {
        guard !isGameComplete else { return false }
        guard currentSession.initialBoard.grid[row][col] == 0 else { return false }

        let value = currentSession.currentBoard.grid[row][col]
        if value != 0 {
            return currentSession.solution[row][col] != value
        }
        return !currentSession.currentBoard.notes[row][col].isEmpty
    }

    public func handleDelete() {
        guard let cell = boardViewModel.selectedCell else { return }
        guard canErase(row: cell.row, col: cell.col) else { return }

        pushUndoSnapshot()
        boardViewModel.didEraseCell(row: cell.row, col: cell.col)

        if currentSession.currentBoard.grid[cell.row][cell.col] != 0 {
            currentSession.currentBoard.grid[cell.row][cell.col] = 0
        } else {
            currentSession.currentBoard.clearNotes(row: cell.row, col: cell.col)
        }
        validateBoard()
    }

    public func validateBoard() {
        invalidCells.removeAll()
        correctCells.removeAll()
        let grid = currentSession.currentBoard.grid
        let initialGrid = currentSession.initialBoard.grid
        let solution = currentSession.solution

        for row in 0..<9 {
            for col in 0..<9 {
                if initialGrid[row][col] != 0 {
                    continue
                }

                let value = grid[row][col]
                if value != 0 {
                    if solution[row][col] == value {
                        correctCells.insert("\(row),\(col)")
                    } else {
                        if !SudokuEngine.isValidMove(grid: grid, row: row, col: col, value: value) {
                            invalidCells.insert("\(row),\(col)")
                        }
                    }
                }
            }
        }
        updateAvailableCandidates()
    }

    private func clearRelatedNotes(row: Int, col: Int, value: Int) {
        for c in 0..<9 {
            currentSession.currentBoard.notes[row][c].remove(value)
        }
        for r in 0..<9 {
            currentSession.currentBoard.notes[r][col].remove(value)
        }
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) {
                currentSession.currentBoard.notes[r][c].remove(value)
            }
        }
    }

    private func updateAvailableCandidates() {
        availableCandidates = Set(1...9)
        let grid = currentSession.currentBoard.grid
        let solution = currentSession.solution

        var numberCounts: [Int: Int] = [:]
        for row in 0..<9 {
            for col in 0..<9 {
                let value = grid[row][col]
                if value != 0 && value == solution[row][col] {
                    numberCounts[value, default: 0] += 1
                }
            }
        }

        for number in 1...9 {
            if let count = numberCounts[number], count >= 9 {
                availableCandidates.remove(number)
            }
        }
    }

    public func checkGameCompletion() {
        let grid = currentSession.currentBoard.grid
        let solution = currentSession.solution

        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] != solution[row][col] {
                    return
                }
            }
        }

        isGameComplete = true
        stopTimer()
        stopAutoSave()
        clearSavedGame()
        saveCompletionTime()

        let record = GameRecord(
            difficulty: currentDifficulty,
            completedAt: Date(),
            duration: elapsedTime,
            metrics: currentMetrics
        )
        history = GameHistoryStore.append(record)
    }

    private func saveCompletionTime() {
        let key = "completionTimes_\(currentDifficulty.rawValue)"
        var times = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        times.append(elapsedTime)
        UserDefaults.standard.set(times, forKey: key)
    }

    public func bestTimeForDifficulty(_ difficulty: Difficulty) -> String {
        let key = "completionTimes_\(difficulty.rawValue)"
        let times = UserDefaults.standard.array(forKey: key) as? [TimeInterval] ?? []

        guard let best = times.min() else { return "--:--" }

        let minutes = Int(best) / 60
        let seconds = Int(best) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public func averageTimeForDifficulty(_ difficulty: Difficulty) -> String {
        let key = "completionTimes_\(difficulty.rawValue)"
        let times = UserDefaults.standard.array(forKey: key) as? [Double] ?? []

        guard !times.isEmpty else { return "--:--" }

        let avg = times.reduce(0, +) / Double(times.count)
        let minutes = Int(avg) / 60
        let seconds = Int(avg) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public func averageTimeForDifficultyValue(_ difficulty: Difficulty) -> Double? {
        let key = "completionTimes_\(difficulty.rawValue)"
        let times = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        guard !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }

    public func formattedTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
