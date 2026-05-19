import AppKit
import SwiftUI
import Combine

@MainActor
final class QuickAccessState: ObservableObject {
    enum Mode { case view, markup }

    @Published var image: CGImage
    @Published var fileURL: URL?
    @Published var entryID: UUID?
    @Published var mode: Mode = .view
    @Published var editorModel: EditorModel?
    let sourceRect: CGRect

    init(image: CGImage, fileURL: URL?, entryID: UUID?, sourceRect: CGRect) {
        self.image = image
        self.fileURL = fileURL
        self.entryID = entryID
        self.sourceRect = sourceRect
    }

    func enterMarkup() {
        editorModel = EditorModel(baseImage: image, sourceRect: sourceRect)
        mode = .markup
    }

    func commitMarkup() -> CGImage? {
        guard let model = editorModel else { return nil }
        guard let flat = model.renderFlattenedImage() else { return nil }
        image = flat
        if let id = entryID,
           let entry = RecentsStore.shared.entries.first(where: { $0.id == id }) {
            let updated = RecentsStore.shared.overwrite(entry, with: flat)
            if let updated { fileURL = updated.url }
        }
        editorModel = nil
        mode = .view
        return flat
    }

    func cancelMarkup() {
        editorModel = nil
        mode = .view
    }
}

@MainActor
final class QuickAccessController {

    private var panel: NSPanel?
    private var hideTimer: Timer?
    private var pinned = false
    private var state: QuickAccessState?

    func show(image: CGImage, sourceRect: CGRect) {
        hideTimer?.invalidate()
        panel?.orderOut(nil)
        pinned = false

        guard let screen = NSScreen.main else { return }

        let aspect = CGFloat(image.width) / max(CGFloat(image.height), 1)
        let targetW: CGFloat = 240
        let targetH: CGFloat = 170
        var thumbW: CGFloat
        var thumbH: CGFloat
        if aspect > targetW / targetH {
            thumbW = targetW
            thumbH = thumbW / aspect
        } else {
            thumbH = targetH
            thumbW = thumbH * aspect
        }
        let panelW = thumbW + 48
        let panelH = thumbH + 48

        let finalFrame = NSRect(
            x: screen.visibleFrame.minX + 16,
            y: screen.visibleFrame.minY + 16,
            width: panelW, height: panelH
        )
        let startFrame = NSRect(
            x: finalFrame.origin.x,
            y: finalFrame.origin.y - panelH,
            width: panelW, height: panelH
        )

        let recentsEntry = RecentsStore.shared.entries.first
        let fileURL = recentsEntry?.url
        let entryID = recentsEntry?.id

        let popupState = QuickAccessState(
            image: image,
            fileURL: fileURL,
            entryID: entryID,
            sourceRect: sourceRect
        )
        self.state = popupState

        let panel = NSPanel(contentRect: startFrame,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        panel.contentView = NSHostingView(rootView: QuickAccessView(
            state: popupState,
            thumbSize: CGSize(width: thumbW, height: thumbH),
            onEditWindow: { [weak self] in
                self?.dismiss()
                EditorWindowController.open(image: popupState.image, sourceRect: sourceRect)
            },
            onCopy: { [weak self] in
                ClipboardWriter.write(image: popupState.image)
                _ = self
            },
            onSave: { [weak self] in
                if let url = try? FileSaver.save(image: popupState.image) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                _ = self
            },
            onPin: { [weak self] in self?.togglePin() },
            onUpload: { [weak self] in self?.uploadStub(image: popupState.image) },
            onClose: { [weak self] in self?.dismiss() },
            onHoverChange: { [weak self] hovering in
                guard let self else { return }
                if hovering || self.pinned || popupState.mode == .markup {
                    self.cancelAutoHide()
                } else {
                    self.scheduleAutoHide()
                }
            },
            isPinned: { [weak self] in self?.pinned ?? false }
        ))
        panel.orderFrontRegardless()
        self.panel = panel

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
        }

        scheduleAutoHide(seconds: 10)
    }

    private func togglePin() {
        pinned.toggle()
        if pinned { cancelAutoHide() } else { scheduleAutoHide() }
    }

    private func uploadStub(image: CGImage) {
        let alert = NSAlert()
        alert.messageText = "Cloud upload not configured"
        alert.informativeText = "CleanX v1 has no cloud backend yet. Use Save or drag-out instead."
        alert.runModal()
    }

