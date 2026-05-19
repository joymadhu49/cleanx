import AppKit
import SwiftUI

struct AnnotationCanvas: NSViewRepresentable {
    @ObservedObject var model: EditorModel

    func makeNSView(context: Context) -> AnnotationCanvasView {
        let v = AnnotationCanvasView(model: model)
        return v
    }

    func updateNSView(_ nsView: AnnotationCanvasView, context: Context) {
        nsView.modelDidChange()
    }
}

final class AnnotationCanvasView: NSView {
    private let model: EditorModel
    private var cancellable: NSObjectProtocol?
    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var liveText: String = ""
    private var liveTextOrigin: CGPoint?

    init(model: EditorModel) {
        self.model = model
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let types = sender.draggingPasteboard.types,
              types.contains(.fileURL) || types.contains(.png) || types.contains(.tiff) else {
            return []
        }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first,
           let img = NSImage(contentsOf: url),
           let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            EditorWindowController.open(image: cg, sourceRect: CGRect(origin: .zero, size: img.size))
            RecentsStore.shared.add(image: cg, sourceRect: .zero)
            return true
        }
        if let data = pb.data(forType: .png) ?? pb.data(forType: .tiff),
           let img = NSImage(data: data),
           let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            EditorWindowController.open(image: cg, sourceRect: CGRect(origin: .zero, size: img.size))
            RecentsStore.shared.add(image: cg, sourceRect: .zero)
            return true
        }
        return false
    }

    func modelDidChange() {
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        // Don't force layout to image pixel size — SwiftUI sets frame explicitly.
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var isFlipped: Bool { true } // top-left origin

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // Keep internal coord space equal to image pixel size so annotation
        // coords and mouse events always operate on pixel space, while frame
        // can be any display size.
        setBoundsSize(NSSize(width: model.baseImage.width, height: model.baseImage.height))
        needsDisplay = true
    }

    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Draw base image into our flipped (top-left) coord space.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(model.baseImage, in: bounds)
        ctx.restoreGState()

        // Draw annotations (canvas coords = bounds, top-left origin).
        for a in model.annotations {
            renderAnnotation(a, in: ctx)
        }

        // Live preview of in-progress drag.
        if let start = dragStart, let current = dragCurrent {
            let preview = previewAnnotation(start: start, current: current)
            renderAnnotation(preview, in: ctx)
        }

        // Live text being typed.
        if let origin = liveTextOrigin {
            renderAnnotation(.text(id: UUID(), origin: origin, text: liveText + "│", style: model.style), in: ctx)
        }
    }

    private func renderAnnotation(_ a: Annotation, in ctx: CGContext) {
        switch a {
        case .arrow(_, let from, let to, let style):
            ctx.setStrokeColor(style.color.cgColor)
            ctx.setFillColor(style.color.cgColor)
            ctx.setLineWidth(style.strokeWidth)
            ctx.setLineCap(.round)
            ctx.beginPath()
            ctx.move(to: from)
            ctx.addLine(to: to)
            ctx.strokePath()
            drawArrowhead(from: from, to: to, style: style, ctx: ctx)
        case .rectangle(_, let rect, let style):
            ctx.setStrokeColor(style.color.cgColor)
            ctx.setLineWidth(style.strokeWidth)
            ctx.stroke(rect)
        case .ellipse(_, let rect, let style):
            ctx.setStrokeColor(style.color.cgColor)
            ctx.setLineWidth(style.strokeWidth)
            ctx.strokeEllipse(in: rect)
        case .highlight(_, let rect, let color):
            ctx.setFillColor(color.withAlphaComponent(0.35).cgColor)
            ctx.fill(rect)
        case .text(_, let origin, let text, let style):
            let font = NSFont.systemFont(ofSize: style.fontSize, weight: .semibold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: style.color,
            ]
            (text as NSString).draw(at: origin, withAttributes: attrs)
        case .blur(_, let rect, _):
            ctx.setFillColor(NSColor.systemGray.withAlphaComponent(0.5).cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(rect)
        }
    }

    private func drawArrowhead(from: CGPoint, to: CGPoint, style: AnnotationStyle, ctx: CGContext) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let headLen: CGFloat = max(12, style.strokeWidth * 4)
        let headAngle: CGFloat = .pi / 6
        let p1 = CGPoint(x: to.x - headLen * cos(angle - headAngle),
                         y: to.y - headLen * sin(angle - headAngle))
        let p2 = CGPoint(x: to.x - headLen * cos(angle + headAngle),
                         y: to.y - headLen * sin(angle + headAngle))
        ctx.beginPath()
        ctx.move(to: to)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.fillPath()
    }

    private func previewAnnotation(start: CGPoint, current: CGPoint) -> Annotation {
        let rect = CGRect(x: min(start.x, current.x),
                          y: min(start.y, current.y),
                          width: abs(current.x - start.x),
                          height: abs(current.y - start.y))
        switch model.currentTool {
        case .arrow: return .arrow(id: UUID(), from: start, to: current, style: model.style)
        case .rectangle: return .rectangle(id: UUID(), rect: rect, style: model.style)
        case .ellipse: return .ellipse(id: UUID(), rect: rect, style: model.style)
        case .highlight: return .highlight(id: UUID(), rect: rect, color: model.style.color)
        case .blur: return .blur(id: UUID(), rect: rect, radius: 10)
        case .text: return .rectangle(id: UUID(), rect: rect, style: model.style)
        case .select: return .rectangle(id: UUID(), rect: rect, style: model.style)
        }
    }

    override func mouseDown(with event: NSEvent) {
        commitLiveText()
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil)
        if model.currentTool == .text {
            liveTextOrigin = p
            liveText = ""
            needsDisplay = true
            return
        }
        dragStart = p
        dragCurrent = p
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragCurrent = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragStart = nil; dragCurrent = nil }
        guard let start = dragStart, let current = dragCurrent else { return }
        let rect = CGRect(x: min(start.x, current.x),
                          y: min(start.y, current.y),
                          width: abs(current.x - start.x),
                          height: abs(current.y - start.y))
        let minSize: CGFloat = 4
        switch model.currentTool {
        case .arrow:
            if hypot(current.x - start.x, current.y - start.y) > minSize {
                model.add(.arrow(id: UUID(), from: start, to: current, style: model.style))
            }
        case .rectangle:
            if rect.width > minSize && rect.height > minSize {
                model.add(.rectangle(id: UUID(), rect: rect, style: model.style))
            }
        case .ellipse:
            if rect.width > minSize && rect.height > minSize {
                model.add(.ellipse(id: UUID(), rect: rect, style: model.style))
            }
        case .highlight:
            if rect.width > minSize && rect.height > minSize {
                model.add(.highlight(id: UUID(), rect: rect, color: .systemYellow))
            }
        case .blur:
            if rect.width > minSize && rect.height > minSize {
                model.add(.blur(id: UUID(), rect: rect, radius: 10))
            }
        case .text, .select:
            break
        }
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if liveTextOrigin != nil {
            handleTextKey(event: event)
            return
        }
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "z" {
            if event.modifierFlags.contains(.shift) {
                model.undoManager.redo()
            } else {
                model.undoManager.undo()
            }
            needsDisplay = true
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 { // delete / fwd-delete
            if let last = model.annotations.last {
                model.annotations.removeAll { $0.id == last.id }
                needsDisplay = true
            }
            return
        }
        super.keyDown(with: event)
    }

    private func handleTextKey(event: NSEvent) {
        guard let origin = liveTextOrigin else { return }
        if event.keyCode == 36 || event.keyCode == 53 { // Return or Escape
            commitLiveText()
            return
        }
        if event.keyCode == 51 { // backspace
            if !liveText.isEmpty { liveText.removeLast() }
            needsDisplay = true
            return
        }
        if let chars = event.characters, !chars.isEmpty {
            liveText.append(chars)
            needsDisplay = true
        }
        _ = origin
    }

    private func commitLiveText() {
        guard let origin = liveTextOrigin else { return }
        if !liveText.isEmpty {
            model.add(.text(id: UUID(), origin: origin, text: liveText, style: model.style))
        }
        liveText = ""
        liveTextOrigin = nil
        needsDisplay = true
    }
}
