import SwiftUI

/// Arc の「スペース」：タブを用途ごとに分け、それぞれに色を持たせる。
enum SpaceTheme: String, Codable, CaseIterable, Identifiable {
    case violet, ocean, mint, sunset, rose, graphite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .violet: return "バイオレット"
        case .ocean: return "オーシャン"
        case .mint: return "ミント"
        case .sunset: return "サンセット"
        case .rose: return "ローズ"
        case .graphite: return "グラファイト"
        }
    }

    var colors: [Color] {
        switch self {
        case .violet: return [Color(red: 0.36, green: 0.42, blue: 1.0), Color(red: 0.66, green: 0.33, blue: 0.95)]
        case .ocean: return [Color(red: 0.10, green: 0.55, blue: 0.95), Color(red: 0.20, green: 0.80, blue: 0.85)]
        case .mint: return [Color(red: 0.15, green: 0.70, blue: 0.50), Color(red: 0.55, green: 0.85, blue: 0.45)]
        case .sunset: return [Color(red: 1.0, green: 0.55, blue: 0.25), Color(red: 0.95, green: 0.30, blue: 0.45)]
        case .rose: return [Color(red: 0.95, green: 0.35, blue: 0.60), Color(red: 0.75, green: 0.35, blue: 0.90)]
        case .graphite: return [Color(red: 0.25, green: 0.27, blue: 0.32), Color(red: 0.45, green: 0.47, blue: 0.52)]
        }
    }

    var accent: Color { colors[0] }
    var gradient: LinearGradient { LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing) }
}

struct BrowserSpace: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon: String
    var theme: SpaceTheme

    /// プライベート（記録を残さない）タブの置き場所。保存しない。
    static let privateID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AF")!
    static let privateSpace = BrowserSpace(id: privateID, name: "プライベート", icon: "eyeglasses", theme: .graphite)

    var isPrivate: Bool { id == Self.privateID }

    static let defaults: [BrowserSpace] = [
        BrowserSpace(name: "パーソナル", icon: "house", theme: .violet),
        BrowserSpace(name: "仕事", icon: "briefcase", theme: .ocean),
    ]

    static let icons = ["house", "briefcase", "book", "graduationcap", "cart", "airplane", "gamecontroller",
                        "music.note", "film", "heart", "star", "leaf", "flame", "paintbrush", "chevron.left.forwardslash.chevron.right", "sparkles"]
}

/// Arc のように、しばらく見ていないタブを自動でしまう。
enum AutoArchive: String, CaseIterable, Identifiable, Codable {
    case never, hours12, day, week

    var id: String { rawValue }

    var label: String {
        switch self {
        case .never: return "しない"
        case .hours12: return "12時間後"
        case .day: return "1日後"
        case .week: return "1週間後"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .never: return nil
        case .hours12: return 12 * 3600
        case .day: return 24 * 3600
        case .week: return 7 * 24 * 3600
        }
    }
}

struct ArchivedTab: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var url: String
    var spaceID: UUID
    var archivedAt: Date
}
