import AppKit

@main
enum CleanXApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(Preferences.shared.showDockIcon ? .regular : .accessory)
        app.run()
    }
}
