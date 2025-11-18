import SwiftUI

struct CharterEventsView: View {
    @EnvironmentObject var gameVM: GameViewModel
    @Environment(\.dismiss) var dismiss
    
    var events: [CharterEvent] {
        gameVM.gameState.charterEvents.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        NavigationView {
            List {
                if events.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("No events yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Charter is running smoothly")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(events) { event in
                        EventRow(event: event)
                    }
                }
            }
            .navigationTitle("Charter Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EventRow: View {
    let event: CharterEvent
    
    var icon: String {
        switch event.type {
        case .incident: return "exclamationmark.triangle.fill"
        case .weatherChange: return "cloud.fill"
        case .guestComplaint: return "person.fill.xmark"
        case .guestPraise: return "star.fill"
        case .crewIssue: return "person.2.fill"
        case .equipmentFailure: return "wrench.fill"
        case .smoothSailing: return "checkmark.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch event.type {
        case .incident, .guestComplaint, .equipmentFailure:
            return .red
        case .weatherChange, .crewIssue:
            return .orange
        case .guestPraise, .smoothSailing:
            return .green
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(event.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Show impact
                HStack(spacing: 12) {
                    if event.impact.guestHappinessDelta != 0 {
                        HStack(spacing: 2) {
                            Image(systemName: event.impact.guestHappinessDelta > 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                            Text("Happiness: \(event.impact.guestHappinessDelta > 0 ? "+" : "")\(Int(event.impact.guestHappinessDelta))%")
                                .font(.caption2)
                        }
                        .foregroundColor(event.impact.guestHappinessDelta > 0 ? .green : .red)
                    }
                    
                    if event.impact.staffStressDelta != 0 {
                        HStack(spacing: 2) {
                            Image(systemName: event.impact.staffStressDelta > 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                            Text("Stress: \(event.impact.staffStressDelta > 0 ? "+" : "")\(Int(event.impact.staffStressDelta))%")
                                .font(.caption2)
                        }
                        .foregroundColor(event.impact.staffStressDelta > 0 ? .red : .green)
                    }
                    
                    if event.impact.costDelta > 0 {
                        Text("Cost: +$\(Int(event.impact.costDelta))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

