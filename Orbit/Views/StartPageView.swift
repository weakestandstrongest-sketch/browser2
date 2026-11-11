import SwiftUI

struct StartPageView: View {
    @Environment(AppModel.self) private var app

    private let suggestions: [(icon: String, text: String)] = [
        ("newspaper", "今日の主要なニュースを3つ教えて"),
        ("fork.knife", "近くで評判のいいランチの探し方を教えて"),
        ("airplane", "週末の小旅行プランを考えて"),
        ("book", "量子コンピュータをやさしく説明して"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    OrbView(size: 72, animating: true)
                    Text("Orbit")
                        .font(.largeTitle.weight(.bold))
                    Text("検索も、質問も、操作の代行も。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 56)

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

                VStack(alignment: .leading, spacing: 10) {
                    Text("AIに聞いてみる")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(suggestions, id: \.text) { item in
                        Button {
                            app.ask(item.text)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .frame(width: 24)
                                    .foregroundStyle(Theme.accent)
                                Text(item.text)
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

                if !app.settings.hasAPIKey {
                    Button {
                        app.showSettings = true
                    } label: {
                        Label("AI機能を使うには設定でAPIキーを入力", systemImage: "key.fill")
                            .font(.footnote)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
}
