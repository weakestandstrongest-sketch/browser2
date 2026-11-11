import SwiftUI
import UIKit

struct BrowserView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 0) {
            ZStack {
                if let tab = app.tabs.current {
                    WebViewContainer(webView: tab.webView)
                        .id(tab.id)
                    if tab.isBlank {
                        StartPageView()
                            .transition(.opacity)
                    }
                } else {
                    StartPageView()
                }
            }
            BottomBar()
        }
        .sheet(isPresented: $app.showAssistant) {
            AssistantPanel()
                .environment(app)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $app.showCommandBar) {
            CommandBarView()
                .environment(app)
        }
        .sheet(isPresented: $app.showTabs) {
            TabSwitcherView()
                .environment(app)
        }
        .sheet(isPresented: $app.showSettings) {
            SettingsView()
                .environment(app)
        }
        .sheet(isPresented: $app.showSkills) {
            SkillsView()
                .environment(app)
        }
    }
}

struct BottomBar: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let tab = app.tabs.current
        VStack(spacing: 8) {
            if let tab, tab.isLoading {
                ProgressView(value: tab.progress)
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
                    .frame(height: 2)
                    .padding(.horizontal, -16)
            }

            Button {
                app.showCommandBar = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: tab?.url?.scheme == "https" ? "lock.fill" : "magnifyingglass")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(addressText(tab))
                        .font(.subheadline)
                        .foregroundStyle((tab?.isBlank ?? true) ? Color.secondary : Color.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let tab, !tab.isBlank {
                        Button {
                            tab.isLoading ? tab.stopLoading() : tab.reload()
                        } label: {
                            Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            HStack {
                toolbarButton("chevron.backward", enabled: tab?.canGoBack ?? false) { tab?.goBack() }
                Spacer()
                toolbarButton("chevron.forward", enabled: tab?.canGoForward ?? false) { tab?.goForward() }
                Spacer()
                Button {
                    app.showAssistant = true
                } label: {
                    OrbView(size: 40, animating: app.assistant.isRunning)
                }
                .accessibilityLabel("AIアシスタント")
                Spacer()
                Button {
                    app.openTabSwitcher()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5).strokeBorder(.primary, lineWidth: 1.6).frame(width: 22, height: 22)
                        Text("\(app.tabs.tabs.count)").font(.caption2.weight(.bold))
                    }
                    .frame(width: 44, height: 36)
                }
                .foregroundStyle(.primary)
                Spacer()
                moreMenu(tab)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
    }

    private func addressText(_ tab: BrowserTab?) -> String {
        guard let tab, !tab.isBlank else { return "検索・URL・AIに質問" }
        return URLParser.displayHost(tab.url)
    }

    private func toolbarButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 44, height: 36)
        }
        .disabled(!enabled)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.5))
    }

    private func moreMenu(_ tab: BrowserTab?) -> some View {
        Menu {
            if let tab, let url = tab.url {
                ShareLink(item: url) { Label("共有", systemImage: "square.and.arrow.up") }
                Button {
                    UIPasteboard.general.url = url
                } label: { Label("URLをコピー", systemImage: "doc.on.doc") }
                Divider()
                if let summarize = app.skills.skills.first {
                    Button {
                        app.run(summarize)
                    } label: { Label("このページを\(summarize.name)", systemImage: summarize.icon) }
                }
            }
            Button {
                app.tabs.newTab()
            } label: { Label("新しいタブ", systemImage: "plus.square.on.square") }
            Button {
                app.showSkills = true
            } label: { Label("スキル", systemImage: "wand.and.stars") }
            Button {
                app.showSettings = true
            } label: { Label("設定", systemImage: "gearshape") }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(width: 44, height: 36)
        }
        .foregroundStyle(.primary)
    }
}
