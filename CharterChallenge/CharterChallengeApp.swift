import SwiftUI

@main
struct CharterChallengeApp: App {
    @StateObject private var gameVM = GameViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if gameVM.isLoading {
                    LoadingView(progress: $gameVM.loadingProgress, title: "Charter Challenge")
                        .environmentObject(gameVM)
                        .transition(.opacity)
                        .zIndex(1)
                } else {
                    ContentView()
                        .environmentObject(gameVM)
                        .transition(.opacity)
                        .zIndex(0)
                }
            }
            .animation(.easeInOut(duration: 1.0), value: gameVM.isLoading)
        }
    }
}
