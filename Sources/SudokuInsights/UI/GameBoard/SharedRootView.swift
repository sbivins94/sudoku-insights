import SwiftUI

/// Cross-platform root view hosting the full Sudoku Insights gameplay experience.
public struct SharedRootView: View {
    @StateObject private var viewModel = SharedAppViewModel()

    public init() {}

    public var body: some View {
        Group {
            if viewModel.showLandingPage {
                LandingPageView(viewModel: viewModel)
            } else {
                GameBoardContentView(viewModel: viewModel)
            }
        }
        // Every surface paints an explicit theme color, so match the system chrome
        // (sheets, the status bar) to the chosen theme rather than pinning to light.
        .preferredColorScheme(viewModel.theme.isDark ? .dark : .light)
        .environment(\.sudokuTheme, viewModel.theme)
    }
}
