import SwiftUI

@main
struct VibeslolApp: App {
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .task {
                    await auth.bootstrap()
                }
        }
    }
}
