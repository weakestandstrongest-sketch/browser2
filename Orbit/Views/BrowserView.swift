import SwiftUI
import UIKit

/// 画面全体。光の背景の上にページのカードが浮かび、
/// 左端から右へスワイプでサイドバー、右端から左へスワイプで AI が出る。
struct BrowserView: View {
    @Environment(AppModel.self) private var app
    @State private var drag: CGFloat = 0

    private let spring = Animation.spring(response: 0.38, dampingFraction: 0.86)

    var body: some View {
        @Bindable var app = app
        ZStack {
            GeometryReader { geo in
                let width = min(geo.size.width * 0.84, 340)
                let progress = min(1, max(0, (app.showSidebar ? 1 : 0) + drag / width))
                ZStack(alignment: .leading) {
                    AuroraBackground(theme: app.tabs.currentSpace.theme, active: app.assistant.isRunning, muted: app.tabs.isPrivate)

                    SidebarView()
                        .frame(width: width)
                        .offset(x: (progress - 1) * width * 0.35)
                        .opacity(Double(progress))
                        .allowsHitTesting(app.showSidebar)

                    stage(height: geo.size.height, sidebarWidth: width)
                        .scaleEffect(1 - 0.08 * progress, anchor: .leading)
                        .offset(x: progress * width)

                    if !app.showSidebar && !app.showCommandBar {
                        edgeStrips(sidebarWidth: width)
                    }
                }
            }
            .ignoresSafeArea(app.showAssistant ? [] : .keyboard, edges: .bottom)

            if app.showCommandBar {
                CommandBarView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(spring, value: app.showSidebar)
        .animation(spring, value: app.showAssistant)
        .animation(spring, value: app.assistantExpanded)
        .animation(.easeOut(duration: 0.2), value: app.showCommandBar)
        .animation(.snappy(duration: 0.25), value: app.tabs.chromeCollapsed)
        .sheet(isPresented: $app.showSettings) {
            SettingsView().environment(app)
        }
        .sheet(isPresented: $app.showSkills) {
            SkillsView().environment(app)
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

    // MARK: Stage (page card + capsule / assistant)

    private func stage(height: CGFloat, sidebarWidth: CGFloat) -> some View {
        let tab = app.tabs.current
        return VStack(spacing: 8) {
            if app.showAssistant && app.assistantExpanded {
                pageStrip(tab)
            } else {
                pageCard(tab)
                    .frame(height: app.showAssistant ? max(140, height * 0.36) : nil)
            }
            if app.showAssistant {
                AssistantPanel()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                CommandCapsule()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .overlay {
            if app.showSidebar {
                Color.black.opacity(0.001)
                    .onTapGesture { app.showSidebar = false }
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { drag = min(0, $0.translation.width) }
                            .onEnded { value in
                                let close = value.translation.width < -sidebarWidth * 0.25 || value.predictedEndTranslation.width < -sidebarWidth * 0.5
                                withAnimation(spring) {
                                    drag = 0
                                    if close { app.showSidebar = false }
                                }
                            }
                    )
            }
        }
    }

    private func pageCard(_ tab: BrowserTab?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let blank = tab?.isBlank ?? true
        return ZStack {
            if let tab, !tab.isBlank {
                WebViewContainer(webView: tab.webView)
                    .id(tab.id)
            } else {
                StartPageView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(blank ? Color.clear : Color(.systemBackground))
        .clipShape(shape)
        .overlay {
            if !blank {
                if app.assistant.isRunning {
                    GlowBorder(shape: shape)
                } else {
                    shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
            }
        }
        .shadow(color: .black.opacity(blank ? 0 : 0.1), radius: 20, y: 10)
    }

    /// AI を全画面にしているあいだの、ページの小さな帯。
    private func pageStrip(_ tab: BrowserTab?) -> some View {
        Button {
            app.assistantExpanded = false
        } label: {
            HStack(spacing: 10) {
                if let tab, !tab.isBlank {
                    SiteIcon(url: tab.url, size: 22)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(tab?.displayTitle ?? "新しいタブ")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "rectangle.split.1x2")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .glass(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Edge swipes

    private func edgeStrips(sidebarWidth: CGFloat) -> some View {
        HStack {
            Color.clear
                .frame(width: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { drag = max(0, $0.translation.width) }
                        .onEnded { value in
                            let open = value.translation.width > sidebarWidth * 0.28 || value.predictedEndTranslation.width > sidebarWidth * 0.6
                            withAnimation(spring) {
                                drag = 0
                                if open { app.showSidebar = true }
                            }
                        }
                )
            Spacer()
            Color.clear
                .frame(width: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onEnded { value in
                            if value.translation.width < -50 { app.showAssistant = true }
                        }
                )
        }
        .padding(.bottom, 110)
    }
}

/// 下に浮かぶガラスのカプセル。サイドバー・アドレス・AI の3つだけ。
struct CommandCapsule: View {
    @Environment(AppModel.self) private var app
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        let tab = app.tabs.current
        let space = app.tabs.currentSpace
        if app.tabs.chromeCollapsed {
            Button {
                app.tabs.chromeCollapsed = false
            } label: {
                HStack(spacing: 7) {
                    OrbView(size: 12)
                    Text(addressText(tab))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glass(Capsule())
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 8) {
                if let tab, !tab.isBlank {
                    suggestions
                }
                HStack(spacing: 0) {
                    sidebarButton(space)
                    Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 1, height: 22)
                    address(tab: tab, space: space)
                    Button {
                        app.showAssistant = true
                    } label: {
                        OrbView(size: 36, animating: app.assistant.isRunning)
                            .frame(width: 50, height: 54)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu { quickActions(tab) }
                    .accessibilityLabel("AIアシスタント")
                }
                .frame(height: 54)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                .overlay {
                    if app.assistant.isRunning {
                        GlowBorder(shape: Capsule(), lineWidth: 2)
                    }
                }
                .background {
                    // Dia のように、入力欄の下から虹色の光がにじむ
                    Capsule()
                        .fill(Theme.gradient)
                        .padding(.horizontal, 26)
                        .blur(radius: 16)
                        .opacity(0.5)
                        .offset(y: 8)
                }
            }
        }
    }

    /// ページに合わせた提案（Comet）。タップですぐ実行。
    private var suggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(app.skills.skills.prefix(4)) { skill in
                    Button {
                        app.run(skill)
                    } label: {
                        Label(skill.name, systemImage: skill.icon)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color(.secondarySystemGroupedBackground).opacity(0.9), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func sidebarButton(_ space: BrowserSpace) -> some View {
        Button {
            app.showSidebar = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: space.isPrivate ? "eyeglasses" : "sidebar.left")
                    .font(.subheadline.weight(.medium))
                Text("\(app.tabs.currentSpaceTabs.count)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 58, height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("サイドバー")
    }

    /// 左右にスワイプすると隣のタブへ。タップで検索・URL・AI への質問。
    private func address(tab: BrowserTab?, space: BrowserSpace) -> some View {
        HStack(spacing: 8) {
            if let tab, tab.canGoBack {
                Button {
                    tab.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 26, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("戻る")
            }
            Image(systemName: (tab?.isBlank ?? true) ? "sparkle.magnifyingglass" : (tab?.url?.scheme == "https" ? "lock.fill" : "globe"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(addressText(tab))
                .font(.subheadline.weight(.medium))
                .foregroundStyle((tab?.isBlank ?? true) ? Color.secondary : Color.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            pageMenu(tab)
        }
        .padding(.leading, 12)
        .frame(height: 54)
        .overlay(alignment: .bottomLeading) {
            if let tab, tab.isLoading {
                GeometryReader { geo in
                    Capsule()
                        .fill(space.theme.gradient)
                        .frame(width: max(8, geo.size.width * tab.progress), height: 2.5)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .padding(.horizontal, 8)
                .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { app.showCommandBar = true }
        .offset(x: dragOffset)
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

    private func pageMenu(_ tab: BrowserTab?) -> some View {
        Menu {
            if let tab, let url = tab.url {
                Button {
                    tab.isLoading ? tab.stopLoading() : tab.reload()
                } label: { Label(tab.isLoading ? "読み込みを中止" : "再読み込み", systemImage: tab.isLoading ? "xmark" : "arrow.clockwise") }
                if tab.canGoForward {
                    Button {
                        tab.goForward()
                    } label: { Label("進む", systemImage: "chevron.forward") }
                }
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
            } label: { Label("新しいタブ", systemImage: "plus") }
            Button {
                app.tabs.newTab(in: BrowserSpace.privateID)
            } label: { Label("プライベートタブ", systemImage: "eyeglasses") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 40)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("ページのメニュー")
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
        guard let tab, !tab.isBlank else { return "検索、URL、AIに質問" }
        return URLParser.displayHost(tab.url)
    }
}
