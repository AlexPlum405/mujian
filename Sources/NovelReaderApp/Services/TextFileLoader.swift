import Foundation

enum TextFileLoaderError: LocalizedError, Equatable {
    case unsupportedEncoding
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .unsupportedEncoding:
            "暂时无法识别这个 TXT 文件的编码。"
        case .emptyFile:
            "这个 TXT 文件没有可显示的内容。"
        }
    }
}

protocol TextFileLoading: Sendable {
    func load(from url: URL, encoding: String.Encoding?, customChapterPattern: String?) async throws -> NovelDocument
}

extension TextFileLoading {
    func load(from url: URL) async throws -> NovelDocument {
        try await load(from: url, encoding: nil, customChapterPattern: nil)
    }

    func load(from url: URL, customChapterPattern: String?) async throws -> NovelDocument {
        try await load(from: url, encoding: nil, customChapterPattern: customChapterPattern)
    }

    func load(from url: URL, encoding: String.Encoding?) async throws -> NovelDocument {
        try await load(from: url, encoding: encoding, customChapterPattern: nil)
    }
}

struct TextFileLoader: TextFileLoading {
    init() {}

    func load(from url: URL, encoding: String.Encoding?, customChapterPattern: String?) async throws -> NovelDocument {
        try await Task.detached(priority: .userInitiated) {
            try Self.loadSync(from: url, encoding: encoding, customChapterPattern: customChapterPattern)
        }.value
    }

    static func loadSync(from url: URL, encoding: String.Encoding? = nil, customChapterPattern: String? = nil) throws -> NovelDocument {
        let data = try Data(contentsOf: url)
        let text = try decodeText(from: data, encoding: encoding)

        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw TextFileLoaderError.emptyFile
        }

        return NovelDocument(
            url: url,
            fileName: url.lastPathComponent,
            chapters: ChapterDetector().detectChapters(in: text, customPattern: customChapterPattern)
        )
    }

    private static func decodeText(from data: Data, encoding: String.Encoding?) throws -> String {
        if let encoding {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
            throw TextFileLoaderError.unsupportedEncoding
        }

        if let utf16Text = decodeUTF16WithBOM(from: data) {
            return utf16Text
        }

        for encoding in nonBOMEncodings {
            if let text = String(data: data, encoding: encoding),
               containsPrivateUseArea(text) == false {
                return text
            }
        }

        throw TextFileLoaderError.unsupportedEncoding
    }

    private static func decodeUTF16WithBOM(from data: Data) -> String? {
        guard data.count >= 2 else {
            return nil
        }

        let prefix = Array(data.prefix(2))
        if prefix == [0xff, 0xfe] || prefix == [0xfe, 0xff] {
            return String(data: data, encoding: .utf16)
        }

        return nil
    }

    private static func containsPrivateUseArea(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0xE000...0xF8FF).contains(scalar.value)
        }
    }

    private static var nonBOMEncodings: [String.Encoding] {
        [
            .utf8,
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))),
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))),
            .shiftJIS,
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue))),
            .windowsCP1252
        ]
    }
}
