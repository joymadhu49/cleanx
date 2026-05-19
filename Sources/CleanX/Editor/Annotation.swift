import AppKit
import CoreGraphics

enum AnnotationTool: String, CaseIterable, Identifiable {
    case select
    case arrow
    case rectangle
    case ellipse
    case highlight
    case text
    case blur

    var id: String { rawValue }
    var label: String {
        switch self {
        case .select: return "Select"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .highlight: return "Highlight"
        case .text: return "Text"
        case .blur: return "Blur"
        }
    }
    var symbol: String {
        switch self {
        case .select: return "arrow.up.left"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .highlight: return "highlighter"
        case .text: return "textformat"
        case .blur: return "drop.fill"
        }
    }
}

struct AnnotationStyle: Equatable {
    var color: NSColor
    var strokeWidth: CGFloat
    var fontSize: CGFloat

    static let `default` = AnnotationStyle(color: .systemRed, strokeWidth: 3, fontSize: 18)
}

enum Annotation: Identifiable, Equatable {
    case arrow(id: UUID, from: CGPoint, to: CGPoint, style: AnnotationStyle)
    case rectangle(id: UUID, rect: CGRect, style: AnnotationStyle)
    case ellipse(id: UUID, rect: CGRect, style: AnnotationStyle)
    case highlight(id: UUID, rect: CGRect, color: NSColor)
    case text(id: UUID, origin: CGPoint, text: String, style: AnnotationStyle)
    case blur(id: UUID, rect: CGRect, radius: CGFloat)

    var id: UUID {
        switch self {
        case .arrow(let id, _, _, _),
             .rectangle(let id, _, _),
             .ellipse(let id, _, _),
             .highlight(let id, _, _),
             .text(let id, _, _, _),
             .blur(let id, _, _):
            return id
        }
    }

    var boundingBox: CGRect {
        switch self {
        case .arrow(_, let a, let b, let s):
            return CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                          width: abs(a.x - b.x), height: abs(a.y - b.y)).insetBy(dx: -s.strokeWidth, dy: -s.strokeWidth)
        case .rectangle(_, let r, _), .ellipse(_, let r, _), .highlight(_, let r, _), .blur(_, let r, _):
            return r
        case .text(_, let o, let t, let s):
            let size = (t as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: s.fontSize, weight: .semibold)])
            return CGRect(origin: o, size: size)
        }
    }
}
