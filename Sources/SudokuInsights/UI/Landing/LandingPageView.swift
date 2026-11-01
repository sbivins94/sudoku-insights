import SwiftUI

public struct LandingPageView: View {
    @ObservedObject var viewModel: SharedAppViewModel
    @State private var showThemePicker = false

    public init(viewModel: SharedAppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let theme = viewModel.theme

        ZStack {
            theme.appBackground
                .ignoresSafeArea()

            // Scrolls rather than centering a fixed stack: with the continue button and
            // the insights panel the content is taller than a phone screen, and an
            // overflowing VStack pushes its top edge up under the status bar.
            ScrollView {
                VStack(spacing: 18) {
                    header(theme: theme)

                    if let savedGame = viewModel.loadGameState() {
                        ContinueGameButton(savedGame: savedGame, theme: theme) {
                            viewModel.continueLastGame()
                        }
                    }

                    DifficultyGridView(viewModel: viewModel)

                    InsightsPanelView(history: viewModel.history, theme: theme)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }

            if viewModel.isGeneratingPuzzle {
                theme.appBackground.opacity(0.75)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    ProgressView()
                    Text("Building puzzle…")
                        .font(.headline)
                        .foregroundColor(theme.primaryText)
                }
                .padding(28)
                .background(theme.cardBackground)
                .cornerRadius(14)
            }
        }
        .sheet(isPresented: $showThemePicker) {
            ThemePickerView(viewModel: viewModel)
        }
    }

    private func header(theme: SudokuTheme) -> some View {
        HStack(alignment: .center) {
            Text("SUDOKU INSIGHTS")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(theme.primaryText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Spacer()

            Button(action: { showThemePicker = true }) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 17))
                    .foregroundColor(theme.controlForeground)
                    .padding(9)
                    .background(theme.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}
