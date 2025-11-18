import SwiftUI

@main
struct CharterChallengeApp: App {
    @StateObject private var gameVM = GameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameVM)
        }
    }
}
