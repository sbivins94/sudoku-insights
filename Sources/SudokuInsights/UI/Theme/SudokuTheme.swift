import SwiftUI

/// Every color the board and landing page draw with. Views read these instead of
/// hardcoding, so a theme swap repaints the whole app consistently.
public struct SudokuTheme: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let blurb: String
    public let isDark: Bool

    // Surfaces
    public let appBackground: Color
    public let boardSurface: Color
    public let cardBackground: Color

    // Cells
    public let cellBackground: Color
    public let selectedCell: Color
    public let peerHighlight: Color
    public let sameNumberHighlight: Color

    // Digits
    public let givenDigit: Color
    public let enteredDigit: Color
    public let errorDigit: Color
    public let noteDigit: Color
    public let noteHighlight: Color

    // Lines
    public let boxLine: Color
    public let cellBorder: Color

    // Chrome
    public let primaryText: Color
    public let secondaryText: Color
    public let accent: Color
    public let controlBackground: Color
    public let controlForeground: Color
    public let difficultyColors: [Color]

    public static func == (lhs: SudokuTheme, rhs: SudokuTheme) -> Bool { lhs.id == rhs.id }
}

public extension SudokuTheme {
    static let classic = SudokuTheme(
        id: "classic",
        name: "Classic",
        blurb: "Newsprint cream",
        isDark: false,
        appBackground: Color(red: 0.96, green: 0.95, blue: 0.90),
        boardSurface: Color(red: 0.87, green: 0.86, blue: 0.83),
        cardBackground: .white,
        cellBackground: .white,
        selectedCell: Color(red: 0.62, green: 0.80, blue: 0.98),
        peerHighlight: Color(red: 0.96, green: 0.95, blue: 0.90),
        sameNumberHighlight: Color(red: 0.90, green: 0.85, blue: 0.62),
        givenDigit: Color(red: 0.15, green: 0.18, blue: 0.22),
        enteredDigit: Color(red: 0.05, green: 0.45, blue: 0.95),
        errorDigit: Color(red: 0.85, green: 0.20, blue: 0.20),
        noteDigit: Color(red: 0.45, green: 0.47, blue: 0.50),
        noteHighlight: Color(red: 0.95, green: 0.85, blue: 0.40),
        boxLine: .black,
        cellBorder: Color.gray.opacity(0.4),
        primaryText: Color(red: 0.15, green: 0.18, blue: 0.22),
        secondaryText: Color(red: 0.35, green: 0.38, blue: 0.42),
        accent: Color(red: 0.05, green: 0.45, blue: 0.95),
        controlBackground: Color(red: 0.80, green: 0.79, blue: 0.76),
        controlForeground: .white,
        difficultyColors: [.green, .blue, .orange, .red]
    )

    /// Mirrors VS Code's Dark High Contrast: near-black ground, pure white rules,
    /// and the editor's signature cyan//amber accents.
    static let vsCodeHighContrast = SudokuTheme(
        id: "vscode-hc",
        name: "VS Code High Contrast",
        blurb: "Pure black, neon rules",
        isDark: true,
        appBackground: .black,
        boardSurface: Color(red: 0.08, green: 0.08, blue: 0.08),
        cardBackground: Color(red: 0.10, green: 0.10, blue: 0.10),
        cellBackground: Color(red: 0.04, green: 0.04, blue: 0.04),
        selectedCell: Color(red: 0.00, green: 0.45, blue: 0.55),
        peerHighlight: Color(red: 0.14, green: 0.14, blue: 0.16),
        sameNumberHighlight: Color(red: 0.30, green: 0.26, blue: 0.00),
        givenDigit: .white,
        enteredDigit: Color(red: 0.22, green: 0.90, blue: 0.94),
        errorDigit: Color(red: 1.00, green: 0.33, blue: 0.33),
        noteDigit: Color(red: 0.60, green: 0.62, blue: 0.64),
        noteHighlight: Color(red: 0.55, green: 0.47, blue: 0.00),
        boxLine: .white,
        cellBorder: Color.white.opacity(0.35),
        primaryText: .white,
        secondaryText: Color(red: 0.70, green: 0.72, blue: 0.74),
        accent: Color(red: 0.22, green: 0.90, blue: 0.94),
        controlBackground: Color(red: 0.18, green: 0.18, blue: 0.20),
        controlForeground: .white,
        difficultyColors: [
            Color(red: 0.30, green: 0.90, blue: 0.40),
            Color(red: 0.22, green: 0.90, blue: 0.94),
            Color(red: 0.95, green: 0.70, blue: 0.20),
            Color(red: 1.00, green: 0.33, blue: 0.33)
        ]
    )

