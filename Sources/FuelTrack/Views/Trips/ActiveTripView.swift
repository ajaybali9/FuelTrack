import SwiftUI

struct ActiveTripView: View {
    let vehicle: Vehicle
    @Environment(TripRecorder.self) private var tripRecorder
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmEnd = false
    @State private var livePulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                liveHero
                    .staggeredAppear(index: 0)

                InstrumentSectionHeader(title: "Live readout", tint: GlassTheme.accent)
                    .staggeredAppear(index: 1)

                GlassCard(padding: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        GlassStatChip(
                            title: "Current",
                            value: Formatters.tripSpeed(tripRecorder.currentSpeed, unit: vehicle.odometerUnit)
                        )
                        GlassStatChip(
                            title: "Average",
                            value: Formatters.tripSpeed(tripRecorder.liveAverageSpeed, unit: vehicle.odometerUnit)
                        )
                        GlassStatChip(
                            title: "Max",
                            value: Formatters.tripSpeed(tripRecorder.liveMaxSpeed, unit: vehicle.odometerUnit)
                        )
                        GlassStatChip(
                            title: "Est. MPG",
                            value: Formatters.consumptionMPG(tripRecorder.liveEstimatedMPG),
                            tint: GlassTheme.accentWarm
                        )
                        GlassStatChip(
                            title: "Est. L/100",
                            value: Formatters.consumptionL100(tripRecorder.liveEstimatedL100)
                        )
                    }
                }
                .staggeredAppear(index: 2)
            }
            .padding(FuelTrackTokens.horizontalPadding)
            .padding(.bottom, 8)
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
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                livePulse = true
            }
        }
    }

    private var liveHero: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(GlassTheme.accentWarm)
                        .frame(width: 8, height: 8)
                        .opacity(livePulse || reduceMotion ? 1 : 0.35)
                        .scaleEffect(livePulse || reduceMotion ? 1.15 : 0.85)
                    Text("LIVE")
                        .font(FuelTrackTokens.labelFont())
                        .tracking(0.12)
                        .foregroundStyle(GlassTheme.accentWarm)
                    Spacer()
                    Image(systemName: "location.fill")
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.accent)
                        .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("DISTANCE")
                        .font(FuelTrackTokens.labelFont())
                        .tracking(0.08)
                        .foregroundStyle(.secondary)
                    Text(Formatters.tripDistance(tripRecorder.liveDistance, unit: vehicle.odometerUnit))
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundStyle(GlassTheme.accent)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }

                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(spacing: 8) {
                        Text("ELAPSED")
                            .font(FuelTrackTokens.labelFont())
                            .tracking(0.06)
                            .foregroundStyle(.secondary)
                        Text(Formatters.tripDuration(liveDuration))
                            .font(.system(.title2, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                    }
                }

                LinearGradient(
                    colors: [GlassTheme.accent, GlassTheme.accentWarm],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 3)
                .clipShape(Capsule())
            }
        }
    }

    private var liveDuration: Double {
        if let startedAt = tripRecorder.activeTrip?.startedAt {
            return TripStats.durationSeconds(startedAt: startedAt, endedAt: .now)
        }
        return tripRecorder.liveDurationSeconds
    }
}