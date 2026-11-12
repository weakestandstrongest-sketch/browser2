import SwiftUI

/// 新しいタブ（Comet / Perplexity のホームのように）：ワードマーク、うっすらした印、候補の一覧。
/// 入力は下のバーから。
struct StartPageView: View {
    @Environment(AppModel.self) private var app
    @State private var showImport = false
    @State private var addingFavorite = false
    @State private var editingFavorite: SpeedDialItem?

    private struct Suggestion: Hashable {
        let text: String
        let mode: SendMode
    }

    private let suggestions = [
        Suggestion(text: "今日のニュースを調べてまとめて", mode: .web),
        Suggestion(text: "量子コンピュータをやさしく説明して", mode: .chat),
        Suggestion(text: "週末の小旅行プランを考えて", mode: .chat),
    ]

    var body: some View {
        let space = app.tabs.currentSpace
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Circle().fill(space.theme.gradient).frame(width: 10, height: 10)
                Text(space.isPrivate ? "private" : "orbit")
                    .font(Theme.display(34))
                Spacer()
                circleButton("eyeglasses", "プライベートタブ") { app.tabs.newTab(in: BrowserSpace.privateID) }
                circleButton("square.on.square", "タブ") { app.showSidebar = true }
            }
            .padding(.top, 14)

            if !app.assistant.usesCloud && !app.localAI.isReady {
                Button {
                    app.showModels = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("AIモデルを用意する")
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }

            Spacer(minLength: 12)
            OrbView(size: 64, animating: app.assistant.isRunning)
                .opacity(0.28)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !space.isPrivate {
                        favorites
                            .padding(.bottom, 14)
                    }
                    ForEach(suggestions, id: \.self) { item in
                        Button {
                            app.ask(item.text, mode: item.mode)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.mode == .web ? "globe" : "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22)
                                Text(item.text)
                                    .font(.body)
                                    .foregroundStyle(Color.primary.opacity(0.9))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .frame(height: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 330)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .sheet(isPresented: $showImport) { BookmarkImportView().environment(app) }
        .sheet(isPresented: $addingFavorite) { FavoriteEditor().environment(app) }
        .sheet(item: $editingFavorite) { item in FavoriteEditor(editing: item).environment(app) }
    }

    // MARK: Favorites (Safari のお気に入りの代わり)

    private let favoriteColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    @ViewBuilder
    private var favorites: some View {
        let items = app.history.speedDial
        if items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("お気に入り").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    favoriteAction("square.and.arrow.down", "Safariから読み込む") { showImport = true }
                    favoriteAction("plus", "追加する") { addingFavorite = true }
                }
            }
        } else {
            LazyVGrid(columns: favoriteColumns, spacing: 14) {
                ForEach(items.prefix(12)) { item in
                    SiteTile(title: item.title, url: URL(string: item.url)) {
                        if let url = URL(string: item.url) { app.tabs.open(url) }
                    }
                    .contextMenu {
                        Button {
                            editingFavorite = item
                        } label: { Label("名前を変更", systemImage: "pencil") }
                        Button(role: .destructive) {
                            app.history.removeFromSpeedDial(item)
                        } label: { Label("削除", systemImage: "trash") }
                    }
                }
                if items.count < 12 {
                    Button {
                        addingFavorite = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 54, height: 54)
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4])))
                            Text("追加").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            showImport = true
                        } label: { Label("Safariのブックマークを読み込む", systemImage: "square.and.arrow.down") }
                    }
                }
            }
        }
    }

    private func favoriteAction(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .frame(height: 40)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func circleButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .frame(width: 46, height: 46)
                .glass(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
