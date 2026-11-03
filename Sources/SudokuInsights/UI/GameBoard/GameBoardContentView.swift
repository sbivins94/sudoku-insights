import SwiftUI

public struct GameBoardContentView: View {
    @ObservedObject var viewModel: SharedAppViewModel
    @State private var selectedCell: (row: Int, col: Int)?
    @State private var showThemePicker = false

    private let numberPadSpacing: CGFloat = 6
    /// Horizontal padding on the whole screen, and the board's own inset. Both are kept
    /// tight so the grid can run close to the full screen width.
    private let bodyPadding: CGFloat = 8
    private let boardInset: CGFloat = 2

    private var theme: SudokuTheme { viewModel.theme }

    public init(viewModel: SharedAppViewModel) {
        self.viewModel = viewModel
    }

    private var selectedValueForHighlighting: Int? {
        guard let selected = selectedCell else { return nil }
        let value = viewModel.currentSession.currentBoard.grid[selected.row][selected.col]
        return value == 0 ? nil : value
    }

    public var body: some View {
        // Measure the available screen once at the top level (a GeometryReader nested
        // inside a ScrollView can't size itself reliably) and derive a cell size that
        // always fits — this keeps the board on-screen on any iPhone instead of
        // overflowing at a mac-sized fixed 50pt/cell.
        GeometryReader { screenGeo in
            let cellSize = gridCellSize(for: screenGeo.size)
            // Number pad buttons at their mac-sized 40pt fixed width (9 * 40 + 8 * 10
            // spacing ≈ 472pt) are wider than an iPhone screen. An oversized row like
            // this stretches the whole VStack's frame to its width, which — since a
            // VStack centers its children by default — pushes every other row
            // (header, board, notes toggle) off-screen to the right with a matching
            // blank gap on the left. Shrinking the buttons to fit keeps every row
            // within the actual screen width.
            let padButtonSize = numberPadButtonSize(for: screenGeo.size)

            ZStack {
                theme.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        header
                        grid(cellSize: cellSize)
                        toolbar
                        numberPad(buttonSize: padButtonSize)
                    }
                    .padding(.horizontal, bodyPadding)
                    .padding(.vertical, 12)
                }
                .frame(width: screenGeo.size.width, height: screenGeo.size.height)

                if viewModel.isGameComplete {
                    GameCompleteOverlay(viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showThemePicker) {
                ThemePickerView(viewModel: viewModel)
            }
        }
    }

    private func gridCellSize(for screenSize: CGSize) -> CGFloat {
        let outerPadding = bodyPadding * 2
        let gridPadding = boardInset * 2
        let widthBudget = screenSize.width - outerPadding - gridPadding
        let heightBudget = screenSize.height * 0.62 // leave room for header/controls
        let rawSize = min(widthBudget, heightBudget) / 9
        return min(max(rawSize, 28), 64)
    }

    private func numberPadButtonSize(for screenSize: CGSize) -> CGFloat {
        let outerPadding = bodyPadding * 2
        let totalSpacing = numberPadSpacing * 8 // 8 gaps between 9 buttons
        let widthBudget = screenSize.width - outerPadding - totalSpacing
        return min(max(widthBudget / 9, 28), 52)
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                Button(action: {
                    viewModel.returnToMenu()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Menu")
                    }
                    .font(.subheadline)
                    .foregroundColor(theme.accent)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { showThemePicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "paintpalette.fill")
                        Text(theme.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(theme.controlForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(theme.accent)
                    .cornerRadius(8)
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline) {
                statColumn("Difficulty", viewModel.currentDifficulty.rawValue.capitalized)
                Spacer()
                statColumn("Mistakes", "\(viewModel.errorCount)")
                Spacer()
                statColumn("Time", viewModel.formattedTime)
            }
        }
        .padding(.horizontal, 4)
    }

    private func statColumn(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundColor(theme.primaryText)
        }
    }

