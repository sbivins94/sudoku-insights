import XCTest
@testable import SudokuInsights

/// The generator used to dig clues at random with no uniqueness check, which produced
/// puzzles with many valid solutions — the app marked correct deductions as mistakes
/// because they disagreed with the one stored solution. These lock that behaviour down.
final class PuzzleGenerationTests: XCTestCase {
    private let samplesPerDifficulty = 3

    func testEveryPuzzleHasExactlyOneSolution() {
        for difficulty in Difficulty.allCases {
            for _ in 0..<samplesPerDifficulty {
                let puzzle = SudokuEngine.generatePuzzle(difficulty: difficulty)
                var solver = SudokuSolver(puzzle.initialGrid)
                XCTAssertEqual(
                    solver.countSolutions(cap: 2), 1,
                    "\(difficulty.rawValue) puzzle does not have a unique solution"
                )
            }
        }
    }

    func testEveryPuzzleIsSolvableWithoutGuessing() {
        for difficulty in Difficulty.allCases {
            for _ in 0..<samplesPerDifficulty {
                let puzzle = SudokuEngine.generatePuzzle(difficulty: difficulty)
                XCTAssertNotNil(
                    LogicalSolver.hardestTechnique(for: puzzle.initialGrid),
                    "\(difficulty.rawValue) puzzle cannot be finished by logic alone"
                )
            }
        }
    }

    func testClueCountsMatchTheAdvertisedRange() {
        for difficulty in Difficulty.allCases {
            let range = SudokuEngine.clueRange(for: difficulty)
            for _ in 0..<samplesPerDifficulty {
                let puzzle = SudokuEngine.generatePuzzle(difficulty: difficulty)
                let clues = puzzle.initialGrid.flatMap { $0 }.filter { $0 != 0 }.count
                XCTAssertTrue(
                    range.contains(clues),
                    "\(difficulty.rawValue) gave \(clues) clues, outside \(range)"
                )
            }
        }
    }

    func testExpertSitsInTheExtremeClueBand() {
        // Matches what sudoku.com hands out for "Extreme".
        XCTAssertEqual(SudokuEngine.clueRange(for: .expert), 24...28)
    }

    func testExpertPuzzlesNeedMoreThanSingles() {
        var neededAdvancedTechnique = 0
        for _ in 0..<samplesPerDifficulty {
            let puzzle = SudokuEngine.generatePuzzle(difficulty: .expert)
            if let technique = LogicalSolver.hardestTechnique(for: puzzle.initialGrid),
               technique > .singles {
                neededAdvancedTechnique += 1
            }
        }
        XCTAssertEqual(
            neededAdvancedTechnique, samplesPerDifficulty,
            "expert puzzles should require more than naked/hidden singles"
        )
    }

    func testSolutionAgreesWithThePuzzlesOnlySolution() {
        for difficulty in Difficulty.allCases {
            let puzzle = SudokuEngine.generatePuzzle(difficulty: difficulty)

            for row in 0..<9 {
                for col in 0..<9 where puzzle.initialGrid[row][col] != 0 {
                    XCTAssertEqual(puzzle.initialGrid[row][col], puzzle.solution[row][col])
                }
            }

            var solver = SudokuSolver(puzzle.initialGrid)
            XCTAssertEqual(solver.countSolutions(cap: 2), 1)
            XCTAssertTrue(SudokuEngine.isComplete(puzzle.solution))
        }
    }
}
