import AppKit

enum AppIconRenderer {
    /// Monochrome template image for NSStatusItem.button.
    /// Draws a minimal viewfinder bracket frame around a stylized X.
    static func menuBarTemplate(size: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineCap(.round)

            let inset = size * 0.10
            let bracketRect = rect.insetBy(dx: inset, dy: inset)
            let armLen = size * 0.22
            let lw = max(1.4, size * 0.10)
            ctx.setLineWidth(lw)

            func bracket(_ p: CGPoint, hx: CGFloat, vy: CGFloat) {
                ctx.move(to: CGPoint(x: p.x + hx * armLen, y: p.y))
                ctx.addLine(to: p)
                ctx.addLine(to: CGPoint(x: p.x, y: p.y + vy * armLen))
            }
            bracket(CGPoint(x: bracketRect.minX, y: bracketRect.minY), hx: 1, vy: 1)
            bracket(CGPoint(x: bracketRect.maxX, y: bracketRect.minY), hx: -1, vy: 1)
            bracket(CGPoint(x: bracketRect.minX, y: bracketRect.maxY), hx: 1, vy: -1)
            bracket(CGPoint(x: bracketRect.maxX, y: bracketRect.maxY), hx: -1, vy: -1)
            ctx.strokePath()

            // X
            let xInset = size * 0.34
            let xRect = rect.insetBy(dx: xInset, dy: xInset)
            ctx.setLineWidth(max(1.6, size * 0.13))
            ctx.move(to: CGPoint(x: xRect.minX, y: xRect.minY))
            ctx.addLine(to: CGPoint(x: xRect.maxX, y: xRect.maxY))
            ctx.move(to: CGPoint(x: xRect.maxX, y: xRect.minY))
            ctx.addLine(to: CGPoint(x: xRect.minX, y: xRect.maxY))
            ctx.strokePath()
            return true
        }
        img.isTemplate = true
        return img
    }
}
