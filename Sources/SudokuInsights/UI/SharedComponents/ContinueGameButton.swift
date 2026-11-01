import SwiftUI

public struct ContinueGameButton: View {
    let savedGame: SavedGameState
    let theme: SudokuTheme
    let action: () -> Void

    public init(savedGame: SavedGameState, theme: SudokuTheme, action: @escaping () -> Void) {
        self.savedGame = savedGame
        self.theme = theme
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
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
                            .foregroundColor(theme.errorDigit)
                    }
                }
                .foregroundColor(theme.secondaryText)
            }
            .foregroundColor(theme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(theme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.accent, lineWidth: 2)
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
