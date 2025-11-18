import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var gameVM: GameViewModel

    var body: some View {
        HStack {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text("Date")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(gameVM.gameState.currentDate, style: .date)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Spacer()

            // Cash
            VStack(alignment: .center, spacing: 2) {
                Text("Cash")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(Int(gameVM.gameState.cash).formatted())")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(gameVM.gameState.cash >= 0 ? .green : .red)
            }

            Spacer()

            // Reputation
            VStack(alignment: .trailing, spacing: 2) {
                Text("Reputation")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("\(gameVM.gameState.reputation)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
    }
}
