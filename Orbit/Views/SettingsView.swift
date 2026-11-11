import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var showKey = false
    @State private var clearedData = false
    @State private var clearedHistory = false

    var body: some View {
        @Bindable var settings = app.settings
        NavigationStack {
            Form {
                Section {
                    Picker("AIを動かす場所", selection: $settings.aiProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.label).tag(provider)
                        }
                    }
                    if settings.aiProvider == .local {
                        NavigationLink {
                            ModelManagerView()
                        } label: {
                            LabeledContent("AIモデル", value: app.localAI.statusLabel)
                        }
                    }
                } header: {
                    Text("AI")
                } footer: {
                    Text(settings.aiProvider == .local
                         ? "ひび手帳の まいにち と同じく、AIはこのiPhoneの中で動きます。ページの内容は外に送られません。"
                         : "Claude（Anthropic）のAPIを使います。ページの内容がAnthropicに送られます。")
                }

                if settings.aiProvider == .cloud {
                    cloudSection(settings)
                }

                Section {
                    Picker("操作の確認", selection: $settings.approvalPolicy) {
                        ForEach(ApprovalPolicy.allCases) { policy in
                            Text(policy.label).tag(policy)
                        }
                    }
                } header: {
                    Text("エージェント（ブラウザ操作）")
                } footer: {
                    Text("「重要な操作のみ」では、購入・送信・削除などに見えるボタンや、パスワード・カード情報の入力の前に確認します。")
                }

                Section {
                    TextEditor(text: $settings.aboutMe)
                        .frame(minHeight: 100)
                } header: {
                    Text("あなたについて（パーソナライズ）")
                } footer: {
                    Text("例：「東京在住のエンジニア。回答は結論から」。毎回AIに伝えます。")
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
                    Toggle("広告・トラッカーをブロック", isOn: $settings.adBlock)
                        .onChange(of: settings.adBlock) {
                            Task { await app.tabs.setAdBlock(settings.adBlock) }
                        }
                    Picker("見ていないタブを自動でしまう", selection: $settings.autoArchive) {
                        ForEach(AutoArchive.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }

                Section("データ") {
                    Button {
                        app.history.clear()
                        clearedHistory = true
                    } label: {
                        Label(clearedHistory ? "消去しました" : "閲覧履歴を消去", systemImage: "clock.arrow.circlepath")
                    }
                    .disabled(clearedHistory)
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

    @ViewBuilder
    private func cloudSection(_ settings: AppSettings) -> some View {
        @Bindable var settings = settings
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
            Picker("モデル", selection: $settings.model) {
                ForEach(ClaudeModelOption.all) { option in
                    Text(option.name).tag(option.id)
                }
            }
            Picker("思考の深さ", selection: $settings.effort) {
                ForEach(EffortLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            TextField("https://api.anthropic.com", text: $settings.baseURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        } header: {
            Text("クラウドAI（Claude）")
        } footer: {
            Text("APIキーはこの端末のキーチェーンに保存されます。プロキシを使う場合のみ接続先を変更してください。")
        }
    }
}
