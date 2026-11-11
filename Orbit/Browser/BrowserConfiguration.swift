import Foundation
import WebKit

/// すべてのタブで共有する WebView の設定（通常とプライベート）と、広告ブロック。
@MainActor
final class BrowserConfiguration {
    let standard: WKWebViewConfiguration
    let privateMode: WKWebViewConfiguration
    private(set) var blockList: WKContentRuleList?

    init() {
        standard = Self.make(store: .default())
        privateMode = Self.make(store: .nonPersistent())
    }

    private static func make(store: WKWebsiteDataStore) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = store
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        return config
    }

    /// 広告・トラッカーのブロックリストを用意する（Opera のような内蔵広告ブロック）。
    func prepareBlockList() async -> WKContentRuleList? {
        if let blockList { return blockList }
        let json = ContentBlocker.rulesJSON()
        let list: WKContentRuleList? = await withCheckedContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "orbit-adblock-v1", encodedContentRuleList: json
            ) { list, _ in
                continuation.resume(returning: list)
            }
        }
        blockList = list
        return list
    }

    func applyBlocking(_ enabled: Bool, to webView: WKWebView) {
        let controller = webView.configuration.userContentController
        controller.removeAllContentRuleLists()
        if enabled, let blockList { controller.add(blockList) }
    }
}

enum ContentBlocker {
    /// よく使われる広告・トラッキングのドメイン（少なめの内蔵リスト）。
    static let domains = [
        "doubleclick.net", "googlesyndication.com", "googleadservices.com", "google-analytics.com",
        "googletagservices.com", "adservice.google.com", "adnxs.com", "adsrvr.org", "advertising.com",
        "amazon-adsystem.com", "criteo.com", "criteo.net", "outbrain.com", "taboola.com", "scorecardresearch.com",
        "quantserve.com", "moatads.com", "rubiconproject.com", "pubmatic.com", "openx.net", "casalemedia.com",
        "smartadserver.com", "teads.tv", "yieldmo.com", "sharethrough.com", "media.net", "bidswitch.net",
        "3lift.com", "adform.net", "adroll.com", "zedo.com", "revcontent.com", "mgid.com", "popads.net",
        "propellerads.com", "hotjar.com", "mouseflow.com", "fullstory.com", "mixpanel.com", "segment.io",
        "branch.io", "app-measurement.com", "connect.facebook.net", "ads-twitter.com", "ads.linkedin.com",
        "analytics.tiktok.com", "ads.yahoo.com", "yads.yahoo.co.jp", "yjtag.yahoo.co.jp", "i-mobile.co.jp",
        "microad.jp", "fout.jp", "impact-ad.jp", "ad-stir.com", "nend.net", "adingo.jp", "logly.co.jp",
        "popin.cc", "gmossp-sp.jp", "socdm.com", "ladsp.com", "adtdp.com", "unthem.com",
    ]

    static let hiddenSelectors = [
        ".adsbygoogle", "ins.adsbygoogle", "[id^='div-gpt-ad']", "[id^='google_ads_iframe']",
        "[class*='ad-banner']", "[class^='ad_']", ".ad-slot", ".advertisement", "[data-ad-slot]",
        ".OUTBRAIN", ".trc_related_container", "#taboola-below-article-thumbnails",
    ]

    static func rulesJSON() -> String {
        var rules: [[String: Any]] = domains.map { domain in
            let escaped = domain.replacingOccurrences(of: ".", with: "\\.")
            return [
                "trigger": ["url-filter": "^[htps]+://([a-z0-9-]+\\.)*\(escaped)[/:?]", "load-type": ["third-party"]],
                "action": ["type": "block"],
            ]
        }
        rules.append([
            "trigger": ["url-filter": ".*"],
            "action": ["type": "css-display-none", "selector": hiddenSelectors.joined(separator: ", ")],
        ])
        let data = (try? JSONSerialization.data(withJSONObject: rules)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
