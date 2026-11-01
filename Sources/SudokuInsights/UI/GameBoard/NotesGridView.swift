import SwiftUI

public struct NotesGridView: View {
    let notes: Set<Int>
    let highlightedNumber: Int?
    let cellSize: CGFloat
    let theme: SudokuTheme

    public init(notes: Set<Int>, highlightedNumber: Int?, cellSize: CGFloat, theme: SudokuTheme) {
        self.notes = notes
        self.highlightedNumber = highlightedNumber
        self.cellSize = cellSize
        self.theme = theme
    }

    public var body: some View {
        // Each slot is sized off the parent cell rather than off the font's intrinsic
        // height — a fixed font makes this grid taller than the cell on small screens,
        // which pushes the bottom row of notes outside the cell's gridlines.
        let slot = cellSize / 3

        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { col in
                        let num = row * 3 + col + 1
                        let hasNote = notes.contains(num)
                        let isHighlighted = highlightedNumber == num && hasNote
                        Text(hasNote ? "\(num)" : "")
                            .font(.system(size: slot * 0.72, weight: isHighlighted ? .bold : .medium))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .foregroundColor(isHighlighted ? theme.enteredDigit : theme.noteDigit)
                            .frame(width: slot, height: slot)
                            .background(isHighlighted ? theme.noteHighlight : Color.clear)
                            .cornerRadius(3)
                    }
                }
            }
        }
        .frame(width: cellSize, height: cellSize)
    }
}
