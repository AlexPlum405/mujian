import Foundation

struct NovelDocument: Equatable {
    let url: URL
    let fileName: String
    let chapters: [NovelChapter]

    var displayTitle: String {
        fileName.isEmpty ? "未命名 TXT" : fileName
    }
}

struct NovelChapter: Identifiable, Equatable {
    let id: Int
    let title: String
    let body: String
    let lineNumber: Int

    static func fallback(body: String) -> NovelChapter {
        NovelChapter(id: 0, title: "全文", body: body, lineNumber: 1)
    }
}
