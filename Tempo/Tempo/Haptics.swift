import UIKit

/// Small, reliable haptic helpers for rewarding moments (saving, filling a gap). Fires
/// immediately regardless of view lifecycle, so it works even when the action dismisses
/// a sheet in the same call.
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
