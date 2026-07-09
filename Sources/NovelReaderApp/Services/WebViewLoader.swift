import Foundation
import WebKit

@MainActor
final class WebViewLoader: NSObject, WKNavigationDelegate {
    private var webView: WKWebView!
    private var continuation: CheckedContinuation<String, Error>?
    private var timeoutTimer: Timer?
    private var finishedFlag = false

    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        config.applicationNameForUserAgent = userAgent
        config.websiteDataStore = WKWebsiteDataStore.default()

        webView = WKWebView(frame: .init(x: 0, y: 0, width: 1280, height: 800), configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = userAgent
    }

    func load(url: URL, method: String = "GET", body: String? = nil, timeout: TimeInterval = 12) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.finishedFlag = false

            timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.finish(with: .failure(BookSourceError.network("WebView 加载超时")))
                }
            }

            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
            request.httpMethod = method
            if method == "POST", let body = body {
                request.httpBody = body.data(using: .utf8)
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }

            webView.load(request)
        }
    }

    private func finish(with result: Result<String, Error>) {
        guard finishedFlag == false else { return }
        finishedFlag = true

        timeoutTimer?.invalidate()
        timeoutTimer = nil

        let continuation = self.continuation
        self.continuation = nil

        switch result {
        case .success:
            Task { @MainActor in
                do {
                    let html = try await self.webView.evaluateJavaScript("document.documentElement.outerHTML") as? String ?? ""
                    continuation?.resume(returning: html)
                } catch {
                    continuation?.resume(throwing: error)
                }
            }
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            self.finish(with: .success(""))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.finish(with: .failure(error))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.finish(with: .failure(error))
        }
    }
}
