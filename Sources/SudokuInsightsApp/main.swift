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

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $viewModel.selectedView) {
                Label("Game Board", systemImage: "square.grid.3x3")
                    .tag(ViewSelection.gameBoard)
                Label("Dashboard", systemImage: "chart.bar")
                    .tag(ViewSelection.dashboard)
                Label("Reports", systemImage: "doc.text")
                    .tag(ViewSelection.reports)
            }
            .navigationTitle("Sudoku Insights")
        } detail: {
            switch viewModel.selectedView {
            case .gameBoard:
                GameBoardContentView(viewModel: viewModel)
            case .dashboard:
                StatsDashboardContentView(viewModel: viewModel)
            case .reports:
                ReportContentView(viewModel: viewModel)
            }
        }
    }
}

enum ViewSelection {
    case gameBoard
    case dashboard
    case reports
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var selectedView: ViewSelection = .gameBoard
    @Published var currentSession: GameSession
    @Published var boardViewModel: GameBoardViewModel
    @Published var isNoteTakingMode: Bool = false
    @Published var invalidCells: Set<String> = [] // "row,col" format
    @Published var correctCells: Set<String> = [] // "row,col" format for correct entries
    @Published var availableCandidates: Set<Int> = Set(1...9) // Numbers not yet fully placed
    @Published var elapsedTime: TimeInterval = 0
    @Published var errorCount: Int = 0
    @Published var isGameComplete: Bool = false
    
    private var timerCancellable: AnyCancellable?
    
    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init() {
        // Create a sample game session
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: SudokuBoard.createSampleBoard(),
            solution: SudokuBoard.getSampleBoardSolution()
        )
        self.currentSession = session
        self.boardViewModel = GameBoardViewModel(session: session)
        startTimer()
    }
    
    func startNewGame(difficulty: Difficulty) {
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: difficulty,
            startTime: Date(),
            initialBoard: SudokuBoard.createSampleBoard(),
            solution: SudokuBoard.getSampleBoardSolution()
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
    
    func handleKeyPress(_ value: Int) {
        guard let cell = boardViewModel.selectedCell else { return }
        guard !isGameComplete else { return }
        
        if isNoteTakingMode {
            currentSession.currentBoard.toggleNote(row: cell.row, col: cell.col, value: value)
        } else {
            // Track errors before placing the value
            if currentSession.solution[cell.row][cell.col] != value {
                errorCount += 1
            }
            boardViewModel.didEnterValue(value, at: cell.row, col: cell.col)
            currentSession.currentBoard.grid[cell.row][cell.col] = value
            // Clear notes when value is entered
            currentSession.currentBoard.clearNotes(row: cell.row, col: cell.col)
            // Validate the entire board
            validateBoard()
            // If correct, clear related notes
            if correctCells.contains("\(cell.row),\(cell.col)") {
                clearRelatedNotes(row: cell.row, col: cell.col, value: value)
            }
            // Check for game completion
            checkGameCompletion()
        }
    }
    
    func handleDelete() {
        guard let cell = boardViewModel.selectedCell else { return }
        boardViewModel.didEraseCell(row: cell.row, col: cell.col)
        currentSession.currentBoard.grid[cell.row][cell.col] = 0
        // Validate the board after deletion
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
                // Skip given/initial numbers
                if initialGrid[row][col] != 0 {
                    continue
                }
                
                let value = grid[row][col]
                if value != 0 {
                    // Check if this value matches the solution
                    if solution[row][col] == value {
                        correctCells.insert("\(row),\(col)")
                    } else {
                        // Check if it's just invalid (violates constraints)
                        if !SudokuEngine.isValidMove(grid: grid, row: row, col: col, value: value) {
                            invalidCells.insert("\(row),\(col)")
                        }
                    }
                }
            }
        }
        // Update candidates after validation
        updateAvailableCandidates()
    }
    
    private func clearRelatedNotes(row: Int, col: Int, value: Int) {
        // Clear notes containing this value from the same row
        for c in 0..<9 {
            currentSession.currentBoard.notes[row][c].remove(value)
        }
        
        // Clear notes containing this value from the same column
        for r in 0..<9 {
            currentSession.currentBoard.notes[r][col].remove(value)
        }
        
        // Clear notes containing this value from the same 3x3 box
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
        
        // Count all cells where grid matches solution (both givens and user entries)
        var numberCounts: [Int: Int] = [:]
        for row in 0..<9 {
            for col in 0..<9 {
                let value = grid[row][col]
                if value != 0 && value == solution[row][col] {
                    numberCounts[value, default: 0] += 1
                }
            }
        }
        
        // Remove numbers that have been placed 9 times (all instances correct)
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
        
        // Game is complete!
        isGameComplete = true
        stopTimer()
        saveCompletionTime()
    }
    
    private func saveCompletionTime() {
        let key = "completionTimes_\(currentSession.difficulty.rawValue)"
        var times = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        times.append(elapsedTime)
        UserDefaults.standard.set(times, forKey: key)
    }
    
    func averageTimeForDifficulty() -> Double? {
        let key = "completionTimes_\(currentSession.difficulty.rawValue)"
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

// MARK: - Game Board View
struct GameBoardContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedCell: (row: Int, col: Int)?
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // Header with title and timer
                HStack {
                    Text("Sudoku Game Board")
                        .font(.largeTitle)
                    Spacer()
                    // Debug: Auto-finish button
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
                    // Timer
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
                // Set up keyboard monitoring
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    self.handleKeyDown(event)
                    return event
                }
            }
            
            // Note-taking toggle button (below grid, aligned right)
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
            
            // Session info
            VStack(alignment: .leading, spacing: 8) {
                Text("Session ID: \(viewModel.currentSession.id.prefix(8))...")
                    .font(.caption)
                Text("Difficulty: \(viewModel.currentSession.difficulty.rawValue.capitalized)")
                    .font(.caption)
                Text("Tap Events: \(viewModel.currentSession.tapEvents.count)")
                    .font(.caption)
                if viewModel.isNoteTakingMode {
                    Text("Mode: Note Taking")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("Mode: Number Entry")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding()
            
            Spacer()
        }
        .padding()
        
        // Game Complete Overlay
        if viewModel.isGameComplete {
            GameCompleteOverlay(viewModel: viewModel)
        }
        } // ZStack
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        guard selectedCell != nil else { return }
        
        // Handle number keys 1-9
        if let chars = event.charactersIgnoringModifiers,
           let char = chars.first,
           let num = Int(String(char)),
           num >= 1 && num <= 9 {
            viewModel.handleKeyPress(num)
            return
        }
        
        // Handle delete/backspace
        if event.keyCode == 51 || event.keyCode == 117 { // Delete or Forward Delete
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
            // Background color based on highlighting
            backgroundColor
            
            // Sparkle animation overlay for correct entries
            if isCorrect && isAnimating {
                Circle()
                    .fill(Color.blue.opacity(0.5))
                    .scaleEffect(2)
                    .opacity(0)
                    .animation(.easeOut(duration: 1.5), value: isAnimating)
            }
            
            // Content: either value or notes
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
                // Bold right border for 3x3 grid (cols 2, 5)
                if col == 2 || col == 5 {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 4)
                        .offset(x: 25)
                }
                
                // Bold bottom border for 3x3 grid (rows 2, 5)
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
            // Light beige/olive tone - same as box highlighting
            return Color(red: 0.96, green: 0.95, blue: 0.90)
        } else if isBoxHighlighted {
            // Light beige/olive tone - much lighter and warmer
            return Color(red: 0.96, green: 0.95, blue: 0.90)
        } else {
            return Color.white
        }
    }
}

