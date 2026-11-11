import Foundation
import Observation

struct ClaudeModelOption: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    /// Server-side refusal fallbacks (`fallbacks: "default"`).
    let supportsFallbacks: Bool
    /// Dynamic-filtering web search (`web_search_20260209`).
    let supportsWebSearch: Bool

    static let all: [ClaudeModelOption] = [
        .init(id: "claude-opus-5-5", name: "Claude Opus 5.5", detail: "最も賢い・既定", supportsFallbacks: true, supportsWebSearch: true),
        .init(id: "claude-sonnet-5-5", name: "Claude Sonnet 5.5", detail: "速さと賢さのバランス", supportsFallbacks: true, supportsWebSearch: true),
        .init(id: "claude-haiku-5-5", name: "Claude Haiku 5.5", detail: "高速・低コスト", supportsFallbacks: false, supportsWebSearch: false),
    ]

    static func find(_ id: String) -> ClaudeModelOption {
        all.first { $0.id == id } ?? all[0]
    }
}

enum EffortLevel: String, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var label: String {
        switch self {
        case .low: return "低（速い）"
        case .medium: return "中（標準）"
        case .high: return "高（じっくり）"
        }
    }
}

enum ApprovalPolicy: String, CaseIterable, Identifiable {
    case always, sensitive, never
    var id: String { rawValue }
    var label: String {
        switch self {
        case .always: return "すべての操作を確認"
        case .sensitive: return "重要な操作のみ確認"
        case .never: return "確認しない"
        }
    }
}

enum OmniboxDefault: String, CaseIterable, Identifiable {
    case search, ai
    var id: String { rawValue }
    var label: String {
        switch self {
        case .search: return "Web検索"
        case .ai: return "AIに質問"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var apiKey: String {
        didSet { Keychain.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: "anthropic-api-key") }
    }
    var model: String { didSet { defaults.set(model, forKey: "model") } }
    var effort: EffortLevel { didSet { defaults.set(effort.rawValue, forKey: "effort") } }
    var approvalPolicy: ApprovalPolicy { didSet { defaults.set(approvalPolicy.rawValue, forKey: "approvalPolicy") } }
    var searchEngine: SearchEngine { didSet { defaults.set(searchEngine.rawValue, forKey: "searchEngine") } }
    var omniboxDefault: OmniboxDefault { didSet { defaults.set(omniboxDefault.rawValue, forKey: "omniboxDefault") } }
    var webSearchEnabled: Bool { didSet { defaults.set(webSearchEnabled, forKey: "webSearchEnabled") } }
    /// Free-form "about me" memory that is added to the system prompt (Dia-style personalization).
    var aboutMe: String { didSet { defaults.set(aboutMe, forKey: "aboutMe") } }
    /// Optional proxy / gateway base URL. Empty = https://api.anthropic.com
    var baseURL: String { didSet { defaults.set(baseURL, forKey: "baseURL") } }

    init() {
        apiKey = Keychain.get("anthropic-api-key") ?? ""
        model = defaults.string(forKey: "model") ?? ClaudeModelOption.all[0].id
        effort = EffortLevel(rawValue: defaults.string(forKey: "effort") ?? "") ?? .medium
        approvalPolicy = ApprovalPolicy(rawValue: defaults.string(forKey: "approvalPolicy") ?? "") ?? .sensitive
        searchEngine = SearchEngine(rawValue: defaults.string(forKey: "searchEngine") ?? "") ?? .google
        omniboxDefault = OmniboxDefault(rawValue: defaults.string(forKey: "omniboxDefault") ?? "") ?? .search
        webSearchEnabled = defaults.object(forKey: "webSearchEnabled") as? Bool ?? true
        aboutMe = defaults.string(forKey: "aboutMe") ?? ""
        baseURL = defaults.string(forKey: "baseURL") ?? ""
    }

    var modelOption: ClaudeModelOption { ClaudeModelOption.find(model) }

    var resolvedBaseURL: URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://api.anthropic.com")!
    }

    var hasAPIKey: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
