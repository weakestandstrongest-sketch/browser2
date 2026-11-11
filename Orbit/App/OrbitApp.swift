import SwiftUI

@main
struct OrbitApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environment(model)
                .tint(model.tabs.currentSpace.theme.accent)
                .onChange(of: scenePhase) {
                    if scenePhase == .active { model.becameActive() }
                }
        }
    }
}
