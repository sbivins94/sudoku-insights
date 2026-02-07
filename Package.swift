// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SudokuInsights",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SudokuInsights",
            targets: ["SudokuInsights"]
        ),
        .executable(
            name: "SudokuInsightsApp",
            targets: ["SudokuInsightsApp"]
        ),
    ],
    dependencies: [
        // Temporarily removed SwiftSudokuSolver - repository doesn't exist
        // .package(url: "https://github.com/jphong1111/SwiftSudokuSolver.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SudokuInsights",
            dependencies: [
                // .product(name: "SwiftSudokuSolver", package: "SwiftSudokuSolver")
            ],
            path: "Sources/SudokuInsights"
        ),
        .executableTarget(
            name: "SudokuInsightsApp",
            dependencies: ["SudokuInsights"],
            path: "Sources/SudokuInsightsApp"
        ),
        .testTarget(
            name: "SudokuInsightsTests",
            dependencies: ["SudokuInsights"],
            path: "Tests/SudokuInsightsTests"
        ),
    ]
)
