import AppKit
import UniformTypeIdentifiers

final class ImageDragProvider: NSObject, NSFilePromiseProviderDelegate {

    let image: CGImage
    let suggestedName: String
    private let queue = OperationQueue()

    init(image: CGImage, suggestedName: String = "CleanX.png") {
        self.image = image
        self.suggestedName = suggestedName
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        suggestedName
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        do {
            let rep = NSBitmapImageRep(cgImage: image)
            if let data = rep.representation(using: .png, properties: [:]) {
                try data.write(to: url)
                completionHandler(nil)
            } else {
                completionHandler(NSError(domain: "CleanX", code: -1))
            }
        } catch {
            completionHandler(error)
        }
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        queue
    }
}

func makeFilePromiseProvider(image: CGImage) -> NSFilePromiseProvider {
    let provider = ImageDragProvider(image: image)
    let promise = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: provider)
    objc_setAssociatedObject(promise, &dragProviderKey, provider, .OBJC_ASSOCIATION_RETAIN)
    return promise
}

private var dragProviderKey: UInt8 = 0
