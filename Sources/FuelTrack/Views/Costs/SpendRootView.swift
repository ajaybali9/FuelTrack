import SwiftData
import SwiftUI

enum SpendScope: String, CaseIterable, Identifiable {
    case car
    case personal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .car: "Car"
        case .personal: "Personal"
        }
    }
}

struct SpendRootView: View {
    @State private var scope: SpendScope = .car
    @State private var showingAddCarCost = false
    @State private var showingAddPersonal = false
    @State private var showingBudgets = false
    @State private var showingCategories = false

    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore

    private var activeVehicle: Vehicle? {
        activeVehicleStore.resolve(from: vehicles)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch scope {
                case .car:
                    CarCostListContent()
                        .smoothContentTransition()
                case .personal:
                    PersonalExpenseListView(showsOwnToolbar: false)
                        .smoothContentTransition()
                }
            }
            .id(scope)
            .animation(.smooth(duration: 0.32), value: scope)
            .navigationTitle("Spend")
            .navigationBarTitleDisplayMode(.large)
            .fuelTrackScreen()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Scope", selection: $scope) {
                        ForEach(SpendScope.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(GlassTheme.accentWarm)
                    .frame(maxWidth: 220)
                }

                ToolbarItem(placement: .topBarLeading) {
                    if scope == .car {
                        vehicleMenu
                    } else {
                        Button {
                            showingBudgets = true
                        } label: {
                            Image(systemName: "chart.pie")
                        }
                        .accessibilityLabel("Budgets")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingCategories = true
                        } label: {
                            Image(systemName: "tag")
                        }
                        .accessibilityLabel("Categories")

                        Button {
                            if scope == .car {
                                showingAddCarCost = true
                            } else {
                                showingAddPersonal = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(scope == .car && activeVehicle == nil)
                    }
                }
            }
            .sheet(isPresented: $showingAddCarCost) {
                if let vehicle = activeVehicle {
                    NavigationStack {
                        CostFormView(vehicle: vehicle, cost: nil)
                    }
                }
            }
            .sheet(isPresented: $showingAddPersonal) {
                NavigationStack {
                    PersonalExpenseFormView(expense: nil)
                }
            }
            .sheet(isPresented: $showingBudgets) {
                NavigationStack {
                    PersonalBudgetView()
                }
            }
            .sheet(isPresented: $showingCategories) {
                NavigationStack {
                    CustomCategoriesView(scope: scope == .car ? .car : .personal)
                }
            }
        }
    }

    @ViewBuilder
    private var vehicleMenu: some View {
        if !vehicles.isEmpty {
            Menu {
                ForEach(vehicles) { vehicle in
                    Button {
                        activeVehicleStore.select(vehicle)
                    } label: {
                        if vehicle.id == activeVehicle?.id {
                            Label(vehicle.name, systemImage: "checkmark")
                        } else {
                            Text(vehicle.name)
                        }
                    }
                }
            } label: {
                Label(activeVehicle?.name ?? "Vehicle", systemImage: "car.side")
            }
        }
    }
}
