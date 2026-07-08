import Foundation
import Testing
@testable import NovelReaderApp

struct TextFileLoaderTests {
    @Test func loadsUTF8TextFile() async throws {
        let url = try temporaryFile(contents: "第一章\n这里是正文。")

        let document = try await TextFileLoader().load(from: url)

        #expect(document.fileName == url.lastPathComponent)
        #expect(document.chapters.first?.title == "第一章")
        #expect(document.chapters.first?.body == "这里是正文。")
    }

    @Test func loadsGB18030TextFile() async throws {
        let url = try temporaryFile(data: Data([0xc4, 0xe3, 0xba, 0xc3]), name: "gb.txt")

        let document = try await TextFileLoader().load(from: url)

        #expect(document.chapters == [.fallback(body: "你好")])
    }

    @Test func rejectsEmptyTextFile() async throws {
        let url = try temporaryFile(contents: "  \n\t")

        await #expect(throws: TextFileLoaderError.emptyFile) {
            try await TextFileLoader().load(from: url)
        }
    }

    @Test func rejectsUnsupportedEncodingTextFile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("bad.txt")
        try Data([0x81, 0xff, 0x81]).write(to: url)

        await #expect(throws: TextFileLoaderError.unsupportedEncoding) {
            try await TextFileLoader().load(from: url)
        }
    }

    @Test func loadsBig5TextFile() async throws {
        let url = try temporaryFile(data: Data([0xA7, 0x41, 0xA6, 0x6E]), name: "big5.txt")

        let document = try await TextFileLoader().load(from: url)

        #expect(document.chapters == [.fallback(body: "你好")])
    }

    @Test func loadsTextFileWithExplicitEncoding() async throws {
        let url = try temporaryFile(data: Data([0xA7, 0x41, 0xA6, 0x6E]), name: "big5.txt")

        let document = try await TextFileLoader().load(from: url, encoding: big5Encoding())

        #expect(document.chapters == [.fallback(body: "你好")])
    }

    @Test func rejectsExplicitEncodingFailure() async throws {
        let url = try temporaryFile(data: Data([0xc4, 0xe3, 0xba, 0xc3]), name: "gb.txt")

        await #expect(throws: TextFileLoaderError.unsupportedEncoding) {
            try await TextFileLoader().load(from: url, encoding: .utf8)
        }
    }

    private func temporaryFile(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("novel.txt")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func temporaryFile(data: Data, name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    private func big5Encoding() -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
    }
}
