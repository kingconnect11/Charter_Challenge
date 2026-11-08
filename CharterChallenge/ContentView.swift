import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gameVM: GameViewModel

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HeaderView()

                // Main Content
                TabView {
                    MapView()
                        .tabItem {
                            Label("Map", systemImage: "map.fill")
                        }

                    FleetView()
                        .tabItem {
                            Label("Fleet", systemImage: "sailboat.fill")
                        }

                    StaffView()
                        .tabItem {
                            Label("Staff", systemImage: "person.3.fill")
                        }

                    ChartersView()
                        .tabItem {
                            Label("Charters", systemImage: "calendar.badge.clock")
                        }
                }
            }

            // Toast overlay
            if let message = gameVM.toastMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: gameVM.toastMessage)
            }
        }
        .sheet(isPresented: $gameVM.showingTripSummary) {
            if let summary = gameVM.currentTripSummary {
                TripSummaryView(summary: summary)
            }
        }
        .overlay {
            // Active Charter Overlay (keeps tab bar visible)
            if gameVM.showingActiveCharter {
                VStack(spacing: 0) {
                    NavigationView {
                        ActiveCharterView()
                            .environmentObject(gameVM)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Spacer to preserve tab bar (typically ~49-83 points)
                    Spacer()
                        .frame(height: 0)
                }
                .background(Color(.systemBackground))
                .ignoresSafeArea(.container, edges: [.top, .leading, .trailing])
                // Bottom safe area NOT ignored - preserves tab bar
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}
