import SwiftUI

@main
struct PeekyApp: App {
    var body: some Scene {
        Window("Peeky", id: "main") {
            WelcomeView()
                .frame(minWidth: 640, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
