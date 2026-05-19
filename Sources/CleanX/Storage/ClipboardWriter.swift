import AppKit

enum ClipboardWriter {

    static func write(image: CGImage) {
        let rep = NSBitmapImageRep(cgImage: image)
        let pb = NSPasteboard.general
        pb.clearContents()
        if let png = rep.representation(using: .png, properties: [:]) {
            pb.setData(png, forType: .png)
        }
        if let tiff = rep.representation(using: .tiff, properties: [:]) {
            pb.setData(tiff, forType: .tiff)
        }
    }
}
