import Foundation
import SwiftSoup

enum BookSourceError: LocalizedError, Equatable {
    case invalidFormat
    case sourceUnavailable
    case chapterNotFound
    case emptyContent
    case paused
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "书源文件格式不正确，无法识别。"
        case .sourceUnavailable:
            "该书源暂不可用。"
        case .chapterNotFound:
            "找不到这一章。"
        case .emptyContent:
            "这一章没有可显示的正文。"
        case .paused:
            "已暂停加载。"
        case .network(let message):
            message
        }
    }
}

struct DownloadProgress: Equatable, Sendable {
    let title: String
    let current: Int
    let total: Int
}

struct OnlineSearchResult: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let author: String?
    let bookUrl: String
    let intro: String?
    let sourceId: String
    let sourceName: String

    init(
        id: String = UUID().uuidString,
        title: String,
        author: String?,
        bookUrl: String,
        intro: String? = nil,
        sourceId: String,
        sourceName: String
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.bookUrl = bookUrl
        self.intro = intro
        self.sourceId = sourceId
        self.sourceName = sourceName
    }
}

struct OnlineChapter: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let url: String

    init(id: String = UUID().uuidString, title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }
}

protocol BookSourceEngine: AnyObject, Sendable {
    func search(query: String, sources: [BookSource]) async -> [OnlineSearchResult]
    func loadChapterList(bookUrl: String, source: BookSource) async throws -> [OnlineChapter]
    func loadChapterContent(chapterUrl: String, source: BookSource) async throws -> String
    func pause()
    func resume()
}

final class StubBookSourceEngine: BookSourceEngine, @unchecked Sendable {
    private(set) var isPaused = false
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0
    private(set) var loadChapterListCallCount = 0
    private(set) var loadChapterContentCallCount = 0
    private(set) var lastSearchQuery: String?
    private(set) var lastSearchedSourceIds: [String] = []
    private(set) var lastLoadedBookUrl: String?

    var searchResults: [OnlineSearchResult] = []
    var chapters: [OnlineChapter] = []
    var content: String = "正文内容"
    var chapterListError: Error?
    var contentError: Error?

    func search(query: String, sources: [BookSource]) async -> [OnlineSearchResult] {
        let enabledIds = Set(sources.filter { $0.isEnabled }.map(\.id))
        lastSearchQuery = query
        lastSearchedSourceIds = Array(enabledIds)
        return searchResults.filter { enabledIds.contains($0.sourceId) }
    }

    func loadChapterList(bookUrl: String, source: BookSource) async throws -> [OnlineChapter] {
        loadChapterListCallCount += 1
        if let chapterListError {
            throw chapterListError
        }
        lastLoadedBookUrl = bookUrl
        return chapters
    }

    func loadChapterContent(chapterUrl: String, source: BookSource) async throws -> String {
        loadChapterContentCallCount += 1
        if let contentError {
            throw contentError
        }
        if isPaused {
            throw BookSourceError.paused
        }
        return content
    }

    func pause() {
        isPaused = true
        pauseCallCount += 1
    }

    func resume() {
        isPaused = false
        resumeCallCount += 1
    }
}

final class LegadoBookSourceEngine: BookSourceEngine, @unchecked Sendable {
    private let pauseLock = NSLock()
    private var paused = false

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var isPaused: Bool {
        pauseLock.lock()
        defer { pauseLock.unlock() }
        return paused
    }

