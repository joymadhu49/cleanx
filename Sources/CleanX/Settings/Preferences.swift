import Foundation
import Carbon.HIToolbox

final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let saveFolder = "saveFolder"
        static let fileFormat = "fileFormat"
        static let jpegQuality = "jpegQuality"
        static let copyToClipboardOnCapture = "copyToClipboardOnCapture"
        static let saveOnCapture = "saveOnCapture"
        static let showDockIcon = "showDockIcon"
        static let areaHotkey = "areaHotkey"
        static let windowHotkey = "windowHotkey"
        static let fullscreenHotkey = "fullscreenHotkey"
        static let openLastHotkey = "openLastHotkey"
        static let recentsHotkey = "recentsHotkey"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Key.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Key.hasLaunchedBefore) }
    }

    enum FileFormat: String, CaseIterable, Identifiable {
        case png, jpeg
        var id: String { rawValue }
        var ext: String { rawValue == "jpeg" ? "jpg" : "png" }
    }

    var saveFolder: URL {
        get {
            if let bookmark = defaults.data(forKey: Key.saveFolder) {
                var stale = false
                if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) {
                    return url
                }
            }
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
        }
        set {
            if let data = try? newValue.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                defaults.set(data, forKey: Key.saveFolder)
            }
        }
    }

    var fileFormat: FileFormat {
        get { FileFormat(rawValue: defaults.string(forKey: Key.fileFormat) ?? "png") ?? .png }
        set { defaults.set(newValue.rawValue, forKey: Key.fileFormat) }
    }

    var jpegQuality: Double {
        get {
            let v = defaults.double(forKey: Key.jpegQuality)
            return v == 0 ? 0.92 : v
        }
        set { defaults.set(newValue, forKey: Key.jpegQuality) }
    }

    var copyToClipboardOnCapture: Bool {
        get { defaults.object(forKey: Key.copyToClipboardOnCapture) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.copyToClipboardOnCapture) }
    }

    var saveOnCapture: Bool {
        get { defaults.object(forKey: Key.saveOnCapture) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.saveOnCapture) }
    }

    var showDockIcon: Bool {
        get { defaults.object(forKey: Key.showDockIcon) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.showDockIcon) }
    }

    var areaHotkey: HotkeyCombo {
        get { readCombo(Key.areaHotkey) ?? HotkeyCombo(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey | optionKey | shiftKey)) }
        set { writeCombo(newValue, key: Key.areaHotkey) }
    }

    var windowHotkey: HotkeyCombo {
        get { readCombo(Key.windowHotkey) ?? HotkeyCombo(keyCode: UInt32(kVK_ANSI_3), modifiers: UInt32(cmdKey | optionKey | shiftKey)) }
        set { writeCombo(newValue, key: Key.windowHotkey) }
    }

    var fullscreenHotkey: HotkeyCombo {
        get { readCombo(Key.fullscreenHotkey) ?? HotkeyCombo(keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(cmdKey | optionKey | shiftKey)) }
        set { writeCombo(newValue, key: Key.fullscreenHotkey) }
    }

    var openLastHotkey: HotkeyCombo {
        get { readCombo(Key.openLastHotkey) ?? HotkeyCombo(keyCode: UInt32(kVK_ANSI_5), modifiers: UInt32(cmdKey | optionKey | shiftKey)) }
        set { writeCombo(newValue, key: Key.openLastHotkey) }
    }

    var recentsHotkey: HotkeyCombo {
        get { readCombo(Key.recentsHotkey) ?? HotkeyCombo(keyCode: UInt32(kVK_ANSI_6), modifiers: UInt32(cmdKey | optionKey | shiftKey)) }
        set { writeCombo(newValue, key: Key.recentsHotkey) }
    }

    private func readCombo(_ key: String) -> HotkeyCombo? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotkeyCombo.self, from: data)
    }

    private func writeCombo(_ combo: HotkeyCombo, key: String) {
        if let data = try? JSONEncoder().encode(combo) { defaults.set(data, forKey: key) }
    }
}
