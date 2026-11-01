# iOS Shared UI Refactor Plan

## Goal

Refactor the project so the polished Sudoku UI is implemented once in the shared `SudokuInsights` package and then hosted by both:

- the macOS executable target in `Sources/SudokuInsightsApp`
- the iPhone app in `SudokuInsightsiOS`

This removes the temporary duplicate iPhone UI and lets both platforms render the same gameplay experience with small platform-specific adapters.

## Current Problem

Today, the most complete UI lives inside `Sources/SudokuInsightsApp/main.swift`, which is the macOS executable target. That file contains two kinds of code mixed together:

1. **Shared SwiftUI/game logic** that should move into the package
2. **macOS-only wiring** that must stay in the macOS host target

Because these concerns are mixed in one file, the iPhone target cannot directly reuse the existing UI.

## High-Level Strategy

1. Extract shared UI + shared view model types from `Sources/SudokuInsightsApp/main.swift` into the `SudokuInsights` library target
2. Leave only thin app-host wrappers in the macOS and iOS app targets
3. Isolate platform-specific behavior behind tiny adapters or conditional compilation
4. Point both app targets at the same shared root view

## Project Structure Delta

### Current

```text
Sources/
  SudokuInsights/
    Core/
    Services/
    UI/
      GameBoard/
        GameBoardView.swift
  SudokuInsightsApp/
    main.swift   # contains app entry + shared UI + shared view model + macOS-only code
SudokuInsightsiOS/
  SudokuInsightsiOS/
    ContentView.swift  # placeholder host UI
    SudokuInsightsiOSApp.swift
```

### Target (feature-only grouping)

```text
Sources/
  SudokuInsights/
    UI/
      Landing/
        SharedRootView.swift
        LandingPageView.swift
      GameBoard/
        SharedAppViewModel.swift
        SavedGameState.swift
        GameBoardContentView.swift
        CellView.swift
        NotesGridView.swift
      Overlays/
        GameCompleteOverlay.swift
        ConfettiView.swift
      SharedComponents/
        DifficultyGridView.swift
        DifficultyCard.swift
        ContinueGameButton.swift
    Platform/
      Mac/
        MacKeyboardHandler.swift    # only if needed
      Shared/
        PlatformColors.swift        # optional helper for cross-platform colors
  SudokuInsightsApp/
    main.swift                      # macOS app entry only
SudokuInsightsiOS/
  SudokuInsightsiOS/
    ContentView.swift               # thin host using SharedRootView
    SudokuInsightsiOSApp.swift
```

## Confirmed Decisions

These decisions are now locked for implementation:

1. Shared files are grouped by feature (no separate `App/` folder)
2. iPhone layout should mirror macOS closely in the first iteration
3. First refactor includes `GameCompleteOverlay`, but excludes dashboard/report placeholders

## What Moves Into the Shared Package

The following types in `Sources/SudokuInsightsApp/main.swift` are strong candidates to move into `Sources/SudokuInsights/`:

- `SavedGameState`
- `ContentView` (rename to `SharedRootView` to avoid app-host naming confusion)
- `AppViewModel` (rename to `SharedAppViewModel`)
- `LandingPageView`
- `ContinueGameButton`
- `DifficultyGridView`
- `DifficultyCard`
- `GameBoardContentView`
- `CellView`
- `NotesGridView`
- `ConfettiPiece`
- `ConfettiView`
- `GameCompleteOverlay`
- `StatsDashboardContentView` and report placeholders, if still needed

## What Stays in the macOS Host Target

These remain in `Sources/SudokuInsightsApp/main.swift` or nearby mac-only files:

- `@main struct SudokuInsightsApp: App`
- `@NSApplicationDelegateAdaptor(AppDelegate.self)`
- `AppDelegate`
- `.windowStyle(.automatic)`
- `.defaultSize(width: 800, height: 900)`
- any keyboard event bridge implemented with `NSEvent`
- any `AppKit` imports

## What Stays in the iOS Host Target

These remain in `SudokuInsightsiOS/SudokuInsightsiOS/`:

- `@main struct SudokuInsightsiOSApp: App`
- a tiny `ContentView` that just renders `SharedRootView()`
- any future iOS-only app capabilities, permissions, or UIKit bridges

## Platform Branching: Exact Places

The main `if mac` / `if iPhone` branching should be limited to a few narrow spots.

### 1. App bootstrap

**macOS only**

