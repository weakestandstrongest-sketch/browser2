import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class TabStore {
    private static let sessionKey = "session.v1"

    var tabs: [BrowserTab] = []
    var selectedID: UUID?

    @ObservationIgnored let configuration: WKWebViewConfiguration

    init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        configuration = config
    }

    var current: BrowserTab? {
        guard let selectedID else { return tabs.first }
        return tabs.first { $0.id == selectedID } ?? tabs.first
    }

    @discardableResult
    func newTab(url: URL? = nil, select: Bool = true) -> BrowserTab {
        let tab = BrowserTab(url: url, configuration: configuration)
        tab.onNavigationCommitted = { [weak self] in self?.saveSession() }
        if let current, let index = tabs.firstIndex(where: { $0.id == current.id }) {
            tabs.insert(tab, at: index + 1)
        } else {
            tabs.append(tab)
        }
        if select { selectedID = tab.id }
        saveSession()
        return tab
    }

    func select(_ tab: BrowserTab) {
        selectedID = tab.id
        saveSession()
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tab.webView.stopLoading()
        tabs.remove(at: index)
        if selectedID == tab.id {
            selectedID = tabs.isEmpty ? nil : tabs[min(index, tabs.count - 1)].id
        }
        if tabs.isEmpty { newTab() }
        saveSession()
    }

    func closeAll() {
        tabs.removeAll()
        selectedID = nil
        newTab()
    }

    /// Opens `url` in the current tab (or a new one if there is none).
    func open(_ url: URL) {
        if let current { current.load(url) } else { newTab(url: url) }
        saveSession()
    }

    // MARK: Persistence

    private struct Session: Codable {
        var urls: [String?]
        var selectedIndex: Int
    }

    func saveSession() {
        let urls = tabs.map { $0.url?.absoluteString }
        let selectedIndex = tabs.firstIndex { $0.id == selectedID } ?? 0
        if let data = try? JSONEncoder().encode(Session(urls: urls, selectedIndex: selectedIndex)) {
            UserDefaults.standard.set(data, forKey: Self.sessionKey)
        }
    }

    func restoreSession() {
        guard tabs.isEmpty else { return }
        if let data = UserDefaults.standard.data(forKey: Self.sessionKey),
           let session = try? JSONDecoder().decode(Session.self, from: data),
           !session.urls.isEmpty {
            for raw in session.urls {
                newTab(url: raw.flatMap(URL.init(string:)), select: false)
            }
            let index = min(max(session.selectedIndex, 0), tabs.count - 1)
            selectedID = tabs[index].id
        } else {
            newTab()
        }
    }

    func clearWebsiteData() async {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await store.removeData(ofTypes: types, modifiedSince: .distantPast)
    }
}
