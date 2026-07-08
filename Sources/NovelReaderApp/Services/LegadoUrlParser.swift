import Foundation

struct LegadoUrlOption {
    var method: String = "GET"
    var body: String?
    var charset: String?
    var headers: [String: String] = [:]
    var type: String?
}

enum LegadoUrlParser {
    static func parse(_ searchUrl: String, searchKey: String, page: Int? = nil) -> (url: String, option: LegadoUrlOption) {
        var raw = searchUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        var option = LegadoUrlOption()

        if let braceIndex = raw.firstIndex(of: "{") {
            let urlPart = String(raw[..<braceIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let jsonPart = String(raw[braceIndex...])

            if let data = jsonPart.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let method = json["method"] as? String {
                    option.method = method.uppercased()
                }
                if let body = json["body"] as? String {
                    option.body = body
                }
                if let charset = json["charset"] as? String {
                    option.charset = charset
                }
                if let type = json["type"] as? String {
                    option.type = type
                }
                if let headers = json["headers"] as? [String: Any] {
                    for (key, value) in headers {
                        option.headers[key] = String(describing: value)
                    }
                }
                raw = urlPart
            }
        } else if let commaIndex = raw.firstIndex(of: ",") {
            let beforeComma = String(raw[..<commaIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if beforeComma.contains("://") {
                let jsonPart = String(raw[raw.index(after: commaIndex)...])
                if let data = jsonPart.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let method = json["method"] as? String {
                        option.method = method.uppercased()
                    }
                    if let body = json["body"] as? String {
                        option.body = body
                    }
                    if let charset = json["charset"] as? String {
                        option.charset = charset
                    }
                    if let headers = json["headers"] as? [String: Any] {
                        for (key, value) in headers {
                            option.headers[key] = String(describing: value)
                        }
                    }
                    raw = beforeComma
                }
            }
        }

        let encoded = searchKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchKey
        raw = raw
            .replacingOccurrences(of: "{{searchKey}}", with: encoded)
            .replacingOccurrences(of: "{{key}}", with: encoded)
            .replacingOccurrences(of: "searchKey", with: encoded)

        if let page {
            let pageStr = String(page)
            raw = raw
                .replacingOccurrences(of: "{{page}}", with: pageStr)
                .replacingOccurrences(of: "page", with: pageStr)
        }

        if let body = option.body {
            option.body = body
                .replacingOccurrences(of: "{{searchKey}}", with: encoded)
                .replacingOccurrences(of: "{{key}}", with: encoded)
        }

        return (raw, option)
    }

    static func resolveURL(base: String, relative: String) -> String {
        let trimmed = relative.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }

        if trimmed.hasPrefix("//") {
            let scheme = base.hasPrefix("https") ? "https" : "http"
            return "\(scheme):\(trimmed)"
        }

        guard let baseURL = URL(string: base) else { return trimmed }

        if trimmed.hasPrefix("/") {
            let host = baseURL.host ?? ""
            let scheme = baseURL.scheme ?? "https"
            return "\(scheme)://\(host)\(trimmed)"
        }

        if let resolved = URL(string: trimmed, relativeTo: baseURL) {
            return resolved.absoluteString
        }

        let baseString = base
        if baseString.hasSuffix("/") {
            return baseString + trimmed
        }
        return baseString + "/" + trimmed
    }
}
