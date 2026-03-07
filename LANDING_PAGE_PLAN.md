# Landing Page Implementation Plan

## Overview
This document outlines the complete plan for implementing a landing/menu page with difficulty selection, game state persistence, and continue-last-game functionality.

---

## Visual Layout

```
┌─────────────────────────────────────────┐
│        SUDOKU INSIGHTS                  │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  ▶ Continue Last Game             │ │  ← Only shows if saved game exists
│  │  Expert · 12:34 elapsed           │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌─────────┐  ┌─────────┐             │
│  │  EASY   │  │ MEDIUM  │             │
│  │  51 pre │  │ 41 pre  │             │
│  │ filled  │  │ filled  │             │
│  │         │  │         │             │
│  │ Best:   │  │ Best:   │             │
│  │ 03:42   │  │ 08:15   │             │
│  │ Avg:    │  │ Avg:    │             │
│  │ 05:20   │  │ 12:30   │             │
│  └─────────┘  └─────────┘             │
│                                         │
│  ┌─────────┐  ┌─────────┐             │
│  │  HARD   │  │ EXPERT  │             │
│  │  31 pre │  │ 21 pre  │             │
│  │ filled  │  │ filled  │             │
│  │         │  │         │             │
│  │ Best:   │  │ Best:   │             │
│  │ 15:22   │  │ --:--   │             │
│  │ Avg:    │  │ Avg:    │             │
│  │ 22:10   │  │ --:--   │             │
│  └─────────┘  └─────────┘             │
└─────────────────────────────────────────┘
```

### Design Specifications

#### Continue Last Game Button
- **Prominence**: Large, primary-styled button at the top
- **Visibility**: Only shown if `savedGameState != nil`
- **Content**:
  - "▶ Continue Last Game" label with play icon
  - Difficulty level and elapsed time (e.g., "Expert · 12:34 elapsed")
  - Subtle indicator: error count if > 0 (e.g., "Expert · 12:34 · 3 errors")
- **Color**: Accent/green to indicate resume action
- **Tap Action**: Loads saved game state, navigates to game view

#### Difficulty Cards
- **Grid Layout**: 2×2 grid with equal-sized cards
- **Card Content**:
  - Difficulty name (EASY, MEDIUM, HARD, EXPERT)
  - Number of pre-filled cells
  - Best completion time (MM:SS format)
  - Average completion time
  - Color-coded borders for visual distinction
- **Color Scheme**:
  - Easy: Green (`Color.green`)
  - Medium: Blue (`Color.blue`)
  - Hard: Orange (`Color.orange`)
  - Expert: Red (`Color.red`)
- **Tap Action**: Starts new game at selected difficulty, navigates to game view

---

## Feature 1: Game State Persistence

### Purpose
Save in-progress games so users can return later without losing their work.

### Data Model

```swift
struct SavedGameState: Codable {
    let difficulty: GameDifficulty
    let board: [[Int]]              // Current board state
    let initialBoard: [[Int]]       // Original given numbers
    let solution: [[Int]]           // Solution for validation
    let notes: [[[Int]]]            // Notes for each cell [row][col][candidates]
    let elapsedTime: TimeInterval   // Time spent so far
    let errorCount: Int             // Errors made
    let timestamp: Date             // When saved
}
```

### Persistence Strategy

#### Save Triggers
- **Auto-save**: Every 30 seconds while game is active
- **On navigation**: When user taps "Back to Menu" button
- **On app close**: Using `scenePhase` or `onDisappear` lifecycle

#### Save/Load Methods
```swift
class AppViewModel: ObservableObject {
    private let savedGameKey = "savedGameState"
    
    func saveGameState() {
        guard !isGameComplete else { return }  // Don't save completed games
        
        let state = SavedGameState(
            difficulty: currentDifficulty,
            board: gameSession.board.grid,
            initialBoard: gameSession.board.initialGrid,
            solution: gameSession.solution,
            notes: gameSession.board.notes,
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
        
        // Restore game state
        currentDifficulty = state.difficulty
        gameSession = GameSession(
            board: SudokuBoard(
                grid: state.board,
                initialGrid: state.initialBoard,
                notes: state.notes
            ),
            difficulty: state.difficulty,
            solution: state.solution
        )
        elapsedTime = state.elapsedTime
        errorCount = state.errorCount
        
        // Start timer from elapsed time
        startTimer()
        
        // Navigate to game
        showLandingPage = false
    }
}
```

