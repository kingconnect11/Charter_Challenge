import SwiftUI

struct CharterClockView: View {
    @EnvironmentObject var gameVM: GameViewModel
    @State private var showingControls = false
    
    var charterState: ActiveCharterState? {
        gameVM.gameState.activeCharterState
    }
    
    var charter: Charter? {
        guard let charterId = charterState?.charterId else { return nil }
        return gameVM.gameState.activeCharters.first(where: { $0.id == charterId })
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // Clock Icon Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingControls.toggle()
                }
            }) {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
            
            // Dropdown Controls
            if showingControls, let state = charterState {
                VStack(spacing: 12) {
                    // Pause/Play Button
                    Button(action: {
                        gameVM.toggleCharterPause()
                    }) {
                        HStack {
                            Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                                .font(.headline)
                            Text(state.isPaused ? "Resume" : "Pause")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(state.isPaused ? Color.green : Color.orange)
                        .cornerRadius(8)
                    }
                    
                    // Speed Multipliers
                    VStack(spacing: 6) {
                        Text("Speed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 6) {
                            SpeedButton(multiplier: 1.0, current: state.speedMultiplier)
                            SpeedButton(multiplier: 2.0, current: state.speedMultiplier)
                            SpeedButton(multiplier: 5.0, current: state.speedMultiplier)
                            SpeedButton(multiplier: 10.0, current: state.speedMultiplier)
                            SpeedButton(multiplier: 20.0, current: state.speedMultiplier)
                        }
                    }
                    
                    Divider()
                    
                    // Time Display
                    if let charter = charter {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Elapsed:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatTime(state.elapsedTime))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Remaining:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                let remaining = charter.durationDays * 86400 - state.elapsedTime
                                Text(formatTime(max(0, remaining)))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(remaining < 3600 ? .red : .primary)
                            }
                        }
                    }
                }
                .padding(12)
                .frame(width: 200)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 8)
                .padding(.trailing, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

struct SpeedButton: View {
    @EnvironmentObject var gameVM: GameViewModel
    let multiplier: Double
    let current: Double
    
    var body: some View {
        Button(action: {
            gameVM.setCharterSpeed(multiplier: multiplier)
        }) {
            Text("\(Int(multiplier))x")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(multiplier == current ? .white : .primary)
                .frame(width: 32, height: 28)
                .background(multiplier == current ? Color.blue : Color(.systemGray5))
                .cornerRadius(6)
        }
    }
}

