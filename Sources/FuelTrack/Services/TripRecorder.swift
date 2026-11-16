import CoreLocation
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TripRecorder: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var modelContext: ModelContext?
    private var lastAcceptedLocation: CLLocation?
    private var nextSequence = 0
    private var economyMPG: Double?
    private var economyL100: Double?
    private var unit: OdometerUnit = .miles

    private(set) var activeTrip: Trip?
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var lastError: String?
    private(set) var isRecording = false
    /// True when trip is active but only When-In-Use was granted.
    private(set) var backgroundLimited = false

    var currentSpeed: Double = 0
    var liveDistance: Double = 0
    var liveDurationSeconds: Double = 0
    var liveAverageSpeed: Double = 0
    var liveMaxSpeed: Double = 0
    var liveEstimatedMPG: Double?
    var liveEstimatedL100: Double?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
        manager.showsBackgroundLocationIndicator = true
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var isAuthorizedWhenInUseOrBetter: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: true
        default: false
        }
    }

    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }

    func requestWhenInUse() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestAlwaysIfNeeded() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
    }

    func restoreActiveTripIfNeeded(for vehicle: Vehicle) {
        guard let trip = vehicle.activeTrip else { return }
        activeTrip = trip
        unit = vehicle.odometerUnit
        economyMPG = trip.estimatedMPG
        economyL100 = trip.estimatedLitersPer100km
        nextSequence = (trip.points.map(\.sequence).max() ?? -1) + 1
        liveDistance = trip.distance
        liveMaxSpeed = trip.maxSpeed
        liveEstimatedMPG = trip.estimatedMPG
        liveEstimatedL100 = trip.estimatedLitersPer100km
        refreshLiveDuration()
        if let last = trip.sortedPoints.last {
            lastAcceptedLocation = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude),
                altitude: 0,
                horizontalAccuracy: last.horizontalAccuracy ?? 0,
                verticalAccuracy: -1,
                course: -1,
                speed: last.speedMps ?? -1,
                timestamp: last.recordedAt
            )
        }
        if isAuthorizedWhenInUseOrBetter {
            beginUpdates()
        }
    }

    @discardableResult
    func start(
        vehicle: Vehicle,
        averageMPG: Double?,
        averageLitersPer100km: Double?
    ) -> Bool {
        guard vehicle.activeTrip == nil else {
            restoreActiveTripIfNeeded(for: vehicle)
            return activeTrip != nil
        }
        guard let modelContext else {
            lastError = "Trip storage isn’t ready."
            return false
        }
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            lastError = "Allow location access to start a trip."
            return false
        }
        guard isAuthorizedWhenInUseOrBetter else {
            lastError = "Location access is required to start a trip."
            return false
        }

        unit = vehicle.odometerUnit
        let eco = TripStats.estimatedEconomy(
            averageMPG: averageMPG,
            averageLitersPer100km: averageLitersPer100km
        )
        economyMPG = eco.mpg
        economyL100 = eco.litersPer100km

        let trip = Trip(
            status: .active,
            estimatedMPG: eco.mpg,
            estimatedLitersPer100km: eco.litersPer100km,
            vehicle: vehicle
        )
        modelContext.insert(trip)
        try? modelContext.save()

        activeTrip = trip
        lastAcceptedLocation = nil
        nextSequence = 0
        liveDistance = 0
        liveMaxSpeed = 0
        currentSpeed = 0
        liveAverageSpeed = 0
        liveDurationSeconds = 0
        liveEstimatedMPG = eco.mpg
        liveEstimatedL100 = eco.litersPer100km
        lastError = nil
        beginUpdates()
        return true
    }

    func end(keepEmptyTrip: Bool = false) {
        guard let trip = activeTrip, let modelContext else { return }
        stopUpdates()
        finalizeLiveFields(on: trip)
        if trip.distance < 0.05 && !keepEmptyTrip {
            modelContext.delete(trip)
        } else {
            trip.status = .completed
            trip.endedAt = .now
        }
        try? modelContext.save()
        clearSession()
    }

    func discard() {
        guard let trip = activeTrip, let modelContext else { return }
        stopUpdates()
        modelContext.delete(trip)
        try? modelContext.save()
        clearSession()
    }

    private func beginUpdates() {
        backgroundLimited = !hasAlwaysAuthorization
        manager.allowsBackgroundLocationUpdates = hasAlwaysAuthorization
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()
        isRecording = true
        if authorizationStatus == .authorizedWhenInUse {
            requestAlwaysIfNeeded()
        }
    }

    private func stopUpdates() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
        isRecording = false
    }

    private func clearSession() {
        activeTrip = nil
        lastAcceptedLocation = nil
        nextSequence = 0
        liveDistance = 0
        liveDurationSeconds = 0
        liveAverageSpeed = 0
        liveMaxSpeed = 0
        currentSpeed = 0
        liveEstimatedMPG = nil
        liveEstimatedL100 = nil
        backgroundLimited = false
    }

    private func refreshLiveDuration() {
        guard let trip = activeTrip else { return }
        liveDurationSeconds = TripStats.durationSeconds(startedAt: trip.startedAt, endedAt: .now)
        liveAverageSpeed = TripStats.averageSpeed(distance: liveDistance, durationSeconds: liveDurationSeconds)
    }

    private func finalizeLiveFields(on trip: Trip) {
        refreshLiveDuration()
        trip.distance = liveDistance
        trip.durationSeconds = liveDurationSeconds
        trip.averageSpeed = liveAverageSpeed
        trip.maxSpeed = liveMaxSpeed
        trip.estimatedMPG = liveEstimatedMPG
        trip.estimatedLitersPer100km = liveEstimatedL100
        if let last = trip.sortedPoints.last {
            trip.endLatitude = last.latitude
            trip.endLongitude = last.longitude
        }
    }

    private func accept(_ location: CLLocation) {
        guard let trip = activeTrip, let modelContext else { return }
        guard TripStats.hasAcceptableAccuracy(location) else { return }

        if let previous = lastAcceptedLocation {
            let jump = location.distance(from: previous)
            if jump > TripStats.maximumJumpMeters {
                lastAcceptedLocation = location
                return
            }
            liveDistance += TripStats.distanceInUnit(metres: jump, unit: unit)
        } else {
            trip.startLatitude = location.coordinate.latitude
            trip.startLongitude = location.coordinate.longitude
        }

        let point = TripPoint(
            recordedAt: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speedMps: location.speed >= 0 ? location.speed : nil,
            horizontalAccuracy: location.horizontalAccuracy,
            sequence: nextSequence,
            trip: trip
        )
        nextSequence += 1
        modelContext.insert(point)

        if location.speed >= 0 {
            let speed = TripStats.speedInUnit(metersPerSecond: location.speed, unit: unit)
            currentSpeed = speed
            liveMaxSpeed = max(liveMaxSpeed, speed)
        }

        refreshLiveDuration()
        trip.distance = liveDistance
        trip.durationSeconds = liveDurationSeconds
        trip.averageSpeed = liveAverageSpeed
        trip.maxSpeed = liveMaxSpeed
        trip.endLatitude = location.coordinate.latitude
        trip.endLongitude = location.coordinate.longitude
        try? modelContext.save()
        lastAcceptedLocation = location
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if self.activeTrip != nil, self.isAuthorizedWhenInUseOrBetter {
                self.beginUpdates()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations {
                self.accept(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.lastError = message
        }
    }
}