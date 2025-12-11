# 📱 SwiftSuDoKu-Based iOS App – Architecture & Development Plan

## 1. **Project Overview**

Build a Sudoku-based iOS application that analyzes a user’s gameplay telemetry (tap events, timestamps, puzzle metadata) and generates insights about cognitive patterns, behavior, problem-solving style, and performance over time.

Tech stack is fully Apple-native:

* **Language**: Swift (latest)
* **Framework**: SwiftUI
* **Package Manager**: Swift Package Manager (SPM)
* **Primary Library**: **SwiftSuDoKu** (preferred)
* **Secondary Options**: `Swift-Sudoku-Solver`, `sudoku-swift` (only if gaps appear)

This project is assumed to run on **macOS via Xcode** for the actual build, but the *planning + coding* phase can partially occur in VS Code on Windows using **Swift for Windows**, **SwiftWasm**, or a remote macOS environment—Copilot Agent can scaffold the Swift project before you open it in Xcode.

---

## 2. **High-Level Features**

### **User Gameplay**

* Start new Sudoku game (via SwiftSuDoKu puzzle generator)
* Continue saved games
* Record all gameplay interactions (cell taps, inputs, erasures, pauses, hints)

### **Data Capture**

Telemetry collected for each tap:

* Timestamp
* Grid coordinate (row/column)
* Action type (select cell, enter value, erase, note mode)
* Puzzle metadata (difficulty, puzzle ID, seed)

### **Analytics Engine**

Analytics runs locally on-device:

* Solve-path reconstruction
* Time-to-first-entry map
* Per-digit performance
* Error pattern identification
* Heatmap of user attention/interaction
* Strategy type classification (candidate-driven, brute-force, scanning, etc.)
* “Mental state indicators” (derived from hesitation, error clustering, early vs late accuracy)

### **Reports + Visualizations**

* Progress dashboard with charts (Swift Charts)
* “Cognitive Mirror” report summarizing patterns
* Streaks, best times, average times per difficulty
* Puzzle exploration heatmap overlay

---

## 3. **App Architecture**

```
/Sources
 ├── Core
 │    ├── SudokuEngine/ (SwiftSuDoKu integration)
 │    ├── GameState/
 │    ├── Telemetry/
 │    └── Analytics/
 │
 ├── UI
 │    ├── GameBoard/
 │    ├── StatsDashboard/
 │    ├── Reports/
 │    └── SharedComponents/
 │
 ├── Services
 │    ├── Persistence (FileManager + Codable)
 │    └── Settings
 │
 └── App.swift
```

### **Module Responsibilities**

#### **Core.SudokuEngine**

* Wraps SwiftSuDoKu APIs
* Generates puzzles
* Validates moves
* Provides difficulty metadata

#### **Core.GameState**

* Represents board state
* Undo/redo stack
* Notes candidate structures
* Associates game session with telemetry recorder

#### **Core.Telemetry**

* Event struct:

  ```swift
  struct TapEvent: Codable {
      let timestamp: TimeInterval
      let row: Int
      let col: Int
      let action: TapAction
  }
  ```
* Session recorder (append-only)
* Session serialization and compression

#### **Core.Analytics**

* Tap-stream ingestion
* Behavior classification
* Heatmap generation
* Time-segmented error analysis
* Per-difficulty aggregation

---

## 4. **Data Models**

### **GameSession**

```swift
struct GameSession: Codable {
    let id: UUID
    let puzzle: SudokuPuzzle
    var startTime: Date
    var endTime: Date?
    var tapEvents: [TapEvent]
}
```

### **AnalyticsReport**

```swift
struct AnalyticsReport: Codable {
    let sessionID: UUID
    let difficulty: Difficulty
    let totalMoves: Int
    let timeToSolve: TimeInterval?
    let errorRate: Double
    let strategyProfile: StrategyProfile
    let heatmap: HeatmapGrid
}
```

---

## 5. **Analytics Engine Specification**

### **5.1 Tap-Sequence Analysis**

* **Move speed curve** → detect warm-up vs fatigue
* **Clustered hesitation** → identifies challenging subgrids
* **Digit preference early-game** → scanning vs candidate-first
* **Error bursts** → frustration/overconfidence signatures

### **5.2 Derived Metrics**

* Completion time
* Mean think time per correct input
* Fastest/slowest rows and columns
* “Flow state index” (steady low-variance move timing)
* “Stuck moments” (longest inactivity intervals)

### **5.3 Strategy Classification (Heuristic)**

* **Scanner** → many cell taps with few inputs
* **Candidate Builder** → note-mode heavy
* **Brute-forcer** → high error rate early
* **Logical solver** → low error rate, consistent pace

### **5.4 Heatmap Generation**

A 9×9 grid storing number of interactions per cell:

```swift
typealias HeatmapGrid = [[Int]]
```

Converted to:

* Color intensity for visualization
* “Attention imbalance score”

---

## 6. **UI Architecture**

### **Game Board Screen**

* SwiftUI Grid layout
* Highlighting logic driven by SwiftSuDoKu’s validity checks
* Animated tap feedback
* Candidate note overlay

### **Analytics Dashboard**

* Swift Charts:

  * Time-to-move histogram
  * Error rate over time
  * Heatmap visualization (custom)

### **Session Report**

A narrative summary:

* “You hesitated longest at cell (3,7).”
* “Your strongest digit today was 4.”
* “Your play style is: scanner → candidate builder → logical finish.”

---

## 7. **Persistence**

* Local JSON storage (FileManager)
* App-level migration support
* Cache for heatmaps and reports

Directory example:

```
/Documents/Sessions/{sessionID}.json
/Documents/Reports/{sessionID}.report.json
```

---

## 8. **First Development Milestones**

### **Milestone 1 — Project Skeleton**

* Create SwiftUI app
* Integrate SwiftSuDoKu via SPM
* Build minimal puzzle rendering
* Hardcode a sample puzzle

### **Milestone 2 — Telemetry Recorder**

* Record taps
* Serialize events
* Save session to disk

### **Milestone 3 — Analytics Engine v1**

* Time-per-move
* Error rate
* Heatmap
* Basic report structure

### **Milestone 4 — UI for Reports**

* Swift Charts
* Heatmap view
* Narrative report generator

### **Milestone 5 — Real Puzzles**

* Replace placeholder with full SwiftSuDoKu integration
* Add difficulty selection
* Add pause/save/continue features

---

## 9. **Copilot Agent Instructions**

When running in agent mode, ask it to:

1. Scaffold folders shown in architecture
2. Create SwiftSuDoKu wrapper module
3. Implement GameSession + TapEvent models
4. Build TelemetryRecorder
5. Stub out AnalyticsEngine with TODOs
6. Scaffold SwiftUI views including GameBoard and Dashboard
7. Generate sample data + sample reports
8. Write preview tests (SwiftUI previews)