    func search(query: String, sources: [BookSource]) async -> [OnlineSearchResult] {
        let enabledSources = sources.filter { $0.isEnabled }

        var results: [OnlineSearchResult] = []
        var runningTasks: [Task<[OnlineSearchResult], Never>] = []

        for source in enabledSources {
            guard let ruleType = SourceRuleType.detect(source.searchRule), ruleType != .unknown else {
                continue
            }

            let task = Task<[OnlineSearchResult], Never> {
                for attempt in 0..<3 {
                    if Task.isCancelled || self.isPaused { return [] }
                    do {
                        let (url, option) = self.resolvedSearchURL(template: source.searchUrl, query: query, base: source.url)
                        var html: String

                        if option.useWebView {
                            html = try await Self.fetchViaWebView(url: url, method: option.method, body: option.body)
                        } else {
                            let data = try await self.fetchData(url: url, option: option)
                            html = EncodingDetector.decode(data: data, httpCharset: option.charset)

                            if self.isCloudflareChallenge(html) {
                                html = try await Self.fetchViaWebView(url: url, method: option.method, body: option.body)
                            }
                        }

                        let parsed: [OnlineSearchResult]
                        if ruleType == .jsonpath {
                            let data = html.data(using: .utf8) ?? Data()
                            parsed = self.parseSearchResultsJSON(data: data, source: source, baseURL: url)
                        } else {
                            parsed = try self.parseSearchResults(html: html, source: source, ruleType: ruleType, baseURL: url)
                        }
                        if parsed.isEmpty == false || attempt == 2 {
                            return parsed
                        }
                    } catch {
                        if attempt == 2 {
                            return []
                        }
                    }

                    try? await Task.sleep(nanoseconds: 350_000_000)
                }

                return []
            }
            runningTasks.append(task)
        }

        for task in runningTasks {
            let partial = await task.value
            results.append(contentsOf: partial)
        }

        return results
    }

    private func isCloudflareChallenge(_ html: String) -> Bool {
        let lower = html.lowercased()
        return lower.contains("just a moment") || lower.contains("cf-browser-verification") || lower.contains("cf-challenge") || lower.contains("cloudflare") && lower.contains("challenge")
    }

    @MainActor
    private static func fetchViaWebView(url: URL, method: String = "GET", body: String? = nil) async throws -> String {
        let loader = WebViewLoader()
        return try await loader.load(url: url, method: method, body: body)
    }

    func loadChapterList(bookUrl: String, source: BookSource) async throws -> [OnlineChapter] {
        guard isPaused == false else {
            throw BookSourceError.paused
        }
        guard let ruleType = SourceRuleType.detect(source.chapterListRule), ruleType != .unknown else {
            throw BookSourceError.sourceUnavailable
        }
        let url = resolvedURL(path: bookUrl, base: source.url)
        var html = try await fetch(url: url)
        if isCloudflareChallenge(html) {
            html = try await Self.fetchViaWebView(url: url)
        }
        if Task.isCancelled || isPaused {
            throw BookSourceError.paused
        }
        var chapters = try parseChapterList(html: html, source: source, ruleType: ruleType, baseURL: url)
        let pageURLs = try chapterListPageURLs(html: html, currentURL: url)

        for pageURL in pageURLs where pageURL != url {
            if Task.isCancelled || isPaused {
                throw BookSourceError.paused
            }

            var pageHTML = try await fetch(url: pageURL)
            if isCloudflareChallenge(pageHTML) {
                pageHTML = try await Self.fetchViaWebView(url: pageURL)
            }
            chapters.append(contentsOf: try parseChapterList(html: pageHTML, source: source, ruleType: ruleType, baseURL: pageURL))
        }

        return normalizedChapterList(chapters)
    }