    /// Midnight green and silver, straight off the helmet.
    static let eagles = SudokuTheme(
        id: "eagles",
        name: "Philadelphia Eagles",
        blurb: "Midnight green & silver",
        isDark: true,
        appBackground: Color(red: 0.00, green: 0.14, blue: 0.16),
        boardSurface: Color(red: 0.00, green: 0.22, blue: 0.25),
        cardBackground: Color(red: 0.00, green: 0.20, blue: 0.23),
        cellBackground: Color(red: 0.02, green: 0.11, blue: 0.13),
        // Selection is vivid green rather than helmet silver: notes are a pale gray and
        // silver-on-silver left them unreadable in the selected cell.
        selectedCell: Color(red: 0.00, green: 0.52, blue: 0.46),
        peerHighlight: Color(red: 0.00, green: 0.19, blue: 0.22),
        sameNumberHighlight: Color(red: 0.00, green: 0.31, blue: 0.34),
        givenDigit: Color(red: 0.85, green: 0.87, blue: 0.88),
        enteredDigit: Color(red: 0.65, green: 0.93, blue: 0.80),
        errorDigit: Color(red: 1.00, green: 0.45, blue: 0.45),
        noteDigit: Color(red: 0.76, green: 0.83, blue: 0.81),
        noteHighlight: Color(red: 0.00, green: 0.42, blue: 0.44),
        boxLine: Color(red: 0.65, green: 0.68, blue: 0.69),
        cellBorder: Color(red: 0.65, green: 0.68, blue: 0.69).opacity(0.28),
        primaryText: Color(red: 0.92, green: 0.94, blue: 0.94),
        secondaryText: Color(red: 0.62, green: 0.70, blue: 0.70),
        accent: Color(red: 0.00, green: 0.48, blue: 0.44),
        controlBackground: Color(red: 0.00, green: 0.28, blue: 0.31),
        controlForeground: .white,
        difficultyColors: [
            Color(red: 0.40, green: 0.85, blue: 0.65),
            Color(red: 0.65, green: 0.68, blue: 0.69),
            Color(red: 0.90, green: 0.75, blue: 0.35),
            Color(red: 1.00, green: 0.45, blue: 0.45)
        ]
    )

    /// Sixers red, white and blue on a clean court.
    static let sixers = SudokuTheme(
        id: "sixers",
        name: "Philadelphia 76ers",
        blurb: "Liberty red & blue",
        isDark: false,
        appBackground: Color(red: 0.94, green: 0.95, blue: 0.97),
        boardSurface: Color(red: 0.00, green: 0.42, blue: 0.71),
        cardBackground: .white,
        cellBackground: .white,
        selectedCell: Color(red: 0.55, green: 0.78, blue: 0.96),
        peerHighlight: Color(red: 0.90, green: 0.94, blue: 0.99),
        sameNumberHighlight: Color(red: 0.98, green: 0.80, blue: 0.84),
        givenDigit: Color(red: 0.04, green: 0.13, blue: 0.29),
        enteredDigit: Color(red: 0.00, green: 0.42, blue: 0.71),
        errorDigit: Color(red: 0.93, green: 0.09, blue: 0.30),
        noteDigit: Color(red: 0.45, green: 0.52, blue: 0.62),
        noteHighlight: Color(red: 0.98, green: 0.78, blue: 0.82),
        boxLine: Color(red: 0.04, green: 0.13, blue: 0.29),
        cellBorder: Color(red: 0.00, green: 0.42, blue: 0.71).opacity(0.30),
        primaryText: Color(red: 0.04, green: 0.13, blue: 0.29),
        secondaryText: Color(red: 0.35, green: 0.43, blue: 0.54),
        accent: Color(red: 0.93, green: 0.09, blue: 0.30),
        controlBackground: Color(red: 0.00, green: 0.42, blue: 0.71),
        controlForeground: .white,
        difficultyColors: [
            Color(red: 0.00, green: 0.62, blue: 0.42),
            Color(red: 0.00, green: 0.42, blue: 0.71),
            Color(red: 0.95, green: 0.55, blue: 0.10),
            Color(red: 0.93, green: 0.09, blue: 0.30)
        ]
    )

