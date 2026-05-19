import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct RecentsView: View {
    @ObservedObject var store: RecentsStore
    let onOpen: (RecentsStore.Entry) -> Void
    let onClose: () -> Void

    @State private var hoveredID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if store.entries.isEmpty {
                    empty
                } else {
                    carousel
                }
            }
            footer
        }
        .frame(minWidth: 720, idealWidth: 880, minHeight: 280, idealHeight: 320)
        .background(VisualEffectBackground())
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.stack.fill")
                .foregroundStyle(.secondary)
            Text("Recent Captures")
                .font(.headline)
            Text("\(store.entries.count)")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.2), in: Capsule())
                .foregroundStyle(.secondary)
            Spacer()
            if !store.entries.isEmpty {
                Menu {
                    Button("Clear All", role: .destructive) { store.clearAll() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var carousel: some View {
        HorizontalScrollCarousel(entries: store.entries) { entry in
            RecentsTile(
                entry: entry,
                hovered: hoveredID == entry.id,
                onOpen: { onOpen(entry) }
            )
            .onHover { hoveredID = $0 ? entry.id : nil }
            .contextMenu {
                Button("Open in Editor") { onOpen(entry) }
                Button("Copy") { copy(entry) }
                Button("Save As…") { saveAs(entry) }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                }
                Divider()
                Button("Delete", role: .destructive) { store.remove(entry) }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(spacing: 4) {
                Text("No captures yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Take a screenshot to get started.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 10) {
                emptyHotkeyButton(title: "Area", combo: "⌘⌥⇧2", action: { (NSApp.delegate as? AppDelegate)?.captureArea() })
                emptyHotkeyButton(title: "Window", combo: "⌘⌥⇧3", action: { (NSApp.delegate as? AppDelegate)?.captureWindow() })
                emptyHotkeyButton(title: "Fullscreen", combo: "⌘⌥⇧4", action: { (NSApp.delegate as? AppDelegate)?.captureFullscreen() })
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private func emptyHotkeyButton(title: String, combo: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(combo).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.caption)
            Text("Drag a thumbnail into any app to share.")
                .font(.caption)
        }
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func copy(_ entry: RecentsStore.Entry) {
        guard let img = store.image(for: entry) else { return }
        ClipboardWriter.write(image: img)
    }

    private func saveAs(_ entry: RecentsStore.Entry) {
        guard let img = store.image(for: entry) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "CleanX.png"
        if panel.runModal() == .OK, let url = panel.url {
            let rep = NSBitmapImageRep(cgImage: img)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }

}

struct RecentsTile: View {
    let entry: RecentsStore.Entry
    let hovered: Bool
    let onOpen: () -> Void

    @State private var thumb: NSImage?

    private let tileWidth: CGFloat = 220
    private let tileHeight: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                DraggableImageView(url: entry.url, cornerRadius: 10, onClick: onOpen)
                    .frame(width: tileWidth, height: tileHeight)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(hovered ? Color.accentColor : Color.white.opacity(0.12),
                            lineWidth: hovered ? 2 : 1)
                    .allowsHitTesting(false)
            }
            .frame(width: tileWidth, height: tileHeight)
            .shadow(color: .black.opacity(hovered ? 0.45 : 0.25),
                    radius: hovered ? 14 : 6,
                    x: 0, y: hovered ? 6 : 3)
            .scaleEffect(hovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.15), value: hovered)

            VStack(alignment: .leading, spacing: 1) {
                Text(formatted(entry.createdAt))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(Int(entry.pixelSize.width)) × \(Int(entry.pixelSize.height))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .frame(width: tileWidth)
        .task { thumb = RecentsStore.shared.thumbnail(for: entry, maxDim: 480) }
    }

    private func formatted(_ date: Date) -> String {
        let df = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            df.dateStyle = .none
            df.timeStyle = .short
        } else {
            df.dateStyle = .short
            df.timeStyle = .short
        }
        return df.string(from: date)
    }
}

/// AppKit-backed image view that renders the screenshot AND handles
/// click + drag itself. SwiftUI's tap gesture would otherwise consume
/// mouseDown before drag could start. Drag uses NSURL as NSPasteboardWriting
/// so browsers (Telegram Web, Slack, Discord), chat apps, terminals and
/// Finder all treat it as a real file drop.
struct DraggableImageView: NSViewRepresentable {
    let url: URL
    let cornerRadius: CGFloat
    let onClick: () -> Void

    init(url: URL, cornerRadius: CGFloat = 0, onClick: @escaping () -> Void = {}) {
        self.url = url
        self.cornerRadius = cornerRadius
        self.onClick = onClick
    }

    func makeNSView(context: Context) -> DraggableImageNSView {
        let v = DraggableImageNSView()
        v.fileURL = url
        v.onClick = onClick
        v.cornerRadius = cornerRadius
        return v
    }

    func updateNSView(_ nsView: DraggableImageNSView, context: Context) {
        if nsView.fileURL != url {
            nsView.fileURL = url
            nsView.reload()
        }
        nsView.onClick = onClick
        nsView.cornerRadius = cornerRadius
    }
}

final class DraggableImageNSView: NSView, NSDraggingSource {
    var fileURL: URL? {
        didSet { reload() }
    }
    var onClick: () -> Void = {}
    var cornerRadius: CGFloat = 0 {
        didSet {
            layer?.cornerRadius = cornerRadius
            layer?.masksToBounds = cornerRadius > 0
        }
    }

    private var image: NSImage?
    private var mouseDownEvent: NSEvent?
    private var didStartDrag = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    func reload() {
        if let url = fileURL { image = NSImage(contentsOf: url) }
        needsDisplay = true
    }

    // Non-flipped so NSImage.draw renders upright. Mouse handling here
    // doesn't depend on coordinate system orientation.
    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let image else { return }
        // Aspect fill into bounds.
        let imgSize = image.size
        guard imgSize.width > 0 && imgSize.height > 0 else { return }
        let scale = max(bounds.width / imgSize.width, bounds.height / imgSize.height)
        let drawSize = NSSize(width: imgSize.width * scale, height: imgSize.height * scale)
        let drawRect = NSRect(
            x: (bounds.width - drawSize.width) / 2,
            y: (bounds.height - drawSize.height) / 2,
            width: drawSize.width, height: drawSize.height
        )
        image.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        didStartDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didStartDrag, let url = fileURL, let down = mouseDownEvent else { return }
        let movement = hypot(event.locationInWindow.x - down.locationInWindow.x,
                             event.locationInWindow.y - down.locationInWindow.y)
        guard movement > 3 else { return }
        didStartDrag = true

        let startPoint = convert(down.locationInWindow, from: nil)
        let dragImage = image ?? NSImage()
        let h: CGFloat = 140
        let aspect = dragImage.size.width / max(dragImage.size.height, 1)
        let w: CGFloat = max(60, h * aspect)
        let dragRect = NSRect(x: startPoint.x - w/2, y: startPoint.y - h/2, width: w, height: h)

        let dragItem = NSDraggingItem(pasteboardWriter: url as NSURL)
        dragItem.setDraggingFrame(dragRect, contents: dragImage)
        beginDraggingSession(with: [dragItem], event: down, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownEvent = nil
            didStartDrag = false
        }
        if !didStartDrag {
            onClick()
        }
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .generic, .link]
    }
}

struct HorizontalScrollCarousel<Content: View>: NSViewRepresentable {
    let entries: [RecentsStore.Entry]
    let content: (RecentsStore.Entry) -> Content

    func makeNSView(context: Context) -> NSScrollView {
        let sv = HorizontalNSScrollView()
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = true
        sv.horizontalScrollElasticity = .allowed
        sv.verticalScrollElasticity = .none
        sv.drawsBackground = false
        sv.backgroundColor = .clear
        sv.scrollerStyle = .overlay
        sv.autohidesScrollers = true
        sv.borderType = .noBorder

        let doc = NSStackView()
        doc.orientation = .horizontal
        doc.spacing = 16
        doc.alignment = .top
        doc.edgeInsets = NSEdgeInsets(top: 8, left: 18, bottom: 8, right: 18)
        doc.translatesAutoresizingMaskIntoConstraints = false
        sv.documentView = doc

        NSLayoutConstraint.activate([
            doc.topAnchor.constraint(equalTo: sv.contentView.topAnchor),
            doc.bottomAnchor.constraint(equalTo: sv.contentView.bottomAnchor),
            doc.leadingAnchor.constraint(equalTo: sv.contentView.leadingAnchor),
            doc.heightAnchor.constraint(equalTo: sv.contentView.heightAnchor)
        ])
        context.coordinator.stack = doc
        rebuild(stack: doc, context: context)
        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        guard let stack = context.coordinator.stack else { return }
        rebuild(stack: stack, context: context)
    }

    private func rebuild(stack: NSStackView, context: Context) {
        let existingIDs = context.coordinator.hostedIDs
        let newIDs = entries.map { $0.id }
        if existingIDs == newIDs { // Same items, refresh hosting roots
            for (i, entry) in entries.enumerated() {
                if let host = stack.arrangedSubviews[safe: i] as? NSHostingView<Content> {
                    host.rootView = content(entry)
                }
            }
            return
        }
        for v in stack.arrangedSubviews { v.removeFromSuperview() }
        for entry in entries {
            let host = NSHostingView(rootView: content(entry))
            host.translatesAutoresizingMaskIntoConstraints = false
            host.widthAnchor.constraint(equalToConstant: 224).isActive = true
            stack.addArrangedSubview(host)
        }
        context.coordinator.hostedIDs = newIDs
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var stack: NSStackView?
        var hostedIDs: [UUID] = []
    }
}

final class HorizontalNSScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        // Translate vertical wheel/trackpad delta to horizontal scroll
        // when horizontal delta is negligible (typical mouse wheel).
        if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) * 2 {
            let cv = contentView
            var origin = cv.bounds.origin
            let dx = event.scrollingDeltaY
            origin.x -= dx
            let docWidth = documentView?.frame.width ?? 0
            let maxX = max(0, docWidth - cv.bounds.width)
            origin.x = min(max(0, origin.x), maxX)
            cv.setBoundsOrigin(origin)
            reflectScrolledClipView(cv)
            return
        }
        super.scrollWheel(with: event)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 14
        v.layer?.masksToBounds = true
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