### Auto-Save Implementation

```swift
// In AppViewModel
private var autoSaveTimer: Timer?

func startAutoSave() {
    autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
        self?.saveGameState()
    }
}

func stopAutoSave() {
    autoSaveTimer?.invalidate()
    autoSaveTimer = nil
}
```

---

## Feature 2: Landing Page View

### Component Structure

```swift
struct LandingPageView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            Text("SUDOKU INSIGHTS")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.primary)
            
            // Continue Last Game Button (conditional)
            if let savedGame = viewModel.loadGameState() {
                ContinueGameButton(savedGame: savedGame) {
                    viewModel.continueLastGame()
                }
            }
            
            // Difficulty Selection Grid
            DifficultyGridView(viewModel: viewModel)
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.96, green: 0.95, blue: 0.90))  // Beige background
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
    let difficulty: GameDifficulty
    let color: Color
    let preFilledCells: Int
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        Button(action: {
            viewModel.startNewGame(difficulty: difficulty)
            viewModel.showLandingPage = false
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
                
                // Stats from UserDefaults
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
```

### AppViewModel Updates

```swift
class AppViewModel: ObservableObject {
    // ... existing properties ...
    
    @Published var showLandingPage: Bool = true
    @Published var currentDifficulty: GameDifficulty = .medium
    
    // Add best time calculation
    func bestTimeForDifficulty(_ difficulty: GameDifficulty) -> String {
        let key = "completionTimes_\(difficulty.rawValue)"
        let times = UserDefaults.standard.array(forKey: key) as? [TimeInterval] ?? []
        
        guard let best = times.min() else { return "--:--" }
        
        let minutes = Int(best) / 60
        let seconds = Int(best) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // averageTimeForDifficulty already exists, just ensure it returns "--:--" for empty
}
```

---

## Feature 3: Navigation Flow

### State Management

```swift
// In AppViewModel
@Published var showLandingPage: Bool = true

// Modify init() to not auto-start a game
init() {
    // Don't create a game session automatically
    // User will select difficulty from landing page
}

func startNewGame(difficulty: GameDifficulty) {
    // Clear any saved game
    clearSavedGame()
    
    // Create new session
    currentDifficulty = difficulty
    let board = SudokuBoard.getSampleBoard(difficulty: difficulty)
    let solution = SudokuBoard.getSampleBoardSolution()
    gameSession = GameSession(board: board, difficulty: difficulty, solution: solution)
    
    // Reset game state
    selectedCell = nil
    invalidCells.removeAll()
    correctCells.removeAll()
    elapsedTime = 0
    errorCount = 0
    isGameComplete = false
    
    // Start timer and auto-save
    startTimer()
    startAutoSave()
    
    // Navigate to game
    showLandingPage = false
}

func returnToMenu() {
    // Save current game if not complete
    if !isGameComplete {
        saveGameState()
    }
    
    // Stop timers
    stopTimer()
    stopAutoSave()
    
    // Navigate to landing page
    showLandingPage = true
}
```

### ContentView Updates

```swift
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
```

### Game View Updates

Add "Back to Menu" button in the header:

```swift
// In GameBoardContentView
HStack {
    // Timer (existing)
    Text(formattedTime)
        .font(.headline)
    
    Spacer()
    
    // Back button
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
}
```

---

## Game Completion Flow Updates

When a game is completed:

```swift
func checkGameCompletion() {
    // ... existing completion logic ...
    
    if isGameComplete {
        // Clear saved game (no longer in-progress)
        clearSavedGame()
        
        // Stop auto-save
        stopAutoSave()
        
        // Show completion overlay (existing)
    }
}
```

---

## Implementation Summary

### Files to Create
1. **LandingPageView.swift** (new file in `Sources/SudokuInsightsApp/`)
   - `LandingPageView`
   - `ContinueGameButton`
   - `DifficultyGridView`
   - `DifficultyCard`

### Files to Modify

