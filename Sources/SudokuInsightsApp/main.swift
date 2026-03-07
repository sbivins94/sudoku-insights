import SwiftUI
import SudokuInsights
import AppKit
import Combine

@main
struct SudokuInsightsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 800, height: 900)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Saved Game State
struct SavedGameState: Codable {
    let difficulty: Difficulty
    let board: [[Int]]
    let initialBoard: [[Int]]
    let solution: [[Int]]
    let notes: [[Set<Int>]]
    let elapsedTime: TimeInterval
    let errorCount: Int
    let timestamp: Date
}

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        if viewModel.showLandingPage {
            LandingPageView(viewModel: viewModel)
        } else {
            GameBoardContentView(viewModel: viewModel)
        }
    }
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var showLandingPage: Bool = true
    @Published var currentDifficulty: Difficulty = .medium
    @Published var currentSession: GameSession
    @Published var boardViewModel: GameBoardViewModel
    @Published var isNoteTakingMode: Bool = false
    @Published var invalidCells: Set<String> = []
    @Published var correctCells: Set<String> = []
    @Published var availableCandidates: Set<Int> = Set(1...9)
    @Published var elapsedTime: TimeInterval = 0
    @Published var errorCount: Int = 0
    @Published var isGameComplete: Bool = false
    
    private var timerCancellable: AnyCancellable?
    private var autoSaveTimer: Timer?
    private let savedGameKey = "savedGameState"
    
    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init() {
        // Initialize with dummy session - will be replaced when game starts
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: SudokuBoard.createSampleBoard(),
            solution: SudokuBoard.getSampleBoardSolution()
        )
        self.currentSession = session
        self.boardViewModel = GameBoardViewModel(session: session)
    }
    
    // MARK: - Persistence Methods
    func saveGameState() {
        guard !isGameComplete else { return }
        
        let state = SavedGameState(
            difficulty: currentDifficulty,
            board: currentSession.currentBoard.grid,
            initialBoard: currentSession.initialBoard.grid,
            solution: currentSession.solution,
            notes: currentSession.currentBoard.notes,
            elapsedTime: elapsedTime,
            errorCount: errorCount,
            timestamp: Date()
        )
        
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: savedGameKey)
        }
    }
    
    func loadGameState() -> SavedGameState? {
        guard let data = UserDefaults.standard.data(forKey: savedGameKey),
              let state = try? JSONDecoder().decode(SavedGameState.self, from: data) else {
            return nil
        }
        return state
    }
    
    func clearSavedGame() {
        UserDefaults.standard.removeObject(forKey: savedGameKey)
    }
    
    func continueLastGame() {
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
        
        startTimer()
        startAutoSave()
        showLandingPage = false
    }
    
    func startNewGame(difficulty: Difficulty) {
        clearSavedGame()
        
        currentDifficulty = difficulty
        let board = SudokuBoard.createSampleBoard()
        let solution = SudokuBoard.getSampleBoardSolution()
        
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
        
        startTimer()
        startAutoSave()
        showLandingPage = false
    }
    
    func returnToMenu() {
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
    
    // MARK: - Game Logic Methods
    func handleKeyPress(_ value: Int) {
        guard let cell = boardViewModel.selectedCell else { return }
        guard !isGameComplete else { return }
        
        if isNoteTakingMode {
            currentSession.currentBoard.toggleNote(row: cell.row, col: cell.col, value: value)
        } else {
            if currentSession.solution[cell.row][cell.col] != value {
                errorCount += 1
            }
            boardViewModel.didEnterValue(value, at: cell.row, col: cell.col)
            currentSession.currentBoard.grid[cell.row][cell.col] = value
            currentSession.currentBoard.clearNotes(row: cell.row, col: cell.col)
            validateBoard()
            if correctCells.contains("\(cell.row),\(cell.col)") {
                clearRelatedNotes(row: cell.row, col: cell.col, value: value)
            }
            checkGameCompletion()
        }
    }
    
    func handleDelete() {
        guard let cell = boardViewModel.selectedCell else { return }
        boardViewModel.didEraseCell(row: cell.row, col: cell.col)
        currentSession.currentBoard.grid[cell.row][cell.col] = 0
        validateBoard()
    }
    
    func validateBoard() {
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
    
    func checkGameCompletion() {
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
    }
    
    private func saveCompletionTime() {
        let key = "completionTimes_\(currentDifficulty.rawValue)"
        var times = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        times.append(elapsedTime)
        UserDefaults.standard.set(times, forKey: key)
    }
    
    func bestTimeForDifficulty(_ difficulty: Difficulty) -> String {
        let key = "completionTimes_\(difficulty.rawValue)"
        let times = UserDefaults.standard.array(forKey: key) as? [TimeInterval] ?? []
        
        guard let best = times.min() else { return "--:--" }
        
        let minutes = Int(best) / 60
        let seconds = Int(best) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func averageTimeForDifficulty(_ difficulty: Difficulty) -> String {
        let key = "completionTimes_\(difficulty.rawValue)"
        let times = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        
        guard !times.isEmpty else { return "--:--" }
        
        let avg = times.reduce(0, +) / Double(times.count)
        let minutes = Int(avg) / 60
        let seconds = Int(avg) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func averageTimeForDifficultyValue(_ difficulty: Difficulty) -> Double? {
        let key = "completionTimes_\(difficulty.rawValue)"
        let times = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        guard !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }
    
    func formattedTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Landing Page View
struct LandingPageView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Text("SUDOKU INSIGHTS")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.primary)
            
            // Continue Last Game Button
            if let savedGame = viewModel.loadGameState() {
                ContinueGameButton(savedGame: savedGame) {
                    viewModel.continueLastGame()
                }
            }
            
            // Difficulty Grid
            DifficultyGridView(viewModel: viewModel)
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.96, green: 0.95, blue: 0.90))
    }
}

