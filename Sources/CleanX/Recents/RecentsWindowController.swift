import AppKit
import SwiftUI

@MainActor
final class RecentsWindowController {
    static let shared = RecentsWindowController()

    private var panel: NSPanel?

    func toggle() {
        if let p = panel, p.isVisible {
            close()
        } else {
            open()
        }
    }

    func open() {
        if let p = panel {
            p.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        guard let screen = NSScreen.main else { return }

        let size = NSSize(width: 880, height: 320)
        let origin = NSPoint(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.minY + 80
        )
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Recent Captures"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        // Window-drag enabled, but DraggableImageNSView returns
        // mouseDownCanMoveWindow=false so tile drags are real drag sessions,
        // not window moves. Header/gaps still move the window.
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        panel.contentView = NSHostingView(rootView: RecentsView(
            store: RecentsStore.shared,
            onOpen: { [weak self] entry in self?.openInEditor(entry) },
            onClose: { [weak self] in self?.close() }
        ))
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func openInEditor(_ entry: RecentsStore.Entry) {
        guard let image = RecentsStore.shared.image(for: entry) else { NSSound.beep(); return }
        EditorWindowController.open(image: image, sourceRect: entry.sourceRect)
    }
}
