import AppKit
import Combine
import Foundation

@MainActor
final class RecentsStore: ObservableObject {
    static let shared = RecentsStore()

    struct Entry: Identifiable, Equatable, Hashable {
        let id: UUID
        let url: URL
        let createdAt: Date
        let sourceRect: CGRect
        let pixelSize: CGSize

        static func == (lhs: Entry, rhs: Entry) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    @Published private(set) var entries: [Entry] = []

    private let maxEntries = 60
    private let folder: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let dir = support.appendingPathComponent("CleanX/Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.folder = dir
        loadFromDisk()
    }

    @discardableResult
    func add(image: CGImage, sourceRect: CGRect) -> Entry? {
        let id = UUID()
        let url = folder.appendingPathComponent("\(id.uuidString).png")
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("CleanX: recents save failed: \(error)")
            return nil
        }
        let entry = Entry(
            id: id,
            url: url,
            createdAt: Date(),
            sourceRect: sourceRect,
            pixelSize: CGSize(width: image.width, height: image.height)
        )
        entries.insert(entry, at: 0)
        trim()
        return entry
    }

    func remove(_ entry: Entry) {
        try? FileManager.default.removeItem(at: entry.url)
        entries.removeAll { $0.id == entry.id }
    }

    @discardableResult
    func overwrite(_ entry: Entry, with image: CGImage) -> Entry? {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return nil }
        do {
            try data.write(to: entry.url, options: .atomic)
        } catch {
            NSLog("CleanX: overwrite failed: \(error)")
            return nil
        }
        let updated = Entry(
            id: entry.id,
            url: entry.url,
            createdAt: entry.createdAt,
            sourceRect: entry.sourceRect,
            pixelSize: CGSize(width: image.width, height: image.height)
        )
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = updated
        }
        return updated
    }

    func clearAll() {
        for e in entries { try? FileManager.default.removeItem(at: e.url) }
        entries.removeAll()
    }

    func image(for entry: Entry) -> CGImage? {
        guard let nsImage = NSImage(contentsOf: entry.url) else { return nil }
        var rect = CGRect(origin: .zero, size: nsImage.size)
        return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    func thumbnail(for entry: Entry, maxDim: CGFloat = 240) -> NSImage {
        let img = NSImage(contentsOf: entry.url) ?? NSImage()
        let aspect = img.size.width / max(img.size.height, 1)
        let target: NSSize
        if aspect > 1 {
            target = NSSize(width: maxDim, height: maxDim / aspect)
        } else {
            target = NSSize(width: maxDim * aspect, height: maxDim)
        }
        let thumb = NSImage(size: target)
        thumb.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: target),
                 from: NSRect(origin: .zero, size: img.size),
                 operation: .copy,
                 fraction: 1.0)
        thumb.unlockFocus()
        return thumb
    }

    private func trim() {
        while entries.count > maxEntries {
            if let last = entries.popLast() {
                try? FileManager.default.removeItem(at: last.url)
            }
        }
    }

    private func loadFromDisk() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]) else { return }
        let pngs = urls.filter { $0.pathExtension.lowercased() == "png" }
        let withDates = pngs.compactMap { url -> (URL, Date)? in
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return (url, date)
        }
        let sorted = withDates.sorted { $0.1 > $1.1 }
        entries = sorted.prefix(maxEntries).compactMap { url, date in
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { return nil }
            let img = NSImage(contentsOf: url)
            let size = img?.size ?? .zero
            return Entry(id: id, url: url, createdAt: date,
                         sourceRect: .zero,
                         pixelSize: size)
        }
    }
}
