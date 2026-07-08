import Foundation
import XPathBridge

struct XPathNode {
    let text: String
    let href: String?
    let html: String?
}

enum XPathEvaluator {
    static func evaluate(html: String, xpath: String) -> [XPathNode] {
        let result = xpath_evaluate(html, xpath)
        defer { xpath_result_list_free(result) }

        var nodes: [XPathNode] = []
        for i in 0..<result.count {
            let item = result.items[i]
            nodes.append(XPathNode(
                text: item.text.map { String(cString: $0) } ?? "",
                href: item.href.map { String(cString: $0) },
                html: item.html.map { String(cString: $0) }
            ))
        }
        return nodes
    }
}
