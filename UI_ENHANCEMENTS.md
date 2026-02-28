# UI Enhancement Plan

## Overview
This document outlines planned improvements to the Sudoku Insights user interface to enhance gameplay experience and visual clarity.

---

## Enhancement 1: Bold 3×3 Grid Outlines

### Current State
- Individual cells have thin borders
- Bold borders not appearing on correct edges (currently buggy)

### Desired State
- 3×3 subgrids have bolder, more prominent borders
- Clear visual separation between the nine 3×3 boxes
- Bold borders should appear on RIGHT and BOTTOM of cells at columns 2, 5 and rows 2, 5

### Implementation Steps
1. Update `CellView` border logic to detect position within 3×3 grid
2. Apply thicker border (3-4pt) to RIGHT edge of cells at cols 2, 5
3. Apply thicker border (3-4pt) to BOTTOM edge of cells at rows 2, 5
4. Use `.overlay()` with Rectangle borders on specific edges
5. Test color contrast (darker gray or black for subgrid borders)

### Files to Modify
- `Sources/SudokuInsightsApp/main.swift` - `CellView` border rendering

### Bug Fix Required
- Current implementation checks `(col + 1) % 3 == 0` which gives cols 2, 5, 8
- Should only apply bold border to cols 2, 5 (not 8 - outer edge)
- Same for rows 2, 5 (not 8)
removed ✅
- Keyboard input implemented but NOT WORKING (bug)
- `.onKeyPress()` modifier added but not receiving events

### Desired State
- Accept keyboard input (1-9) for selected cell
- Accept Delete/Backspace to clear selected cell
- More compact, focused UI

### Implementation Steps
1. ✅ Remove `HStack` containing number buttons and "Clear" button
2. Fix keyboard event handling - current `.onKeyPress()` not working
3. Alternative approaches:
   - Use `.onReceive(NotificationCenter.default.publisher)` for key events
   - Implement NSEvent monitoring for macOS
   - Use environment key handler
4. Ensure view is first responder and can receive keyboard events
5. Add visual indicator that keyboard input is active

### Files to Modify
- `Sources/SudokuInsightsApp/main.swift` - `GameBoardContentView`

### Bug Fix Required
- `.onKeyPress()` modifier not capturing keyboard input
- May need to use macOS-specific event handling
- Consider using `.background()` with custom NSViewRepresentable for key events
### Files to Modify
- `Sources/SudokuInsightsApp/main.swift` - `GameBoardContentView`

### Technical Notes
- Use `.focused()` modifier to ensure view receives keyboard events
- Consider `.onKeyPress()` or `.keyboardShortcut()` depending on macOS version

---

## Enhancement 3: Smart Cell Highlighting

### Current State
- Selected cell shows blue background
- No highlighting of related cells or matching numbers

### Desired State
When a cell is tapped:
- Highlight all cells in the same **row** (light background)
- Highlight all cells in the same **column** (light background)
- Highlight all cells containing the **same number** (different color, e.g., yellow)
- Maintain clear visual hierarchy

### Implementation Steps
1. Add computed properties to determine highlighting:
   ```swift
   func shouldHighlightAxis(row: Int, col: Int, selected: (row: Int, col: Int)?) -> Bool
   func shouldHighlightNumber(value: Int, selectedValue: Int?) -> Bool
   ```
2. Update `CellView` to accept highlighting parameters:
   - `isAxisHighlighted`: For row/column highlighting
   - `isNumberHighlighted`: For matching number highlighting
3. Define color scheme:
   - Selected cell: Blue (existing)
   - Same row/column: Light gray or blue tint (e.g., `Color.blue.opacity(0.15)`)
   - Matching number: Yellow/amber tint (e.g., `Color.yellow.opacity(0.3)`)
4. Layer backgrounds appropriately (selected > number match > axis)

### Files to Modify
- `Sources/SudokuInsightsApp/main.swift` - `CellView` and `GameBoardContentView`

### Design Considerations
- Ensure color combinations are accessible
- Test with partially filled and completed boards
- Maintain distinction between initial (bold) and user-entered numbers

---

## Enhancement 4: Note-Taking Mode with 3×3 Grid Display

### Current State
- No note-taking functionality implemented
- Only full number entry supported

### Desired State
- Toggle button to switch between normal and note-taking mode
- In note mode, tapping 1-9 adds/removes candidate notes
- Notes display in 3×3 grid within cell:
  ```
  1 2 3
  4 5 6
  7 8 9
  ```
- Small, readable font for notes

### Implementation Steps

#### 4.1 Data Model Updates
1. Update `SudokuBoard` to include notes:
   ```swift
   public var notes: [[[Int]]]  // [row][col][candidates]
   // or
   public var notes: [[Set<Int>]]  // [row][col] = Set of candidates
   ```
2. Add note manipulation methods:
   ```swift
   mutating func toggleNote(row: Int, col: Int, value: Int)
   mutating func clearNotes(row: Int, col: Int)
   ```

#### 4.2 View Model Updates
1. Add note-taking mode state to `AppViewModel`:
   ```swift
   @Published var isNoteTakingMode: Bool = false
   ```
