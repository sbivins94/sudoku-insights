import SwiftUI
import SudokuInsights
import AppKit

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
    
    init() {
        // Create a sample game session
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: .medium,
            startTime: Date(),
            initialBoard: SudokuBoard.createSampleBoard()
        )
        self.currentSession = session
        self.boardViewModel = GameBoardViewModel(session: session)
    }
    
    func startNewGame(difficulty: Difficulty) {
        let session = GameSession(
            id: UUID().uuidString,
            difficulty: difficulty,
            startTime: Date(),
            initialBoard: SudokuBoard.createSampleBoard()
        )
        self.currentSession = session
        self.boardViewModel = GameBoardViewModel(session: session)
    }
    
    func handleKeyPress(_ value: Int) {
        guard let cell = boardViewModel.selectedCell else { return }
        
        if isNoteTakingMode {
            currentSession.currentBoard.toggleNote(row: cell.row, col: cell.col, value: value)
        } else {
            boardViewModel.didEnterValue(value, at: cell.row, col: cell.col)
            currentSession.currentBoard.grid[cell.row][cell.col] = value
            // Clear notes when value is entered
            currentSession.currentBoard.clearNotes(row: cell.row, col: cell.col)
        }
    }
    
    func handleDelete() {
        guard let cell = boardViewModel.selectedCell else { return }
        boardViewModel.didEraseCell(row: cell.row, col: cell.col)
        currentSession.currentBoard.grid[cell.row][cell.col] = 0
    }
}

// MARK: - Game Board View
struct GameBoardContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedCell: (row: Int, col: Int)?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sudoku Game Board")
                .font(.largeTitle)
                .padding()
            
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
}

struct CellView: View {
    let value: Int
    let notes: Set<Int>
    let isSelected: Bool
    let isInitial: Bool
    let isAxisHighlighted: Bool
    let isNumberHighlighted: Bool
    let row: Int
    let col: Int
    
    var body: some View {
        ZStack {
            // Background color based on highlighting
            backgroundColor
            
            // Content: either value or notes
            if value == 0 && !notes.isEmpty {
                NotesGridView(notes: notes)
            } else if value != 0 {
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(isInitial ? .bold : .regular)
                    .foregroundColor(isInitial ? .black : .blue)
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
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.4)
        } else if isNumberHighlighted {
            return Color.yellow.opacity(0.3)
        } else if isAxisHighlighted {
            return Color.blue.opacity(0.15)
        } else if isInitial {
            return Color.gray.opacity(0.2)
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