| File | Changes |
|------|---------|
| `main.swift` | • Add `SavedGameState` struct<br>• Add `showLandingPage` property to `AppViewModel`<br>• Add `currentDifficulty` property<br>• Add save/load/clear game state methods<br>• Add `continueLastGame()` method<br>• Add `returnToMenu()` method<br>• Add `bestTimeForDifficulty()` method<br>• Add auto-save timer logic<br>• Modify `init()` to not auto-start game<br>• Modify `startNewGame()` to clear saved state<br>• Modify `checkGameCompletion()` to clear saved state<br>• Update `ContentView` to conditionally show landing page<br>• Add "Back to Menu" button in `GameBoardContentView` |
| `GameModels.swift` | • Add `notes` property to `SudokuBoard` if not already present<br>• Ensure `SudokuBoard` has initializer accepting all needed parameters |

### Implementation Steps

1. **Create SavedGameState model** in main.swift
2. **Add persistence methods** to AppViewModel (save/load/clear)
3. **Add navigation state** (`showLandingPage`, `currentDifficulty`)
4. **Create LandingPageView** components (new file or in main.swift)
5. **Add ContinueGameButton** with conditional rendering
6. **Create DifficultyGridView** with 2×2 card layout
7. **Update ContentView** to show landing page vs game view
8. **Add "Back to Menu" button** to game view header
9. **Implement auto-save** with 30-second timer
10. **Update game completion** to clear saved state
11. **Add lifecycle hooks** for save-on-navigate and save-on-background

---

## Test Coverage Plan

### Unit Tests

```swift
// Test file: SavedGameStateTests.swift

class SavedGameStateTests: XCTestCase {
    var viewModel: AppViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = AppViewModel()
        // Clear any existing saved state
        UserDefaults.standard.removeObject(forKey: "savedGameState")
    }
    
    func testSaveGameState() {
        // Given: A game in progress
        viewModel.startNewGame(difficulty: .medium)
        viewModel.elapsedTime = 120.0  // 2 minutes
        viewModel.errorCount = 3
        
        // When: Game state is saved
        viewModel.saveGameState()
        
        // Then: State can be loaded
        let loaded = viewModel.loadGameState()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.difficulty, .medium)
        XCTAssertEqual(loaded?.elapsedTime, 120.0)
        XCTAssertEqual(loaded?.errorCount, 3)
    }
    
    func testLoadNonexistentGameState() {
        // When: No saved state exists
        let loaded = viewModel.loadGameState()
        
        // Then: Returns nil
        XCTAssertNil(loaded)
    }
    
    func testClearSavedGame() {
        // Given: A saved game exists
        viewModel.startNewGame(difficulty: .easy)
        viewModel.saveGameState()
        XCTAssertNotNil(viewModel.loadGameState())
        
        // When: Saved game is cleared
        viewModel.clearSavedGame()
        
        // Then: No saved state exists
        XCTAssertNil(viewModel.loadGameState())
    }
    
    func testContinueLastGame() {
        // Given: A saved game with specific state
        viewModel.startNewGame(difficulty: .hard)
        viewModel.elapsedTime = 300.0
        viewModel.errorCount = 5
        viewModel.saveGameState()
        
        // When: User continues last game
        let newViewModel = AppViewModel()
        newViewModel.continueLastGame()
        
        // Then: State is restored
        XCTAssertEqual(newViewModel.currentDifficulty, .hard)
        XCTAssertEqual(newViewModel.elapsedTime, 300.0)
        XCTAssertEqual(newViewModel.errorCount, 5)
        XCTAssertFalse(newViewModel.showLandingPage)
    }
    
    func testStartNewGameClearsSavedState() {
        // Given: A saved game exists
        viewModel.startNewGame(difficulty: .medium)
        viewModel.saveGameState()
        XCTAssertNotNil(viewModel.loadGameState())
        
        // When: Starting a new game
        viewModel.startNewGame(difficulty: .expert)
        
        // Then: Saved state is cleared
        XCTAssertNil(viewModel.loadGameState())
    }
    
    func testGameCompletionClearsSavedState() {
        // Given: A saved game exists
        viewModel.startNewGame(difficulty: .easy)
        viewModel.saveGameState()
        XCTAssertNotNil(viewModel.loadGameState())
        
        // When: Game is completed
        // (Simulate completion by filling board correctly)
        // ... fill board logic ...
        viewModel.checkGameCompletion()
        
        // Then: Saved state is cleared
        XCTAssertNil(viewModel.loadGameState())
    }
    
    func testReturnToMenuSavesInProgressGame() {
        // Given: A game in progress
        viewModel.startNewGame(difficulty: .medium)
        viewModel.elapsedTime = 180.0
        
        // When: User returns to menu
        viewModel.returnToMenu()
        
        // Then: Game state is saved
        let saved = viewModel.loadGameState()
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.elapsedTime, 180.0)
        XCTAssertTrue(viewModel.showLandingPage)
    }
    
    func testContinueButtonOnlyShowsWithSavedGame() {
        // When: No saved game exists
        XCTAssertNil(viewModel.loadGameState())
        
        // Then: Continue button should not show
        // (This will be a UI test, ensuring conditional rendering)
        
        // When: Saved game exists
        viewModel.startNewGame(difficulty: .easy)
        viewModel.saveGameState()
        
        // Then: Continue button should show
        XCTAssertNotNil(viewModel.loadGameState())
    }
    
    func testBestTimeCalculation() {
        // Given: Multiple completion times for a difficulty
        let key = "completionTimes_easy"
        UserDefaults.standard.set([300.0, 240.0, 360.0], forKey: key)
        
        // When: Requesting best time
        let best = viewModel.bestTimeForDifficulty(.easy)
        
        // Then: Returns fastest time (04:00)
        XCTAssertEqual(best, "04:00")
    }
    
    func testBestTimeWithNoCompletions() {
        // When: No completions exist for difficulty
        let best = viewModel.bestTimeForDifficulty(.expert)
        
        // Then: Returns placeholder
        XCTAssertEqual(best, "--:--")
    }
}
```

