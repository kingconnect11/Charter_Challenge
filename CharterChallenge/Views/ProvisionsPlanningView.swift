import SwiftUI

struct ProvisionsPlanningView: View {
    @EnvironmentObject var gameVM: GameViewModel
    let charter: Charter
    let vessel: Vessel
    @Binding var isPresented: Bool
    @State private var selectedQuality: ProvisionQuality = .standard
    @State private var loadedUnits: Int = 0
    
    var crewCount: Int {
        vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
    }
    
    var requiredUnits: Int {
        ProvisionsCalculator.calculateRequiredUnits(
            for: charter,
            guests: charter.guests,
            crewCount: crewCount
        )
    }
    
    var plan: ProvisionsPlan {
        ProvisionsCalculator.createPlan(
            for: charter,
            guests: charter.guests,
            crewCount: crewCount,
            quality: selectedQuality,
            loadedUnits: loadedUnits == 0 ? nil : loadedUnits
        )
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Charter Details") {
                    HStack {
                        Text("Guests")
                        Spacer()
                        Text("\(charter.guests)")
                    }
                    HStack {
                        Text("Crew")
                        Spacer()
                        Text("\(crewCount)")
                    }
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(Int(ceil(charter.durationDays))) days")
                    }
                }
                
                Section("Required Provisions") {
                    HStack {
                        Text("Required Units")
                        Spacer()
                        Text("\(requiredUnits)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Vessel Capacity")
                        Spacer()
                        Text("\(vessel.pantryUnits + vessel.coldStorageUnits) units")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Provision Quality") {
                    Picker("Quality", selection: $selectedQuality) {
                        ForEach([ProvisionQuality.basic, .standard, .premium], id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("Unit Cost")
                        Spacer()
                        Text("$\(Int(ProvisionsCalculator.unitCost(for: selectedQuality)))")
                    }
                }
                
                Section("Load Provisions") {
                    Stepper("Units to Load: \(loadedUnits == 0 ? requiredUnits : loadedUnits)", value: $loadedUnits, in: 0...max(requiredUnits * 2, vessel.pantryUnits + vessel.coldStorageUnits))
                    
                    if loadedUnits == 0 {
                        Text("Will load \(requiredUnits) units (recommended)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if loadedUnits < requiredUnits {
                        Text("⚠️ Under-provisioned by \(requiredUnits - loadedUnits) units")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if loadedUnits > requiredUnits {
                        Text("⚠️ Over-provisioned by \(loadedUnits - requiredUnits) units (risk of spoilage)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Section("Cost Summary") {
                    HStack {
                        Text("Total Cost")
                        Spacer()
                        Text("$\(Int(plan.totalCost))")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    if plan.remainingUnits > 0 {
                        HStack {
                            Text("Estimated Spoilage Loss")
                            Spacer()
                            Text("$\(Int(plan.spoilageLoss))")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Plan Provisions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Load") {
                        let finalPlan = ProvisionsPlan(
                            charterId: charter.id,
                            quality: selectedQuality,
                            requiredUnits: requiredUnits,
                            loadedUnits: loadedUnits == 0 ? requiredUnits : loadedUnits,
                            unitCost: ProvisionsCalculator.unitCost(for: selectedQuality),
                            totalCost: Double(loadedUnits == 0 ? requiredUnits : loadedUnits) * ProvisionsCalculator.unitCost(for: selectedQuality)
                        )
                        gameVM.loadProvisions(vesselId: vessel.id, plan: finalPlan)
                        isPresented = false
                    }
                    .disabled(gameVM.gameState.cash < plan.totalCost)
                }
            }
        }
    }
}

