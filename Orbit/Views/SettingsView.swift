import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var showKey = false
    @State private var clearedData = false

    var body: some View {
        @Bindable var settings = app.settings
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if showKey {
                                TextField("sk-ant-...", text: $settings.apiKey)
                            } else {
                                SecureField("sk-ant-...", text: $settings.apiKey)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                        Link("APIキーを取得する（Anthropic Console）", destination: url)
                            .font(.footnote)
                    }
                } header: {
                    Text("Anthropic APIキー")
                } footer: {
                    Text("キーはこの端末のキーチェーンに保存され、Claude API への通信にのみ使われます。")
                }

                Section("AIモデル") {
                    Picker("モデル", selection: $settings.model) {
                        ForEach(ClaudeModelOption.all) { option in
                            VStack(alignment: .leading) {
                                Text(option.name)
                                Text(option.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(option.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    Picker("思考の深さ", selection: $settings.effort) {
                        ForEach(EffortLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    Toggle("Web検索を使う", isOn: $settings.webSearchEnabled)
                        .disabled(!settings.modelOption.supportsWebSearch)
                }

                Section {
                    Picker("操作の確認", selection: $settings.approvalPolicy) {
                        ForEach(ApprovalPolicy.allCases) { policy in
                            Text(policy.label).tag(policy)
                        }
                    }
                } header: {
                    Text("エージェント")
                } footer: {
                    Text("「重要な操作のみ」では、購入・送信・削除などに見えるボタンや、パスワード・カード情報の入力の前に確認します。")
                }

                Section {
                    TextEditor(text: $settings.aboutMe)
                        .frame(minHeight: 100)
                } header: {
                    Text("あなたについて（パーソナライズ）")
                } footer: {
                    Text("例：「東京在住のエンジニア。回答は結論から、専門用語はそのままでOK」。毎回AIに伝えられます。")
                }

                Section("ブラウザ") {
                    Picker("検索エンジン", selection: $settings.searchEngine) {
                        ForEach(SearchEngine.allCases) { engine in
                            Text(engine.name).tag(engine)
                        }
                    }
                    Picker("アドレスバーでEnter", selection: $settings.omniboxDefault) {
                        ForEach(OmniboxDefault.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    Button {
                        Task {
                            await app.tabs.clearWebsiteData()
                            clearedData = true
                        }
                    } label: {
                        Label(clearedData ? "消去しました" : "Cookieとサイトデータを消去", systemImage: "trash")
                    }
                    .disabled(clearedData)
                }

                Section {
                    TextField("https://api.anthropic.com", text: $settings.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("詳細")
                } footer: {
                    Text("独自のプロキシ／ゲートウェイを使う場合のみ変更してください。")
                }

                Section {
                    LabeledContent("バージョン", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
