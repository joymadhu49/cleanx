import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    let captureCoordinator = CaptureCoordinator()
    let hotkeyManager = HotkeyManager()
    let permissions = PermissionsManager()
    let quickAccess = QuickAccessController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        permissions.ensureScreenRecordingAccess()
        registerHotkeys()
        captureCoordinator.onCaptureComplete = { [weak self] image, sourceRect in
            self?.handleCapture(image: image, sourceRect: sourceRect)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openSettings() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregisterAll()
    }

    private func makeMenuItem(title: String, action: Selector, key: String = "", symbol: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            item.image = img.withSymbolConfiguration(cfg)
        }
        return item
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(makeMenuItem(title: "Capture Area", action: #selector(captureArea), symbol: "dashed.rectangle"))
        menu.addItem(makeMenuItem(title: "Capture Window", action: #selector(captureWindow), symbol: "macwindow"))
        menu.addItem(makeMenuItem(title: "Capture Fullscreen", action: #selector(captureFullscreen), symbol: "display"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(title: "Show Recents", action: #selector(toggleRecents), symbol: "photo.stack"))
        menu.addItem(makeMenuItem(title: "Open Last Capture", action: #selector(openLast), symbol: "arrow.uturn.backward.circle"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(title: "Settings…", action: #selector(openSettings), key: ",", symbol: "gearshape"))
        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "Quit CleanX", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        if let img = NSImage(systemSymbolName: "power", accessibilityDescription: nil) {
            quit.image = img
        }
        menu.addItem(quit)
        return menu
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "CleanX")
            button.image?.isTemplate = true
            button.toolTip = "CleanX"
        }
        statusItem.menu = buildStatusMenu()
    }

    private func registerHotkeys() {
        let prefs = Preferences.shared
        hotkeyManager.register(.area, combo: prefs.areaHotkey) { [weak self] in self?.captureArea() }
        hotkeyManager.register(.window, combo: prefs.windowHotkey) { [weak self] in self?.captureWindow() }
        hotkeyManager.register(.fullscreen, combo: prefs.fullscreenHotkey) { [weak self] in self?.captureFullscreen() }
        hotkeyManager.register(.openLast, combo: prefs.openLastHotkey) { [weak self] in self?.openLast() }
        hotkeyManager.register(.recents, combo: prefs.recentsHotkey) { [weak self] in self?.toggleRecents() }
    }

    @objc func toggleRecents() {
        RecentsWindowController.shared.toggle()
    }

    @objc func captureArea() { captureCoordinator.startArea() }
    @objc func captureWindow() { captureCoordinator.startWindow() }
    @objc func captureFullscreen() { captureCoordinator.startFullscreen() }

    @objc func openLast() {
        guard let last = LastCaptureStore.shared.lastImage else { NSSound.beep(); return }
        EditorWindowController.open(image: last.image, sourceRect: last.rect)
    }

    @objc func openSettings() {
        if let w = settingsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = SettingsView(onHotkeysChanged: { [weak self] in
            self?.hotkeyManager.unregisterAll()
            self?.registerHotkeys()
        })
        let host = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: host)
        w.title = "CleanX"
        w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.setContentSize(NSSize(width: 720, height: 520))
        w.center()
        w.isReleasedWhenClosed = false
        settingsWindow = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleCapture(image: CGImage, sourceRect: CGRect) {
        LastCaptureStore.shared.set(image: image, rect: sourceRect)
        RecentsStore.shared.add(image: image, sourceRect: sourceRect)
        if Preferences.shared.copyToClipboardOnCapture {
            ClipboardWriter.write(image: image)
        }
        if Preferences.shared.saveOnCapture {
            _ = try? FileSaver.save(image: image)
        }
        quickAccess.show(image: image, sourceRect: sourceRect)
    }
}
