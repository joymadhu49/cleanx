import AppKit
import ScreenCaptureKit

struct DisplayInfo {
    let scDisplay: SCDisplay
    let nsScreen: NSScreen
}

enum DisplayEnumerator {
    static func map(content: SCShareableContent) -> [DisplayInfo] {
        content.displays.compactMap { d in
            guard let screen = NSScreen.screens.first(where: { $0.scDisplayID == d.displayID }) else { return nil }
            return DisplayInfo(scDisplay: d, nsScreen: screen)
        }
    }
}
