import AppKit
import ScreenCaptureKit

enum ScreenshotError: Error {
    case noContent
    case noDisplay
    case captureFailed(Error)
    case cropFailed
}

struct DisplaySnapshot {
    let display: SCDisplay
    let nsScreen: NSScreen
    let image: CGImage
}

final class ScreenshotService {

    func captureDisplay(_ display: SCDisplay, excludingWindows: [SCWindow] = []) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: excludingWindows)
        let config = SCStreamConfiguration()
        config.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
        config.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
        config.showsCursor = false
        config.capturesAudio = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            throw ScreenshotError.captureFailed(error)
        }
    }

    func captureWindow(_ window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let w = filter.contentRect.width * CGFloat(filter.pointPixelScale)
        let h = filter.contentRect.height * CGFloat(filter.pointPixelScale)
        config.width = max(Int(w), 1)
        config.height = max(Int(h), 1)
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.ignoreShadowsSingleWindow = false
        NSLog("CleanX: capturing window \(window.title ?? "?") owner=\(window.owningApplication?.applicationName ?? "?") rect=\(filter.contentRect) scale=\(filter.pointPixelScale)")
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            throw ScreenshotError.captureFailed(error)
        }
    }

    func snapshotAllDisplays() async throws -> [DisplaySnapshot] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        var snapshots: [DisplaySnapshot] = []
        for display in content.displays {
            let screen = await MainActor.run { NSScreen.screens.first(where: { $0.scDisplayID == display.displayID }) }
            guard let screen else { continue }
            let img = try await captureDisplay(display)
            snapshots.append(DisplaySnapshot(display: display, nsScreen: screen, image: img))
        }
        return snapshots
    }

    func sharedContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }
}

extension NSScreen {
    var scDisplayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}

func cropCGImage(_ image: CGImage, to rect: CGRect) -> CGImage? {
    image.cropping(to: rect)
}
