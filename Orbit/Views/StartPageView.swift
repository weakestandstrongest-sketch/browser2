import SwiftUI

/// 新しいタブ：Opera のスピードダイヤル ＋ よく見るサイト ＋ AI への入り口。
struct StartPageView: View {
    @Environment(AppModel.self) private var app

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        let space = app.tabs.currentSpace
        ScrollView {
            VStack(spacing: 26) {
                header(space)

                Button {
                    app.showCommandBar = true
                } label: {
                    HStack {
                        Image(systemName: "sparkle.magnifyingglass")
                        Text("検索、URL、またはAIに質問")
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                if !space.isPrivate {
                    speedDial
                    frequentSites
                }
                aiSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background {
            ZStack {
                Color(.systemBackground)
                space.theme.gradient.opacity(space.isPrivate ? 0.25 : 0.08)
            }
            .ignoresSafeArea()
        }
    }

    private func header(_ space: BrowserSpace) -> some View {
        VStack(spacing: 12) {
            if space.isPrivate {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("プライベート").font(.title.weight(.bold))
                Text("このタブの履歴・Cookie は、タブを閉じると消えます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                OrbView(size: 60, animating: true)
                Text(space.name).font(.title.weight(.bold))
            }
        }
        .padding(.top, 44)
    }

    @ViewBuilder
    private var speedDial: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("スピードダイヤル").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(app.history.speedDial) { item in
                    SiteTile(title: item.title, url: URL(string: item.url)) {
                        if let url = URL(string: item.url) { app.tabs.open(url) }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            app.history.removeFromSpeedDial(item)
                        } label: { Label("削除", systemImage: "trash") }
                    }
                }
                if app.history.speedDial.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .frame(width: 54, height: 54)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
                        Text("…メニューから追加").font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    }
                    .multilineTextAlignment(.center)
                }
            }
        }
    }

    @ViewBuilder
    private var frequentSites: some View {
        let sites = app.history.topSites(8)
        if !sites.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("よく見るサイト").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(sites) { entry in
                        SiteTile(title: entry.host, url: URL(string: entry.url)) {
                            if let url = URL(string: entry.url) { app.tabs.open(url) }
                        }
                        .contextMenu {
                            Button {
                                if let url = URL(string: entry.url) { app.history.addToSpeedDial(title: entry.host, url: url) }
                            } label: { Label("スピードダイヤルに追加", systemImage: "square.grid.2x2") }
                        }
                    }
                }
            }
        }
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AIに聞いてみる").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            suggestion("globe", "今日の主要なニュースを調べてまとめて", mode: .web)
            suggestion("lightbulb", "量子コンピュータをやさしく説明して", mode: .chat)
            suggestion("airplane", "週末の小旅行プランを考えて", mode: .chat)
            if !app.assistant.usesCloud && !app.localAI.isReady {
                Button {
                    app.showModels = true
                } label: {
                    Label("AIを使うには、まずAIモデルを用意してください", systemImage: "arrow.down.circle")
                        .font(.footnote.weight(.semibold))
                }
                .padding(.top, 4)
            }
        }
    }

    private func suggestion(_ icon: String, _ text: String, mode: SendMode) -> some View {
        Button {
            app.ask(text, mode: mode)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(Theme.accent)
                Text(text)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

/// サイトのアイコン（favicon が取れなければ頭文字）。
struct SiteTile: View {
    let title: String
    let url: URL?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                SiteIcon(url: url, size: 54)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SiteIcon: View {
    let url: URL?
    var size: CGFloat = 40

    private var letter: String {
        String(URLParser.displayHost(url).prefix(1)).uppercased()
    }

    private var iconURL: URL? {
        guard let url, let scheme = url.scheme, let host = url.host else { return nil }
        return URL(string: "\(scheme)://\(host)/apple-touch-icon.png")
    }

    var body: some View {
        AsyncImage(url: iconURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Text(letter.isEmpty ? "?" : letter)
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26))
        .overlay(RoundedRectangle(cornerRadius: size * 0.26).strokeBorder(Color.primary.opacity(0.08)))
    }
}
