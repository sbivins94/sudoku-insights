# Sudoku Insights

A Sudoku app with gameplay telemetry/analytics, shared across macOS and iOS via a Swift Package.

## Project layout

- `Sources/SudokuInsights/` — shared library target (SPM). Core game logic, analytics, and SwiftUI views live here.
  - `Core/SudokuEngine/` — puzzle generation & validation
  - `Core/GameState/` — game session models
  - `Core/Telemetry/` — event recording
  - `Core/Analytics/` — analytics engine
  - `Services/PersistenceService.swift` — JSON persistence
  - `UI/` — SwiftUI views (GameBoard, StatsDashboard, Reports, SharedComponents)
- `Sources/SudokuInsightsApp/main.swift` — **macOS** executable host. This currently contains the most complete/polished gameplay UI (landing page, board, notes mode, timer, completion overlay), plus macOS-only code (AppKit, NSEvent keyboard handling, window config) all mixed together in one large file (~1100 lines).
- `SudokuInsightsiOS/` — Xcode project for the **iOS** app host. Links to the local `SudokuInsights` package via `XCLocalSwiftPackageReference`. Dev team and bundle ID (`com.seanbivins.SudokuInsightsiOS`) are already configured.
- `Tests/SudokuInsightsTests/` — unit tests for the shared package.

## Build & test

```bash
swift build              # build the shared package + macOS executable
swift run SudokuInsightsApp   # run the macOS app
swift test                # run unit tests
```

The iOS app must be built/run through Xcode (open `SudokuInsightsiOS/SudokuInsightsiOS.xcodeproj`), since it needs a simulator or device — `swift build` does not build the iOS target.

## Current state

The shared UI/gameplay refactor described in `IOS_SHARED_UI_REFACTOR_PLAN.md` is complete: both the macOS and iOS hosts render `SharedRootView()` from `Sources/SudokuInsights/UI/GameBoard/SharedRootView.swift`. Feature parity includes notes mode, row/column/box/number highlighting, the confetti completion overlay, save/resume via `SharedAppViewModel` + `SavedGameState`, and best/average completion time tracking per difficulty.

- `Sources/SudokuInsightsApp/main.swift` is now a thin macOS host: `@main App`, `AppDelegate`, window sizing. No gameplay logic lives here.
- `SudokuInsightsiOS/SudokuInsightsiOS/ContentView.swift` is a thin iOS host rendering the same `SharedRootView()`.
- Platform-only code is isolated: `Sources/SudokuInsights/Platform/Mac/MacKeyboardHandler.swift` (physical keyboard shortcuts, `#if os(macOS)` only) and `Sources/SudokuInsights/Platform/Shared/PlatformColors.swift` (cross-platform color helpers, e.g. `Color.platformWindowBackground` instead of `NSColor`/`UIColor` directly).
- The number pad under the board doubles as the candidates tracker and is tappable on both platforms (needed since iOS has no physical keyboard); it disables/strikes through numbers once all 9 instances are correctly placed.

## Conventions

- Keep AppKit/NSEvent-specific code confined to `Sources/SudokuInsightsApp/main.swift` (or future mac-only files) — never in `Sources/SudokuInsights/`, which must stay cross-platform.
- New shared UI/gameplay code belongs in `Sources/SudokuInsights/`, not duplicated per-platform.
