import AppKit
import ScreenCaptureKit

struct WindowPickResult {
    let window: SCWindow
}

@MainActor
final class WindowPickerOverlay {

    private let snapshots: [DisplaySnapshot]
    private let windows: [SCWindow]
    private let completion: (WindowPickResult?) -> Void
    private var panels: [(NSWindow, WindowPickerView)] = []
    private var finished = false

    init(snapshots: [DisplaySnapshot], windows: [SCWindow], completion: @escaping (WindowPickResult?) -> Void) {
        self.snapshots = snapshots
        self.windows = windows
        self.completion = completion
    }

    func present() {
        for snap in snapshots {
            let candidates = windows.filter { w in
                w.frame.intersects(snap.display.frame)
            }
            let view = WindowPickerView(snapshot: snap, windows: candidates)
            view.onPick = { [weak self] win in self?.commit(window: win) }
            view.onCancel = { [weak self] in self?.cancel() }
            let panel = NSPanel(contentRect: snap.nsScreen.frame,
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered,
                                defer: false,
                                screen: snap.nsScreen)
            panel.contentView = view
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            panel.ignoresMouseEvents = false
            panel.acceptsMouseMovedEvents = true
            panels.append((panel, view))
        }
        for (p, _) in panels { p.makeKeyAndOrderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func commit(window: SCWindow) {
        guard !finished else { return }
        finished = true
        teardown()
        completion(WindowPickResult(window: window))
    }

    private func cancel() {
        guard !finished else { return }
        finished = true
        teardown()
        completion(nil)
    }

    private func teardown() {
        for (p, _) in panels { p.orderOut(nil) }
        panels.removeAll()
    }
}

final class WindowPickerView: NSView {
    let snapshot: DisplaySnapshot
    let windows: [SCWindow]
    var onPick: ((SCWindow) -> Void)?
    var onCancel: (() -> Void)?

    private var hoveredWindow: SCWindow?
    private let backdrop: NSImage

    init(snapshot: DisplaySnapshot, windows: [SCWindow]) {
        self.snapshot = snapshot
        self.windows = windows
        self.backdrop = NSImage(cgImage: snapshot.image, size: snapshot.nsScreen.frame.size)
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        NSCursor.pointingHand.push()
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseMoved, .inVisibleRect], owner: self, userInfo: nil))
    }

    override func draw(_ dirtyRect: NSRect) {
        backdrop.draw(in: bounds, from: .zero, operation: .copy, fraction: 1.0)
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()

        guard let hovered = hoveredWindow, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let local = localRect(forWindowFrame: hovered.frame)
        ctx.setBlendMode(.copy)
        backdrop.draw(in: local, from: local, operation: .copy, fraction: 1.0)
        ctx.setBlendMode(.normal)
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: local.integral)
        path.lineWidth = 2
        path.stroke()
    }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let global = CGPoint(x: snapshot.nsScreen.frame.minX + p.x,
                             y: snapshot.nsScreen.frame.minY + p.y)
        hoveredWindow = topmostWindow(at: global)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.pop()
        if let w = hoveredWindow { onPick?(w) } else { onCancel?() }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            NSCursor.pop()
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    private func topmostWindow(at globalPoint: CGPoint) -> SCWindow? {
        // SCWindow.frame uses top-left origin in global display coords.
        // NSScreen origin is bottom-left of the primary screen.
        // Convert globalPoint (NSScreen bottom-left coords) to SCWindow frame coords.
        guard let mainScreen = NSScreen.screens.first else { return nil }
        let topLeftY = mainScreen.frame.height - globalPoint.y
        let pt = CGPoint(x: globalPoint.x, y: topLeftY)
        // windows from SCShareableContent are ordered front-to-back per Apple docs.
        return windows.first { $0.frame.contains(pt) }
    }

    private func localRect(forWindowFrame frame: CGRect) -> CGRect {
        guard let mainScreen = NSScreen.screens.first else { return .zero }
        let bottomLeftY = mainScreen.frame.height - frame.origin.y - frame.height
        let global = CGRect(x: frame.origin.x, y: bottomLeftY, width: frame.width, height: frame.height)
        return CGRect(
            x: global.origin.x - snapshot.nsScreen.frame.origin.x,
            y: global.origin.y - snapshot.nsScreen.frame.origin.y,
            width: global.width,
            height: global.height
        )
    }
}
