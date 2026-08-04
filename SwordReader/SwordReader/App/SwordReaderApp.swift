import SwiftUI

@main
struct SwordReaderApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.start() }
        }
        #if os(macOS)
        .commands { SwordReaderCommands(model: model) }
        #endif
    }
}

