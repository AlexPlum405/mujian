import Foundation

struct ReadingSettings: Equatable {
    var fontSize: Double
    var lineHeight: Double
    var theme: ReadingTheme
    var paperColorHex: String
    var inkColorHex: String
    var accentColorHex: String
    var fontFamily: String
    var isEmergencyBossCornerEnabled: Bool
    var bookshelfStyle: BookshelfStyle
    var customChapterPattern: String?
    var readingMode: ReadingMode

    static let `default` = ReadingSettings(
        fontSize: 17,
        lineHeight: 1.82,
        theme: .light,
        paperColorHex: "#FBF8F1",
        inkColorHex: "#26211A",
        accentColorHex: "#8F4F2E",
        fontFamily: "Songti SC",
        isEmergencyBossCornerEnabled: true,
        bookshelfStyle: .desk,
        customChapterPattern: nil,
        readingMode: .scroll
    )
}

enum ReadingTheme: String, CaseIterable, Equatable {
    case white
    case light
    case sepia
    case dark

    var label: String {
        switch self {
        case .white:
            "纯白"
        case .light:
            "纸白"
        case .sepia:
            "护眼"
        case .dark:
            "夜读"
        }
    }
}

enum BookshelfStyle: String, CaseIterable, Equatable {
    case desk
    case spines
    case drawer

    var label: String {
        switch self {
        case .desk:
            "案头"
        case .spines:
            "书脊"
        case .drawer:
            "清单"
        }
    }
}
