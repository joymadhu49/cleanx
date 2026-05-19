import AppKit
import ScreenCaptureKit

struct AreaCaptureResult {
    let image: CGImage
    let globalRect: CGRect
}

@MainActor
final class AreaSelectionOverlay {

    private let snapshots: [DisplaySnapshot]
    private var windows: [(NSWindow, AreaSelectionView)] = []
    private let completion: (AreaCaptureResult?) -> Void
    private var finished = false

    init(snapshots: [DisplaySnapshot], completion: @escaping (AreaCaptureResult?) -> Void) {
        self.snapshots = snapshots
        self.completion = completion
    }

    func present() {
        for snap in snapshots {
            let view = AreaSelectionView(snapshot: snap)
            view.onCommit = { [weak self] rect in self?.commit(view: view, rect: rect) }
            view.onCancel = { [weak self] in self?.cancel() }
            let window = NSPanel(contentRect: snap.nsScreen.frame,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false,
                                 screen: snap.nsScreen)
            window.contentView = view
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.hidesOnDeactivate = false
            window.isMovableByWindowBackground = false
            windows.append((window, view))
        }
        for (w, _) in windows {
            w.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func commit(view: AreaSelectionView, rect: CGRect) {
        guard !finished else { return }
        finished = true

        let snap = view.snapshot
        let screenFrame = snap.nsScreen.frame

        let pixelW = CGFloat(snap.image.width)
        let pixelH = CGFloat(snap.image.height)
        let sx = pixelW / screenFrame.width
        let sy = pixelH / screenFrame.height

        let localRectFlipped = CGRect(
            x: rect.origin.x * sx,
            y: (screenFrame.height - rect.origin.y - rect.height) * sy,
            width: rect.width * sx,
            height: rect.height * sy
        ).integral

        let cropped = snap.image.cropping(to: localRectFlipped)
        teardown()
        if let cropped {
            let globalRect = CGRect(
                x: screenFrame.origin.x + rect.origin.x,
                y: screenFrame.origin.y + rect.origin.y,
                width: rect.width,
                height: rect.height
            )
            completion(AreaCaptureResult(image: cropped, globalRect: globalRect))
        } else {
            completion(nil)
        }
    }

    private func cancel() {
        guard !finished else { return }
        finished = true
        teardown()
        completion(nil)
    }

    private func teardown() {
        for (w, _) in windows {
            w.orderOut(nil)
        }
        windows.removeAll()
    }
}

final class AreaSelectionView: NSView {
    let snapshot: DisplaySnapshot
    var onCommit: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentRect: CGRect = .zero
    private var backdrop: NSImage

    init(snapshot: DisplaySnapshot) {
        self.snapshot = snapshot
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
        NSCursor.crosshair.push()
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseMoved, .inVisibleRect], owner: self, userInfo: nil))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        backdrop.draw(in: bounds, from: .zero, operation: .copy, fraction: 1.0)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        ctx.fill(bounds)

        if currentRect != .zero {
            ctx.setBlendMode(.copy)
            let drawRect = currentRect
            let imgRect = CGRect(
                x: drawRect.origin.x,
                y: drawRect.origin.y,
                width: drawRect.width,
                height: drawRect.height
            )
            backdrop.draw(in: imgRect, from: imgRect, operation: .copy, fraction: 1.0)
            ctx.setBlendMode(.normal)

            ctx.setStrokeColor(NSColor.systemBlue.cgColor)
            ctx.setLineWidth(1.5)
            ctx.stroke(drawRect.integral)

            drawDimensionsHUD(rect: drawRect)
        }
        ctx.restoreGState()
    }

    private func drawDimensionsHUD(rect: CGRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        let pad: CGFloat = 6
        let bg = CGRect(x: rect.maxX - size.width - pad * 2 - 6,
                        y: rect.minY - size.height - pad * 2 - 6,
                        width: size.width + pad * 2,
                        height: size.height + pad * 2)
        let visible: CGRect
        if bg.minY < 0 {
            visible = CGRect(x: bg.origin.x, y: rect.maxY + 6, width: bg.width, height: bg.height)
        } else {
            visible = bg
        }
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: visible, xRadius: 4, yRadius: 4).fill()
        str.draw(at: CGPoint(x: visible.minX + pad, y: visible.minY + pad))
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        startPoint = p
        currentRect = CGRect(origin: p, size: .zero)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let p = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: min(start.x, p.x),
            y: min(start.y, p.y),
            width: abs(p.x - start.x),
            height: abs(p.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { startPoint = nil }
        NSCursor.pop()
        if currentRect.width < 4 || currentRect.height < 4 {
            onCancel?()
            return
        }
        onCommit?(currentRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            NSCursor.pop()
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}
