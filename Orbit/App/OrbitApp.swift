import SwiftUI

@main
struct OrbitApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environment(model)
                .tint(Theme.accent)
        }
    }
}
