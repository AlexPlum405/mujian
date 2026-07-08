import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
protocol FilePicking {
    func pickTextFile() -> URL?
    func pickTextFile(allowingEncodingSelection: Bool) -> (url: URL, encoding: String.Encoding?)?
    func pickBookSourceFile() -> [BookSource]
}

@MainActor
final class NSOpenPanelFilePicker: FilePicking {
    func pickTextFile() -> URL? {
        runOpenPanel()
    }

    func pickTextFile(allowingEncodingSelection: Bool) -> (url: URL, encoding: String.Encoding?)? {
        guard let url = runOpenPanel() else {
            return nil
        }

        if allowingEncodingSelection, autoDecodeFailed(at: url) {
            guard let encoding = promptEncodingSelection() else {
                return nil
            }
            return (url, encoding)
        }

        return (url, nil)
    }

    func pickBookSourceFile() -> [BookSource] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "json")].compactMap { $0 }
        panel.prompt = "导入"
        panel.message = "选择书源 JSON 文件"

        guard panel.runModal() == .OK, let url = panel.url else {
            return []
        }

        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        return (try? BookSource.decode(from: data)) ?? []
    }

    private func runOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "txt")].compactMap { $0 }
        panel.prompt = "打开"
        panel.message = "选择一本 TXT 小说"

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    private func autoDecodeFailed(at url: URL) -> Bool {
        do {
            _ = try TextFileLoader.loadSync(from: url)
            return false
        } catch TextFileLoaderError.unsupportedEncoding {
            return true
        } catch {
            return false
        }
    }

    private func promptEncodingSelection() -> String.Encoding? {
        let alert = NSAlert()
        alert.messageText = "无法识别编码"
        alert.informativeText = "请手动选择文件编码"
        for item in Self.selectableEncodings {
            alert.addButton(withTitle: item.name)
        }
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        if index >= 0 && index < Self.selectableEncodings.count {
            return Self.selectableEncodings[index].encoding
        }
        return nil
    }

    private static let selectableEncodings: [(name: String, encoding: String.Encoding)] = [
        ("UTF-8", .utf8),
        ("GB18030", String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))),
        ("Big5", String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))),
        ("Shift-JIS", .shiftJIS),
        ("EUC-KR", String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))),
        ("Windows-1252", .windowsCP1252)
    ]
}
