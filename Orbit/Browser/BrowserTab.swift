import Foundation
import Observation
import UIKit
import WebKit

/// One browser tab backed by its own WKWebView.
@MainActor
@Observable
final class BrowserTab: Identifiable {
    let id: UUID
    var title: String
    var url: URL?
    var isLoading = false
    var progress: Double = 0
    var canGoBack = false
    var canGoForward = false
    var thumbnail: UIImage? = nil
    var spaceID: UUID
    var isPinned = false
    var lastViewed = Date()
    /// パソコン用の表示を頼んでいるか
    var desktopMode = false
    let isPrivate: Bool

    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private var coordinator: TabCoordinator?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    /// まだ読み込んでいない（復元したタブは、開くまで読み込まない）
    @ObservationIgnored private var pendingLoad = false
    @ObservationIgnored private var lastScrollY: CGFloat = 0
    /// Called when the committed URL changes, so the store can persist the session.
    @ObservationIgnored var onNavigationCommitted: (() -> Void)?
    /// Called when a page has finished loading (for history).
    @ObservationIgnored var onPageFinished: ((URL, String) -> Void)?
    /// Called when the user scrolls the page down (true) or up (false).
    @ObservationIgnored var onScroll: ((Bool) -> Void)?

    init(id: UUID = UUID(), url: URL?, configuration: WKWebViewConfiguration, loadNow: Bool = true,
         spaceID: UUID = UUID(), title: String? = nil) {
        self.id = id
        self.url = url
        self.spaceID = spaceID
        self.isPrivate = spaceID == BrowserSpace.privateID
        let host = URLParser.displayHost(url)
        self.title = title ?? (host.isEmpty ? "新しいタブ" : host)
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        // 左端・右端のスワイプはサイドバーと AI に使う（戻るはカプセルの ‹ とサイドバー）
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = true
        webView.isFindInteractionEnabled = true
        if #available(iOS 16.4, *) { webView.isInspectable = true }

        let coordinator = TabCoordinator(tab: self)
        self.coordinator = coordinator
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        coordinator.installRefreshControl(on: webView)

        observeWebView()
        if let url {
            if loadNow { webView.load(URLRequest(url: url)) } else { pendingLoad = true }
        }
    }

    /// 復元したタブを開いたときに読み込む。
    func activate() {
        lastViewed = Date()
        if pendingLoad, let url {
            pendingLoad = false
            webView.load(URLRequest(url: url))
        }
    }

    var isBlank: Bool { url == nil }
    var displayTitle: String { title.isEmpty ? "新しいタブ" : title }

    func load(_ url: URL) {
        self.url = url
        pendingLoad = false
        webView.load(URLRequest(url: url))
    }

    func reload() { webView.reload() }

    func findInPage() {
        webView.findInteraction?.presentFindNavigator(showingReplace: false)
    }

    func toggleDesktopMode() {
        desktopMode.toggle()
        webView.customUserAgent = desktopMode
            ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
            : nil
        webView.reload()
    }
    func stopLoading() { webView.stopLoading() }
    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }

    /// Waits until the page has (mostly) finished loading. Used by the agent after actions.
    func waitForLoad(timeout: TimeInterval = 12) async {
        try? await Task.sleep(nanoseconds: 450_000_000)
        let deadline = Date().addingTimeInterval(timeout)
        while webView.isLoading && Date() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
    }

    /// Runs a JavaScript function body in an isolated content world. The body must return a string.
    func runJS(_ body: String, arguments: [String: Any] = [:]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            webView.callAsyncJavaScript(body, arguments: arguments, in: nil, in: .defaultClient, completionHandler: { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: (value as? String) ?? "")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            })
        }
    }

    func captureThumbnail() async {
        guard !isBlank, webView.bounds.width > 0 else { return }
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = 360
        let image: UIImage? = await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: config, completionHandler: { image, _ in
                continuation.resume(returning: image)
            })
        }
        if let image { thumbnail = image }
    }

    // MARK: State sync

    private func observeWebView() {
        let handler: (WKWebView) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.syncFromWebView() }
        }
        observations = [
            webView.observe(\.title, options: [.new]) { wv, _ in handler(wv) },
            webView.observe(\.url, options: [.new]) { wv, _ in handler(wv) },
            webView.observe(\.isLoading, options: [.new]) { wv, _ in handler(wv) },
            webView.observe(\.estimatedProgress, options: [.new]) { wv, _ in handler(wv) },
            webView.observe(\.canGoBack, options: [.new]) { wv, _ in handler(wv) },
            webView.observe(\.canGoForward, options: [.new]) { wv, _ in handler(wv) },
            webView.scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                let y = scrollView.contentOffset.y
                let dragging = scrollView.isDragging || scrollView.isDecelerating
                MainActor.assumeIsolated { self?.scrolled(to: y, dragging: dragging) }
            },
        ]
    }

    private func scrolled(to y: CGFloat, dragging: Bool) {
        let delta = y - lastScrollY
        guard dragging, abs(delta) > 14 else {
            if !dragging { lastScrollY = y }
            return
        }
        lastScrollY = y
        if y < 40 {
            onScroll?(false)
        } else {
            onScroll?(delta > 0)
        }
    }

    fileprivate func syncFromWebView() {
        let current = webView.url
        if let current, current.absoluteString != "about:blank" {
            if url != current { url = current }
        }
        if let t = webView.title, !t.isEmpty {
            title = t
        } else if let url {
            title = URLParser.displayHost(url)
        }
        isLoading = webView.isLoading
        progress = webView.estimatedProgress
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    fileprivate func didCommitNavigation() {
        syncFromWebView()
        onNavigationCommitted?()
    }

    fileprivate func didFinishNavigation() {
        syncFromWebView()
        onNavigationCommitted?()
        if let url, !isPrivate { onPageFinished?(url, displayTitle) }
    }
}

/// WKWebView delegates for a tab.
@MainActor
final class TabCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var tab: BrowserTab?
    private let refreshControl = UIRefreshControl()

    init(tab: BrowserTab) {
        self.tab = tab
        super.init()
    }

    func installRefreshControl(on webView: WKWebView) {
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
    }

    @objc private func pullToRefresh() {
        tab?.reload()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        tab?.didCommitNavigation()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshControl.endRefreshing()
        tab?.didFinishNavigation()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        refreshControl.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        refreshControl.endRefreshing()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else { return .allow }
        let webSchemes: Set<String> = ["http", "https", "about", "data", "blob", "file", "javascript"]
        if webSchemes.contains(scheme) { return .allow }
        // tel:, mailto:, maps, App Store links etc. → hand off to the system.
        _ = await UIApplication.shared.open(url)
        return .cancel
    }

    /// target="_blank" links open in the same tab.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
