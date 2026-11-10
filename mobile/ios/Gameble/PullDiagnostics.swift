import UIKit
import WebKit

final class PullDiagnostics: NSObject {
    static let shared = PullDiagnostics()

    var state = ""
    private let enabled = ProcessInfo.processInfo.arguments.contains("-pull_diagnostics")
    private var lowest: CGFloat = 0
    private weak var webView: WKWebView?

    func watch(_ webView: WKWebView, pullsToRefresh: Bool) {
        guard enabled else { return }
        send("activated pulls=\(pullsToRefresh) url=\(webView.url?.path ?? "-")")
        webView.scrollView.panGestureRecognizer.addTarget(self, action: #selector(panned(_:)))
    }

    func moved(_ scrollView: UIScrollView) {
        lowest = min(lowest, scrollView.contentOffset.y)
    }

    @objc private func panned(_ pan: UIPanGestureRecognizer) {
        guard let scrollView = pan.view as? UIScrollView else { return }
        switch pan.state {
        case .began:
            lowest = scrollView.contentOffset.y
            send("began offset=\(scrollView.contentOffset.y) size=\(scrollView.contentSize) bounds=\(scrollView.bounds.size) inset=\(scrollView.adjustedContentInset) bounces=\(scrollView.bounces) always=\(scrollView.alwaysBounceVertical) scrollEnabled=\(scrollView.isScrollEnabled) \(state)")
            probe(scrollView.superview as? WKWebView ?? scrollView.superview?.superview as? WKWebView, at: pan.location(in: scrollView.superview))
        case .ended, .cancelled, .failed:
            send("ended state=\(pan.state.rawValue) lowest=\(lowest) offset=\(scrollView.contentOffset.y) translation=\(pan.translation(in: scrollView).y) \(state)")
        default:
            break
        }
    }

    private func probe(_ webView: WKWebView?, at point: CGPoint) {
        let script = """
        (() => { const s = document.scrollingElement; const e = document.elementFromPoint(\(point.x), \(point.y));
        const c = e ? getComputedStyle(e) : null; const r = getComputedStyle(document.documentElement); const b = getComputedStyle(document.body);
        return `page scroll=${s.scrollTop}/${s.scrollHeight}/${s.clientHeight} html=${r.overflow},${r.overscrollBehaviorY},${r.touchAction},${r.height} body=${b.overflow},${b.overscrollBehaviorY},${b.touchAction},${b.height} at=${e?.tagName}.${e?.className} touch=${c?.touchAction} title=${document.title}` })()
        """
        guard let webView else { return send("probe: no web view") }
        webView.evaluateJavaScript(script) { [weak self] result, error in
            self?.send("\(result ?? error.map { "\($0)" } ?? "nil")")
        }
    }

    private func send(_ line: String) {
        var parts = URLComponents(url: Gameble.rootURL.appending(path: "__log"), resolvingAgainstBaseURL: false)
        parts?.queryItems = [URLQueryItem(name: "line", value: line)]
        guard let url = parts?.url else { return }
        URLSession.shared.dataTask(with: url).resume()
    }
}
