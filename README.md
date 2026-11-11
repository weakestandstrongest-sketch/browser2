# Orbit — iPhone向けAIブラウザ

[Dia](https://www.diabrowser.com/)・[Comet](https://www.perplexity.ai/comet) の AI 機能と、Arc・Opera の UI を参考にした iPhone 用ブラウザです。
**AI は基本的に iPhone の中で動きます**（ひび手帳の「まいにち」と同じ llama.cpp / Apple Intelligence の仕組み）。ページの内容や質問は外に送られません。
SwiftUI + WKWebView 製で、GitHub Actions が **未署名の IPA** を作ります。

## AI（ローカル・まいにち と同じ作り）

| | 内容 |
| --- | --- |
| エンジン | llama.cpp（GGUF、Metal で GPU 実行）と Apple Intelligence（iOS 26 の Foundation Models） |
| モデル | まいにち と同じ顔ぶれ：Apple Intelligence / Qwen3.5 4B（おすすめ）/ Gemma 4 E4B / LFM3 VL 2B / Ternary Bonsai 2 9B / LLM-jp-4.1 8B |
| 入手 | Hugging Face から一度だけダウンロードし、アプリの中（Application Support/orbit-models、iCloud バックアップ対象外）に保存 |
| 会話の書式 | まいにち の chat template（gemma4 / qwen35 / lfm3 / llmjp41）の文字部分を Swift に移植。考える部分はオフ、`<think>` やチャンネル形式は答えから除去 |
| llama.cpp の版 | `v0.9.0`（ひび手帳と同じ）。CI が `build-xcframework.sh ios-device` で作ってキャッシュ |

AI でできること:

- **タブと会話（Dia）**：表示中のページや他のタブを読ませて質問・要約・比較。ページが長いときは自動で短くして再試行
- **スキル（Dia）**：「要約」「翻訳」などの指示を保存して `/要約` で呼び出し。AI オーブを長押しでもすぐ実行
- **ブラウザ操作（Comet）**：AI が1回に1つの操作（タップ・入力・スクロール・URL を開く・検索・戻る）を JSON で決めて実行。llama.cpp では **GBNF の文法で JSON の形を固定**するので、小さなモデルでも壊れた出力になりません。購入・送信・パスワード入力などの前は確認カードが出ます
- **Webでまとめて調べる（Arc Search の Browse for Me）**：検索 → 上位のページを見えないところで開いて読む → 出典つきでまとめる
- **パーソナライズ**：設定の「あなたについて」を毎回 AI に伝える

クラウドの Claude（Anthropic API）も **任意で** 選べます（設定 → AI →「AIを動かす場所」）。既定はローカルです。

## ブラウザの UI（Arc / Opera）

| 機能 | 参考 | 内容 |
| --- | --- | --- |
| スペース | Arc | タブを「パーソナル」「仕事」などに分け、それぞれに色とアイコン。ツールバーやスタートページがスペースの色になる |
| ピン留めタブ | Arc | タブ一覧の上に丸いアイコンで並ぶ。自動アーカイブの対象外 |
| 自動アーカイブ | Arc | しばらく見ていないタブを自動でしまう（12時間／1日／1週間／しない）。アーカイブから開き直せる |
| アドレスバーをスワイプ | Arc Search | 左右にスワイプで隣のタブへ |
| ツールバーが小さくなる | Arc / Safari | 下にスクロールすると最小表示、上に戻すと元どおり |
| スピードダイヤル・よく見るサイト | Opera | 新しいタブにお気に入りと、履歴から多く見ているサイトを表示 |
| 広告ブロック | Opera | 内蔵の広告・トラッカーブロック（WebKit のコンテンツブロッカー） |
| プライベートタブ | Opera / Safari | 履歴・Cookie を残さないタブ（タブ一覧の「プライベート」） |
| 統合アドレスバー | Dia / Arc | URL・検索・履歴・AI に質問・Web でまとめて調べる・ブラウザ操作・スキル・タブ検索 |

ほかに、タブの保存と復元（開くまで読み込まない）、引っ張って更新、スワイプで戻る／進む、共有などがあります。

## IPA の作り方

### A. GitHub Actions（Mac 不要）

1. push すると `.github/workflows/build-ipa.yml` が macOS ランナーでビルドします（Actions タブから手動実行も可）。
   - llama.cpp（`v0.9.0`）を iOS 用にビルドして `Vendor/llama.xcframework` に置き、アプリに組み込みます（2回目からはキャッシュ）。
2. 実行結果ページの Artifacts から **`Orbit-unsigned-ipa`** をダウンロードします。
3. 中の `Orbit-unsigned.ipa` は未署名です。**AltStore / Sideloadly** などで自分の Apple ID で署名して入れてください（無料の Apple ID は7日ごとに再署名）。
   - バンドルIDは `dev.orbit.browser`（`project.yml` で変更可）

### B. 手元の Mac でビルド

```bash
brew install xcodegen
```

```bash
./scripts/build-llama.sh "ios-device ios-sim"
```

```bash
xcodegen generate && open Orbit.xcodeproj
```

シミュレータでも動かしたいときは、上のように `ios-sim` も一緒に作ってください（CI は実機用の `ios-device` だけ）。

## 初めて使うとき

1. メニュー（…）→ 設定 → AI →「AIモデル」で、モデルを選んでダウンロードします。
   - iOS 26 で Apple Intelligence が使える iPhone なら、ダウンロードなしで使えます。
   - おすすめは **Qwen3.5 4B**（約2.7GB、ページ操作にも向く）。メモリが少ない iPhone は **LFM3 VL 2B**（約1.1GB）。
2. 下の ✨ ボタンで AI パネルを開いて質問します。🪄 でブラウザ操作、🌐 で「Webでまとめて調べる」のオン/オフ。
3. メモリが足りずに読み込めないときは、「AIモデル」の「コンテキスト長」を短くしてください。

## 構成

```
project.yml                    XcodeGen の定義（iOS 17+、llama.xcframework を埋め込み、FoundationModels は weak）
Orbit/
  LocalAI/
    LlamaEngine.swift          llama.cpp の実行（ひび手帳の HibiLLMPlugin と同じ作り＋GBNF の文法）、モデルのダウンロード
    AppleLLM.swift             Apple Intelligence（Foundation Models）
    ChatTemplate.swift         モデルごとの会話の書式、<think> とチャンネル形式の取り除き
    ModelCatalog.swift         モデルの一覧（まいにち と同じ）
    LocalAI.swift              モデルの管理・読み込み・生成
  AI/
    AssistantEngine.swift      会話の入口（ローカル / クラウドの振り分け、クラウドの tool use）
    AssistantEngine+Local.swift ローカルでの会話・ブラウザ操作・Webでまとめて調べる
    AssistantEngine+Tools.swift ブラウザ操作の実行と確認カード
    LocalAgent.swift           操作の JSON と GBNF、見えないところでページを読む仕組み
    AnthropicClient.swift      （任意）Claude API
  Browser/                     タブ、スペース、アーカイブ、広告ブロック、ページの読み取り・操作の JavaScript
  Models/                      設定、スキル、履歴とスピードダイヤル
  Views/                       画面（ボトムバー、AIパネル、アドレスバー、タブ一覧、スタートページ、設定、AIモデル）
scripts/build-llama.sh         llama.cpp → Vendor/llama.xcframework
scripts/package-ipa.sh         .app → .ipa
```

## 注意点・制限

- iOS のブラウザは WebKit（WKWebView）を使う決まりがあるため、Chromium 系の機能は再現していません。
- ローカルのモデルは数 GB あり、初回のダウンロードに時間がかかります（Wi-Fi 推奨）。生成の速さは iPhone の性能によります。
- 小さなモデルでのブラウザ操作は試験的です。複雑なサイトや、クロスオリジンの iframe・canvas の中は操作できないことがあります。
- 「Webでまとめて調べる」は、選んでいる検索エンジンの結果ページから上位のリンクを読み取ります。検索エンジン側の画面が変わると取れないことがあります。
- 内蔵の広告ブロックは主な広告・トラッカーのドメインだけを対象にした小さなリストです。
