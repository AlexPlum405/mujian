import Foundation

struct BookSource: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let url: String
    let searchUrl: String
    var isEnabled: Bool
    let searchRule: String
    let titleRule: String
    let authorRule: String
    let bookUrlRule: String
    let introRule: String
    let chapterListRule: String
    let chapterTitleRule: String
    let chapterUrlRule: String
    let contentRule: String

    init(
        id: String,
        name: String,
        url: String,
        searchUrl: String,
        isEnabled: Bool = true,
        searchRule: String,
        titleRule: String,
        authorRule: String,
        bookUrlRule: String = "",
        introRule: String = "",
        chapterListRule: String,
        chapterTitleRule: String,
        chapterUrlRule: String,
        contentRule: String
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.searchUrl = searchUrl
        self.isEnabled = isEnabled
        self.searchRule = searchRule
        self.titleRule = titleRule
        self.authorRule = authorRule
        self.bookUrlRule = bookUrlRule
        self.introRule = introRule
        self.chapterListRule = chapterListRule
        self.chapterTitleRule = chapterTitleRule
        self.chapterUrlRule = chapterUrlRule
        self.contentRule = contentRule
    }

    static func decode(from data: Data) throws -> [BookSource] {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            throw BookSourceError.invalidFormat
        }

        let rawSources: [[String: Any]]
        if let array = json as? [[String: Any]] {
            rawSources = array
        } else if let single = json as? [String: Any] {
            rawSources = [single]
        } else {
            throw BookSourceError.invalidFormat
        }

        var results: [BookSource] = []
        for raw in rawSources {
            if let source = BookSource.parseLegado(raw) {
                results.append(source)
            }
        }

        if results.isEmpty {
            throw BookSourceError.invalidFormat
        }
        return results
    }

    private static func parseLegado(_ raw: [String: Any]) -> BookSource? {
        let resolvedUrl = (raw["bookSourceUrl"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard resolvedUrl.isEmpty == false else { return nil }

        let id = resolvedUrl
        let name = (raw["bookSourceName"] as? String ?? "").isEmpty ? resolvedUrl : (raw["bookSourceName"] as? String ?? resolvedUrl)
        let searchUrl = raw["searchUrl"] as? String ?? ""
        let enabled = raw["enabled"] as? Bool ?? true

        let ruleSearch = raw["ruleSearch"] as? [String: Any] ?? [:]
        let ruleToc = raw["ruleToc"] as? [String: Any] ?? [:]
        let ruleContent = raw["ruleContent"] as? [String: Any] ?? [:]

        return BookSource(
            id: id,
            name: name,
            url: resolvedUrl,
            searchUrl: searchUrl,
            isEnabled: enabled,
            searchRule: normalize(ruleSearch["bookList"] as? String),
            titleRule: normalize(ruleSearch["name"] as? String),
            authorRule: normalize(ruleSearch["author"] as? String),
            bookUrlRule: normalize(ruleSearch["bookUrl"] as? String),
            introRule: normalize(ruleSearch["intro"] as? String),
            chapterListRule: normalize(ruleToc["chapterList"] as? String),
            chapterTitleRule: normalize(ruleToc["chapterName"] as? String),
            chapterUrlRule: normalize(ruleToc["chapterUrl"] as? String),
            contentRule: normalize(ruleContent["content"] as? String)
        )
    }
}

extension BookSource {
    static func normalize(_ rule: String?) -> String {
        guard var rule, rule.isEmpty == false else { return "" }
        rule = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        if rule.hasPrefix("@css:") {
            rule.removeFirst("@css:".count)
        } else if rule.hasPrefix("css:") {
            rule.removeFirst("css:".count)
        }
        return rule
    }
}