### Integration Tests

1. **Navigation flow**: Landing → Game → Menu → Resume
2. **Auto-save trigger**: Verify save occurs every 30 seconds
3. **State persistence**: Close and reopen app, verify saved game persists
4. **Stats display**: Verify completion times update difficulty cards

### Manual Testing Checklist

- [ ] Landing page displays all 4 difficulty cards
- [ ] Continue button only shows when saved game exists
- [ ] Continue button shows correct difficulty, time, and error count
- [ ] Tapping difficulty card starts new game at that level
- [ ] "Back to Menu" button saves game and returns to landing
- [ ] Saved game persists across app restarts
- [ ] Completing a game clears the saved state
- [ ] Starting a new game clears any existing saved state
- [ ] Best and average times display correctly on cards
- [ ] Auto-save occurs every 30 seconds during active game
- [ ] Timer resumes from correct time when continuing game
- [ ] Board state (numbers, notes, errors) fully restored on continue

---

## Design Notes

### Color Palette
- **Background**: Beige `rgb(0.96, 0.95, 0.90)` — matches game board
- **Continue button**: Green tint with green border — indicates resume action
- **Difficulty borders**: Color-coded (green/blue/orange/red) for quick recognition
- **Cards**: White background with colored borders

### Accessibility
- High contrast text on all backgrounds
- Large tap targets for buttons (minimum 44×44 points)
- Clear visual hierarchy (header → continue → difficulties)
- Semantic labels for screen readers

### Performance
- Save operations are async and don't block UI
- Auto-save only when game is active (not paused)
- Minimal UserDefaults reads (cache loaded state in memory)

---

## Future Enhancements

- **Multiple saved games**: Allow saving multiple in-progress games
- **Game history**: Show list of all completed games with details
- **Statistics page**: Detailed analytics per difficulty level
- **Cloud sync**: Save game state to iCloud for cross-device play
- **Custom puzzles**: Import or generate custom difficulty levels
- **Daily challenges**: Special puzzles that reset each day

---

## Summary

This plan adds:
1. ✅ **Landing page** with difficulty selection
2. ✅ **Continue last game** button with full state restoration
3. ✅ **Game state persistence** (board, notes, timer, errors)
4. ✅ **Auto-save** every 30 seconds
5. ✅ **Navigation** between menu and game
6. ✅ **Stats display** on difficulty cards (best/average times)
7. ✅ **Comprehensive test coverage** for all persistence logic

Ready for user review and implementation!
