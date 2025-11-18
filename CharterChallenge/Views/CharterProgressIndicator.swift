import SwiftUI

struct CharterProgressIndicator: View {
    @EnvironmentObject var gameVM: GameViewModel
    let charterState: ActiveCharterState
    @State private var isExpanded = false
    
    var charter: Charter? {
        gameVM.gameState.activeCharters.first(where: { $0.id == charterState.charterId })
    }
    
    var originPort: Port? {
        guard let charter = charter else { return nil }
        return PortRegistry.port(withName: charter.origin)
    }
    
    var destPort: Port? {
        guard let charter = charter else { return nil }
        return PortRegistry.port(withName: charter.destination)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Expanded Card
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        Text("Route Progress")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Route Info
                    if let origin = originPort, let dest = destPort {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(origin.name)
                                    .font(.subheadline)
                                Spacer()
                            }
                            
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            HStack {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(dest.name)
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                    }
                    
                    // Progress Bar
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Progress")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(Int(charterState.currentPosition.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: charterState.currentPosition.progress, total: 1.0)
                            .tint(.blue)
                            .frame(height: 8)
                        
                        HStack {
                            Text("\(Int(charterState.currentPosition.distanceRemaining)) NM remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .frame(width: 280)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 8)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            // Icon Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 44, height: 44)
                        .shadow(radius: 4)
                    
                    Image(systemName: isExpanded ? "map.fill" : "location.north.line.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding(.trailing, 16)
        }
    }
}

