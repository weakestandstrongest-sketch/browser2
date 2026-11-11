import Foundation
import Observation
import WebKit

/// タブ・スペース（Arc）・ピン留め・アーカイブ・プライベートタブをまとめて持つ。
@MainActor
@Observable
final class TabStore {
    private static let sessionKey = "session.v2"
    private static let archiveKey = "archive.v1"

    var tabs: [BrowserTab] = []
    var spaces: [BrowserSpace] = BrowserSpace.defaults
    var currentSpaceID: UUID
    var selectedID: UUID?
    var archived: [ArchivedTab] = []
    /// スクロール中はツールバーを小さくする（Safari / Arc）
    var chromeCollapsed = false
    var adBlockEnabled = false

    @ObservationIgnored let configuration: BrowserConfiguration
    @ObservationIgnored private var lastSelected: [UUID: UUID] = [:]
    /// ページを見終わったとき（履歴用）
    @ObservationIgnored var onPageVisited: ((URL, String) -> Void)?

    init() {
        configuration = BrowserConfiguration()
        currentSpaceID = BrowserSpace.defaults[0].id
    }

    // MARK: Lookup

    var current: BrowserTab? {
        if let selectedID, let tab = tabs.first(where: { $0.id == selectedID }) { return tab }
        return tabs(in: currentSpaceID).first
    }

    var currentSpace: BrowserSpace {
        if currentSpaceID == BrowserSpace.privateID { return .privateSpace }
        return spaces.first { $0.id == currentSpaceID } ?? spaces.first ?? BrowserSpace.defaults[0]
    }

    var isPrivate: Bool { currentSpaceID == BrowserSpace.privateID }

    func space(for id: UUID) -> BrowserSpace {
        if id == BrowserSpace.privateID { return .privateSpace }
        return spaces.first { $0.id == id } ?? currentSpace
    }

    /// ピン留めを先に、その後は開いた順
    func tabs(in spaceID: UUID) -> [BrowserTab] {
        let inSpace = tabs.filter { $0.spaceID == spaceID }
        return inSpace.filter(\.isPinned) + inSpace.filter { !$0.isPinned }
    }

    var currentSpaceTabs: [BrowserTab] { tabs(in: currentSpaceID) }

    // MARK: Tabs

    @discardableResult
    func newTab(url: URL? = nil, select: Bool = true, in spaceID: UUID? = nil, loadNow: Bool = true, title: String? = nil) -> BrowserTab {
        let space = spaceID ?? currentSpaceID
        let config = space == BrowserSpace.privateID ? configuration.privateMode : configuration.standard
        let tab = BrowserTab(url: url, configuration: config, loadNow: loadNow, spaceID: space, title: title)
        configure(tab)
        if let current, current.spaceID == space, let index = tabs.firstIndex(where: { $0.id == current.id }) {
            tabs.insert(tab, at: index + 1)
        } else {
            tabs.append(tab)
        }
        if select { self.select(tab) }
        saveSession()
        return tab
    }

    private func configure(_ tab: BrowserTab) {
        configuration.applyBlocking(adBlockEnabled, to: tab.webView)
        tab.onNavigationCommitted = { [weak self] in
            self?.chromeCollapsed = false
            self?.saveSession()
        }
        tab.onPageFinished = { [weak self] url, title in self?.onPageVisited?(url, title) }
        tab.onScroll = { [weak self, weak tab] down in
            guard let self, let tab, tab.id == self.current?.id else { return }
            if self.chromeCollapsed != down { self.chromeCollapsed = down }
        }
    }

    func select(_ tab: BrowserTab) {
        selectedID = tab.id
        currentSpaceID = tab.spaceID
        lastSelected[tab.spaceID] = tab.id
        chromeCollapsed = false
        tab.activate()
        saveSession()
    }

    /// アドレスバーを左右にスワイプしたとき（同じスペースの隣のタブへ）
    func selectAdjacent(_ offset: Int) {
        let list = currentSpaceTabs
        guard let current, let index = list.firstIndex(where: { $0.id == current.id }) else { return }
        let next = index + offset
        guard list.indices.contains(next) else { return }
        select(list[next])
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tab.webView.stopLoading()
        let space = tab.spaceID
        let siblings = tabs(in: space)
        let position = siblings.firstIndex { $0.id == tab.id } ?? 0
        tabs.remove(at: index)
        if selectedID == tab.id {
            let rest = tabs(in: space)
            if rest.isEmpty {
                if space == BrowserSpace.privateID {
                    switchSpace(to: spaces.first?.id ?? currentSpaceID)
                } else {
                    newTab(in: space)
                }
            } else {
                select(rest[min(position, rest.count - 1)])
            }
        }
        saveSession()
    }

    func closeAll(in spaceID: UUID) {
        for tab in tabs where tab.spaceID == spaceID && !tab.isPinned { tab.webView.stopLoading() }
        tabs.removeAll { $0.spaceID == spaceID && !$0.isPinned }
        if tabs(in: spaceID).isEmpty, spaceID != BrowserSpace.privateID {
            newTab(in: spaceID)
        } else if let first = tabs(in: spaceID).first {
            select(first)
        } else {
            switchSpace(to: spaces.first?.id ?? currentSpaceID)
        }
        saveSession()
    }

    /// Opens `url` in the current tab (or a new one if there is none).
    func open(_ url: URL) {
        if let current { current.load(url) } else { newTab(url: url) }
        chromeCollapsed = false
        saveSession()
    }

    func togglePin(_ tab: BrowserTab) {
        tab.isPinned.toggle()
        saveSession()
    }