- file: `Sources/SudokuInsightsApp/main.swift`
- use `AppKit`
- set window behavior
- register mac app delegate

Example shape:

```swift
#if os(macOS)
import AppKit
#endif
```

### 2. Keyboard handling

Current macOS code uses `NSEvent.addLocalMonitorForEvents` and `handleKeyDown(_ event: NSEvent)`.

This must not live inside shared iOS UI directly.

Recommended approach:

- keep the shared game board tap/selection/value APIs in the shared view model
- add a mac-only view modifier or helper that converts `NSEvent` into calls like:
  - `viewModel.handleKeyPress(_:)`
  - `viewModel.handleDelete()`
  - `viewModel.isNoteTakingMode.toggle()`

Branch point:

```swift
#if os(macOS)
// attach NSEvent keyboard monitor
#endif
```

### 3. Platform colors

Current macOS overlay uses `Color(NSColor.windowBackgroundColor)`.

Recommended options:

- prefer platform-neutral SwiftUI colors where acceptable
- or isolate in a helper:

```swift
#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#elseif os(iOS)
import UIKit
typealias PlatformColor = UIColor
#endif
```

Then expose shared color helpers from one place.

### 4. Layout tuning, not logic

Some spacing, typography, and board sizing may need platform tweaks, but this should be lightweight and local.

Branch point examples:

```swift
#if os(iOS)
// tighter spacing, touch-first layout
#elseif os(macOS)
// roomier desktop layout
#endif
```

Use this only where necessary; keep gameplay logic shared.

## Refactor Phases

### Phase 1 — Extract shared root and state

- Move `SavedGameState` and `AppViewModel` into the package
- Rename `ContentView` to `SharedRootView`
- Ensure persistence and timer logic compile in the library target
- Keep public/internal visibility minimal

### Phase 2 — Extract shared view hierarchy

- Move landing page, board, overlay, and helper views into package files
- Keep the UI decomposition close to current structure, not a big redesign
- Preserve existing styling and behavior from the macOS app

### Phase 3 — Isolate mac-only behavior

- Move AppKit imports and app delegate code into mac-only host files
- Extract `NSEvent` keyboard logic into a mac-only adapter
- Replace direct `NSColor` usage with shared helper or SwiftUI-native colors

### Phase 4 — Rewire both hosts

- macOS host renders `SharedRootView()`
- iOS host renders `SharedRootView()`
- Remove any remaining duplicate iOS stopgap code

### Phase 5 — Validate both platforms

- Build package with `swift build`
- Build/run macOS target in Xcode
- Build/run iOS target in Xcode on device/simulator
- Check landing page, timer, board rendering, thick borders, notes mode, overlays

## Risks / Watchouts

- `ObservableObject` and persistence code may need access-level cleanup when moved into package
- mac keyboard shortcuts should not be embedded in shared iOS views
- some desktop-specific layout assumptions may feel cramped on iPhone and need responsive layout adjustments
- moving many view types out of `main.swift` is mechanical but large; doing it incrementally reduces breakage

## Recommended First Implementation Slice (updated)

To reduce risk, start with this minimal vertical slice:

1. Create `SharedRootView` and `SharedAppViewModel` in the package
2. Move `LandingPageView`, `GameBoardContentView`, and `GameCompleteOverlay` into the package with minimal changes
3. Mirror macOS layout on iPhone first; defer touch-specific layout improvements
4. Rewire macOS and iOS hosts to use `SharedRootView`

This gets the real Sudoku experience onto iPhone quickly without requiring the entire file to be perfectly reorganized in one pass.

## iOS Folder Naming Cleanup

Current structure:

```text
SudokuInsightsiOS/                # project container folder
  SudokuInsightsiOS.xcodeproj
  SudokuInsightsiOS/              # target source folder
```

Why it appears duplicated: this is Xcode's default layout (outer project folder + inner target-source folder with same name).

Safe cleanup option (recommended): keep the outer folder, rename only the inner source folder to `AppHost`:

```text
SudokuInsightsiOS/
  SudokuInsightsiOS.xcodeproj
  AppHost/
    ContentView.swift
    SudokuInsightsiOSApp.swift
    Assets.xcassets/
```

This removes visual duplication without changing product name, bundle id, or scheme names.

## Review Questions

Before implementation, confirm:

1. Should the iOS inner source folder be renamed to `AppHost` in this same refactor pass?
