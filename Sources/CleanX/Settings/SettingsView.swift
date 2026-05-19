import SwiftUI
import AppKit
import Carbon.HIToolbox

struct SettingsView: View {
    let onHotkeysChanged: () -> Void

    enum Section: String, CaseIterable, Identifiable {
        case general, capture, hotkeys, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return "General"
            case .capture: return "Capture"
            case .hotkeys: return "Shortcuts"
            case .about: return "About"
            }
        }
        var symbol: String {
            switch self {
            case .general: return "gearshape.fill"
            case .capture: return "camera.viewfinder"
            case .hotkeys: return "command"
            case .about: return "info.circle.fill"
            }
        }
    }

    @State private var section: Section = .general

    @State private var fileFormat: Preferences.FileFormat = Preferences.shared.fileFormat
    @State private var jpegQuality: Double = Preferences.shared.jpegQuality
    @State private var copyClipboard: Bool = Preferences.shared.copyToClipboardOnCapture
    @State private var saveOnCapture: Bool = Preferences.shared.saveOnCapture
    @State private var showDockIcon: Bool = Preferences.shared.showDockIcon
    @State private var saveFolderPath: String = Preferences.shared.saveFolder.path

    @State private var areaHotkey: HotkeyCombo = Preferences.shared.areaHotkey
    @State private var windowHotkey: HotkeyCombo = Preferences.shared.windowHotkey
    @State private var fullscreenHotkey: HotkeyCombo = Preferences.shared.fullscreenHotkey
    @State private var openLastHotkey: HotkeyCombo = Preferences.shared.openLastHotkey
    @State private var recentsHotkey: HotkeyCombo = Preferences.shared.recentsHotkey

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 180)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 520)
        .background(SettingsBackground().ignoresSafeArea())
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AppLogoView(size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text("CleanX").font(.system(size: 14, weight: .bold))
                    Text("v\(appVersion)").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Section.allCases) { s in
                    sidebarItem(s)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Divider()
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Privacy Settings", systemImage: "lock.shield")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .padding(.bottom, 8)
    }

    private func sidebarItem(_ s: Section) -> some View {
        Button { section = s } label: {
            HStack(spacing: 10) {
                Image(systemName: s.symbol)
                    .frame(width: 18)
                    .font(.system(size: 13, weight: .medium))
                Text(s.title).font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(section == s ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .foregroundStyle(section == s ? Color.accentColor : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(section.title)
                    .font(.system(size: 22, weight: .bold))
                    .padding(.top, 24)
                    .padding(.horizontal, 28)
                Group {
                    switch section {
                    case .general: generalSection
                    case .capture: captureSection
                    case .hotkeys: hotkeysSection
                    case .about: aboutSection
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard {
                cardRow(title: "Show in Dock",
                        subtitle: "Useful if menu bar is hidden by notch overflow.") {
                    Toggle("", isOn: $showDockIcon).labelsHidden()
                        .onChange(of: showDockIcon) { _, v in
                            Preferences.shared.showDockIcon = v
                            NSApp.setActivationPolicy(v ? .regular : .accessory)
                            if v { NSApp.activate(ignoringOtherApps: true) }
                        }
                }
            }
        }
    }

    // MARK: - Capture

    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard {
                VStack(spacing: 0) {
                    cardRow(title: "File format",
                            subtitle: "Format used for saved screenshots.") {
                        Picker("", selection: $fileFormat) {
                            Text("PNG").tag(Preferences.FileFormat.png)
                            Text("JPEG").tag(Preferences.FileFormat.jpeg)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 130)
                        .onChange(of: fileFormat) { _, v in Preferences.shared.fileFormat = v }
                    }
                    if fileFormat == .jpeg {
                        Divider().padding(.horizontal, 14)
                        cardRow(title: "JPEG quality",
                                subtitle: "Higher quality, larger file size.") {
                            HStack {
                                Slider(value: $jpegQuality, in: 0.5...1.0)
                                    .frame(width: 150)
                                    .onChange(of: jpegQuality) { _, v in Preferences.shared.jpegQuality = v }
                                Text("\(Int(jpegQuality * 100))%")
                                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            settingsCard {
                cardRow(title: "Save location",
                        subtitle: saveFolderPath,
                        subtitleStyle: .mono) {
                    Button("Choose…") { chooseSaveFolder() }
                }
            }
            settingsCard {
                VStack(spacing: 0) {
                    cardRow(title: "Copy to clipboard",
                            subtitle: "Each capture is placed on the clipboard.") {
                        Toggle("", isOn: $copyClipboard).labelsHidden()
                            .onChange(of: copyClipboard) { _, v in Preferences.shared.copyToClipboardOnCapture = v }
                    }
                    Divider().padding(.horizontal, 14)
                    cardRow(title: "Save automatically",
                            subtitle: "Save to the chosen folder on every capture.") {
                        Toggle("", isOn: $saveOnCapture).labelsHidden()
                            .onChange(of: saveOnCapture) { _, v in Preferences.shared.saveOnCapture = v }
                    }
                }
            }
        }
    }

    // MARK: - Hotkeys

    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard {
                VStack(spacing: 0) {
                    hotkeyRow("Capture area", combo: $areaHotkey) {
                        Preferences.shared.areaHotkey = areaHotkey; onHotkeysChanged()
                    }
                    Divider().padding(.horizontal, 14)
                    hotkeyRow("Capture window", combo: $windowHotkey) {
                        Preferences.shared.windowHotkey = windowHotkey; onHotkeysChanged()
                    }
                    Divider().padding(.horizontal, 14)
                    hotkeyRow("Capture fullscreen", combo: $fullscreenHotkey) {
                        Preferences.shared.fullscreenHotkey = fullscreenHotkey; onHotkeysChanged()
                    }
                    Divider().padding(.horizontal, 14)
                    hotkeyRow("Open last capture", combo: $openLastHotkey) {
                        Preferences.shared.openLastHotkey = openLastHotkey; onHotkeysChanged()
                    }
                    Divider().padding(.horizontal, 14)
                    hotkeyRow("Recents panel", combo: $recentsHotkey) {
                        Preferences.shared.recentsHotkey = recentsHotkey; onHotkeysChanged()
                    }
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.system(size: 11))
                Text("macOS reserves ⌘⇧3/4/5. Defaults use ⌘⌥⇧.")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
    }

    private func hotkeyRow(_ label: String, combo: Binding<HotkeyCombo>, onCommit: @escaping () -> Void) -> some View {
        cardRow(title: label, subtitle: nil) {
            HotkeyCaptureButton(combo: combo, onCommit: onCommit)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                AppLogoView(size: 96)
                    .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 6)
                Text("CleanX")
                    .font(.system(size: 28, weight: .bold))
                Text("Version \(appVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("A fast, native macOS screenshot and markup tool.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button("Take a Screenshot") { (NSApp.delegate as? AppDelegate)?.captureArea() }
                        .controlSize(.large)
                    Button("Show Recents") { (NSApp.delegate as? AppDelegate)?.toggleRecents() }
                        .controlSize(.large)
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06)))

            Spacer(minLength: 0)

            Text("© 2026 CleanX")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.top, 16)
        }
    }

    // MARK: - Helpers

    private func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Preferences.shared.saveFolder
        if panel.runModal() == .OK, let url = panel.url {
            Preferences.shared.saveFolder = url
            saveFolderPath = url.path
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 0.5))
    }

    private enum SubtitleStyle { case normal, mono }

    @ViewBuilder
    private func cardRow<Trailing: View>(title: String,
                                         subtitle: String?,
                                         subtitleStyle: SubtitleStyle = .normal,
                                         @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(subtitleStyle == .mono
                              ? .system(size: 11, design: .monospaced)
                              : .system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - App Logo (matches AppIcon.icns design)

struct AppLogoView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.10, blue: 0.22),
                            Color(red: 0.12, green: 0.36, blue: 0.55),
                            Color(red: 0.20, green: 0.72, blue: 0.74)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.225)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )

            // Viewfinder corner brackets
            Canvas { ctx, _ in
                let inset: CGFloat = size * 0.20
                let inner = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
                let arm = size * 0.16
                let lw = size * 0.055
                let strokeStyle = StrokeStyle(lineWidth: lw, lineCap: .round)
                let white = Color.white.opacity(0.95)

                func bracket(_ p: CGPoint, hx: CGFloat, vy: CGFloat) -> Path {
                    var path = Path()
                    path.move(to: CGPoint(x: p.x + hx * arm, y: p.y))
                    path.addLine(to: p)
                    path.addLine(to: CGPoint(x: p.x, y: p.y + vy * arm))
                    return path
                }
                ctx.stroke(bracket(CGPoint(x: inner.minX, y: inner.minY), hx: 1, vy: 1), with: .color(white), style: strokeStyle)
                ctx.stroke(bracket(CGPoint(x: inner.maxX, y: inner.minY), hx: -1, vy: 1), with: .color(white), style: strokeStyle)
                ctx.stroke(bracket(CGPoint(x: inner.minX, y: inner.maxY), hx: 1, vy: -1), with: .color(white), style: strokeStyle)
                ctx.stroke(bracket(CGPoint(x: inner.maxX, y: inner.maxY), hx: -1, vy: -1), with: .color(white), style: strokeStyle)

                // X accent
                let xInset: CGFloat = size * 0.33
                let xRect = CGRect(x: xInset, y: xInset, width: size - 2 * xInset, height: size - 2 * xInset)
                let xStyle = StrokeStyle(lineWidth: size * 0.075, lineCap: .round)
                let accent = Color(red: 1.0, green: 0.85, blue: 0.30)
                var p1 = Path(); p1.move(to: CGPoint(x: xRect.minX, y: xRect.minY)); p1.addLine(to: CGPoint(x: xRect.maxX, y: xRect.maxY))
                var p2 = Path(); p2.move(to: CGPoint(x: xRect.maxX, y: xRect.minY)); p2.addLine(to: CGPoint(x: xRect.minX, y: xRect.maxY))
                ctx.stroke(p1, with: .color(accent), style: xStyle)
                ctx.stroke(p2, with: .color(accent), style: xStyle)
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

struct SettingsBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .windowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Hotkey capture button

struct HotkeyCaptureButton: View {
    @Binding var combo: HotkeyCombo
    let onCommit: () -> Void

    @State private var capturing = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { capturing.toggle() }) {
                Text(capturing ? "Press shortcut…" : (combo.displayString.isEmpty ? "—" : combo.displayString))
                    .font(.system(size: 12, weight: .semibold))
                    .frame(minWidth: 110)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(capturing ? Color.accentColor.opacity(0.20) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(capturing ? Color.accentColor : Color.white.opacity(0.12), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
            .background(KeyCaptureView(active: $capturing) { newCombo in
                combo = newCombo
                capturing = false
                onCommit()
            })
            Button {
                combo = .none
                onCommit()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help("Clear shortcut")
        }
    }
}

struct KeyCaptureView: NSViewRepresentable {
    @Binding var active: Bool
    let onCapture: (HotkeyCombo) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        KeyCaptureNSView()
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        if active {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

final class KeyCaptureNSView: NSView {
    var onCapture: ((HotkeyCombo) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let combo = HotkeyCombo.from(nsEvent: event)
        onCapture?(combo)
    }
}