    func move(_ tab: BrowserTab, to spaceID: UUID) {
        guard !tab.isPrivate, spaceID != BrowserSpace.privateID else { return }
        tab.spaceID = spaceID
        if selectedID == tab.id { currentSpaceID = spaceID }
        saveSession()
    }

    // MARK: Spaces

    func switchSpace(to id: UUID) {
        currentSpaceID = id
        let list = tabs(in: id)
        if let last = lastSelected[id], let tab = list.first(where: { $0.id == last }) {
            select(tab)
        } else if let tab = list.max(by: { $0.lastViewed < $1.lastViewed }) {
            select(tab)
        } else {
            newTab(in: id)
        }
    }

    @discardableResult
    func addSpace(name: String, icon: String, theme: SpaceTheme) -> BrowserSpace {
        let space = BrowserSpace(name: name, icon: icon, theme: theme)
        spaces.append(space)
        saveSession()
        return space
    }

    func updateSpace(_ space: BrowserSpace) {
        guard let index = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        spaces[index] = space
        saveSession()
    }

    func deleteSpace(_ space: BrowserSpace) {
        guard spaces.count > 1, let index = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        spaces.remove(at: index)
        let fallback = spaces[0].id
        for tab in tabs where tab.spaceID == space.id { tab.spaceID = fallback }
        if currentSpaceID == space.id { switchSpace(to: fallback) }
        saveSession()
    }

    // MARK: Auto archive (Arc)

    func archiveStale(after interval: TimeInterval?) {
        guard let interval else { return }
        let limit = Date().addingTimeInterval(-interval)
        let stale = tabs.filter { tab in
            !tab.isPinned && !tab.isPrivate && tab.id != selectedID && !tab.isBlank && tab.lastViewed < limit
        }
        guard !stale.isEmpty else { return }
        for tab in stale {
            archived.insert(ArchivedTab(title: tab.displayTitle, url: tab.url?.absoluteString ?? "", spaceID: tab.spaceID, archivedAt: Date()), at: 0)
            tab.webView.stopLoading()
        }
        let ids = Set(stale.map(\.id))
        tabs.removeAll { ids.contains($0.id) }
        archived = Array(archived.prefix(150))
        saveArchive()
        saveSession()
    }

    func restore(_ item: ArchivedTab) {
        archived.removeAll { $0.id == item.id }
        saveArchive()
        let space = spaces.contains { $0.id == item.spaceID } ? item.spaceID : currentSpaceID
        newTab(url: URL(string: item.url), in: space)
    }

    func clearArchive() {
        archived = []
        saveArchive()
    }

    // MARK: Ad blocking (Opera)

    func setAdBlock(_ enabled: Bool) async {
        adBlockEnabled = enabled
        if enabled { _ = await configuration.prepareBlockList() }
        for tab in tabs { configuration.applyBlocking(enabled, to: tab.webView) }
    }

    // MARK: Persistence (private tabs are never saved)

    private struct SavedTab: Codable {
        var id: UUID
        var url: String?
        var title: String
        var spaceID: UUID
        var pinned: Bool
        var lastViewed: Date
    }

    private struct Session: Codable {
        var spaces: [BrowserSpace]
        var currentSpaceID: UUID
        var tabs: [SavedTab]
        var selectedID: UUID?
    }

    func saveSession() {
        let saved = tabs.filter { !$0.isPrivate }.map {
            SavedTab(id: $0.id, url: $0.url?.absoluteString, title: $0.displayTitle, spaceID: $0.spaceID, pinned: $0.isPinned, lastViewed: $0.lastViewed)
        }
        let space = currentSpaceID == BrowserSpace.privateID ? (spaces.first?.id ?? currentSpaceID) : currentSpaceID
        let selected = current?.isPrivate == true ? nil : selectedID
        let session = Session(spaces: spaces, currentSpaceID: space, tabs: saved, selectedID: selected)
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: Self.sessionKey)
        }
    }

    private func saveArchive() {
        if let data = try? JSONEncoder().encode(archived) {
            UserDefaults.standard.set(data, forKey: Self.archiveKey)
        }
    }

    func restoreSession() {
        guard tabs.isEmpty else { return }
        if let data = UserDefaults.standard.data(forKey: Self.archiveKey),
           let list = try? JSONDecoder().decode([ArchivedTab].self, from: data) {
            archived = list
        }
        guard let data = UserDefaults.standard.data(forKey: Self.sessionKey),
              let session = try? JSONDecoder().decode(Session.self, from: data),
              !session.spaces.isEmpty else {
            spaces = BrowserSpace.defaults
            currentSpaceID = spaces[0].id
            newTab()
            return
        }
        spaces = session.spaces
        currentSpaceID = session.spaces.contains { $0.id == session.currentSpaceID } ? session.currentSpaceID : session.spaces[0].id
        for saved in session.tabs {
            let spaceID = spaces.contains { $0.id == saved.spaceID } ? saved.spaceID : spaces[0].id
            let tab = BrowserTab(id: saved.id, url: saved.url.flatMap(URL.init(string:)), configuration: configuration.standard,
                                 loadNow: false, spaceID: spaceID, title: saved.title)
            tab.isPinned = saved.pinned
            tab.lastViewed = saved.lastViewed
            configure(tab)
            tabs.append(tab)
        }
        if let id = session.selectedID, let tab = tabs.first(where: { $0.id == id }) {
            select(tab)
        } else {
            switchSpace(to: currentSpaceID)
        }
    }

    func clearWebsiteData() async {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await store.removeData(ofTypes: types, modifiedSince: .distantPast)
    }
}
