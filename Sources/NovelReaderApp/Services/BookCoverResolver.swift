import Foundation

enum BookCoverResolver {
    static let supportedImageExtensions = [
        "jpg", "jpeg", "png", "webp", "heic", "tiff", "tif"
    ]

    static func localCoverURL(for book: Book, fileManager: FileManager = .default) -> URL? {
        guard case .local(let textURL) = book.origin else {
            return nil
        }

        return localCoverURL(forTextFile: textURL, fileManager: fileManager)
    }

    static func localCoverURL(forTextFile textURL: URL, fileManager: FileManager = .default) -> URL? {
        let directory = textURL.deletingLastPathComponent()
        let baseName = textURL.deletingPathExtension().lastPathComponent
        let fullName = textURL.lastPathComponent

        let stems = baseName == fullName ? [baseName] : [baseName, fullName]

        for stem in stems {
            for ext in supportedImageExtensions {
                let candidate = directory.appendingPathComponent(stem).appendingPathExtension(ext)
                if fileManager.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return nil
    }
}
