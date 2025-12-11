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
    ],
    dependencies: [
        .package(url: "https://github.com/jphong1111/SwiftSudokuSolver.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SudokuInsights",
            dependencies: [
                .product(name: "SwiftSudokuSolver", package: "SwiftSudokuSolver")
            ],
            path: "Sources/SudokuInsights"
        ),
        .testTarget(
            name: "SudokuInsightsTests",
            dependencies: ["SudokuInsights"],
            path: "Tests/SudokuInsightsTests"
        ),
    ]
)
