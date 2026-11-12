import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let tabs: TabStore
    let skills: SkillStore
    let history: HistoryStore
    let localAI: LocalAI
    let assistant: AssistantEngine

    var showAssistant = false
    var showCommandBar = false
    /// 左端からのスワイプで出るサイドバー
    var showSidebar = false
    /// AI を全画面に広げているか（false ならページと上下に並ぶ）
    var assistantExpanded = false
    var showSettings = false
    var showSkills = false
    var showModels = false
    /// Comet 風の「…」メニュー
    var showPageMenu = false

    init() {
        let settings = AppSettings()
        let tabs = TabStore()
        let localAI = LocalAI()
        let history = HistoryStore()
        self.settings = settings
        self.tabs = tabs
        self.localAI = localAI
        self.history = history
        self.skills = SkillStore()
        self.assistant = AssistantEngine(settings: settings, tabs: tabs, localAI: localAI)
        tabs.onPageVisited = { [weak history] url, title in history?.record(url: url, title: title) }
        tabs.restoreSession()
        Task { await tabs.setAdBlock(settings.adBlockLevel) }
    }

    /// アプリが前面に来たとき：しばらく見ていないタブをしまい、モデルの状態を確かめる。
    func becameActive() {
        tabs.archiveStale(after: settings.autoArchive.interval)
        localAI.refresh()
    }

    // MARK: Omnibox actions

    func openOrSearch(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let url = URLParser.url(from: text) {
            tabs.open(url)
        } else if let url = URLParser.searchURL(for: text, engine: settings.searchEngine) {
            tabs.open(url)
        }
    }

    func search(_ query: String) {
        guard let url = URLParser.searchURL(for: query, engine: settings.searchEngine) else { return }
        tabs.open(url)
    }

    /// Ask the assistant from anywhere (omnibox, start page). Attaches the current page if there is one.
    func ask(_ text: String, mode: SendMode = .auto) {
        let attach = mode == .web ? [] : currentPageAttachment()
        presentAssistant {
            self.assistant.send(text, attaching: attach, mode: mode)
        }
    }

    func run(_ skill: Skill, extra: String = "") {
        let attach: [BrowserTab]
        switch skill.scope {
        case .currentTab: attach = currentPageAttachment()
        case .allTabs: attach = tabs.currentSpaceTabs.filter { !$0.isBlank }
        case .none: attach = []
        }
        let extraTrimmed = extra.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = extraTrimmed.isEmpty ? skill.prompt : skill.prompt + "\n\n追加の指示: " + extraTrimmed
        let display = "/" + skill.name + (extraTrimmed.isEmpty ? "" : " " + extraTrimmed)
        presentAssistant {
            self.assistant.send(prompt, attaching: attach, displayText: display, mode: skill.usesAgent ? .agent : .chat)
        }
    }

    func currentPageAttachment() -> [BrowserTab] {
        guard let current = tabs.current, !current.isBlank else { return [] }
        return [current]
    }

    private func presentAssistant(then action: @escaping @MainActor () -> Void) {
        let needsDelay = showSkills || showPageMenu
        showPageMenu = false
        showCommandBar = false
        showSidebar = false
        showSkills = false
        Task { @MainActor in
            if needsDelay { try? await Task.sleep(nanoseconds: 450_000_000) }
            self.showAssistant = true
            action()
        }
    }
}