    func loadChapterContent(chapterUrl: String, source: BookSource) async throws -> String {
        guard isPaused == false else {
            throw BookSourceError.paused
        }
        guard let ruleType = SourceRuleType.detect(source.contentRule), ruleType != .unknown else {
            throw BookSourceError.sourceUnavailable
        }
        let url = resolvedURL(path: chapterUrl, base: source.url)
        var html = try await fetch(url: url)
        if isCloudflareChallenge(html) {
            html = try await Self.fetchViaWebView(url: url)
        }
        if Task.isCancelled || isPaused {
            throw BookSourceError.paused
        }
        let text = try parseContent(html: html, source: source, ruleType: ruleType)
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw BookSourceError.emptyContent
        }
        return text
    }

    func pause() {
        pauseLock.lock()
        paused = true
        pauseLock.unlock()
    }

    func resume() {
        pauseLock.lock()
        paused = false
        pauseLock.unlock()
    }

    private func encodeFormBody(_ body: String) -> String {
        let pairs = body.split(separator: "&")
        let encoded = pairs.map { pair -> String in
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0])
                let value = String(parts[1])
                return "\(key)=\(percentEncodeFormValue(value))"
            }
            return String(pair)
        }
        return encoded.joined(separator: "&")
    }

    private func percentEncodeFormValue(_ value: String) -> String {
        if value.contains("%") && isPercentEncoded(value) {
            return value
        }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=;+")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func isPercentEncoded(_ value: String) -> Bool {
        let pattern = "%[0-9A-Fa-f]{2}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(value.startIndex..., in: value)
        let matches = regex.matches(in: value, range: range)
        let nonPercentCount = value.count - matches.reduce(0) { $0 + ($1.range.length) }
        return matches.count > 0 && nonPercentCount < value.count
    }

    func fetchData(url: URL, option: LegadoUrlOption? = nil) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        if let option {
            if option.method == "POST" {
                request.httpMethod = "POST"
                if let body = option.body {
                    if body.contains("{") && body.contains("}") {
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.httpBody = body.data(using: .utf8)
                    } else {
                        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                        let encodedBody = encodeFormBody(body)
                        request.httpBody = encodedBody.data(using: .utf8)
                    }
                }
            }
            for (key, value) in option.headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (400...499).contains(http.statusCode) {
                throw BookSourceError.sourceUnavailable
            }
            return data
        } catch let error as URLError {
            throw BookSourceError.network(Self.friendlyMessage(for: error))
        } catch {
            throw BookSourceError.network("请求失败，请稍后再试。")
        }
    }

    private func fetch(url: URL) async throws -> String {
        let data = try await fetchData(url: url)
        return EncodingDetector.decode(data: data)
    }

    private func resolvedSearchURL(template: String, query: String, base: String) -> (url: URL, option: LegadoUrlOption) {
        let (rawUrl, option) = LegadoUrlParser.parse(template, searchKey: query)
        let absolute = LegadoUrlParser.resolveURL(base: base, relative: rawUrl)
        let url = URL(string: absolute) ?? URL(string: base)!
        return (url, option)
    }

    private func resolvedURL(path: String, base: String) -> URL {
        let absolute = LegadoUrlParser.resolveURL(base: base, relative: path)
        return URL(string: absolute) ?? URL(string: base)!
    }

    func parseSearchResultsForTest(html: String, source: BookSource, ruleType: SourceRuleType, baseURL: URL? = nil) throws -> [OnlineSearchResult] {
        try parseSearchResults(html: html, source: source, ruleType: ruleType, baseURL: baseURL)
    }

    func parseChapterListForTest(html: String, source: BookSource, ruleType: SourceRuleType, baseURL: URL? = nil) throws -> [OnlineChapter] {
        try parseChapterList(html: html, source: source, ruleType: ruleType, baseURL: baseURL)
    }

    private func parseSearchResults(html: String, source: BookSource, ruleType: SourceRuleType, baseURL: URL? = nil) throws -> [OnlineSearchResult] {
        var results: [OnlineSearchResult] = []
        let base = baseURL?.absoluteString ?? source.url

        switch ruleType {
        case .css:
            let doc = try SwiftSoup.parse(html)
            let rawCssRule = SourceRuleType.stripCSSPrefix(source.searchRule)
            let cssRule = LegadoSelector.isLegadoSelector(rawCssRule) ? LegadoSelector.toCSS(rawCssRule) : rawCssRule
            for selector in searchResultSelectors(primary: cssRule) {
                var selectorResults: [OnlineSearchResult] = []
                let nodes = try doc.select(selector)
                for node in nodes {
                    let title = (try? extractCSS(from: node, rule: source.titleRule)) ?? ""
                    if title.isEmpty { continue }
                    let author = try? extractCSS(from: node, rule: source.authorRule)
                    let bookUrlRule = source.bookUrlRule.isEmpty ? source.chapterUrlRule : source.bookUrlRule
                    let bookUrl = try extractCSS(from: node, rule: bookUrlRule)
                    let intro = try? extractCSS(from: node, rule: source.introRule)
                    selectorResults.append(OnlineSearchResult(
                        title: title,
                        author: author,
                        bookUrl: resolvedURL(path: bookUrl, base: base).absoluteString,
                        intro: intro?.isEmpty == false ? intro : nil,
                        sourceId: source.id,
                        sourceName: source.name
                    ))
                }

                if selectorResults.isEmpty == false {
                    results = selectorResults
                    break
                }
            }
        case .xpath:
            let xpath = SourceRuleType.stripXPathPrefix(source.searchRule)
            let nodes = XPathEvaluator.evaluate(html: html, xpath: xpath)
            for node in nodes {
                let title = extractXPath(from: node, rule: source.titleRule)
                if title.isEmpty { continue }
                let author = extractXPath(from: node, rule: source.authorRule)
                let bookUrlRule = source.bookUrlRule.isEmpty ? source.chapterUrlRule : source.bookUrlRule
                let bookUrl = extractXPath(from: node, rule: bookUrlRule)
                let intro = extractXPath(from: node, rule: source.introRule)
                results.append(OnlineSearchResult(
                    title: title,
                    author: author,
                    bookUrl: resolvedURL(path: bookUrl, base: base).absoluteString,
                    intro: intro.isEmpty == false ? intro : nil,
                    sourceId: source.id,
                    sourceName: source.name
                ))
            }
        case .js:
            let (cssPart, jsPart) = SourceRuleType.splitJS(source.searchRule)
            let cssSelector = LegadoSelector.isLegadoSelector(cssPart) ? LegadoSelector.toCSS(cssPart) : SourceRuleType.stripCSSPrefix(cssPart)
            let doc = try SwiftSoup.parse(html)
            if cssSelector.isEmpty == false {
                results = collectSearchResults(from: doc, source: source, base: base, primarySelector: cssSelector)
            }
            if results.isEmpty {
                let jsResult = LegadoJSBridge().execute(jsCode: jsPart, result: html, baseUrl: base, book: nil, source: nil)
                if jsResult.isEmpty == false {
                    let jsDoc = try SwiftSoup.parse(jsResult)
                    results = collectSearchResults(from: jsDoc, source: source, base: base, primarySelector: "")
                }
            }
        default:
            return []
        }
        return results
    }

    private func searchResultSelectors(primary: String) -> [String] {
        let candidates = [
            primary,
            "ul.txt-list li",
            ".txt-list li",
            ".result-list > div",
            ".result-list div",
            ".result-item",
            "#sitembox > dl"
        ]

        var seen: Set<String> = []
        return candidates.compactMap { selector in
            let trimmed = selector.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false, seen.contains(trimmed) == false else {
                return nil
            }
            seen.insert(trimmed)
            return trimmed
        }
    }

    private func collectSearchResults(from doc: Document, source: BookSource, base: String, primarySelector: String) -> [OnlineSearchResult] {
        for selector in searchResultSelectors(primary: primarySelector) {
            var batch: [OnlineSearchResult] = []
            guard let nodes = try? doc.select(selector) else { continue }
            for node in nodes {
                let title = (try? extractCSS(from: node, rule: source.titleRule)) ?? ""
                if title.isEmpty { continue }
                let author = try? extractCSS(from: node, rule: source.authorRule)
                let bookUrlRule = source.bookUrlRule.isEmpty ? source.chapterUrlRule : source.bookUrlRule
                let bookUrl = (try? extractCSS(from: node, rule: bookUrlRule)) ?? ""
                let intro = try? extractCSS(from: node, rule: source.introRule)
                batch.append(OnlineSearchResult(
                    title: title,
                    author: author,
                    bookUrl: resolvedURL(path: bookUrl, base: base).absoluteString,
                    intro: intro?.isEmpty == false ? intro : nil,
                    sourceId: source.id,
                    sourceName: source.name
                ))
            }
            if batch.isEmpty == false {
                return batch
            }
        }
        return []
    }

    private func chapterListPageURLs(html: String, currentURL: URL) throws -> [URL] {
        let doc = try SwiftSoup.parse(html, currentURL.absoluteString)
        let optionValues = try doc.select(".index-container option[value], #indexselect option[value], select option[value]")
            .array()
            .compactMap { try? $0.attr("value") }
        let linkValues = try doc.select(".index-container a[href]")
            .array()
            .compactMap { try? $0.attr("href") }
        let values = optionValues.isEmpty ? linkValues : optionValues

        var seen: Set<String> = []
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false,
                  trimmed.hasPrefix("javascript:") == false else {
                return nil
            }

            let absolute = LegadoUrlParser.resolveURL(base: currentURL.absoluteString, relative: trimmed)
            guard let url = URL(string: absolute) else {
                return nil
            }

            let key = url.absoluteString
            guard seen.contains(key) == false else {
                return nil
            }
            seen.insert(key)
            return url
        }
    }

    private func normalizedChapterList(_ chapters: [OnlineChapter]) -> [OnlineChapter] {
        var seenURLs: Set<String> = []
        let unique = chapters.enumerated().compactMap { index, chapter -> (index: Int, number: Int?, chapter: OnlineChapter)? in
            guard seenURLs.contains(chapter.url) == false else {
                return nil
            }
            seenURLs.insert(chapter.url)
            return (index, chapterNumber(in: chapter.title), chapter)
        }

        let numberedCount = unique.filter { $0.number != nil }.count
        guard numberedCount > unique.count / 2 else {
            return unique.map(\.chapter)
        }

        return unique.sorted { lhs, rhs in
            switch (lhs.number, rhs.number) {
            case let (left?, right?) where left != right:
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.index < rhs.index
            }
        }.map(\.chapter)
    }

    private func chapterNumber(in title: String) -> Int? {
        let arabicPattern = #"第\s*0*([0-9]+)\s*章"#
        if let regex = try? NSRegularExpression(pattern: arabicPattern),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let range = Range(match.range(at: 1), in: title),
           let number = Int(title[range]) {
            return number
        }

        let chinesePattern = #"第\s*([零〇一二两三四五六七八九十百千万]+)\s*章"#
        guard let regex = try? NSRegularExpression(pattern: chinesePattern),
              let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let range = Range(match.range(at: 1), in: title) else {
            return nil
        }

        return chineseNumber(String(title[range]))
    }

    private func chineseNumber(_ text: String) -> Int? {
        let digits: [Character: Int] = [
            "零": 0, "〇": 0,
            "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]
        let units: [Character: Int] = [
            "十": 10,
            "百": 100,
            "千": 1_000,
            "万": 10_000
        ]

        var total = 0
        var section = 0
        var digit = 0
        var hasNumber = false

        for character in text {
            if let value = digits[character] {
                digit = value
                hasNumber = true
                continue
            }

            guard let unit = units[character] else {
                return nil
            }

            hasNumber = true
            if unit == 10_000 {
                section += digit == 0 ? 1 : digit
                total += section * unit
                section = 0
            } else {
                section += (digit == 0 ? 1 : digit) * unit
            }
            digit = 0
        }

        guard hasNumber else {
            return nil
        }

        return total + section + digit
    }

    private func parseChapterList(html: String, source: BookSource, ruleType: SourceRuleType, baseURL: URL? = nil) throws -> [OnlineChapter] {
        var chapters: [OnlineChapter] = []
        let base = baseURL?.absoluteString ?? source.url

        switch ruleType {
        case .css:
            let doc = try SwiftSoup.parse(html)
            let rawCssRule = SourceRuleType.stripCSSPrefix(source.chapterListRule)
            let cssRule = LegadoSelector.isLegadoSelector(rawCssRule) ? LegadoSelector.toCSS(rawCssRule) : rawCssRule
            let nodes = try doc.select(cssRule)
            for node in nodes {
                let title = (try? extractCSS(from: node, rule: source.chapterTitleRule)) ?? ""
                let url = try extractCSS(from: node, rule: source.chapterUrlRule)
                guard url.isEmpty == false else { continue }
                let absoluteUrl = resolvedURL(path: url, base: base).absoluteString
                guard isLikelyChapterUrl(absoluteUrl, title: title) else { continue }
                chapters.append(OnlineChapter(
                    title: title.isEmpty ? "未命名章节" : title,
                    url: absoluteUrl
                ))
            }
        case .xpath:
            let xpath = SourceRuleType.stripXPathPrefix(source.chapterListRule)
            let nodes = XPathEvaluator.evaluate(html: html, xpath: xpath)
            for node in nodes {
                let title = extractXPath(from: node, rule: source.chapterTitleRule)
                let url = extractXPath(from: node, rule: source.chapterUrlRule)
                guard url.isEmpty == false else { continue }
                let absoluteUrl = resolvedURL(path: url, base: base).absoluteString
                guard isLikelyChapterUrl(absoluteUrl, title: title) else { continue }
                chapters.append(OnlineChapter(
                    title: title.isEmpty ? "未命名章节" : title,
                    url: absoluteUrl
                ))
            }
        case .js:
            let (cssPart, jsPart) = SourceRuleType.splitJS(source.chapterListRule)
            let cssSelector = LegadoSelector.isLegadoSelector(cssPart) ? LegadoSelector.toCSS(cssPart) : SourceRuleType.stripCSSPrefix(cssPart)
            let doc = try SwiftSoup.parse(html)
            if cssSelector.isEmpty == false {
                let nodes = try doc.select(cssSelector)
                for node in nodes {
                    let title = (try? extractCSS(from: node, rule: source.chapterTitleRule)) ?? ""
                    let url = (try? extractCSS(from: node, rule: source.chapterUrlRule)) ?? ""
                    guard url.isEmpty == false else { continue }
                    let absoluteUrl = resolvedURL(path: url, base: base).absoluteString
                    guard isLikelyChapterUrl(absoluteUrl, title: title) else { continue }
                    chapters.append(OnlineChapter(
                        title: title.isEmpty ? "未命名章节" : title,
                        url: absoluteUrl
                    ))
                }
            }
            if chapters.isEmpty {
                let jsResult = LegadoJSBridge().execute(jsCode: jsPart, result: html, baseUrl: base, book: nil, source: nil)
                if jsResult.isEmpty == false {
                    let jsDoc = try SwiftSoup.parse(jsResult)
                    let nodes = try jsDoc.select("a[href]")
                    for node in nodes {
                        let title = (try? node.text()) ?? ""
                        let url = (try? node.attr("href")) ?? ""
                        guard url.isEmpty == false else { continue }
                        let absoluteUrl = resolvedURL(path: url, base: base).absoluteString
                        guard isLikelyChapterUrl(absoluteUrl, title: title) else { continue }
                        chapters.append(OnlineChapter(
                            title: title.isEmpty ? "未命名章节" : title,
                            url: absoluteUrl
                        ))
                    }
                }
            }
        default:
            return []
        }
        return chapters
    }

    private func parseSearchResultsJSON(data: Data, source: BookSource, baseURL: URL? = nil) -> [OnlineSearchResult] {
        let path = SourceRuleType.stripJSONPathPrefix(source.searchRule)
        let nodes = JSONPathEvaluator.evaluate(jsonData: data, path: path)
        let base = baseURL?.absoluteString ?? source.url

        var results: [OnlineSearchResult] = []
        for node in nodes {
            let title = applyLegadoRules(JSONPathEvaluator.extractAttribute(from: node, rule: source.titleRule), source.titleRule)
            if title.isEmpty { continue }
            let author = applyLegadoRules(JSONPathEvaluator.extractAttribute(from: node, rule: source.authorRule), source.authorRule)
            let bookUrlRule = source.bookUrlRule.isEmpty ? source.chapterUrlRule : source.bookUrlRule
            let bookUrl = applyLegadoRules(JSONPathEvaluator.extractAttribute(from: node, rule: bookUrlRule), bookUrlRule)
            let intro = applyLegadoRules(JSONPathEvaluator.extractAttribute(from: node, rule: source.introRule), source.introRule)
            results.append(OnlineSearchResult(
                title: title,
                author: author,
                bookUrl: resolvedURL(path: bookUrl, base: base).absoluteString,
                intro: intro.isEmpty == false ? intro : nil,
                sourceId: source.id,
                sourceName: source.name
            ))
        }
        return results
    }

    private func applyLegadoRules(_ text: String, _ rule: String) -> String {
        var result = text

        if let replaceRange = rule.range(of: "##") {
            let afterHashes = String(rule[replaceRange.upperBound...])
            let segments = afterHashes.split(separator: "|", maxSplits: 1).map(String.init)

            if segments.count == 1 {
                let patterns = segments[0].split(separator: "@").map(String.init)
                let replacement = ""
                for pattern in patterns {
                    if pattern.isEmpty == false, let regex = try? NSRegularExpression(pattern: pattern) {
                        let range = NSRange(result.startIndex..., in: result)
                        result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
                    }
                }
            } else if segments.count == 2 {
                let patterns = segments[0].split(separator: "@").map(String.init)
                let replacement = segments[1]
                for pattern in patterns {
                    if pattern.isEmpty == false, let regex = try? NSRegularExpression(pattern: pattern) {
                        let range = NSRange(result.startIndex..., in: result)
                        result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
                    }
                }
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseContent(html: String, source: BookSource, ruleType: SourceRuleType) throws -> String {
        switch ruleType {
        case .css:
            let doc = try SwiftSoup.parse(html)
            let rawRule = SourceRuleType.stripCSSPrefix(source.contentRule)
            let selector: String
            let attr: String

            if let atIndex = rawRule.lastIndex(of: "@") {
                selector = String(rawRule[..<atIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                attr = String(rawRule[rawRule.index(after: atIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                selector = rawRule
                attr = "text"
            }

            let resolvedSelector = LegadoSelector.isLegadoSelector(selector) ? LegadoSelector.toCSS(selector) : selector
            let nodes = try doc.select(resolvedSelector)

            if attr == "html" || attr == "innerHTML" {
                let htmlContent = try nodes.html()
                return formatHTMLContent(htmlContent)
            }

            if attr.isEmpty || attr == "text" {
                let htmlContent = try nodes.html()
                return formatHTMLContent(htmlContent)
            }

            return try nodes.attr(attr)

        case .xpath:
            let xpath = SourceRuleType.stripXPathPrefix(source.contentRule)
            let nodes = XPathEvaluator.evaluate(html: html, xpath: xpath)
            return nodes.map(\.text).joined(separator: "\n")
        case .js:
            let (cssPart, jsPart) = SourceRuleType.splitJS(source.contentRule)
            if cssPart.isEmpty {
                return LegadoJSBridge().execute(jsCode: jsPart, result: html, baseUrl: source.url, book: nil, source: nil)
            }
            let cssSelector = LegadoSelector.isLegadoSelector(cssPart) ? LegadoSelector.toCSS(cssPart) : SourceRuleType.stripCSSPrefix(cssPart)
            let doc = try SwiftSoup.parse(html)
            let nodes = try doc.select(cssSelector)
            let initial = try nodes.html()
            return LegadoJSBridge().execute(jsCode: jsPart, result: initial, baseUrl: source.url, book: nil, source: nil)
        default:
            return ""
        }
    }

    private func isLikelyChapterUrl(_ url: String, title: String) -> Bool {
        if url.contains("fenlei") || url.contains("category") || url.contains("list") {
            return false
        }
        if url.hasSuffix("/") || url.hasSuffix("/index.html") || url.hasSuffix("/index.htm") {
            return false
        }
        let titleTrimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if titleTrimmed.contains("小说") || titleTrimmed.contains("首页") || titleTrimmed.contains("排行") || titleTrimmed.contains("分类") {
            return false
        }
        if titleTrimmed.contains("书架") || titleTrimmed.contains("完本") || titleTrimmed.contains("下载") {
            return false
        }
        if titleTrimmed.contains("阅读记录") || titleTrimmed.contains("设置") || titleTrimmed.contains("登录") || titleTrimmed.contains("注册") {
            return false
        }
        if titleTrimmed.contains("玄幻") || titleTrimmed.contains("武侠") || titleTrimmed.contains("都市") || titleTrimmed.contains("历史") {
            return false
        }
        if titleTrimmed.contains("科幻") || titleTrimmed.contains("网游") || titleTrimmed.contains("女生") || titleTrimmed.contains("男生") {
            return false
        }
        return true
    }

    private func formatHTMLContent(_ html: String) -> String {
        OnlineContentFormatter.cleanHTML(html)
    }

    private func extractCSS(from element: Element, rule: String) throws -> String {
        if LegadoSelector.isLegadoSelector(rule) {
            return LegadoSelector.selectTextFromElement(element, selector: rule)
        }
        var trimmed = SourceRuleType.stripCSSPrefix(rule)
        if LegadoSelector.isLegadoSelector(trimmed) {
            return LegadoSelector.selectTextFromElement(element, selector: trimmed)
        }
        if trimmed.hasPrefix("*") {
            trimmed = String(trimmed.dropFirst())
        }

        if let atIndex = trimmed.lastIndex(of: "@") {
            let selector = String(trimmed[..<atIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let attr = String(trimmed[trimmed.index(after: atIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

            if selector.isEmpty {
                if attr.isEmpty || attr == "text" {
                    return try element.text()
                }
                if attr == "html" || attr == "innerHTML" {
                    return try element.html()
                }
                return try element.attr(attr)
            }

            guard let target = try element.select(selector).first() else {
                return ""
            }

            if attr.isEmpty || attr == "text" {
                return try target.text()
            }
            if attr == "html" || attr == "innerHTML" {
                return try target.html()
            }
            return try target.attr(attr)
        }

        if trimmed.isEmpty {
            return try element.text()
        }

        if let selected = try element.select(trimmed).first() {
            return try selected.text()
        }
        return try element.text()
    }

    private func extractXPath(from node: XPathNode, rule: String) -> String {
        var trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = SourceRuleType.stripXPathPrefix(trimmed)

        if trimmed.hasSuffix("@text") || trimmed.hasSuffix("/text()") {
            return node.text
        }

        if trimmed.hasSuffix("@href") {
            return node.href ?? ""
        }

        if trimmed.hasSuffix("@html") || trimmed.hasSuffix("/html()") {
            return node.html ?? ""
        }

        if trimmed.hasPrefix("@") {
            let attrName = String(trimmed.dropFirst())
            if attrName == "text" {
                return node.text
            }
            if attrName == "href" {
                return node.href ?? ""
            }
            return ""
        }

        return node.text
    }

    private static func friendlyMessage(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            "没有网络连接，请检查网络后重试。"
        case .timedOut:
            "请求超时，请稍后再试。"
        case .cannotConnectToHost, .cannotFindHost:
            "无法连接到服务器。"
        case .cancelled:
            "已暂停加载。"
        default:
            "网络异常，请稍后再试。"
        }
    }
}

enum SourceRuleType {
    case css
    case xpath
    case jsonpath
    case js
    case unknown

    static func detect(_ rule: String?) -> SourceRuleType? {
        guard let rule, rule.isEmpty == false else { return nil }
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower.hasPrefix("xpath:") || lower.hasPrefix("@xpath:") {
            return .xpath
        }
        if lower.hasPrefix("css:") || lower.hasPrefix("@css:") {
            return .css
        }
        if lower.hasPrefix("json:") || lower.hasPrefix("@json:") || lower.hasPrefix("$.") {
            return .jsonpath
        }
        if lower.contains("<js>") || lower.contains("@js:") || lower.hasPrefix("js:") {
            return .js
        }

        if trimmed.hasPrefix("//") || trimmed.hasPrefix(".//") || trimmed.hasPrefix("(") {
            return .xpath
        }

        if trimmed.hasPrefix(".") && trimmed.contains("[") {
            return .jsonpath
        }

        if trimmed.contains("##") || trimmed.contains("@put:") {
            if trimmed.hasPrefix(".") || trimmed.hasPrefix("$") {
                return .jsonpath
            }
        }

        if trimmed.hasPrefix("class.") || trimmed.hasPrefix("id.") || trimmed.hasPrefix("tag.") {
            return .css
        }

        return .css
    }

    static func stripXPathPrefix(_ rule: String) -> String {
        var result = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.lowercased().hasPrefix("@xpath:") {
            result = String(result.dropFirst("@xpath:".count))
        } else if result.lowercased().hasPrefix("xpath:") {
            result = String(result.dropFirst("xpath:".count))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stripCSSPrefix(_ rule: String) -> String {
        var result = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.lowercased().hasPrefix("@css:") {
            result = String(result.dropFirst("@css:".count))
        } else if result.lowercased().hasPrefix("css:") {
            result = String(result.dropFirst("css:".count))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stripJSONPathPrefix(_ rule: String) -> String {
        var result = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.lowercased().hasPrefix("@json:") {
            result = String(result.dropFirst("@json:".count))
        } else if result.lowercased().hasPrefix("json:") {
            result = String(result.dropFirst("json:".count))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func splitJS(_ rule: String) -> (css: String, js: String) {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)

        if let openRange = trimmed.range(of: "<js>", options: .caseInsensitive) {
            let css = String(trimmed[..<openRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let afterOpen = String(trimmed[openRange.upperBound...])
            if let closeRange = afterOpen.range(of: "</js>", options: .caseInsensitive) {
                return (css, String(afterOpen[..<closeRange.lowerBound]))
            }
            return (css, afterOpen)
        }

        if let jsRange = trimmed.range(of: "@js:", options: .caseInsensitive) {
            let css = String(trimmed[..<jsRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (css, String(trimmed[jsRange.upperBound...]))
        }

        if trimmed.lowercased().hasPrefix("js:") {
            return ("", String(trimmed.dropFirst(3)))
        }

        return ("", trimmed)
    }
}