    /// Warm paper and ink for long sessions.
    static let sepia = SudokuTheme(
        id: "sepia",
        name: "Sepia",
        blurb: "Warm paper & ink",
        isDark: false,
        appBackground: Color(red: 0.93, green: 0.88, blue: 0.79),
        boardSurface: Color(red: 0.79, green: 0.72, blue: 0.61),
        cardBackground: Color(red: 0.98, green: 0.95, blue: 0.89),
        cellBackground: Color(red: 0.98, green: 0.95, blue: 0.89),
        selectedCell: Color(red: 0.83, green: 0.72, blue: 0.51),
        peerHighlight: Color(red: 0.91, green: 0.86, blue: 0.76),
        sameNumberHighlight: Color(red: 0.87, green: 0.78, blue: 0.58),
        givenDigit: Color(red: 0.24, green: 0.18, blue: 0.11),
        enteredDigit: Color(red: 0.58, green: 0.30, blue: 0.10),
        errorDigit: Color(red: 0.72, green: 0.15, blue: 0.12),
        noteDigit: Color(red: 0.52, green: 0.45, blue: 0.36),
        noteHighlight: Color(red: 0.88, green: 0.78, blue: 0.55),
        boxLine: Color(red: 0.30, green: 0.22, blue: 0.14),
        cellBorder: Color(red: 0.30, green: 0.22, blue: 0.14).opacity(0.30),
        primaryText: Color(red: 0.24, green: 0.18, blue: 0.11),
        secondaryText: Color(red: 0.45, green: 0.38, blue: 0.29),
        accent: Color(red: 0.58, green: 0.30, blue: 0.10),
        controlBackground: Color(red: 0.72, green: 0.64, blue: 0.52),
        controlForeground: .white,
        difficultyColors: [
            Color(red: 0.35, green: 0.52, blue: 0.28),
            Color(red: 0.30, green: 0.44, blue: 0.58),
            Color(red: 0.75, green: 0.48, blue: 0.15),
            Color(red: 0.72, green: 0.15, blue: 0.12)
        ]
    )

    /// Deep navy with electric accents.
    static let midnight = SudokuTheme(
        id: "midnight",
        name: "Midnight",
        blurb: "Deep navy, electric ink",
        isDark: true,
        appBackground: Color(red: 0.05, green: 0.07, blue: 0.13),
        boardSurface: Color(red: 0.10, green: 0.13, blue: 0.22),
        cardBackground: Color(red: 0.09, green: 0.12, blue: 0.20),
        cellBackground: Color(red: 0.07, green: 0.09, blue: 0.16),
        selectedCell: Color(red: 0.20, green: 0.35, blue: 0.65),
        peerHighlight: Color(red: 0.11, green: 0.15, blue: 0.26),
        sameNumberHighlight: Color(red: 0.25, green: 0.20, blue: 0.45),
        givenDigit: Color(red: 0.88, green: 0.91, blue: 0.96),
        enteredDigit: Color(red: 0.45, green: 0.78, blue: 1.00),
        errorDigit: Color(red: 1.00, green: 0.42, blue: 0.52),
        noteDigit: Color(red: 0.52, green: 0.57, blue: 0.68),
        noteHighlight: Color(red: 0.32, green: 0.26, blue: 0.55),
        boxLine: Color(red: 0.75, green: 0.80, blue: 0.92),
        cellBorder: Color(red: 0.75, green: 0.80, blue: 0.92).opacity(0.22),
        primaryText: Color(red: 0.90, green: 0.93, blue: 0.98),
        secondaryText: Color(red: 0.58, green: 0.64, blue: 0.76),
        accent: Color(red: 0.45, green: 0.78, blue: 1.00),
        controlBackground: Color(red: 0.16, green: 0.20, blue: 0.32),
        controlForeground: .white,
        difficultyColors: [
            Color(red: 0.35, green: 0.85, blue: 0.60),
            Color(red: 0.45, green: 0.78, blue: 1.00),
            Color(red: 0.95, green: 0.72, blue: 0.35),
            Color(red: 1.00, green: 0.42, blue: 0.52)
        ]
    )

    static let all: [SudokuTheme] = [.classic, .vsCodeHighContrast, .eagles, .sixers, .sepia, .midnight]

    static func theme(id: String) -> SudokuTheme {
        all.first { $0.id == id } ?? .classic
    }
}

private struct SudokuThemeKey: EnvironmentKey {
    static let defaultValue = SudokuTheme.classic
}

public extension EnvironmentValues {
    var sudokuTheme: SudokuTheme {
        get { self[SudokuThemeKey.self] }
        set { self[SudokuThemeKey.self] = newValue }
    }
}
