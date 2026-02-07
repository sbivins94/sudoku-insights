import SwiftUI
import SudokuInsights

@main
struct SudokuInsightsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 800, height: 900)
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
            VStack(spacing: 2) {
                ForEach(0..<9) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<9) { col in
                            CellView(
                                value: viewModel.currentSession.currentBoard.grid[row][col],
                                isSelected: selectedCell?.row == row && selectedCell?.col == col,
                                isInitial: viewModel.currentSession.initialBoard.grid[row][col] != 0
                            )
                            .onTapGesture {
                                selectedCell = (row, col)
                                viewModel.boardViewModel.didTapCell(row: row, col: col)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            
            // Number input buttons
            HStack(spacing: 10) {
                ForEach(1...9, id: \.self) { number in
                    Button(action: {
                        if let cell = selectedCell {
                            viewModel.boardViewModel.didEnterValue(number, at: cell.row, col: cell.col)
                            viewModel.currentSession.currentBoard.grid[cell.row][cell.col] = number
                        }
                    }) {
                        Text("\(number)")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                Button("Clear") {
                    if let cell = selectedCell {
                        viewModel.boardViewModel.didEraseCell(row: cell.row, col: cell.col)
                        viewModel.currentSession.currentBoard.grid[cell.row][cell.col] = 0
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            // Session info
            VStack(alignment: .leading, spacing: 8) {
                Text("Session ID: \(viewModel.currentSession.id.prefix(8))...")
                    .font(.caption)
                Text("Difficulty: \(viewModel.currentSession.difficulty.rawValue.capitalized)")
                    .font(.caption)
                Text("Tap Events: \(viewModel.currentSession.tapEvents.count)")
                    .font(.caption)
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
}

struct CellView: View {
    let value: Int
    let isSelected: Bool
    let isInitial: Bool
    
    var body: some View {
        Text(value == 0 ? "" : "\(value)")
            .font(.title2)
            .fontWeight(isInitial ? .bold : .regular)
            .frame(width: 50, height: 50)
            .background(isSelected ? Color.blue.opacity(0.3) : (isInitial ? Color.gray.opacity(0.2) : Color.white))
            .border(Color.black, width: 1)
            .foregroundColor(isInitial ? .black : .blue)
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
