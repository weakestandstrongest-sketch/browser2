import SwiftUI

/// Arc 風のタブ一覧：上でスペースを切り替え、ピン留めタブは丸いアイコンで上に並ぶ。
struct TabSwitcherView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var editingSpace: BrowserSpace?
    @State private var creatingSpace = false
    @State private var showArchive = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        let space = app.tabs.currentSpace
        let all = app.tabs.currentSpaceTabs
        let pinned = all.filter(\.isPinned)
        let others = all.filter { !$0.isPinned }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    spaceBar

                    if !pinned.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(pinned) { tab in
                                    Button {
                                        app.tabs.select(tab)
                                        dismiss()
                                    } label: {
                                        VStack(spacing: 4) {
                                            SiteIcon(url: tab.url, size: 48)
                                                .overlay(alignment: .bottomTrailing) {
                                                    if tab.id == app.tabs.current?.id {
                                                        Circle().fill(space.theme.accent).frame(width: 10, height: 10)
                                                    }
                                                }
                                            Text(tab.displayTitle).font(.caption2).lineLimit(1).frame(width: 64)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu { tabMenu(tab) }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(others) { tab in
                            TabCard(tab: tab, isSelected: tab.id == app.tabs.current?.id, accent: space.theme.accent) {
                                app.tabs.select(tab)
                                dismiss()
                            } onClose: {
                                withAnimation { app.tabs.close(tab) }
                            }
                            .contextMenu { tabMenu(tab) }
                        }
                    }
                    .padding(.horizontal)

                    if !space.isPrivate && !app.tabs.archived.isEmpty {
                        Button {
                            showArchive = true
                        } label: {
                            Label("アーカイブ（\(app.tabs.archived.count)）", systemImage: "archivebox")
                                .font(.subheadline)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background {
                ZStack {
                    Color(.systemGroupedBackground)
                    space.theme.gradient.opacity(space.isPrivate ? 0.3 : 0.1)
                }
                .ignoresSafeArea()
            }
            .navigationTitle(space.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            app.run(Skill(name: "タブを整理", icon: "square.grid.2x2",
                                          prompt: "開いているタブをテーマごとにグループ分けし、それぞれの要点を一行でまとめてください。不要そうなタブがあれば指摘してください。",
                                          scope: .allTabs))
                        } label: { Label("AIでタブを整理", systemImage: "sparkles") }
                        if !space.isPrivate {
                            Button {
                                editingSpace = space
                            } label: { Label("このスペースを編集", systemImage: "pencil") }
                        }
                        Button(role: .destructive) {
                            app.tabs.closeAll(in: space.id)
                            dismiss()
                        } label: { Label("ピン留め以外のタブを閉じる", systemImage: "xmark.square") }
                    } label: { Image(systemName: "ellipsis.circle") }
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
            .sheet(item: $editingSpace) { space in
                SpaceEditor(space: space, canDelete: app.tabs.spaces.count > 1) { updated in
                    app.tabs.updateSpace(updated)
                } onDelete: {
                    app.tabs.deleteSpace(space)
                }
            }
            .sheet(isPresented: $creatingSpace) {
                SpaceEditor(space: BrowserSpace(name: "", icon: "star", theme: .mint), canDelete: false) { created in
                    let space = app.tabs.addSpace(name: created.name, icon: created.icon, theme: created.theme)
                    app.tabs.switchSpace(to: space.id)
                } onDelete: {}
            }
            .sheet(isPresented: $showArchive) {
                ArchiveView().environment(app)
            }
        }
    }

    private var spaceBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(app.tabs.spaces + [BrowserSpace.privateSpace]) { space in
                    let selected = space.id == app.tabs.currentSpaceID
                    Button {
                        withAnimation(.snappy) { app.tabs.switchSpace(to: space.id) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: space.icon)
                            Text(space.name).lineLimit(1)
                            Text("\(app.tabs.tabs(in: space.id).count)")
                                .font(.caption2.weight(.bold))
                                .opacity(0.7)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            if selected {
                                Capsule().fill(space.theme.gradient)
                            } else {
                                Capsule().fill(Color(.secondarySystemBackground))
                            }
                        }
                        .foregroundStyle(selected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    creatingSpace = true
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("スペースを追加")
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func tabMenu(_ tab: BrowserTab) -> some View {
        if !tab.isPrivate {
            Button {
                app.tabs.togglePin(tab)
            } label: { Label(tab.isPinned ? "ピン留めを外す" : "ピン留め", systemImage: tab.isPinned ? "pin.slash" : "pin") }
            Menu {
                ForEach(app.tabs.spaces.filter { $0.id != tab.spaceID }) { space in
                    Button {
                        app.tabs.move(tab, to: space.id)
                    } label: { Label(space.name, systemImage: space.icon) }
                }
            } label: { Label("別のスペースへ移動", systemImage: "arrow.right.square") }
            if let url = tab.url {
                Button {
                    app.history.addToSpeedDial(title: tab.displayTitle, url: url)
                } label: { Label("スピードダイヤルに追加", systemImage: "square.grid.2x2") }
            }
        }
        Button(role: .destructive) {
            app.tabs.close(tab)
        } label: { Label("閉じる", systemImage: "xmark") }
    }
}

private struct TabCard: View {
    let tab: BrowserTab
    let isSelected: Bool
    let accent: Color
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                SiteIcon(url: tab.url, size: 16)
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
                            .foregroundStyle(accent)
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
                .strokeBorder(isSelected ? accent : Color.clear, lineWidth: 2.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

/// スペースの名前・アイコン・色を決める。
struct SpaceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var space: BrowserSpace
    let canDelete: Bool
    let onSave: (BrowserSpace) -> Void
    let onDelete: () -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 8)

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("例：旅行", text: $space.name)
                }
                Section("色") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SpaceTheme.allCases) { theme in
                                Circle()
                                    .fill(theme.gradient)
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().strokeBorder(Color.primary, lineWidth: space.theme == theme ? 3 : 0))
                                    .onTapGesture { space.theme = theme }
                                    .accessibilityLabel(theme.label)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("アイコン") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(BrowserSpace.icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .frame(width: 32, height: 32)
                                .background(space.icon == icon ? space.theme.accent.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(space.icon == icon ? space.theme.accent : Color.primary)
                                .onTapGesture { space.icon = icon }
                        }
                    }
                    .padding(.vertical, 4)
                }
                if canDelete {
                    Section {
                        Button("このスペースを削除", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    } footer: {
                        Text("タブは最初のスペースに移ります。")
                    }
                }
            }
            .navigationTitle(space.name.isEmpty ? "新しいスペース" : space.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(space)
                        dismiss()
                    }
                    .disabled(space.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// 自動でしまったタブ（Arc のアーカイブ）。
struct ArchiveView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(app.tabs.archived) { item in
                        Button {
                            app.tabs.restore(item)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                SiteIcon(url: URL(string: item.url), size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).lineLimit(1).foregroundStyle(.primary)
                                    Text("\(URLParser.displayHost(URL(string: item.url))) ・ \(item.archivedAt.formatted(.relative(presentation: .named)))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("しばらく見ていないタブは自動でここにしまわれます（設定で変更できます）。タップで開き直せます。")
                }
            }
            .navigationTitle("アーカイブ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("すべて削除", role: .destructive) { app.tabs.clearArchive() }
                        .disabled(app.tabs.archived.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } }
            }
        }
    }
}
