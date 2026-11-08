import SwiftUI

struct ProvisionsPlanningView: View {
    @EnvironmentObject var gameVM: GameViewModel
    let charter: Charter
    let vessel: Vessel
    @Binding var isPresented: Bool
    @State private var selectedCategory: ProvisionCategory = .food
    @State private var selectedPackages = SelectedProvisions()
    
    var crewCount: Int {
        vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ProvisionCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.rawValue)
                        }
                        .tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Package List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(ProvisionPackageCatalog.packages(for: selectedCategory)) { package in
                            PackageCard(
                                package: package,
                                isSelected: selectedPackages.hasPackage(package.id),
                                onToggle: {
                                    if selectedPackages.hasPackage(package.id) {
                                        selectedPackages.removePackage(package.id)
                                    } else {
                                        selectedPackages.addPackage(package.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                // Summary Footer
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack {
                        Text("Total Cost:")
                            .font(.headline)
                        Spacer()
                        Text("$\(Int(selectedPackages.totalCost))")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Total Satisfaction Bonus:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("+\(Int(selectedPackages.totalSatisfactionBonus))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    // Check for luxury employees
                    let hasChef = vessel.assignedCrew.contains { crewId in
                        gameVM.gameState.hiredCrew.first(where: { $0.id == crewId })?.role == .chef
                    }
                    let hasBartender = vessel.assignedCrew.contains { crewId in
                        gameVM.gameState.hiredCrew.first(where: { $0.id == crewId })?.role == .bartender
                    }
                    let hasMasseuse = vessel.assignedCrew.contains { crewId in
                        gameVM.gameState.hiredCrew.first(where: { $0.id == crewId })?.role == .masseuse
                    }
                    
                    if selectedPackages.totalSatisfactionBonus >= 50.0 && hasChef && hasBartender && hasMasseuse {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Premium setup guarantees 90+ satisfaction!")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .navigationTitle("Select Provisions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Load") {
                        gameVM.loadProvisionPackages(vesselId: vessel.id, packages: selectedPackages)
                        isPresented = false
                    }
                    .disabled(gameVM.gameState.cash < selectedPackages.totalCost || selectedPackages.packages.isEmpty)
                }
            }
        }
    }
}

struct PackageCard: View {
    let package: ProvisionPackage
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Package Name
                    Text(package.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Price Rating
                    HStack(spacing: 4) {
                        Text("Price:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(1...5, id: \.self) { rating in
                            Image(systemName: rating <= package.priceRating ? "dollarsign.circle.fill" : "dollarsign.circle")
                                .font(.caption2)
                                .foregroundColor(rating <= package.priceRating ? .green : .gray)
                        }
                    }
                    
                    // Satisfaction Bonus
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text("+\(Int(package.satisfactionBonus))% satisfaction")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    // Risk Warning (if applicable)
                    if let riskChance = package.riskChance, let riskImpact = package.riskImpact {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            if let condition = package.specialCondition {
                                Text(condition)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            } else {
                                Text("\(Int(riskChance * 100))% chance: \(riskImpact > 0 ? "+" : "")\(Int(riskImpact))% satisfaction")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Cost
                VStack(alignment: .trailing) {
                    Text("$\(Int(package.baseCost))")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
