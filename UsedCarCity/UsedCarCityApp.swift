import SwiftUI

@main
struct UsedCarCityApp: App {
    @StateObject private var game = GameEngine()

    init() {
        GameTheme.installAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .preferredColorScheme(.light)
                .fontDesign(.rounded)
        }
    }
}

