import AppKit
import Carbon.HIToolbox

struct HotkeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let none = HotkeyCombo(keyCode: 0, modifiers: 0)

    var isEmpty: Bool { keyCode == 0 && modifiers == 0 }

    var displayString: String {
        guard !isEmpty else { return "—" }
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        s += KeyCodeMap.string(for: keyCode)
        return s
    }

    static func from(nsEvent event: NSEvent) -> HotkeyCombo {
        var mods: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        return HotkeyCombo(keyCode: UInt32(event.keyCode), modifiers: mods)
    }
}

enum HotkeyAction: UInt32, CaseIterable {
    case area = 1
    case window = 2
    case fullscreen = 3
    case openLast = 4
    case recents = 5
}

final class HotkeyManager {
    private struct Registration {
        let action: HotkeyAction
        let ref: EventHotKeyRef
        let handler: () -> Void
    }

    private var registrations: [UInt32: Registration] = [:]
    private var handler: EventHandlerRef?

    init() { installHandler() }

    deinit { unregisterAll(); if let h = handler { RemoveEventHandler(h) } }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let event = event, let userData = userData else { return noErr }
            var hkID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if status != noErr { return status }
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            mgr.fire(id: hkID.id)
            return noErr
        }, 1, &spec, selfPtr, &handler)
    }

    func register(_ action: HotkeyAction, combo: HotkeyCombo, handler: @escaping () -> Void) {
        guard !combo.isEmpty else { return }
        unregister(action)
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x434C5358), id: action.rawValue) // 'CLSX'
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            registrations[action.rawValue] = Registration(action: action, ref: ref, handler: handler)
        } else {
            NSLog("CleanX: failed to register hotkey \(action) status=\(status)")
        }
    }

    func unregister(_ action: HotkeyAction) {
        if let reg = registrations.removeValue(forKey: action.rawValue) {
            UnregisterEventHotKey(reg.ref)
        }
    }

    func unregisterAll() {
        for (_, reg) in registrations { UnregisterEventHotKey(reg.ref) }
        registrations.removeAll()
    }

    fileprivate func fire(id: UInt32) {
        DispatchQueue.main.async { [weak self] in
            self?.registrations[id]?.handler()
        }
    }
}

enum KeyCodeMap {
    static func string(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Escape: return "⎋"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        default: return "Key(\(keyCode))"
        }
    }
}
