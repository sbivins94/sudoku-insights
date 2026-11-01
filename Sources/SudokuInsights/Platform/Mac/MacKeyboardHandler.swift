#if os(macOS)
import SwiftUI
import AppKit

public extension View {
    /// Captures physical keyboard input on macOS for Sudoku gameplay shortcuts
    /// (digit keys, "n" for notes, delete/backspace). No-op on other platforms.
    func onMacKeyboardInput(
        isSelectionActive: @escaping () -> Bool,
        onNumber: @escaping (Int) -> Void,
        onToggleNotes: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        self.onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard isSelectionActive() else { return event }

                if let chars = event.charactersIgnoringModifiers,
                   let char = chars.first,
                   let num = Int(String(char)),
                   (1...9).contains(num) {
                    onNumber(num)
                    return event
                }

                if event.charactersIgnoringModifiers?.lowercased() == "n" {
                    onToggleNotes()
                    return event
                }

                if event.keyCode == 51 || event.keyCode == 117 {
                    onDelete()
                    return event
                }

                return event
            }
        }
    }
}
#endif