    private func cancelAutoHide() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func scheduleAutoHide(seconds: TimeInterval = 4) {
        if pinned { return }
        if state?.mode == .markup { return }
        cancelAutoHide()
        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    private func dismiss() {
        cancelAutoHide()
        pinned = false
        state = nil
        guard let panel else { return }
        let target = NSRect(
            x: panel.frame.origin.x,
            y: panel.frame.origin.y - panel.frame.height,
            width: panel.frame.width,
            height: panel.frame.height
        )
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel?.orderOut(nil)
                self?.panel = nil
            }
        })
    }
}

struct QuickAccessView: View {
    @ObservedObject var state: QuickAccessState
    let thumbSize: CGSize
    let onEditWindow: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void
    let onPin: () -> Void
    let onUpload: () -> Void
    let onClose: () -> Void
    let onHoverChange: (Bool) -> Void
    let isPinned: () -> Bool

    @State private var hovering = false
    @State private var copyFeedback = false
    @State private var saveFeedback = false

    var body: some View {
        ZStack {
            screenshot
            if state.mode == .view {
                viewToolbar
                    .frame(width: thumbSize.width, height: thumbSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .opacity(hovering ? 1 : 0)
                    .allowsHitTesting(hovering)
                    .animation(.easeOut(duration: 0.15), value: hovering)
            } else {
                markupToolbar
                    .frame(width: thumbSize.width, height: thumbSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
        .onHover { h in
            hovering = h
            onHoverChange(h)
        }
    }

    @ViewBuilder
    private var screenshot: some View {
        Group {
            if state.mode == .markup, let model = state.editorModel {
                AnnotationCanvas(model: model)
            } else if let url = state.fileURL {
                DraggableImageView(url: url, cornerRadius: 6, onClick: onEditWindow)
            } else {
                Image(decorative: state.image, scale: 1.0)
                    .resizable()
                    .interpolation(.high)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(width: thumbSize.width, height: thumbSize.height)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 12)
    }

    private var viewToolbar: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.35))
                .allowsHitTesting(false)

            VStack {
                HStack {
                    cornerButton(systemName: isPinned() ? "pin.fill" : "pin",
                                 tint: isPinned() ? .accentColor : .secondary,
                                 rotation: -45, action: onPin)
                    Spacer()
                    cornerButton(systemName: "xmark", tint: .secondary, action: onClose)
                }
                Spacer()
                HStack {
                    cornerButton(systemName: "pencil.tip", tint: .secondary, action: onEditWindow)
                    Spacer()
                    cornerButton(systemName: "icloud.and.arrow.up", tint: .secondary, action: onUpload)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            VStack(spacing: 8) {
                primaryButton(label: copyFeedback ? "Copied" : "Copy") {
                    onCopy(); flash($copyFeedback)
                }
                primaryButton(label: saveFeedback ? "Saved" : "Save") {
                    onSave(); flash($saveFeedback)
                }
            }
            .frame(maxWidth: 150)
        }
    }

    private var markupToolbar: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.55))

            if let model = state.editorModel {
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        ForEach([AnnotationTool.arrow, .rectangle, .ellipse, .text, .blur, .highlight]) { tool in
                            toolButton(tool: tool, model: model)
                        }
                    }
                    HStack(spacing: 6) {
                        ColorPicker("", selection: Binding(
                            get: { Color(model.style.color) },
                            set: { model.style.color = NSColor($0) }
                        ))
                        .labelsHidden()
                        .frame(width: 26, height: 20)

                        Slider(value: Binding(
                            get: { model.style.strokeWidth },
                            set: { model.style.strokeWidth = $0 }
                        ), in: 1...12)
                        .controlSize(.mini)

                        Button(action: { model.undoManager.undo() }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 10, weight: .medium))
                                .frame(width: 20, height: 20)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 6) {
                        Button("Cancel") { state.cancelMarkup() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                            .foregroundStyle(.primary)
                        Button("Done") {
                            _ = state.commitMarkup()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
        }
    }

    private func toolButton(tool: AnnotationTool, model: EditorModel) -> some View {
        Button(action: { model.currentTool = tool }) {
            Image(systemName: tool.symbol)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(model.currentTool == tool ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06))
                )
                .foregroundStyle(model.currentTool == tool ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(tool.label)
    }

    private func cornerButton(systemName: String, tint: Color, rotation: Double = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .rotationEffect(.degrees(rotation))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.92)))
                .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                .foregroundStyle(tint == .secondary ? Color.black.opacity(0.75) : tint)
                .contentShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(Capsule().fill(Color.white.opacity(0.92)))
        .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        .foregroundStyle(.black)
        .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
    }

    private func flash(_ binding: Binding<Bool>) {
        binding.wrappedValue = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { binding.wrappedValue = false }
    }
}
