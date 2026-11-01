import SwiftUI

public struct GameCompleteOverlay: View {
    @ObservedObject var viewModel: SharedAppViewModel

    private var theme: SudokuTheme { viewModel.theme }
    @State private var showStats = false

    public init(viewModel: SharedAppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {}

            ConfettiView()

            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 60))

                Text("Puzzle Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(theme.controlForeground)

                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(theme.enteredDigit)
                            .frame(width: 20)
                        Text("Time")
                            .foregroundColor(theme.secondaryText)
                            .frame(maxWidth: 60, alignment: .leading)
                        Spacer()
                        Text(viewModel.formattedTime)
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundColor(theme.primaryText)
                    }
                    .padding(.bottom, 8)

                    Divider()

                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.errorDigit)
                            .frame(width: 20)
                        Text("Mistakes")
                            .foregroundColor(theme.secondaryText)
                            .frame(maxWidth: 60, alignment: .leading)
                        Spacer()
                        Text("\(viewModel.errorCount)")
                            .font(.headline)
                            .foregroundColor(theme.primaryText)
                    }
                    .padding(.vertical, 8)

                    Divider()

                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        Text("Avg Time")
                            .foregroundColor(theme.secondaryText)
                            .frame(maxWidth: 60, alignment: .leading)
                        Spacer()
                        if let avg = viewModel.averageTimeForDifficultyValue(viewModel.currentDifficulty) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(viewModel.formattedTimeInterval(avg))
                                    .font(.headline)
                                    .monospacedDigit()
                                    .foregroundColor(theme.primaryText)
                                let diff = viewModel.elapsedTime - avg
                                if diff < 0 {
                                    Text("\(viewModel.formattedTimeInterval(abs(diff))) faster")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else if diff > 0 {
                                    Text("\(viewModel.formattedTimeInterval(diff)) slower")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else {
                                    Text("Right on average!")
                                        .font(.caption)
                                        .foregroundColor(theme.enteredDigit)
                                }
                            }
                        } else {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("First game!")
                                    .font(.headline)
                                    .foregroundColor(theme.secondaryText)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(theme.appBackground.opacity(0.5))
                .cornerRadius(12)

                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.returnToMenu()
                    }) {
                        Text("Back to Menu")
                            .font(.headline)
                            .foregroundColor(theme.controlForeground)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(theme.controlBackground)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.startNewGame(difficulty: viewModel.currentDifficulty)
                    }) {
                        Text("New Game")
                            .font(.headline)
                            .foregroundColor(theme.controlForeground)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 10)
                            .background(theme.accent)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
            .frame(width: 380)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardBackground)
                    .shadow(radius: 20)
            )
            .scaleEffect(showStats ? 1.0 : 0.8)
            .opacity(showStats ? 1.0 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showStats)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showStats = true
                }
            }
        }
    }
}
