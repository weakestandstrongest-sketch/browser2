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
        .animation(.snappy(duration: 0.25), value: app.tabs.chromeCollapsed)
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
        .sheet(isPresented: $app.showModels) {
            NavigationStack {
                ModelManagerView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完了") { app.showModels = false }
                        }
                    }
            }
            .environment(app)
        }
    }
}

/// Arc Search / Safari のように下にまとめたツールバー。スペースの色がつき、スクロール中は小さくなる。
struct BottomBar: View {
    @Environment(AppModel.self) private var app
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        let tab = app.tabs.current
        let space = app.tabs.currentSpace
        Group {
            if app.tabs.chromeCollapsed {
                Button {
                    app.tabs.chromeCollapsed = false
                } label: {
                    HStack(spacing: 6) {
                        if tab?.isPrivate == true { Image(systemName: "eyeglasses") }
                        Text(addressText(tab))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(.bar)
            } else {
                fullBar(tab: tab, space: space)
            }
        }
    }

    private func fullBar(tab: BrowserTab?, space: BrowserSpace) -> some View {
        VStack(spacing: 8) {
            if let tab, tab.isLoading {
                ProgressView(value: tab.progress)
                    .progressViewStyle(.linear)
                    .tint(space.theme.accent)
                    .frame(height: 2)
                    .padding(.horizontal, -16)
            }

            addressCapsule(tab: tab, space: space)

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
                .contextMenu { quickActions(tab) }
                .accessibilityLabel("AIアシスタント")
                Spacer()
                Button {
                    app.openTabSwitcher()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(.primary, lineWidth: 1.6)
                            .frame(width: 22, height: 22)
                        Text("\(app.tabs.currentSpaceTabs.count)").font(.caption2.weight(.bold))
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
        .background {
            ZStack {
                Rectangle().fill(.bar)
                Rectangle().fill(space.theme.gradient).opacity(tab?.isPrivate == true ? 0.35 : 0.12)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// 左右にスワイプすると隣のタブへ（Arc Search）
    private func addressCapsule(tab: BrowserTab?, space: BrowserSpace) -> some View {
        Button {
            app.showCommandBar = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: space.icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(space.theme.accent)
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
            .offset(x: dragOffset)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        dragOffset = value.translation.width / 3
                    }
                }
                .onEnded { value in
                    let dx = value.translation.width
                    withAnimation(.snappy) { dragOffset = 0 }
                    guard abs(dx) > 60, abs(dx) > abs(value.translation.height) else { return }
                    app.tabs.selectAdjacent(dx < 0 ? 1 : -1)
                }
        )
    }

    @ViewBuilder
    private func quickActions(_ tab: BrowserTab?) -> some View {
        if let tab, !tab.isBlank {
            ForEach(app.skills.skills.prefix(4)) { skill in
                Button {
                    app.run(skill)
                } label: { Label(skill.name, systemImage: skill.icon) }
            }
            Divider()
        }
        Button {
            app.showCommandBar = true
        } label: { Label("Webでまとめて調べる", systemImage: "globe") }
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
                Button {
                    app.history.addToSpeedDial(title: tab.displayTitle, url: url)
                } label: { Label("スピードダイヤルに追加", systemImage: "square.grid.2x2") }
                Button {
                    app.tabs.togglePin(tab)
                } label: { Label(tab.isPinned ? "ピン留めを外す" : "ピン留め", systemImage: tab.isPinned ? "pin.slash" : "pin") }
                Divider()
            }
            Button {
                app.tabs.newTab()
            } label: { Label("新しいタブ", systemImage: "plus.square.on.square") }
            Button {
                app.tabs.newTab(in: BrowserSpace.privateID)
            } label: { Label("プライベートタブ", systemImage: "eyeglasses") }
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
