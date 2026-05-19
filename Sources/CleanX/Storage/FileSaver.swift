import AppKit
import UniformTypeIdentifiers

enum FileSaverError: Error {
    case encodeFailed
    case writeFailed(Error)
}

enum FileSaver {

    static func save(image: CGImage) throws -> URL {
        let prefs = Preferences.shared
        let folder = prefs.saveFolder
        try ensureFolderExists(folder)

        let format = prefs.fileFormat
        let utType: UTType = format == .png ? .png : .jpeg

        let rep = NSBitmapImageRep(cgImage: image)
        let data: Data?
        switch format {
        case .png:
            data = rep.representation(using: .png, properties: [:])
        case .jpeg:
            data = rep.representation(using: .jpeg, properties: [.compressionFactor: prefs.jpegQuality])
        }
        guard let payload = data else { throw FileSaverError.encodeFailed }

        let fileName = generateFileName(ext: utType.preferredFilenameExtension ?? format.ext)
        let url = folder.appendingPathComponent(fileName)
        do {
            try payload.write(to: url, options: .atomic)
            return url
        } catch {
            throw FileSaverError.writeFailed(error)
        }
    }

    private static func ensureFolderExists(_ url: URL) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private static func generateFileName(ext: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "CleanX \(df.string(from: Date())).\(ext)"
    }
}