    private func grid(cellSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { col in
                        CellView(
                            value: viewModel.currentSession.currentBoard.grid[row][col],
                            notes: viewModel.currentSession.currentBoard.notes[row][col],
                            highlightedNoteNumber: selectedValueForHighlighting,
                            isSelected: selectedCell?.row == row && selectedCell?.col == col,
                            isInitial: viewModel.currentSession.initialBoard.grid[row][col] != 0,
                            isAxisHighlighted: isAxisHighlighted(row: row, col: col),
                            isNumberHighlighted: isNumberHighlighted(row: row, col: col),
                            isBoxHighlighted: isBoxHighlighted(row: row, col: col),
                            isInvalid: viewModel.invalidCells.contains("\(row),\(col)"),
                            isCorrect: viewModel.correctCells.contains("\(row),\(col)"),
                            cellSize: cellSize,
                            theme: theme
                        )
                        .equatable()
                        .onTapGesture {
                            selectedCell = (row, col)
                            viewModel.recordCellTap(row: row, col: col)
                            viewModel.boardViewModel.didTapCell(row: row, col: col)
                            viewModel.boardViewModel.selectedCell = (row, col)
                        }
                    }
                }
            }
        }
        .overlay(boxSeparators(cellSize: cellSize))
        .padding(boardInset)
        .background(theme.boardSurface)
        .cornerRadius(4)
        #if os(macOS)
        .onMacKeyboardInput(
            isSelectionActive: { selectedCell != nil },
            onNumber: { viewModel.handleKeyPress($0) },
            onToggleNotes: { viewModel.isNoteTakingMode.toggle() },
            onDelete: { viewModel.handleDelete() }
        )
        #endif
    }

    // Drawn once over the whole board rather than per-cell. Per-cell lines straddle the
    // boundary, so the neighbouring cell's background paints over the inner half — which
    // is invisible against white but leaves a blended dark edge on a highlighted cell.
    private func boxSeparators(cellSize: CGFloat) -> some View {
        let boardSize = cellSize * 9
        let lineWidth: CGFloat = 2

        return ZStack(alignment: .topLeading) {
            ForEach([3, 6], id: \.self) { index in
                Rectangle()
                    .fill(theme.boxLine)
                    .frame(width: lineWidth, height: boardSize)
                    .offset(x: cellSize * CGFloat(index) - lineWidth / 2)
            }

            ForEach([3, 6], id: \.self) { index in
                Rectangle()
                    .fill(theme.boxLine)
                    .frame(width: boardSize, height: lineWidth)
                    .offset(y: cellSize * CGFloat(index) - lineWidth / 2)
            }
        }
        .frame(width: boardSize, height: boardSize, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var canErase: Bool {
        guard let cell = selectedCell else { return false }
        return viewModel.canErase(row: cell.row, col: cell.col)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            toolbarButton(
                icon: "arrow.uturn.backward",
                label: "Undo",
                isEnabled: viewModel.canUndo,
                isActive: false
            ) {
                viewModel.undo()
            }

            toolbarButton(
                icon: "eraser",
                label: "Erase",
                isEnabled: canErase,
                isActive: false
            ) {
                viewModel.handleDelete()
            }

            toolbarButton(
                icon: viewModel.isNoteTakingMode ? "pencil.circle.fill" : "pencil.circle",
                label: viewModel.isNoteTakingMode ? "Notes ON" : "Notes OFF",
                isEnabled: true,
                isActive: viewModel.isNoteTakingMode
            ) {
                // Toggling republishes the view model, and SwiftUI would inherit any
                // ambient animation to cross-fade all 81 cells — which reads as lag on
                // a button that should feel instant.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    viewModel.isNoteTakingMode.toggle()
                }
            }
            .animation(nil, value: viewModel.isNoteTakingMode)
        }
    }

    private func toolbarButton(
        icon: String,
        label: String,
        isEnabled: Bool,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isActive ? theme.accent : theme.controlBackground.opacity(isEnabled ? 1.0 : 0.4))
            .foregroundColor(theme.controlForeground.opacity(isEnabled ? 1.0 : 0.6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    // Doubles as the candidates tracker; disables numbers once all 9 are correctly placed.
    private func numberPad(buttonSize: CGFloat) -> some View {
        HStack(spacing: numberPadSpacing) {
            ForEach(1...9, id: \.self) { num in
                let isAvailable = viewModel.availableCandidates.contains(num)
                Button {
                    selectedCell.map { _ in viewModel.handleKeyPress(num) }
                } label: {
                    Text("\(num)")
                        .font(.system(size: buttonSize * 1.08, weight: .regular))
                        .foregroundColor(isAvailable ? theme.enteredDigit : theme.secondaryText.opacity(0.45))
                        .strikethrough(!isAvailable)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(width: buttonSize, height: buttonSize * 1.35)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isAvailable || selectedCell == nil)
            }
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