struct ContinueGameButton: View {
    let savedGame: SavedGameState
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Continue Last Game")
                        .font(.headline)
                }
                
                HStack(spacing: 12) {
                    Text(savedGame.difficulty.rawValue.capitalized)
                        .font(.subheadline)
                    Text("·")
                    Text(formatTime(savedGame.elapsedTime))
                        .font(.subheadline)
                    if savedGame.errorCount > 0 {
                        Text("·")
                        Text("\(savedGame.errorCount) errors")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.green.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct DifficultyGridView: View {
    @ObservedObject var viewModel: AppViewModel
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            DifficultyCard(
                difficulty: .easy,
                color: .green,
                preFilledCells: 51,
                viewModel: viewModel
            )
            DifficultyCard(
                difficulty: .medium,
                color: .blue,
                preFilledCells: 41,
                viewModel: viewModel
            )
            DifficultyCard(
                difficulty: .hard,
                color: .orange,
                preFilledCells: 31,
                viewModel: viewModel
            )
            DifficultyCard(
                difficulty: .expert,
                color: .red,
                preFilledCells: 21,
                viewModel: viewModel
            )
        }
    }
}

struct DifficultyCard: View {
    let difficulty: Difficulty
    let color: Color
    let preFilledCells: Int
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        Button(action: {
            viewModel.startNewGame(difficulty: difficulty)
        }) {
            VStack(spacing: 12) {
                Text(difficulty.rawValue.uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(preFilledCells) pre-filled")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                    .padding(.horizontal, 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Best:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.bestTimeForDifficulty(difficulty))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Avg:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.averageTimeForDifficulty(difficulty))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal, 10)
            }
            .padding(20)
            .frame(width: 160, height: 180)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Game Board View
struct GameBoardContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedCell: (row: Int, col: Int)?
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // Header with title and timer
                HStack {
                    Button(action: {
                        viewModel.returnToMenu()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Menu")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: {
                        for row in 0..<9 {
                            for col in 0..<9 {
                                viewModel.currentSession.currentBoard.grid[row][col] = viewModel.currentSession.solution[row][col]
                            }
                        }
                        viewModel.validateBoard()
                        viewModel.checkGameCompletion()
                    }) {
                        Text("⚡ Auto-Finish")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text(viewModel.formattedTime)
                            .font(.title2)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            
                // 9x9 Sudoku Grid
                VStack(spacing: 0) {
                    ForEach(0..<9) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9) { col in
                                CellView(
                                    value: viewModel.currentSession.currentBoard.grid[row][col],
                                    notes: viewModel.currentSession.currentBoard.notes[row][col],
                                    isSelected: selectedCell?.row == row && selectedCell?.col == col,
                                    isInitial: viewModel.currentSession.initialBoard.grid[row][col] != 0,
                                    isAxisHighlighted: isAxisHighlighted(row: row, col: col),
                                    isNumberHighlighted: isNumberHighlighted(row: row, col: col),
                                    isBoxHighlighted: isBoxHighlighted(row: row, col: col),
                                    isInvalid: viewModel.invalidCells.contains("\(row),\(col)"),
                                    isCorrect: viewModel.correctCells.contains("\(row),\(col)"),
                                    row: row,
                                    col: col
                                )
                                .onTapGesture {
                                    selectedCell = (row, col)
                                    viewModel.boardViewModel.didTapCell(row: row, col: col)
                                    viewModel.boardViewModel.selectedCell = (row, col)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .onAppear {
                    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                        self.handleKeyDown(event)
                        return event
                    }
                }
                
                // Note-taking toggle button
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.isNoteTakingMode.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isNoteTakingMode ? "pencil.circle.fill" : "pencil.circle")
                            Text(viewModel.isNoteTakingMode ? "Notes ON" : "Notes OFF")
                                .font(.callout)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewModel.isNoteTakingMode ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(viewModel.isNoteTakingMode ? .white : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Candidates tracker
                HStack(spacing: 8) {
                    ForEach(1...9, id: \.self) { num in
                        if viewModel.availableCandidates.contains(num) {
                            Text("\(num)")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(6)
                        } else {
                            Text("\(num)")
                                .font(.callout)
                                .foregroundColor(.gray.opacity(0.3))
                                .strikethrough()
                                .frame(width: 32, height: 32)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            
            if viewModel.isGameComplete {
                GameCompleteOverlay(viewModel: viewModel)
            }
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        guard selectedCell != nil else { return }
        
        if let chars = event.charactersIgnoringModifiers,
           let char = chars.first,
           let num = Int(String(char)),
           num >= 1 && num <= 9 {
            viewModel.handleKeyPress(num)
            return
        }
        
        if event.keyCode == 51 || event.keyCode == 117 {
            viewModel.handleDelete()
            return
        }
    }
    
    private func isAxisHighlighted(row: Int, col: Int) -> Bool {
        guard let selected = selectedCell else { return false }
        return row == selected.row || col == selected.col
    }
    
    private func isNumberHighlighted(row: Int, col: Int) -> Bool {
        guard let selected = selectedCell else { return false }
        let selectedValue = viewModel.currentSession.currentBoard.grid[selected.row][selected.col]
        let cellValue = viewModel.currentSession.currentBoard.grid[row][col]
        return selectedValue != 0 && cellValue == selectedValue
    }
    
    private func isBoxHighlighted(row: Int, col: Int) -> Bool {
        guard let selected = selectedCell else { return false }
        let boxRow = selected.row / 3
        let boxCol = selected.col / 3
        return (row / 3 == boxRow) && (col / 3 == boxCol)
    }
}

struct CellView: View {
    let value: Int
    let notes: Set<Int>
    let isSelected: Bool
    let isInitial: Bool
    let isAxisHighlighted: Bool
    let isNumberHighlighted: Bool
    let isBoxHighlighted: Bool
    let isInvalid: Bool
    let isCorrect: Bool
    let row: Int
    let col: Int
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            backgroundColor
            
            if isCorrect && isAnimating {
                Circle()
                    .fill(Color.blue.opacity(0.5))
                    .scaleEffect(2)
                    .opacity(0)
                    .animation(.easeOut(duration: 1.5), value: isAnimating)
            }
            
            if value == 0 && !notes.isEmpty {
                NotesGridView(notes: notes)
            } else if value != 0 {
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(
                        isCorrect ? .bold : (isInitial ? .bold : .regular)
                    )
                    .foregroundColor(
                        isInvalid ? .red : (isCorrect ? .blue : (isInitial ? .black : .blue))
                    )
            }
        }
        .frame(width: 50, height: 50)
        .border(Color.gray.opacity(0.4), width: 0.5)
        .overlay(
            Group {
                if col == 2 || col == 5 {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 4)
                        .offset(x: 25)
                }
                
                if row == 2 || row == 5 {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 4)
                        .offset(y: 25)
                }
            }
        )
        .onChange(of: isCorrect) { oldValue, newValue in
            if newValue && !oldValue {
                isAnimating = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isAnimating = false
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.4)
        } else if isNumberHighlighted {
            return Color.yellow.opacity(0.3)
        } else if isAxisHighlighted {
            return Color(red: 0.96, green: 0.95, blue: 0.90)
        } else if isBoxHighlighted {
            return Color(red: 0.96, green: 0.95, blue: 0.90)
        } else {
            return Color.white
        }
    }
}

struct NotesGridView: View {
    let notes: Set<Int>
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3) { col in
                        let num = row * 3 + col + 1
                        Text(notes.contains(num) ? "\(num)" : "")
                            .font(.system(size: 10))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(2)
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let x: CGFloat
    let speed: Double
    let delay: Double
    let rotation: Double
    let size: CGFloat
}

struct ConfettiView: View {
    @State private var animate = false
    
    let pieces: [ConfettiPiece] = (0..<60).map { _ in
        ConfettiPiece(
            color: [Color.red, .blue, .green, .yellow, .orange, .purple, .pink, .mint, .cyan].randomElement()!,
            x: CGFloat.random(in: -200...200),
            speed: Double.random(in: 2...4),
            delay: Double.random(in: 0...1.5),
            rotation: Double.random(in: 0...360),
            size: CGFloat.random(in: 6...12)
        )
    }
    
    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size * 1.4)
                    .rotationEffect(.degrees(animate ? piece.rotation + 360 : piece.rotation))
                    .offset(
                        x: piece.x,
                        y: animate ? 500 : -100
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeIn(duration: piece.speed)
                        .delay(piece.delay),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct GameCompleteOverlay: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showStats = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {}
            
            ConfettiView()
            
            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 60))
                
                Text("Puzzle Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Time")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: 60, alignment: .leading)
                        Spacer()
                        Text(viewModel.formattedTime)
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .frame(width: 20)
                        Text("Errors")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: 60, alignment: .leading)
                        Spacer()
                        Text("\(viewModel.errorCount)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        Text("Avg Time")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: 60, alignment: .leading)
                        Spacer()
                        if let avg = viewModel.averageTimeForDifficultyValue(viewModel.currentDifficulty) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(viewModel.formattedTimeInterval(avg))
                                    .font(.headline)
                                    .monospacedDigit()
                                    .foregroundColor(.primary)
                                let diff = viewModel.elapsedTime - avg
                                if diff < 0 {
                                    Text("\(viewModel.formattedTimeInterval(abs(diff))) faster")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else if diff > 0 {
                                    Text("\(viewModel.formattedTimeInterval(diff)) slower")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else {
                                    Text("Right on average!")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        } else {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("First game!")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.returnToMenu()
                    }) {
                        Text("Back to Menu")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.gray)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        viewModel.startNewGame(difficulty: viewModel.currentDifficulty)
                    }) {
                        Text("New Game")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
            .frame(width: 380)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(radius: 20)
            )
            .scaleEffect(showStats ? 1.0 : 0.8)
            .opacity(showStats ? 1.0 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showStats)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showStats = true
                }
            }
        }
    }
}

// MARK: - Dashboard View (kept for compatibility)
struct StatsDashboardContentView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        Text("Dashboard")
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ReportContentView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        Text("Reports")
    }
}

struct ReportSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}
