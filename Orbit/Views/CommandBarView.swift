import SwiftUI

/// Dia-style omnibox: one field that can open a URL, search the web, ask the AI, or run a skill.
struct CommandBarView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                if !trimmed.isEmpty {
                    Section {
                        if let url = URLParser.url(from: trimmed) {
                            row("arrow.up.right.square", "開く", url.absoluteString) {
                                app.tabs.open(url); dismiss()
                            }
                        }
                        row("magnifyingglass", "\(app.settings.searchEngine.name)で検索", trimmed) {
                            app.search(trimmed); dismiss()
                        }
                        row("sparkles", "AIに質問", trimmed) {
                            app.ask(trimmed, mode: .chat)
                        }
                        row("globe", "Webでまとめて調べる（AIが複数のページを読む）", trimmed) {
                            app.ask(trimmed, mode: .web)
                        }
                        row("wand.and.stars", "AIに実行させる（ブラウザ操作）", trimmed) {
                            app.ask(trimmed, mode: .agent)
                        }
                    }
                }

                let historyHits = isSkillCommand ? [] : app.history.search(trimmed)
                if !historyHits.isEmpty && app.tabs.current?.url?.absoluteString != trimmed {
                    Section("履歴") {
                        ForEach(historyHits) { entry in
                            row("clock.arrow.circlepath", entry.title.isEmpty ? entry.host : entry.title, entry.url) {
                                if let url = URL(string: entry.url) { app.tabs.open(url) }
                                dismiss()
                            }
                        }
                    }
                }

                let skills = matchingSkills
                if !skills.isEmpty {
                    Section("スキル") {
                        ForEach(skills) { skill in
                            row(skill.icon, "/" + skill.name, skill.prompt) {
                                app.run(skill, extra: skillExtra)
                            }
                        }
                    }
                }

                let tabs = matchingTabs
                if !tabs.isEmpty {
                    Section("開いているタブ") {
                        ForEach(tabs) { tab in
                            row("square.on.square", tab.displayTitle, URLParser.displayHost(tab.url)) {
                                app.tabs.select(tab); dismiss()
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkle.magnifyingglass").foregroundStyle(.secondary)
                    TextField("検索、URL、AIへの質問、/スキル", text: $text)
                        .focused($focused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .onSubmit(submit)
                    if !text.isEmpty {
                        Button { text = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.bottom, 6)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Orbit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .onAppear {
            if let url = app.tabs.current?.url { text = url.absoluteString }
            focused = true
        }
    }

    private var isSkillCommand: Bool { trimmed.hasPrefix("/") }

    private var skillQuery: String {
        guard isSkillCommand else { return "" }
        return String(trimmed.dropFirst()).components(separatedBy: " ").first ?? ""
    }

    private var skillExtra: String {
        guard isSkillCommand, let space = trimmed.firstIndex(of: " ") else { return "" }
        return String(trimmed[space...])
    }

    private var matchingSkills: [Skill] {
        if isSkillCommand {
            let q = skillQuery
            return app.skills.skills.filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) }
        }
        return trimmed.isEmpty || app.tabs.current?.url.map({ $0.absoluteString == trimmed }) == true
            ? app.skills.skills
            : []
    }

    private var matchingTabs: [BrowserTab] {
        let all = app.tabs.tabs.filter { !$0.isBlank }
        guard !trimmed.isEmpty, app.tabs.current?.url?.absoluteString != trimmed else { return all }
        return all.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(trimmed) ||
            ($0.url?.absoluteString.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        if isSkillCommand, let skill = app.skills.skills.first(where: { $0.name == skillQuery }) ?? matchingSkills.first {
            app.run(skill, extra: skillExtra)
            return
        }
        if URLParser.url(from: trimmed) != nil || app.settings.omniboxDefault == .search {
            app.openOrSearch(trimmed)
            dismiss()
        } else {
            app.ask(trimmed, mode: .auto)
        }
    }

    private func row(_ icon: String, _ title: String, _ subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 26)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }
}
