import AppKit
import SwiftUI

@MainActor
final class EditorWindowController {

    private static var controllers: [EditorWindowController] = []

    private let window: NSWindow
    private let model: EditorModel

    static func open(image: CGImage, sourceRect: CGRect) {
        let model = EditorModel(baseImage: image, sourceRect: sourceRect)
        let controller = EditorWindowController(model: model)
        controllers.append(controller)
        controller.show()
    }

    private init(model: EditorModel) {
        self.model = model
        let imgW = CGFloat(model.baseImage.width)
        let imgH = CGFloat(model.baseImage.height)
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
        let displayPointsW = imgW / scaleFactor
        let displayPointsH = imgH / scaleFactor
        let avail = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1400, height: 900)
        let chromeW: CGFloat = 80
        let chromeH: CGFloat = 160
        let maxCanvasW = avail.width * 0.7 - chromeW
        let maxCanvasH = avail.height * 0.7 - chromeH
        let aspect = imgW / imgH
        var canvasW = min(displayPointsW, maxCanvasW)
        var canvasH = canvasW / aspect
        if canvasH > maxCanvasH {
            canvasH = maxCanvasH
            canvasW = canvasH * aspect
        }
        let targetW = max(canvasW + chromeW, 980)
        let targetH = max(canvasH + chromeH, 640)
        _ = displayPointsH

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: targetW, height: targetH),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "CleanX Editor"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 820, height: 560)
        window.setContentSize(NSSize(width: targetW, height: targetH))
        window.center()
        self.window = window
        window.contentView = NSHostingView(rootView: EditorView(
            model: model,
            onCopy: { [weak self] in self?.copy() },
            onSave: { [weak self] in self?.save() },
            onClose: { [weak self] in self?.close() }
        ))
    }

    private func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func copy() {
        guard let img = model.renderFlattenedImage() else { NSSound.beep(); return }
        ClipboardWriter.write(image: img)
    }

    private func save() {
        guard let img = model.renderFlattenedImage() else { NSSound.beep(); return }
        do {
            let url = try FileSaver.save(image: img)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSLog("CleanX: save failed: \(error)")
            NSSound.beep()
        }
    }

    private func close() {
        window.close()
        Self.controllers.removeAll { $0 === self }
    }
}
