import SwiftUI

public struct CellView: View, Equatable {
    let value: Int
    let notes: Set<Int>
    let highlightedNoteNumber: Int?
    let isSelected: Bool
    let isInitial: Bool
    let isAxisHighlighted: Bool
    let isNumberHighlighted: Bool
    let isBoxHighlighted: Bool
    let isInvalid: Bool
    let isCorrect: Bool
    let cellSize: CGFloat
    let theme: SudokuTheme

    public init(
        value: Int,
        notes: Set<Int>,
        highlightedNoteNumber: Int?,
        isSelected: Bool,
        isInitial: Bool,
        isAxisHighlighted: Bool,
        isNumberHighlighted: Bool,
        isBoxHighlighted: Bool,
        isInvalid: Bool,
        isCorrect: Bool,
        cellSize: CGFloat,
        theme: SudokuTheme
    ) {
        self.value = value
        self.notes = notes
        self.highlightedNoteNumber = highlightedNoteNumber
        self.isSelected = isSelected
        self.isInitial = isInitial
        self.isAxisHighlighted = isAxisHighlighted
        self.isNumberHighlighted = isNumberHighlighted
        self.isBoxHighlighted = isBoxHighlighted
        self.isInvalid = isInvalid
        self.isCorrect = isCorrect
        self.cellSize = cellSize
        self.theme = theme
    }

    public var body: some View {
        ZStack {
            backgroundColor

            if value == 0 && !notes.isEmpty {
                NotesGridView(
                    notes: notes,
                    highlightedNumber: highlightedNoteNumber,
                    cellSize: cellSize,
                    theme: theme
                )
            } else if value != 0 {
                Text("\(value)")
                    // Given vs. entered is carried by color alone — a larger, lighter
                    // digit reads more clearly than a smaller bold one.
                    .font(.system(size: cellSize * 0.76, weight: .regular))
                    .foregroundColor(digitColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .clipped()
        .border(theme.cellBorder, width: 0.5)
    }

    private var digitColor: Color {
        if isInvalid { return theme.errorDigit }
        return isInitial ? theme.givenDigit : theme.enteredDigit
    }

    private var backgroundColor: Color {
        if isSelected {
            return theme.selectedCell
        } else if isNumberHighlighted {
            return theme.sameNumberHighlight
        } else if isAxisHighlighted || isBoxHighlighted {
            return theme.peerHighlight
        } else {
            return theme.cellBackground
        }
    }
}
