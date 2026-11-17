import SwiftUI

struct ActiveTripView: View {
    let vehicle: Vehicle
    @Environment(TripRecorder.self) private var tripRecorder
    @Environment(\.dismiss) private var dismiss
    @State private var confirmEnd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(Formatters.tripDistance(tripRecorder.liveDistance, unit: vehicle.odometerUnit))
                    .font(.largeTitle.weight(.bold).monospacedDigit())
                    .fontDesign(.rounded)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(Formatters.tripDuration(liveDuration))
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    GlassStatChip(title: "Current", value: Formatters.tripSpeed(tripRecorder.currentSpeed, unit: vehicle.odometerUnit))
                    GlassStatChip(title: "Average", value: Formatters.tripSpeed(tripRecorder.liveAverageSpeed, unit: vehicle.odometerUnit))
                    GlassStatChip(title: "Max", value: Formatters.tripSpeed(tripRecorder.liveMaxSpeed, unit: vehicle.odometerUnit))
                    GlassStatChip(title: "Est. MPG", value: Formatters.consumptionMPG(tripRecorder.liveEstimatedMPG), tint: GlassTheme.accentWarm)
                    GlassStatChip(title: "Est. L/100", value: Formatters.consumptionL100(tripRecorder.liveEstimatedL100))
                }
            }
            .padding()
        }
        .navigationTitle("Active trip")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackScreen()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("End") { confirmEnd = true }
            }
        }
        .confirmationDialog("End trip?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End trip", role: .destructive) {
                tripRecorder.end(keepEmptyTrip: true)
                dismiss()
            }
            Button("Discard trip", role: .destructive) {
                tripRecorder.discard()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: tripRecorder.activeTrip?.id) { _, newValue in
            if newValue == nil { dismiss() }
        }
    }

    private var liveDuration: Double {
        if let startedAt = tripRecorder.activeTrip?.startedAt {
            return TripStats.durationSeconds(startedAt: startedAt, endedAt: .now)
        }
        return tripRecorder.liveDurationSeconds
    }
}