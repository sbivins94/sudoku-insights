import SwiftUI

public struct ThemePickerView: View {
    @ObservedObject var viewModel: SharedAppViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: SharedAppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let theme = viewModel.theme

        ZStack {
            theme.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Theme")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)
                    Spacer()
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.accent)
                        .fontWeight(.semibold)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(SudokuTheme.all) { option in
                            Button {
                                viewModel.theme = option
                            } label: {
                                ThemeRow(option: option, isSelected: option.id == theme.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

private struct ThemeRow: View {
    let option: SudokuTheme
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            MiniBoardPreview(theme: option)

            VStack(alignment: .leading, spacing: 3) {
                Text(option.name)
                    .font(.headline)
                    .foregroundColor(option.primaryText)
                Text(option.blurb)
                    .font(.caption)
                    .foregroundColor(option.secondaryText)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(option.accent)
            }
        }
        .padding(12)
        .background(option.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? option.accent : option.cellBorder, lineWidth: isSelected ? 3 : 1)
        )
    }
}

/// A 3x3 sketch of the board so each theme shows its actual cell, highlight and
/// gridline colors rather than a row of abstract swatches.
private struct MiniBoardPreview: View {
    let theme: SudokuTheme

    private let slot: CGFloat = 16

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { col in
                            ZStack {
                                background(row: row, col: col)
                                Text(digit(row: row, col: col))
                                    .font(.system(size: slot * 0.62, weight: .bold))
                                    .foregroundColor(digitColor(row: row, col: col))
                            }
                            .frame(width: slot, height: slot)
                            .border(theme.cellBorder, width: 0.5)
                        }
                    }
                }
            }

            Rectangle()
                .fill(theme.boxLine)
                .frame(width: 2, height: slot * 3)
                .offset(x: slot / 2)
        }
        .padding(5)
        .background(theme.boardSurface)
        .cornerRadius(6)
    }

    private func background(row: Int, col: Int) -> Color {
        if row == 1 && col == 1 { return theme.selectedCell }
        if row == 1 || col == 1 { return theme.peerHighlight }
        if row == 0 && col == 2 { return theme.sameNumberHighlight }
        return theme.cellBackground
    }

    private func digit(row: Int, col: Int) -> String {
        let grid = [["5", "", "3"], ["", "7", ""], ["1", "", "9"]]
        return grid[row][col]
    }

    private func digitColor(row: Int, col: Int) -> Color {
        (row + col) % 2 == 0 ? theme.givenDigit : theme.enteredDigit
    }
}
