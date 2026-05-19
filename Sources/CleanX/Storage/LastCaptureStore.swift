import CoreGraphics

final class LastCaptureStore {
    static let shared = LastCaptureStore()

    struct Entry {
        let image: CGImage
        let rect: CGRect
    }

    private(set) var lastImage: Entry?

    func set(image: CGImage, rect: CGRect) {
        lastImage = Entry(image: image, rect: rect)
    }
}
