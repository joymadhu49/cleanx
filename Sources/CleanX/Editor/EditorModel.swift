import AppKit
import Combine
import Foundation

@MainActor
final class EditorModel: ObservableObject {
    let baseImage: CGImage
    let sourceRect: CGRect

    @Published var annotations: [Annotation] = []
    @Published var currentTool: AnnotationTool = .arrow
    @Published var style: AnnotationStyle = .default

    let undoManager = UndoManager()

    init(baseImage: CGImage, sourceRect: CGRect) {
        self.baseImage = baseImage
        self.sourceRect = sourceRect
    }

    func add(_ annotation: Annotation) {
        annotations.append(annotation)
        let id = annotation.id
        undoManager.registerUndo(withTarget: self) { target in
            Task { @MainActor in target.removeAnnotation(id: id, registerRedo: true) }
        }
    }

    private func removeAnnotation(id: UUID, registerRedo: Bool) {
        guard let idx = annotations.firstIndex(where: { $0.id == id }) else { return }
        let removed = annotations.remove(at: idx)
        if registerRedo {
            undoManager.registerUndo(withTarget: self) { target in
                Task { @MainActor in target.insertAnnotation(removed, at: idx) }
            }
        }
    }

    private func insertAnnotation(_ annotation: Annotation, at index: Int) {
        let idx = min(index, annotations.count)
        annotations.insert(annotation, at: idx)
        let id = annotation.id
        undoManager.registerUndo(withTarget: self) { target in
            Task { @MainActor in target.removeAnnotation(id: id, registerRedo: true) }
        }
    }

    func clearAll() {
        let snapshot = annotations
        annotations.removeAll()
        undoManager.registerUndo(withTarget: self) { target in
            Task { @MainActor in target.annotations = snapshot }
        }
    }

    func renderFlattenedImage() -> CGImage? {
        AnnotationRenderer.flatten(base: baseImage, annotations: annotations)
    }
}
