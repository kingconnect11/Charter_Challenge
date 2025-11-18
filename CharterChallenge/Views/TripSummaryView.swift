import SwiftUI

struct TripSummaryView: View {
    @EnvironmentObject var gameVM: GameViewModel
    let summary: TripSummary
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Charter Complete!")
                            .font(.title)
                            .fontWeight(.bold)

                        Text(summary.charter.title)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Net Profit
                    VStack(spacing: 4) {
                        Text("Net Profit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(Int(summary.netProfit).formatted())")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(summary.netProfit >= 0 ? .green : .red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Revenue Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Revenue")
                            .font(.headline)

                        SummaryRow(
                            label: "Base Pay",
                            value: summary.basePay,
                            color: .green
                        )

                        SummaryRow(
                            label: "Tip (\(Int(summary.tipRate * 100))%)",
                            value: summary.tipAmount,
                            color: .green
                        )

                        Divider()

                        SummaryRow(
                            label: "Total Revenue",
                            value: summary.totalPay,
                            color: .green,
                            bold: true
                        )
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 2)

                    // Costs Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Costs")
                            .font(.headline)

                        SummaryRow(
                            label: "Operations & Crew",
                            value: summary.opexCost,
                            color: .red
                        )

                        SummaryRow(
                            label: "Repairs",
                            value: summary.repairCost,
                            color: .red
                        )

                        SummaryRow(
                            label: "Cleaning",
                            value: summary.cleaningCost,
                            color: .red
                        )

                        if summary.spoilageLoss > 0 {
                            SummaryRow(
                                label: "Spoilage Loss",
                                value: summary.spoilageLoss,
                                color: .orange
                            )
                        }

                        Divider()

                        SummaryRow(
                            label: "Total Costs",
                            value: summary.opexCost + summary.repairCost + summary.cleaningCost + summary.spoilageLoss,
                            color: .red,
                            bold: true
                        )
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 2)

                    // Satisfaction Scores
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Guest Satisfaction")
                            .font(.headline)

                        SatisfactionBar(label: "Service", score: summary.satisfaction.service)
                        SatisfactionBar(label: "Cuisine", score: summary.satisfaction.cuisine)
                        SatisfactionBar(label: "Safety", score: summary.satisfaction.safety)
                        SatisfactionBar(label: "Comfort", score: summary.satisfaction.comfort)
                        SatisfactionBar(label: "Activities", score: summary.satisfaction.activities)

                        Divider()

                        HStack {
                            Text("Overall")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.1f / 5.0", summary.satisfaction.overall))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor(summary.satisfaction.overall))
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 2)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Trip Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    func scoreColor(_ score: Double) -> Color {
        if score >= 4.5 {
            return .green
        } else if score >= 3.5 {
            return .blue
        } else if score >= 2.5 {
            return .orange
        } else {
            return .red
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: Double
    let color: Color
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(bold ? .subheadline.bold() : .subheadline)
            Spacer()
            Text("$\(Int(value).formatted())")
                .font(bold ? .subheadline.bold() : .subheadline)
                .foregroundColor(color)
        }
    }
}

struct SatisfactionBar: View {
    let label: String
    let score: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f", score))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(barColor(score))
                        .frame(width: geometry.size.width * (score / 5.0), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }

    func barColor(_ score: Double) -> Color {
        if score >= 4.5 {
            return .green
        } else if score >= 3.5 {
            return .blue
        } else if score >= 2.5 {
            return .orange
        } else {
            return .red
        }
    }
}
