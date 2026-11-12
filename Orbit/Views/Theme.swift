import SwiftUI

enum Theme {
    static let accent = Color(red: 0.45, green: 0.32, blue: 0.95)
    static let gradient = LinearGradient(
        colors: [Color(red: 0.36, green: 0.42, blue: 1.0), Color(red: 0.62, green: 0.30, blue: 0.95), Color(red: 0.95, green: 0.40, blue: 0.62)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// The glowing "ask AI" orb used in the toolbar and start page.
struct OrbView: View {
    var size: CGFloat = 36
    var animating = false
    @State private var rotation = 0.0

    var body: some View {
        ZStack {
            Circle().fill(Theme.gradient)
            Circle()
                .strokeBorder(AngularGradient(colors: [.white.opacity(0.9), .clear, .white.opacity(0.5), .clear], center: .center), lineWidth: 1.5)
                .rotationEffect(.degrees(rotation))
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.accent.opacity(0.45), radius: animating ? 10 : 4)
        .onAppear { updateAnimation() }
        .onChange(of: animating) { updateAnimation() }
    }

    private func updateAnimation() {
        if animating {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { rotation = 360 }
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
        let k: Double = muted ? 0.35 : (scheme == .dark ? 0.7 : 1.0)
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                scheme == .dark ? Color(red: 0.045, green: 0.047, blue: 0.07) : Color(red: 0.95, green: 0.95, blue: 0.975)
                Circle()
                    .fill(theme.colors[0])
                    .frame(width: w * 1.1, height: w * 1.1)
                    .blur(radius: 110)
                    .offset(x: -w * 0.45 + (drift ? 50 : 0), y: -h * 0.42)
                    .opacity(0.55 * k)
                Circle()
                    .fill(theme.colors[1])
                    .frame(width: w, height: w)
                    .blur(radius: 120)
                    .offset(x: w * 0.45 - (drift ? 60 : 0), y: h * 0.40)
                    .opacity(0.5 * k)
                Circle()
                    .fill(Color(red: 0.95, green: 0.40, blue: 0.62))
                    .frame(width: w * 0.6, height: w * 0.6)
                    .blur(radius: 100)
                    .offset(x: w * 0.3, y: -h * 0.1 + (drift ? 70 : 0))
                    .opacity(0.22 * k)
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
    var colors: [Color] = [Color(red: 0.36, green: 0.42, blue: 1.0), Color(red: 0.66, green: 0.33, blue: 0.95),
                           Color(red: 0.95, green: 0.40, blue: 0.62), Color(red: 0.2, green: 0.8, blue: 0.85)]
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
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) { angle = 360 }
        }
    }
}
