import SwiftUI

/// 新しいタブ。光の背景の上に直接置かれる：あいさつ、AI への入り口、スピードダイヤル。
struct StartPageView: View {
    @Environment(AppModel.self) private var app

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: return "おはようございます"
        case 11..<18: return "こんにちは"
        default: return "こんばんは"
        }
    }

    var body: some View {
        let space = app.tabs.currentSpace
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: space.icon)
                        Text(space.name)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    Text(space.isPrivate ? "プライベート" : greeting)
                        .font(Theme.display(38))
                        .padding(.top, 2)
                    Text(space.isPrivate ? "このタブの履歴と Cookie は、閉じると消えます。" : Date().formatted(date: .complete, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 56)

                askCard(space)

                if !space.isPrivate {
                    speedDial
                    frequentSites
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }

    /// AI への入り口。タップでコマンドバー、下の例はそのまま実行。
    private func askCard(_ space: BrowserSpace) -> some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return VStack(alignment: .leading, spacing: 14) {
            Button {
                app.showCommandBar = true
            } label: {
                HStack(spacing: 12) {
                    OrbView(size: 40, animating: app.assistant.isRunning)
                    Text("何でも聞く、探す、任せる")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    example("globe", "今日のニュースを調べてまとめて", .web)
                    example("lightbulb", "量子コンピュータをやさしく説明して", .chat)
                    example("airplane", "週末の小旅行プランを考えて", .chat)
                }
            }

            if !app.assistant.usesCloud && !app.localAI.isReady {
                Button {
                    app.showModels = true
                } label: {
                    Label("まずAIモデルを用意する", systemImage: "arrow.down.circle.fill")
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: shape)
        .overlay(shape.strokeBorder(Theme.gradient, lineWidth: 1.2))
        .background {
            shape.fill(Theme.gradient).padding(.horizontal, 24).blur(radius: 22).opacity(0.4).offset(y: 12)
        }
    }

    private func example(_ icon: String, _ text: String, _ mode: SendMode) -> some View {
        Button {
            app.ask(text, mode: mode)
        } label: {
            Label(text, systemImage: icon)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(.secondary).textCase(nil)
    }

    @ViewBuilder
    private var speedDial: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("スピードダイヤル")
            if app.history.speedDial.isEmpty {
                Text("ページのメニュー（…）から、よく使うサイトを追加できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
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
                }
            }
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var frequentSites: some View {
        let sites = app.history.topSites(8)
        if !sites.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                label("よく見るサイト")
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
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
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
