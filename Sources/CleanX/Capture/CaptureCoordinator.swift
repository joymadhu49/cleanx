import AppKit
import ScreenCaptureKit

final class CaptureCoordinator {

    var onCaptureComplete: ((CGImage, CGRect) -> Void)?

    private let service = ScreenshotService()
    private var areaOverlay: AreaSelectionOverlay?
    private var windowOverlay: WindowPickerOverlay?

    func startArea() {
        guard areaOverlay == nil, windowOverlay == nil else { return }
        Task { @MainActor in
            do {
                let snapshots = try await service.snapshotAllDisplays()
                let overlay = AreaSelectionOverlay(snapshots: snapshots) { [weak self] result in
                    self?.areaOverlay = nil
                    if let result {
                        self?.onCaptureComplete?(result.image, result.globalRect)
                    }
                }
                self.areaOverlay = overlay
                overlay.present()
            } catch {
                NSLog("CleanX: area capture failed: \(error)")
                NSSound.beep()
            }
        }
    }

    func startFullscreen() {
        Task { @MainActor in
            do {
                guard let screen = NSScreen.main ?? NSScreen.screens.first else { throw ScreenshotError.noDisplay }
                let content = try await service.sharedContent()
                guard let display = content.displays.first(where: { $0.displayID == screen.scDisplayID }) ?? content.displays.first else {
                    throw ScreenshotError.noDisplay
                }
                let image = try await service.captureDisplay(display)
                let rect = screen.frame
                onCaptureComplete?(image, rect)
            } catch {
                NSLog("CleanX: fullscreen capture failed: \(error)")
                NSSound.beep()
            }
        }
    }

    func startWindow() {
        guard areaOverlay == nil, windowOverlay == nil else { return }
        Task { @MainActor in
            do {
                let content = try await service.sharedContent()
                let snapshots = try await service.snapshotAllDisplays()
                let pickable = content.windows.filter { w in
                    w.isOnScreen
                        && w.frame.width > 80 && w.frame.height > 80
                        && w.windowLayer == 0
                        && w.owningApplication != nil
                        && (w.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier)
                        && (w.owningApplication?.bundleIdentifier != "com.apple.dock")
                        && (w.owningApplication?.bundleIdentifier != "com.apple.WindowManager")
                }
                let overlay = WindowPickerOverlay(snapshots: snapshots, windows: pickable) { [weak self] result in
                    self?.windowOverlay = nil
                    guard let result else { return }
                    Task { @MainActor in
                        do {
                            try await Task.sleep(nanoseconds: 150_000_000)
                            // Re-fetch fresh window handle - stale SCWindow refs return black frames.
                            let fresh = try await self?.service.sharedContent()
                            let target = fresh?.windows.first { $0.windowID == result.window.windowID } ?? result.window
                            let img = try await self?.service.captureWindow(target)
                            if let img { self?.onCaptureComplete?(img, target.frame) }
                        } catch {
                            NSLog("CleanX: window capture failed: \(error)")
                            NSSound.beep()
                        }
                    }
                }
                self.windowOverlay = overlay
                overlay.present()
            } catch {
                NSLog("CleanX: window pick failed: \(error)")
                NSSound.beep()
            }
        }
    }
}
