# Orbit — iPhone向けAIブラウザ

[Dia](https://www.diabrowser.com/) と [Comet](https://www.perplexity.ai/comet) のコンセプトを参考にした、iPhone 用の AI ブラウザです。
SwiftUI + WKWebView で作られており、AI には Claude API（Anthropic）を使います。GitHub Actions で **IPA を自動ビルド**できます。

## 主な機能

| 機能 | 参考 | 内容 |
| --- | --- | --- |
| タブと会話する | Dia | 表示中のページ（＋任意の他のタブ）を読み込ませて質問・要約・比較ができる |
| スキル | Dia | 「要約」「翻訳」「タブを比較」などよく使う指示を保存。`/要約` のように呼び出せる。自作も可能 |
| 統合アドレスバー | Dia / Comet | 1つの入力欄で URL を開く・Web検索・AIに質問・エージェントに依頼・スキル実行・タブ検索 |
| パーソナライズ | Dia | 「あなたについて」のメモを毎回AIに伝え、回答スタイルを調整 |
| アシスタントのサイドパネル | Comet | ページを見たまま下からパネルを出して会話（ハーフシート表示中もページを操作可能） |
| エージェント（操作の代行） | Comet | AIがページを読み取り、タップ・入力・スクロール・ページ移動・新規タブを自分で実行 |
| 安全確認 | Comet | 購入・送信・削除などの操作やパスワード入力の前に、許可カードで確認（設定で変更可） |
| Web検索と出典 | Comet / Perplexity | Claude のサーバー側 Web 検索で最新情報を調べ、出典を表示（タップで新しいタブ） |
| AIでタブ整理 | — | タブ一覧から開いているタブをテーマ別にまとめる |

ほかに、タブの保存・復元、引っ張って更新、スワイプで戻る/進む、共有、Cookie消去などの基本機能があります。

## 画面構成

- **ボトムバー**: アドレス（タップで統合アドレスバー）／戻る・進む／✨ AIボタン／タブ数／メニュー
- **AIパネル**: 上部に会話、下部にスキルチップ・添付タブチップ・入力欄。🪄 でブラウザ操作のオン/オフ、🌐 でWeb検索のオン/オフ
- **スタートページ**: 新しいタブを開いたときの画面。AIへの質問例を表示

## IPA の作り方

### A. GitHub Actions（Mac 不要）

1. このリポジトリに push すると `.github/workflows/build-ipa.yml` が macOS ランナーでビルドします（Actions タブから手動実行も可）。
2. 完了したら Actions の実行結果ページから **`Orbit-unsigned-ipa`** をダウンロードします。
3. 中の `Orbit-unsigned.ipa` は**未署名**です。iPhone に入れるには署名が必要です:
   - **Sideloadly / AltStore**: 無料の Apple ID で署名してインストールできます（無料アカウントは7日ごとに再署名が必要）。
   - **Apple Developer Program**（有料）の証明書があれば、長期間使え、TestFlight 配布もできます。
   - バンドルIDは `dev.orbit.browser` です。必要に応じて `project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` を変更してください。

### B. 手元の Mac でビルド

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

```bash
open Orbit.xcodeproj
```

Xcode で Signing & Capabilities の Team を設定すれば、実機で実行したり Archive から IPA を書き出したりできます。
未署名の IPA をコマンドラインで作る場合は、CI と同じ手順で:

```bash
xcodebuild -project Orbit.xcodeproj -scheme Orbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

```bash
./scripts/package-ipa.sh build/Build/Products/Release-iphoneos/Orbit.app Orbit-unsigned.ipa
```

## 初回設定

1. [Anthropic Console](https://console.anthropic.com/settings/keys) で API キーを発行します。
2. アプリのメニュー（…）→ **設定** で API キーを入力します（端末のキーチェーンに保存されます）。
3. モデル（既定は Claude Opus 5.5。Sonnet 5.5 / Haiku 5.5 も選択可）、思考の深さ、操作確認のレベルを好みに合わせて設定します。

## 構成

```
project.yml                 XcodeGen のプロジェクト定義（iOS 17+）
Orbit/
  App/                      エントリポイント・アプリ全体の状態（AppModel）
  Browser/                  タブ（WKWebView）、タブ管理、ページ読み取り・操作用JavaScript
  AI/
    AnthropicClient.swift   Claude Messages API クライアント（SSEストリーミング、リトライ）
    AssistantEngine.swift   会話とエージェントループ（ツール呼び出し→実行→結果返却）
    AssistantEngine+Tools   ブラウザ操作ツールの実行と承認フロー
    Prompts.swift           システムプロンプトとツール定義
  Models/                   設定、スキル
  Views/                    SwiftUI 画面（ボトムバー、AIパネル、アドレスバー、タブ一覧、設定…）
  Resources/                アセット（アプリアイコンなど）
.github/workflows/          IPA ビルド用ワークフロー
scripts/package-ipa.sh      .app → .ipa へのパッケージング
```

### AI まわりの仕組み

- Swift 用の公式 SDK はないため、`POST /v1/messages` を直接呼び出し（`anthropic-version: 2026-10-21`）、SSE をパースして逐次表示します。
- エージェントは Claude の **tool use** で動きます。ツールは `read_page`（操作可能な要素に番号を振って一覧化）、`click`、`type_text`、`scroll`、`navigate`、`go_back`、`open_new_tab` です。JavaScript は WKWebView の分離された content world で実行し、ページ側のスクリプトからは干渉されません。
- Web 検索は Claude のサーバー側ツール（`web_search_20260209`）を使用し、引用元を「出典」として表示します。
- 会話全体にプロンプトキャッシュ（`cache_control`）を適用し、長い会話やエージェント実行のコストを抑えています。
- Opus / Sonnet では安全分類器による拒否時に自動で別モデルへ切り替える `fallbacks: "default"` を有効にしています。
- ページの内容は「信頼できないデータ」としてシステムプロンプトで扱い、ページ内に書かれた指示（プロンプトインジェクション）には従わないよう指示しています。

## 注意点・制限

- iOS のブラウザは WebKit（WKWebView）を使う必要があります。Dia / Comet のような Chromium 拡張やデスクトップ専用機能は再現していません。
- エージェントは DOM 操作で動くため、クロスオリジンの iframe 内、canvas で描かれた UI、一部の厳しいボット対策があるサイトでは操作できないことがあります。
- API キーをアプリに直接持たせる方式は、個人利用やサイドロードを想定しています。App Store などで配布する場合は、キーを持つサーバー（プロキシ）を用意し、設定の「詳細」にその URL を入れる構成にしてください。
- API の利用料金は各自の Anthropic アカウントに発生します。

## 今後のアイデア

- 履歴・ブックマーク・リーダーモード
- 音声入力、共有シート（Share Extension）からの「AIに聞く」
- 会話履歴の保存、タブごとの会話
- エージェントの進捗表示（`thinking.display: "updates"`）や、スクリーンショットを使った視覚的な操作
