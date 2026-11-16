import SwiftData
import SwiftUI
import UIKit

struct HomeTripCard: View {
    let vehicle: Vehicle

    @Environment(TripRecorder.self) private var tripRecorder
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var showActive = false
    @State private var confirmEnd = false

    private var isThisVehicleActive: Bool {
        tripRecorder.activeTrip?.vehicle?.id == vehicle.id
            || vehicle.activeTrip != nil
    }

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Trip Logger", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.headline)
                    Spacer()
                    if tripRecorder.isRecording && isThisVehicleActive {
                        Text("LIVE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GlassTheme.accentWarm)
                    }
                }

                if let error = tripRecorder.lastError, !isThisVehicleActive {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if isThisVehicleActive {
                    liveBlock
                } else {
                    Text("Track distance, speed, and estimated MPG from your fuel log.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        start()
                    } label: {
                        Text("Start trip")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GlassTheme.accent)
                }
            }
        }
        .onAppear {
            tripRecorder.attach(modelContext: modelContext)
            tripRecorder.restoreActiveTripIfNeeded(for: vehicle)
        }
        .onChange(of: vehicle.id) { _, _ in
            tripRecorder.attach(modelContext: modelContext)
            tripRecorder.restoreActiveTripIfNeeded(for: vehicle)
        }
        .sheet(isPresented: $showActive) {
            NavigationStack {
                ActiveTripView(vehicle: vehicle)
            }
        }
        .confirmationDialog("End trip?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End trip", role: .destructive) {
                tripRecorder.end(keepEmptyTrip: true)
            }
            Button("Discard trip", role: .destructive) {
                tripRecorder.discard()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var liveBlock: some View {
        if tripRecorder.backgroundLimited {
            Text("Background tracking needs Always location. Open Settings if the trip pauses when locked.")
                .font(.caption2)
                .foregroundStyle(.orange)
        }

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            GlassStatChip(title: "Distance", value: Formatters.tripDistance(tripRecorder.liveDistance, unit: vehicle.odometerUnit))
            GlassStatChip(title: "Speed", value: Formatters.tripSpeed(tripRecorder.currentSpeed, unit: vehicle.odometerUnit))
            GlassStatChip(title: "Avg", value: Formatters.tripSpeed(tripRecorder.liveAverageSpeed, unit: vehicle.odometerUnit))
            GlassStatChip(
                title: "Est. MPG",
                value: Formatters.consumptionMPG(tripRecorder.liveEstimatedMPG),
                tint: GlassTheme.accentWarm
            )
        }

        HStack {
            Button("Open") { showActive = true }
                .buttonStyle(.bordered)
            Button("End trip") { confirmEnd = true }
                .buttonStyle(.borderedProminent)
                .tint(GlassTheme.accentWarm)
            if !tripRecorder.hasAlwaysAuthorization {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(.caption)
            }
        }
    }

    private func start() {
        tripRecorder.attach(modelContext: modelContext)
        let stats = FuelStats.compute(vehicle: vehicle)
        let ok = tripRecorder.start(
            vehicle: vehicle,
            averageMPG: stats.averageMPG,
            averageLitersPer100km: stats.averageLitersPer100km
        )
        if ok { showActive = true }
    }
}