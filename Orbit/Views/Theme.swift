import SwiftUI

/// 色と書体。Dia の「白い紙＋虹色の光」と Comet の「墨色＋ティール＋明朝の見出し」を合わせる。
enum Theme {
    /// Comet のティール
    static let accent = Color(red: 0.07, green: 0.58, blue: 0.66)
    /// Dia の虹（入力欄や AI の縁からにじむ光）
    static let rainbow: [Color] = [
        Color(red: 1.00, green: 0.56, blue: 0.69), Color(red: 1.00, green: 0.72, blue: 0.44),
        Color(red: 0.48, green: 0.72, blue: 1.00), Color(red: 0.71, green: 0.61, blue: 1.00),
    ]
    static let gradient = LinearGradient(colors: rainbow, startPoint: .leading, endPoint: .trailing)
    /// 紙と墨
    static let paper = Color(red: 0.969, green: 0.965, blue: 0.949)
    static let ink = Color(red: 0.055, green: 0.059, blue: 0.063)

    /// 見出し用の明朝体
    static func display(_ size: CGFloat) -> Font {
        Font.custom("HiraMinProN-W6", size: size)
    }
}

/// AI の印：虹の輪と墨の点。動いている間は輪が回る。
struct OrbView: View {
    var size: CGFloat = 36
    var animating = false
    @State private var rotation = 0.0

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(AngularGradient(colors: Theme.rainbow + [Theme.rainbow[0]], center: .center), lineWidth: max(2.5, size * 0.11))
                .rotationEffect(.degrees(rotation))
            Circle()
                .fill(Color.primary)
                .frame(width: size * 0.26, height: size * 0.26)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.rainbow[3].opacity(animating ? 0.7 : 0), radius: 8)
        .onAppear { updateAnimation() }
        .onChange(of: animating) { updateAnimation() }
    }

    private func updateAnimation() {
        if animating {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { rotation = 360 }
        } else {
            withAnimation(.default) { rotation = 0 }
        }
    }
}

// MARK: - Halo design language (Dia の光 × Comet のサイドカー)

extension View {
    /// すりガラスの面。
    func glass<S: InsettableShape>(_ shape: S) -> some View {
        self
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.09), lineWidth: 1))
    }
}

/// スペースの色がにじむ背景。AI が動いている間はゆっくり揺れる。
struct AuroraBackground: View {
    let theme: SpaceTheme
    var active = false
    var muted = false
    @Environment(\.colorScheme) private var scheme
    @State private var drift = false

    var body: some View {
        let k: Double = muted ? 0.15 : (scheme == .dark ? 0.42 : 0.5)
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                scheme == .dark ? Theme.ink : Theme.paper
                Circle()
                    .fill(theme.colors[0])
                    .frame(width: w * 1.1, height: w * 1.1)
                    .blur(radius: 110)
                    .offset(x: -w * 0.5 + (drift ? 50 : 0), y: h * 0.46)
                    .opacity(0.55 * k)
                Circle()
                    .fill(theme.colors[1])
                    .frame(width: w, height: w)
                    .blur(radius: 120)
                    .offset(x: w * 0.45 - (drift ? 60 : 0), y: h * 0.40)
                    .opacity(0.5 * k)
                Circle()
                    .fill(Theme.rainbow[0])
                    .frame(width: w * 0.6, height: w * 0.6)
                    .blur(radius: 100)
                    .offset(x: w * 0.35, y: -h * 0.46 + (drift ? 70 : 0))
                    .opacity(0.3 * k)
            }
        }
        .ignoresSafeArea()
        .onChange(of: active, initial: true) { _, now in
            if now {
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { drift = true }
            } else {
                withAnimation(.easeInOut(duration: 1.2)) { drift = false }
            }
        }
    }
}

/// 縁を光が回る（AI が考えている・操作している合図）。
struct GlowBorder<S: InsettableShape>: View {
    let shape: S
    var colors: [Color] = Theme.rainbow
    var lineWidth: CGFloat = 2.5
    @State private var angle = 0.0

    var body: some View {
        GeometryReader { geo in
            let side = max(geo.size.width, geo.size.height) * 1.6
            AngularGradient(colors: colors + [colors[0]], center: .center)
                .frame(width: side, height: side)
                .rotationEffect(.degrees(angle))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .mask(shape.strokeBorder(lineWidth: lineWidth))
        .shadow(color: colors[3].opacity(0.6), radius: 7)
        .shadow(color: colors[0].opacity(0.4), radius: 14)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) { angle = 360 }
        }
    }
}
