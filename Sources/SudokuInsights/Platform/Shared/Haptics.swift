import Foundation
#if os(iOS)
import UIKit
#endif

/// Cross-platform wrapper so gameplay code can ask for feedback without caring which
/// platform it's on — on macOS every call is a no-op.
public enum Haptics {
    /// A single light tap, used when an entered digit turns out to be wrong.
    @MainActor
    public static func mistake() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
}
