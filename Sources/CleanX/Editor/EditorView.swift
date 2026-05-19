import SwiftUI
import AppKit

struct EditorView: View {
    @StateObject var model: EditorModel
    let onCopy: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    @State private var copyFeedback = false
    @State private var saveFeedback = false

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(model: model)
            Divider()
            GeometryReader { geo in
                let aspect = CGFloat(model.baseImage.width) / CGFloat(model.baseImage.height)
                let avail = CGSize(width: max(geo.size.width - 48, 50),
                                   height: max(geo.size.height - 48, 50))
                let fit: CGSize = {
                    if avail.width / avail.height > aspect {
                        return CGSize(width: avail.height * aspect, height: avail.height)
                    } else {
                        return CGSize(width: avail.width, height: avail.width / aspect)
                    }
                }()
                AnnotationCanvas(model: model)
                    .frame(width: fit.width, height: fit.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(20)
            }
            .background(Color(NSColor.windowBackgroundColor))
            Divider()
            actionBar
        }
        .frame(minWidth: 820, minHeight: 560)
        .background(KeyShortcutCatcher(model: model))
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            statusText
            Spacer()
            Button {
                onCopy(); flash($copyFeedback)
            } label: {
                Label(copyFeedback ? "Copied" : "Copy", systemImage: "doc.on.doc")
                    .frame(minWidth: 70)
            }
            .keyboardShortcut("c", modifiers: .command)
            .controlSize(.large)

            Button {
                onSave(); flash($saveFeedback)
            } label: {
                Label(saveFeedback ? "Saved" : "Save", systemImage: "square.and.arrow.down")
                    .frame(minWidth: 70)
            }
            .keyboardShortcut("s", modifiers: .command)
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Button("Close", action: onClose)
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var statusText: some View {
        HStack(spacing: 6) {
            Image(systemName: model.currentTool.symbol)
                .foregroundStyle(.secondary)
            Text(model.currentTool.label).font(.system(size: 12, weight: .medium))
            Text("·").foregroundStyle(.tertiary)
            Text("\(model.annotations.count) annotation\(model.annotations.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func flash(_ binding: Binding<Bool>) {
        binding.wrappedValue = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { binding.wrappedValue = false }
    }
}

// MARK: - Toolbar

struct EditorToolbar: View {
    @ObservedObject var model: EditorModel

    private let presetColors: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemBlue, .systemPurple, .black, .white
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                toolGroup
                Divider().frame(height: 26)
                colorGroup
                Divider().frame(height: 26)
                styleGroup
                Spacer()
                actionGroup
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }

    private static let editorTools: [AnnotationTool] = [
        .arrow, .rectangle, .ellipse, .highlight, .text, .blur
    ]

    private var toolGroup: some View {
        HStack(spacing: 4) {
            ForEach(EditorToolbar.editorTools) { tool in
                toolButton(tool)
            }
        }
    }

    private func toolButton(_ tool: AnnotationTool) -> some View {
        let active = model.currentTool == tool
        return Button {
            model.currentTool = tool
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tool.symbol)
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(width: 34, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(active ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(active ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.06), lineWidth: 0.8)
            )
            .foregroundStyle(active ? Color.accentColor : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(tool.label)  ·  \(shortcutHint(tool))")
    }

    private func shortcutHint(_ tool: AnnotationTool) -> String {
        switch tool {
        case .select: return "V"
        case .arrow: return "A"
        case .rectangle: return "R"
        case .ellipse: return "E"
        case .highlight: return "H"
        case .text: return "T"
        case .blur: return "B"
        }
    }

    private var colorGroup: some View {
        HStack(spacing: 6) {
            ForEach(presetColors, id: \.self) { color in
                let selected = model.style.color.isApproxEqual(to: color)
                Button {
                    model.style.color = color
                } label: {
                    Circle()
                        .fill(Color(color))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.5), lineWidth: 0.6)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2)
                                .padding(-2)
                                .opacity(selected ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)
                .help(color.colorName)
            }
            RainbowColorPicker(color: Binding(
                get: { model.style.color },
                set: { model.style.color = $0 }
            ))
        }
    }

