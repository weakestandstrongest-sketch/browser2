import SwiftUI

@main
struct OrbitApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environment(model)
                .tint(Theme.accent)
                .preferredColorScheme(model.settings.appearance == .system ? nil : (model.settings.appearance == .dark ? .dark : .light))
                .onChange(of: scenePhase) {
                    if scenePhase == .active { model.becameActive() }
                }
        }
    }
}
