import Foundation

struct JSONPathNode {
    let text: String
    let rawValue: Any?
}

enum JSONPathEvaluator {
    static func evaluate(jsonData: Data, path: String) -> [JSONPathNode] {
        guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
            return []
        }
        return evaluate(object: json, path: path)
    }

    static func evaluate(jsonString: String, path: String) -> [JSONPathNode] {
        guard let data = jsonString.data(using: .utf8) else { return [] }
        return evaluate(jsonData: data, path: path)
    }

    private static func evaluate(object: Any, path: String) -> [JSONPathNode] {
        var current = path.trimmingCharacters(in: .whitespacesAndNewlines)

        if current.hasPrefix("$") {
            current = String(current.dropFirst())
        }

        var working: Any = object

        while current.isEmpty == false {
            if current.hasPrefix(".") {
                current = String(current.dropFirst())
            }

            if current.hasPrefix("[") {
                guard let closeIndex = current.firstIndex(of: "]") else { break }
                let indexStr = String(current[current.index(after: current.startIndex)..<closeIndex])
                current = String(current[current.index(after: closeIndex)...])

                if let index = Int(indexStr) {
                    if let array = working as? [Any], array.indices.contains(index) {
                        working = array[index]
                    } else {
                        return []
                    }
                } else {
                    return []
                }
                continue
            }

            var keyEnd = current.startIndex
            if let dotIndex = current.firstIndex(of: ".") {
                keyEnd = dotIndex
            } else if let bracketIndex = current.firstIndex(of: "[") {
                keyEnd = bracketIndex
            } else {
                keyEnd = current.endIndex
            }

            let key = String(current[..<keyEnd])
            current = String(current[keyEnd...])

            if key == "*" || key.isEmpty {
                continue
            }

            if let dict = working as? [String: Any] {
                if let value = dict[key] {
                    working = value
                } else {
                    return []
                }
            } else {
                return []
            }
        }

        return extractNodes(from: working)
    }

    private static func extractNodes(from object: Any) -> [JSONPathNode] {
        if let array = object as? [Any] {
            return array.map { item in
                JSONPathNode(text: textValue(of: item), rawValue: item)
            }
        }
        return [JSONPathNode(text: textValue(of: object), rawValue: object)]
    }

    static func textValue(of object: Any) -> String {
        if let str = object as? String { return str }
        if let num = object as? NSNumber { return num.stringValue }
        if let dict = object as? [String: Any] {
            if let name = dict["name"] as? String ?? dict["title"] as? String {
                return name
            }
            return dict.values.compactMap { $0 as? String }.first ?? ""
        }
        return ""
    }

    static func extractAttribute(from node: JSONPathNode, rule: String) -> String {
        var current = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.hasPrefix("$") {
            current = String(current.dropFirst())
        }

        if current.hasPrefix("@") {
            current = String(current.dropFirst())
        }

        if current.isEmpty {
            return node.text
        }

        if current.hasPrefix(".") {
            current = String(current.dropFirst())
        }

        var working: Any? = node.rawValue

        while current.isEmpty == false {
            if current.hasPrefix(".") {
                current = String(current.dropFirst())
            }

            if current.hasPrefix("[") {
                guard let closeIndex = current.firstIndex(of: "]") else { break }
                let indexStr = String(current[current.index(after: current.startIndex)..<closeIndex])
                current = String(current[current.index(after: closeIndex)...])

                if let index = Int(indexStr), let array = working as? [Any], array.indices.contains(index) {
                    working = array[index]
                } else {
                    return ""
                }
                continue
            }

            var keyEnd = current.startIndex
            if let dotIndex = current.firstIndex(of: ".") {
                keyEnd = dotIndex
            } else if let bracketIndex = current.firstIndex(of: "[") {
                keyEnd = bracketIndex
            } else {
                keyEnd = current.endIndex
            }

            let key = String(current[..<keyEnd])
            current = String(current[keyEnd...])

            if let dict = working as? [String: Any] {
                working = dict[key]
            } else {
                return ""
            }
        }

        guard let value = working else { return "" }
        return textValue(of: value)
    }
}
