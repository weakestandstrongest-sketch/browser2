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
