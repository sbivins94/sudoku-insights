import SwiftUI

public struct DifficultyGridView: View {
    @ObservedObject var viewModel: SharedAppViewModel

    public init(viewModel: SharedAppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let theme = viewModel.theme
        let colors = theme.difficultyColors

        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(Array(Difficulty.allCases.enumerated()), id: \.element) { index, difficulty in
                DifficultyCard(
                    difficulty: difficulty,
                    color: colors[min(index, colors.count - 1)],
                    viewModel: viewModel
                )
            }
        }
        .frame(maxWidth: 760)
    }
}

public struct DifficultyCard: View {
    let difficulty: Difficulty
    let color: Color
    @ObservedObject var viewModel: SharedAppViewModel

    public init(difficulty: Difficulty, color: Color, viewModel: SharedAppViewModel) {
        self.difficulty = difficulty
        self.color = color
        self.viewModel = viewModel
    }

    private var clueDescription: String {
        let range = SudokuEngine.clueRange(for: difficulty)
        return "\(range.lowerBound)-\(range.upperBound) clues"
    }

    public var body: some View {
        let theme = viewModel.theme

        Button(action: {
            viewModel.startNewGame(difficulty: difficulty)
        }) {
            VStack(spacing: 6) {
                Text(difficulty.rawValue.uppercased())
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(theme.primaryText)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(clueDescription)
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)

                Divider()
                    .background(theme.cellBorder)
                    .padding(.horizontal, 4)

                VStack(spacing: 3) {
                    statRow("Best", viewModel.bestTimeForDifficulty(difficulty), theme: theme)
                    statRow("Avg", viewModel.averageTimeForDifficulty(difficulty), theme: theme)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(theme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }

    private func statRow(_ label: String, _ value: String, theme: SudokuTheme) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(theme.primaryText)
        }
    }
}
