import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum AnnotationRenderer {

    /// Flattens annotations onto base CGImage. Annotations use canvas coords
    /// equal to image pixel size with top-left origin.
    static func flatten(base: CGImage, annotations: [Annotation]) -> CGImage? {
        let size = NSSize(width: base.width, height: base.height)
        let blurredBase = applyBlurRegions(to: base, annotations: annotations) ?? base

        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: base.width,
                                   pixelsHigh: base.height,
                                   bitsPerSample: 8,
                                   samplesPerPixel: 4,
                                   hasAlpha: true,
                                   isPlanar: false,
                                   colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0,
                                   bitsPerPixel: 32)
        guard let rep else { return nil }
        rep.size = size

        guard let gctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gctx
        let cg = gctx.cgContext

        // Draw base (CG bottom-left). Fills full bitmap.
        cg.draw(blurredBase, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))

        // Flip into top-left for annotation drawing convenience.
        cg.translateBy(x: 0, y: CGFloat(base.height))
        cg.scaleBy(x: 1, y: -1)

        for a in annotations {
            switch a {
            case .arrow(_, let from, let to, let style):
                drawArrow(cg: cg, from: from, to: to, style: style)
            case .rectangle(_, let rect, let style):
                cg.setStrokeColor(style.color.cgColor)
                cg.setLineWidth(style.strokeWidth)
                cg.stroke(rect)
            case .ellipse(_, let rect, let style):
                cg.setStrokeColor(style.color.cgColor)
                cg.setLineWidth(style.strokeWidth)
                cg.strokeEllipse(in: rect)
            case .highlight(_, let rect, let color):
                cg.setFillColor(color.withAlphaComponent(0.35).cgColor)
                cg.fill(rect)
            case .text(_, let origin, let text, let style):
                drawText(cg: cg, origin: origin, text: text, style: style)
            case .blur:
                break
            }
        }

        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    private static func drawArrow(cg: CGContext, from: CGPoint, to: CGPoint, style: AnnotationStyle) {
        cg.setStrokeColor(style.color.cgColor)
        cg.setFillColor(style.color.cgColor)
        cg.setLineWidth(style.strokeWidth)
        cg.setLineCap(.round)
        cg.beginPath()
        cg.move(to: from)
        cg.addLine(to: to)
        cg.strokePath()

        let angle = atan2(to.y - from.y, to.x - from.x)
        let headLen: CGFloat = max(12, style.strokeWidth * 4)
        let headAngle: CGFloat = .pi / 6
        let p1 = CGPoint(x: to.x - headLen * cos(angle - headAngle),
                         y: to.y - headLen * sin(angle - headAngle))
        let p2 = CGPoint(x: to.x - headLen * cos(angle + headAngle),
                         y: to.y - headLen * sin(angle + headAngle))
        cg.beginPath()
        cg.move(to: to)
        cg.addLine(to: p1)
        cg.addLine(to: p2)
        cg.closePath()
        cg.fillPath()
    }

    private static func drawText(cg: CGContext, origin: CGPoint, text: String, style: AnnotationStyle) {
        let font = NSFont.systemFont(ofSize: style.fontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.color,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        // Counter-flip locally so glyphs are not mirrored.
        cg.saveGState()
        cg.translateBy(x: origin.x, y: origin.y + font.ascender)
        cg.scaleBy(x: 1, y: -1)
        cg.textPosition = .zero
        CTLineDraw(line, cg)
        cg.restoreGState()
    }

    private static func applyBlurRegions(to base: CGImage, annotations: [Annotation]) -> CGImage? {
        let blurAnnotations = annotations.compactMap { a -> CGRect? in
            if case .blur(_, let rect, _) = a { return rect }
            return nil
        }
        if blurAnnotations.isEmpty { return nil }

        let ci = CIImage(cgImage: base)
        let ctx = CIContext()
        var working = ci
        let imageHeight = CGFloat(base.height)

        for canvasRect in blurAnnotations {
            // canvasRect is top-left; CIImage is bottom-left.
            let pixelRect = CGRect(x: canvasRect.origin.x,
                                   y: imageHeight - canvasRect.origin.y - canvasRect.height,
                                   width: canvasRect.width,
                                   height: canvasRect.height)
            let filter = CIFilter.pixellate()
            filter.inputImage = working.cropped(to: pixelRect)
            filter.scale = Float(max(8, min(pixelRect.width, pixelRect.height) / 12))
            filter.center = CGPoint(x: pixelRect.midX, y: pixelRect.midY)
            if let pixellated = filter.outputImage {
                working = pixellated.composited(over: working)
            }
        }
        return ctx.createCGImage(working, from: CGRect(x: 0, y: 0, width: base.width, height: base.height))
    }
}