    private var styleGroup: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "lineweight").foregroundStyle(.secondary)
                Slider(value: $model.style.strokeWidth, in: 1...30)
                    .frame(width: 90)
                Text("\(Int(model.style.strokeWidth))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .trailing)
            }
            if model.currentTool == .text {
                HStack(spacing: 4) {
                    Image(systemName: "textformat.size").foregroundStyle(.secondary)
                    Slider(value: $model.style.fontSize, in: 12...160)
                        .frame(width: 110)
                    Text("\(Int(model.style.fontSize))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
    }

    private var actionGroup: some View {
        HStack(spacing: 6) {
            Button {
                model.undoManager.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .disabled(!model.undoManager.canUndo)
            .help("Undo  ·  ⌘Z")

            Button {
                model.undoManager.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .disabled(!model.undoManager.canRedo)
            .help("Redo  ·  ⌘⇧Z")

            Button {
                model.clearAll()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .disabled(model.annotations.isEmpty)
            .help("Clear all")
        }
    }
}

// MARK: - Tool keyboard shortcuts

struct KeyShortcutCatcher: NSViewRepresentable {
    let model: EditorModel

    func makeNSView(context: Context) -> NSView {
        let v = KeyShortcutNSView()
        v.model = model
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let v = nsView as? KeyShortcutNSView { v.model = model }
    }
}

final class KeyShortcutNSView: NSView {
    weak var model: EditorModel?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        guard let window else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === window, let model = self.model else { return event }
            // Skip if a text field has focus or text tool is committing text
            if event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
               let chars = event.charactersIgnoringModifiers?.lowercased(),
               chars.count == 1,
               let tool = self.toolForChar(chars) {
                Task { @MainActor in model.currentTool = tool }
                return nil
            }
            return event
        }
    }

    private func toolForChar(_ c: String) -> AnnotationTool? {
        switch c {
        case "v": return .select
        case "a": return .arrow
        case "r": return .rectangle
        case "e": return .ellipse
        case "h": return .highlight
        case "t": return .text
        case "b": return .blur
        default: return nil
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}

struct RainbowColorPicker: View {
    @Binding var color: NSColor
    @State private var hosting: NSView?

    var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(
                    gradient: Gradient(colors: [
                        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red
                    ]),
                    center: .center))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .fill(Color(color))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.6)
                )
        }
        .contentShape(Circle())
        .onTapGesture { openColorPanel() }
        .help("Choose color")
    }

    private func openColorPanel() {
        ColorPanelProxy.shared.show(initial: color) { new in
            self.color = new
        }
    }
}

@MainActor
final class ColorPanelProxy: NSObject {
    static let shared = ColorPanelProxy()
    private var callback: ((NSColor) -> Void)?

    func show(initial: NSColor, callback: @escaping (NSColor) -> Void) {
        self.callback = callback
        let panel = NSColorPanel.shared
        panel.color = initial
        panel.showsAlpha = false
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        callback?(sender.color)
    }
}

private extension NSColor {
    func isApproxEqual(to other: NSColor, tolerance: CGFloat = 0.02) -> Bool {
        guard let a = self.usingColorSpace(.deviceRGB),
              let b = other.usingColorSpace(.deviceRGB) else { return self == other }
        return abs(a.redComponent - b.redComponent) < tolerance
            && abs(a.greenComponent - b.greenComponent) < tolerance
            && abs(a.blueComponent - b.blueComponent) < tolerance
    }
    var colorName: String {
        switch self {
        case .systemRed: return "Red"
        case .systemOrange: return "Orange"
        case .systemYellow: return "Yellow"
        case .systemGreen: return "Green"
        case .systemBlue: return "Blue"
        case .systemPurple: return "Purple"
        case .black: return "Black"
        case .white: return "White"
        default: return "Color"
        }
    }
}
