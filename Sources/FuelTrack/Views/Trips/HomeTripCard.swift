import SwiftData
import SwiftUI
import UIKit

struct HomeTripCard: View {
    let vehicle: Vehicle

    @Environment(TripRecorder.self) private var tripRecorder
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showActive = false
    @State private var confirmEnd = false
    @State private var liveBadgePulse = false

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
                        liveBadge
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
            startLiveBadgeAnimationIfNeeded()
        }
        .onChange(of: vehicle.id) { _, _ in
            tripRecorder.attach(modelContext: modelContext)
            tripRecorder.restoreActiveTripIfNeeded(for: vehicle)
        }
        .onChange(of: tripRecorder.isRecording) { _, _ in
            startLiveBadgeAnimationIfNeeded()
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

    private var liveBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(GlassTheme.accentWarm)
                .frame(width: 7, height: 7)
                .opacity(liveBadgePulse || reduceMotion ? 1 : 0.4)
                .scaleEffect(liveBadgePulse || reduceMotion ? 1.2 : 0.8)
            Text("LIVE")
                .font(.caption.weight(.bold))
                .tracking(0.08)
                .foregroundStyle(GlassTheme.accentWarm)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(GlassTheme.accentWarm.opacity(liveBadgePulse || reduceMotion ? 0.22 : 0.12))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(GlassTheme.accentWarm.opacity(0.45), lineWidth: 1)
        }
        .accessibilityLabel("Recording live trip")
    }

    @ViewBuilder
    private var liveBlock: some View {
        if tripRecorder.backgroundLimited {
            Text("Background tracking needs Always location. Open Settings if the trip pauses when locked.")
                .font(.caption2)
                .foregroundStyle(.orange)
        }

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            GlassStatChip(
                title: "Distance",
                value: Formatters.tripDistance(tripRecorder.liveDistance, unit: vehicle.odometerUnit)
            )
            GlassStatChip(
                title: "Speed",
                value: Formatters.tripSpeed(tripRecorder.currentSpeed, unit: vehicle.odometerUnit)
            )
            GlassStatChip(
                title: "Avg",
                value: Formatters.tripSpeed(tripRecorder.liveAverageSpeed, unit: vehicle.odometerUnit)
            )
            GlassStatChip(
                title: "Est. MPG",
                value: Formatters.consumptionMPG(tripRecorder.liveEstimatedMPG),
                tint: GlassTheme.accentWarm
            )
        }

        LinearGradient(
            colors: [GlassTheme.accent, GlassTheme.accentWarm],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 2)
        .clipShape(Capsule())

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

    private func startLiveBadgeAnimationIfNeeded() {
        guard tripRecorder.isRecording, isThisVehicleActive, !reduceMotion else {
            liveBadgePulse = true
            return
        }
        liveBadgePulse = false
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            liveBadgePulse = true
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