2. Update `didEnterValue` to handle note mode:
   ```swift
   if isNoteTakingMode {
       // Toggle note
   } else {
       // Enter value
   }
   ```

#### 4.3 UI Components
1. Add toggle button **OUTSIDE and BELOW** the 9×9 game board:
   ```swift
   Button(action: { viewModel.isNoteTakingMode.toggle() }) {
       Label(viewModel.isNoteTakingMode ? "Note Mode: ON" : "Normal Mode", 
             systemImage: "pencil.circle")
   }
   .buttonStyle(.bordered)
   ```
   - Position in VStack AFTER the grid (not as overlay)
   - Align to trailing edge
   
### Bug Fix Required
- Current implementation overlays button ON the grid
- Should be positioned outside/below the grid in the VStack layout

2. Update `CellView` to display notes:
   ```swift
   struct CellView: View {
       let value: Int
       let notes: Set<Int>
       let isNoteTakingMode: Bool
       
       var body: some View {
           ZStack {
               if value != 0 {
                   // Show main number
               } else if !notes.isEmpty {
                   // Show 3x3 note grid
                   NotesGridView(notes: notes)
               }
           }
       }
   }
   ```

3. Create `NotesGridView`:
   ```swift
   struct NotesGridView: View {
       let notes: Set<Int>
       
       var body: some View {
           VStack(spacing: 0) {
               ForEach(0..<3) { row in
                   HStack(spacing: 0) {
                       ForEach(0..<3) { col in
                           let num = row * 3 + col + 1
                           Text(notes.contains(num) ? "\(num)" : "")
                               .font(.system(size: 8))
                               .frame(maxWidth: .infinity, maxHeight: .infinity)
                       }
                   }
               }
           }
       }
   }
   ```

#### 4.4 Keyboard Integration
- Update keyboard handler to respect note mode
- When note mode is ON, typing 1-9 toggles notes instead of entering values

### Files to Modify
- `Sources/SudokuInsights/Core/GameState/GameModels.swift` - Add notes to `SudokuBoard`
- `Sources/SudokuInsightsApp/main.swift` - UI components and view models

### Technical Considerations
- Notes should clear when a value is entered in that cell
- Consider auto-calculating initial candidate notes for empty cells
- Ensure notes are visually distinct from entered values
- Font size should be readable but not overwhelming (~8-10pt)

---

## Implementation Priority

1. ~~**Enhancement 1** (Bold Grid Outlines)~~ ✅
2. ~~**Enhancement 2** (Keyboard Input)~~ ✅
3. ~~**Enhancement 3** (Smart Highlighting)~~ ✅
4. ~~**Enhancement 4** (Note-Taking)~~ ✅
5. **Enhancement 5** (Incorrect Input Feedback) - Visual error feedback
6. **Enhancement 6** (Correct Input Animation) - Satisfying confirmation animation
7. **Enhancement 7** (Remove Gray Background on Givens) - Cleaner board aesthetics
8. **Enhancement 8** (3×3 Box Highlighting) - Highlight containing box on cell select

## Testing Checklist

- [x] 3×3 grids are visually distinct and properly aligned
- [x] Keyboard input works for numbers 1-9
- [x] Delete/Backspace clears selected cell
- [x] Row/column highlighting works correctly
- [x] Number matching highlights all instances
- [x] Note toggle button changes state
- [x] Notes display correctly in 3×3 format
- [x] Notes clear when value is entered
- [x] Initial (bold) numbers remain unmodifiable
- [ ] Telemetry records all interactions (notes, keyboard input)
- [ ] Incorrect numbers display in red
- [ ] Correct numbers flash blue/bold then fade to default over 3 seconds
- [ ] 3×3 box containing selected cell is subtly highlighted
- [ ] Given numbers no longer have gray background

---

## Enhancement 5: Incorrect Number Input Displays Red

### Current State
- All user-entered numbers display in blue regardless of correctness
- No visual feedback when a wrong number is entered

### Desired State
- When a user enters an incorrect number, it displays in **red**
- Incorrect = violates Sudoku constraints (duplicate in row, column, or 3×3 box)
- Red color persists until the number is cleared or corrected

### Implementation Steps

#### 5.1 Validation Logic
1. Add validation check when a number is entered:
   ```swift
   func isValidPlacement(row: Int, col: Int, value: Int) -> Bool
   ```
2. Use existing `SudokuEngine.isValidMove()` to check against current board state
3. Store validity state per cell for rendering

#### 5.2 Data Model Updates
1. Add error tracking to the board or view model:
   ```swift
   @Published var invalidCells: Set<String>  // "row,col" keys
   ```
2. Update on every number entry — revalidate affected cells when board changes

#### 5.3 UI Updates
1. Update `CellView` to accept an `isInvalid` parameter
2. When `isInvalid == true`, render number text in `Color.red`
3. When `isInvalid == false`, render with default color (black for givens, contextual for user entries)

### Files to Modify
- `Sources/SudokuInsightsApp/main.swift` — `AppViewModel`, `CellView`
- `Sources/SudokuInsights/Core/SudokuEngine/SudokuEngine.swift` — may leverage existing `isValidMove()`

