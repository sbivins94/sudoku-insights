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

1. **Enhancement 1** (Bold Grid Outlines) - Quick win, improves visual clarity immediately
2. **Enhancement 2** (Keyboard Input) - Removes screen clutter, improves UX
3. **Enhancement 3** (Smart Highlighting) - Enhances gameplay strategy
4. **Enhancement 4** (Note-Taking) - Most complex, adds advanced functionality

## Testing Checklist

- [ ] 3×3 grids are visually distinct and properly aligned
- [ ] Keyboard input works for numbers 1-9
- [ ] Delete/Backspace clears selected cell
- [ ] Row/column highlighting works correctly
- [ ] Number matching highlights all instances
- [ ] Note toggle button changes state
- [ ] Notes display correctly in 3×3 format
- [ ] Notes clear when value is entered
- [ ] Initial (bold) numbers remain unmodifiable
- [ ] Telemetry records all interactions (notes, keyboard input)

---

## Future Considerations

- Auto-fill candidate notes for all empty cells
- Smart note elimination when numbers are placed
- Undo/Redo functionality
- Timer display
- Difficulty selector for new games
- Dark mode support
