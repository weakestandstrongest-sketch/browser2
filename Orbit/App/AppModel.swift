import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let tabs: TabStore
    let skills: SkillStore
    let assistant: AssistantEngine

    var showAssistant = false
    var showCommandBar = false
    var showTabs = false
    var showSettings = false
    var showSkills = false

    init() {
        let settings = AppSettings()
        let tabs = TabStore()
        self.settings = settings
        self.tabs = tabs
        self.skills = SkillStore()
        self.assistant = AssistantEngine(settings: settings, tabs: tabs)
        tabs.restoreSession()
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
    func ask(_ text: String, agent: Bool = false) {
        if agent { assistant.agentMode = true }
        let attach = currentPageAttachment()
        presentAssistant {
            self.assistant.send(text, attaching: attach)
        }
    }

    func run(_ skill: Skill, extra: String = "") {
        if skill.usesAgent { assistant.agentMode = true }
        let attach: [BrowserTab]
        switch skill.scope {
        case .currentTab: attach = currentPageAttachment()
        case .allTabs: attach = tabs.tabs.filter { !$0.isBlank }
        case .none: attach = []
        }
        let extraTrimmed = extra.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = extraTrimmed.isEmpty ? skill.prompt : skill.prompt + "\n\n追加の指示: " + extraTrimmed
        let display = "/" + skill.name + (extraTrimmed.isEmpty ? "" : " " + extraTrimmed)
        presentAssistant {
            self.assistant.send(prompt, attaching: attach, displayText: display)
        }
    }

    func currentPageAttachment() -> [BrowserTab] {
        guard let current = tabs.current, !current.isBlank else { return [] }
        return [current]
    }

    private func presentAssistant(then action: @escaping @MainActor () -> Void) {
        let needsDelay = showCommandBar || showTabs || showSkills
        showCommandBar = false
        showTabs = false
        showSkills = false
        Task { @MainActor in
            if needsDelay { try? await Task.sleep(nanoseconds: 450_000_000) }
            self.showAssistant = true
            action()
        }
    }

    func openTabSwitcher() {
        Task { @MainActor in
            await tabs.current?.captureThumbnail()
            showTabs = true
        }
    }
}