---

## Enhancement 6: Correct Input Animation (Blue/Bold → Default Fade)

### Current State
- User-entered numbers appear in blue immediately with no animation
- No visual confirmation that a correct number was placed

### Desired State
- When a correct number is entered, it appears in **bold blue**
- Over **3 seconds**, the color and weight gradually transition to match the default style (black, regular weight)
- Provides satisfying visual feedback for correct placements

### Implementation Steps

#### 6.1 Animation State Tracking
1. Track recently placed correct cells with timestamps:
   ```swift
   @Published var recentCorrectCells: [String: Date]  // "row,col" → time placed
   ```
2. On each render, compute elapsed time since placement to drive the animation

#### 6.2 Animation Implementation
1. Use SwiftUI's animation system with a timer or `TimelineView`:
   ```swift
   // Interpolate color from blue → black over 3 seconds
   let progress = min(elapsed / 3.0, 1.0)
   let color = Color.blue.opacity(1.0 - progress)  // fades toward black
   let weight: Font.Weight = progress < 0.5 ? .bold : .regular
   ```
2. Alternative: Use `withAnimation(.easeOut(duration: 3.0))` on state change
3. Consider `TimelineView(.animation)` for smooth continuous interpolation

#### 6.3 UI Updates
1. Update `CellView` to accept animation progress:
   - `animationProgress: Double` (0.0 = just placed, 1.0 = fully settled)
2. Interpolate font color from blue → black based on progress
3. Interpolate font weight from bold → regular

### Files to Modify
- `Sources/SudokuInsightsApp/main.swift` — `AppViewModel`, `CellView`

### Technical Considerations
- Clean up `recentCorrectCells` entries once animation completes (progress ≥ 1.0)
- Ensure animation doesn't interfere with cell selection or highlighting
- Consider using `TimelineView` for frame-accurate animation without manual timers

---

## Enhancement 7: Remove Gray Background on Given Numbers

### Current State
- Cells with pre-filled (given) numbers have a gray background (`Color.gray.opacity(0.2)`)
- This creates visual noise and makes the board feel cluttered

### Desired State
- Given numbers render with the **same white background** as empty cells
- Given numbers remain **bold black** to distinguish them from user entries
- The bold font weight alone is sufficient to indicate a given vs. user-entered number

### Implementation Steps

1. Update `CellView.backgroundColor` computed property:
   ```swift
   // Remove the isInitial case — treat it the same as empty cells
   private var backgroundColor: Color {
       if isSelected {
           return Color.blue.opacity(0.4)
       } else if isNumberHighlighted {
           return Color.yellow.opacity(0.3)
       } else if isAxisHighlighted {
           return Color.blue.opacity(0.15)
       } else {
           return Color.white  // Same for givens and empty cells
       }
   }
   ```

### Files to Modify
- `Sources/SudokuInsightsApp/main.swift` — `CellView.backgroundColor`

---
Enhancement 8: 3×3 Box Highlighting

### Current State
- When a cell is selected, its row and column are highlighted with a light blue tint
- The 3×3 box the cell belongs to is not highlighted
- Makes it harder to quickly scan constraints within the box

### Desired State
- When a cell is selected, the entire **3×3 box** containing it is subtly highlighted
- Uses a color on the **same gray gradient** as the board background (e.g., `Color.gray.opacity(0.1)`)
- Lighter/subtler than the row/column highlighting so it doesn't compete visually
- Visual hierarchy: **selected cell > number match > row/column > 3×3 box > default**

### Implementation Steps

#### 8.1 Box Detection
1. Add helper to determine if a cell shares a 3×3 box with the selected cell:
   ```swift
   func isInSameBox(row: Int, col: Int) -> Bool {
       guard let selected = selectedCell else { return false }
       let boxRow = selected.row / 3
       let boxCol = selected.col / 3
       return (row / 3 == boxRow) && (col / 3 == boxCol)
   }
   ```

#### 8.2 UI Updates
1. Add `isBoxHighlighted` parameter to `CellView`
2. Update `backgroundColor` computed property — insert box highlighting below axis but above default:
   ```swift
   private var backgroundColor: Color {
       if isSelected {
           return Color.blue.opacity(0.4)
       } else if isNumberHighlighted {
           return Color.yellow.opacity(0.3)
       } else if isAxisHighlighted {
           return Color.blue.opacity(0.15)
       } else if isBoxHighlighted {
           return Color.gray.opacity(0.1)  // Same gradient as board background
       } else {
           return Color.white
       }
   }
   ```

### Files to Modify
- `Sources/SudokuInsightsApp/main.swift` — `GameBoardContentView`, `CellView`

### Design Considerations
- Box highlight should be **subtler** than row/column (gray vs blue tint)
- Where row/column and box overlap, row/column takes priority
- Uses the board's gray color family so it feels like a natural part of the grid

---

## 
## Future Considerations

- Auto-fill candidate notes for all empty cells
- Smart note elimination when numbers are placed
- Undo/Redo functionality
- Timer display
- Difficulty selector for new games
- Dark mode support