// MARK: - Notes Grid View
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

// MARK: - Confetti Particle
struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let x: CGFloat
    let speed: Double
    let delay: Double
    let rotation: Double
    let size: CGFloat
}

// MARK: - Confetti View
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

// MARK: - Game Complete Overlay
struct GameCompleteOverlay: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showStats = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {} // Block taps through
            
            // Confetti
            ConfettiView()
            
            // Stats card
            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 60))
                
                Text("Puzzle Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(spacing: 16) {
                    // Time to complete
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
                    
                    // Error count
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
                    
                    // Average time comparison
                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        Text("Avg Time")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: 60, alignment: .leading)
                        Spacer()
                        if let avg = viewModel.averageTimeForDifficulty() {
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
                
                // New Game button
                Button(action: {
                    viewModel.startNewGame(difficulty: viewModel.currentSession.difficulty)
                }) {
                    Text("New Game")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
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

// MARK: - Dashboard View
struct StatsDashboardContentView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Analytics Dashboard")
                    .font(.largeTitle)
                    .padding()
                
                // Generate analytics
                let analytics = AnalyticsEngine(session: viewModel.currentSession)
                let metrics = analytics.generateSessionMetrics()
                
                // Metrics cards
                HStack(spacing: 20) {
                    MetricCard(title: "Total Taps", value: "\(metrics.totalTaps)")
                    MetricCard(title: "Duration", value: String(format: "%.1fs", metrics.elapsedTime))
                    MetricCard(title: "Avg Hesitation", value: String(format: "%.2fs", metrics.averageHesitationTime))
                }
                .padding()
                
                // Heatmap placeholder
                VStack {
                    Text("Tap Heatmap")
                        .font(.headline)
                    
                    VStack(spacing: 2) {
                        ForEach(0..<9) { row in
                            HStack(spacing: 2) {
                                ForEach(0..<9) { col in
                                    let tapCount = viewModel.currentSession.tapEvents.filter {
                                        $0.row == row && $0.col == col
                                    }.count
                                    
                                    Rectangle()
                                        .fill(heatmapColor(for: tapCount))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(tapCount > 0 ? "\(tapCount)" : "")
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
        }
    }
    
    func heatmapColor(for count: Int) -> Color {
        switch count {
        case 0: return Color.gray.opacity(0.2)
        case 1...2: return Color.green.opacity(0.5)
        case 3...5: return Color.yellow.opacity(0.7)
        case 6...10: return Color.orange.opacity(0.8)
        default: return Color.red.opacity(0.9)
        }
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

// MARK: - Report View
struct ReportContentView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Session Report")
                    .font(.largeTitle)
                    .padding()
                
                let analytics = AnalyticsEngine(session: viewModel.currentSession)
                let report = analytics.generateDetailedReport()
                
                // Report sections
                ReportSection(title: "Session Overview", content: report.sessionOverview)
                ReportSection(title: "Performance Metrics", content: report.performanceMetrics)
                ReportSection(title: "Cognitive Patterns", content: report.cognitivePatterns)
                ReportSection(title: "Recommendations", content: report.recommendations)
                
                Spacer()
            }
            .padding()
        }
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
