import SwiftUI

struct TabSwitcherView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(app.tabs.tabs) { tab in
                        TabCard(tab: tab, isSelected: tab.id == app.tabs.current?.id) {
                            app.tabs.select(tab)
                            dismiss()
                        } onClose: {
                            withAnimation { app.tabs.close(tab) }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(app.tabs.tabs.count)個のタブ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(role: .destructive) {
                            app.tabs.closeAll()
                            dismiss()
                        } label: { Label("すべてのタブを閉じる", systemImage: "xmark.square") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        app.run(Skill(name: "タブを整理", icon: "square.grid.2x2",
                                      prompt: "開いているタブをテーマごとにグループ分けし、それぞれの要点を一行でまとめてください。不要そうなタブがあれば指摘してください。",
                                      scope: .allTabs))
                    } label: {
                        Label("AIで整理", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        app.tabs.newTab()
                        dismiss()
                    } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

private struct TabCard: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(tab.displayTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            ZStack {
                Color(.secondarySystemBackground)
                if let image = tab.thumbnail, !tab.isBlank {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: tab.isBlank ? "sparkles" : "globe")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                        Text(tab.isBlank ? "新しいタブ" : URLParser.displayHost(tab.url))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 200, alignment: .top)
            .clipped()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 2.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
