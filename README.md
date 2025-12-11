# 📱 Sudoku Insights

A comprehensive Sudoku-based iOS app that analyzes gameplay telemetry to generate insights about cognitive patterns, problem-solving style, and performance.

## Project Status

✅ **Milestone 1 Complete**: Project skeleton with all core modules scaffolded  
🚀 **Next**: GitHub Actions automated builds + unit tests

## Tech Stack

- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Package Manager**: Swift Package Manager (SPM)
- **Sudoku Library**: [SwiftSudokuSolver](https://github.com/jphong1111/SwiftSudokuSolver.git)
- **CI/CD**: GitHub Actions (macOS builds)

## Project Structure

```
sudoku-insights/
├── Sources/SudokuInsights/
│   ├── Core/
│   │   ├── SudokuEngine/          # Puzzle generation & validation
│   │   ├── GameState/             # Game session models
│   │   ├── Telemetry/             # Event recording
│   │   └── Analytics/             # Analytics engine
│   │
│   ├── UI/
│   │   ├── GameBoard/             # Game board UI
│   │   ├── StatsDashboard/        # Analytics dashboard
│   │   ├── Reports/               # Detailed reports
│   │   └── SharedComponents/      # Reusable UI components
│   │
│   ├── Services/
│   │   └── PersistenceService.swift
│   │
│   └── App.swift
│
├── Tests/SudokuInsightsTests/     # Unit tests
├── Package.swift                  # SPM manifest
└── .github/workflows/
    └── build.yml                  # GitHub Actions workflow
```

## Getting Started

### Prerequisites

- Git
- GitHub account

### Development Workflow

1. **Clone the repository**:
   ```bash
   git clone https://github.com/sbivins94/sudoku-insights.git
   cd sudoku-insights
   ```

2. **Build locally** (requires macOS):
   ```bash
   swift build
   ```

3. **Run tests** (requires macOS):
   ```bash
   swift test
   ```

4. **Open in Xcode** (for iOS development):
   ```bash
   open Package.swift
   ```

### Building on Windows

Since iOS development requires macOS, use **GitHub Actions** for automated builds:

1. Push your changes to the `main` or `develop` branch
2. GitHub Actions automatically builds and tests on macOS
3. View results at: `https://github.com/sbivins94/sudoku-insights/actions`

## Milestones

### Milestone 1 — Project Skeleton ✅
- Swift package structure
- Core models and telemetry recorder
- Analytics engine skeleton
- GitHub Actions workflow

### Milestone 2 — Full Telemetry (In Progress)
- Enhanced event recording
- Session serialization
- File-based persistence

### Milestone 3 — Analytics Engine v1
- Move timing analysis
- Strategy classification
- Heatmap generation

### Milestone 4 — UI & Visualization
- GameBoard SwiftUI view
- Analytics dashboard
- Interactive heatmap

### Milestone 5 — Real Puzzles & Features
- Full SwiftSuDoKu integration
- Difficulty selection
- Pause/save/continue features
- Session history

## Core Components

### GameSession
Represents a complete game from start to finish:
- Puzzle metadata
- Tap event log
- Duration and completion status

### TapEvent
Individual user action with:
- Timestamp (relative to session start)
- Grid coordinates
- Action type (select, enter, erase, note)

### AnalyticsEngine
Processes telemetry to extract:
- Performance metrics (time, accuracy)
- Strategy classification
- Interaction heatmaps
- "Mental state indicators"

### PersistenceService
Handles:
- Session serialization (JSON)
- Report caching
- Local file storage

## Testing

Run tests via GitHub Actions or locally:

```bash
swift test
```

Current test coverage:
- ✅ Session creation and event recording
- ✅ Analytics report generation
- ✅ Heatmap generation
- ✅ Sudoku validation logic

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Commit changes: `git commit -am 'Add feature'`
3. Push to branch: `git push origin feature/your-feature`
4. GitHub Actions will automatically run tests

## Architecture Highlights

- **Modular design**: Core, UI, and Services layers are independent
- **Event-driven telemetry**: All gameplay recorded as immutable events
- **Analytics pipeline**: Tap stream → metrics → report generation
- **Testable architecture**: Each component has clear responsibilities

## Next Steps

1. Integrate real puzzle generation from SwiftSudokuSolver
2. Implement full SwiftUI board visualization
3. Add Swift Charts for analytics dashboard
4. Develop "Cognitive Mirror" narrative reports
5. Add session history and streak tracking

## License

MIT

## Questions?

See [PLAN.md](PLAN.md) for full architecture and feature specifications.
