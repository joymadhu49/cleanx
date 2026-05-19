import SwiftUI
import AppKit

struct EditorView: View {
    @StateObject var model: EditorModel
    let onCopy: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(model: model)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
            Divider()
            GeometryReader { geo in
                let aspect = CGFloat(model.baseImage.width) / CGFloat(model.baseImage.height)
                let avail = CGSize(width: max(geo.size.width - 40, 50),
                                   height: max(geo.size.height - 40, 50))
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
            HStack {
                Button("Copy", action: onCopy).keyboardShortcut("c", modifiers: .command)
                Button("Save", action: onSave).keyboardShortcut("s", modifiers: .command)
                Spacer()
                Button("Close", action: onClose).keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct EditorToolbar: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AnnotationTool.allCases) { tool in
                Button(action: { model.currentTool = tool }) {
                    Image(systemName: tool.symbol)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .background(model.currentTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .help(tool.label)
            }
            Divider().frame(height: 24)
            ColorPicker("", selection: Binding(
                get: { Color(model.style.color) },
                set: { model.style.color = NSColor($0) }
            ))
            .labelsHidden()
            .frame(width: 40)
            HStack(spacing: 4) {
                Text("Width")
                    .font(.caption)
                Slider(value: $model.style.strokeWidth, in: 1...12)
                    .frame(width: 100)
            }
            Spacer()
            Button("Undo") { model.undoManager.undo() }
                .keyboardShortcut("z", modifiers: .command)
            Button("Clear") { model.clearAll() }
        }
    }
}
