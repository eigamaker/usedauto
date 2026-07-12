import SwiftUI

@main
struct UsedCarCityApp: App {
    @StateObject private var game = GameEngine()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .preferredColorScheme(.light)
        }
    }
}

