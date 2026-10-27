import CoreLocation
import Foundation
import Observation

/// Everything the "New ride" sheet needs: the driver's schedule, free start times for the picked
/// day and duration, the meeting point, and sending the request.
@Observable
final class NewRideModel {
    enum SlotsState: Equatable {
        case loading, loaded
        case failed(String)
    }

    /// What the free times depend on. The view reloads them whenever this changes (`.task(id:)`).
    struct SlotsQuery: Equatable {
        let day: Date
        let duration: Int
    }

    static let durations = [30, 60, 90, 120, 180, 240]

    let car: NearbyCar

    /// Days and times are shown in the driver's time zone, since that's where the ride happens.
    private(set) var timeZone: TimeZone = .current
    /// Weekdays the driver works (Calendar numbering, 1 = Sunday). Nil until the schedule has loaded.
    private(set) var workingWeekdays: Set<Int>?
    var selectedDay: Date
    var duration = 60

    private(set) var slots: [TimeSlot] = []
    private(set) var slotsState: SlotsState = .loading
    private(set) var price: Decimal?
    var selectedSlot: TimeSlot?

    var meetingPoint: MeetingPointType = .riderComesToDriver
    var address = ""
    var note = ""

    private(set) var isSubmitting = false
    var errorMessage: String?
    private(set) var createdRide: Ride?

    private let cars: CarsService
    private let drivers: DriversService
    private let rides: RidesService

    init(car: NearbyCar, cars: CarsService = CarsService(), drivers: DriversService = DriversService(), rides: RidesService = RidesService()) {
        self.car = car
        self.cars = cars
        self.drivers = drivers
        self.rides = rides
        selectedDay = Calendar.current.startOfDay(for: .now)
    }

    // MARK: Derived values

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Today plus the next 13 days.
    var days: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var slotsQuery: SlotsQuery { SlotsQuery(day: selectedDay, duration: duration) }

    /// Exact price from the server once slots have loaded; an estimate before that.
    var totalPrice: Decimal { price ?? car.car.pricePerHour * Decimal(duration) / 60 }

    var canSubmit: Bool { selectedSlot != nil && !isSubmitting }

    func isWorkingDay(_ day: Date) -> Bool {
        workingWeekdays?.contains(calendar.component(.weekday, from: day)) ?? true
    }

    func format(_ date: Date, _ style: Date.FormatStyle) -> String {
        var style = style
        style.timeZone = timeZone
        return date.formatted(style)
    }

    // MARK: Loading

    func loadSchedule() async {
        guard let schedule = try? await drivers.schedule(car.driver.id) else { return }
        if let zone = TimeZone(identifier: schedule.timeZoneId) {
            timeZone = zone
        }
        workingWeekdays = Set(schedule.windows.compactMap { Self.weekdayNumbers[$0.dayOfWeek] })

        // Start on the first day the driver actually works.
        let today = calendar.startOfDay(for: .now)
        selectedDay = days.first(where: isWorkingDay) ?? today
    }

    func loadSlots() async {
        slotsState = .loading
        do {
            let response = try await cars.slots(carID: car.car.id, date: apiDate(selectedDay), durationMinutes: duration)
            slots = response.slots
            price = response.price
            slotsState = .loaded
            if let selectedSlot, !slots.contains(selectedSlot) {
                self.selectedSlot = nil
            }
        } catch {
            // Cancelled because the user picked another day/duration; the new load takes over.
            if Task.isCancelled { return }
            slotsState = .failed(error.localizedDescription)
        }
    }

    // MARK: Booking

    func requestRide() async {
        guard let slot = selectedSlot, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        var latitude: Double?
        var longitude: Double?
        if meetingPoint == .driverComesToRider {
            let location = await LocationProvider.currentLocation()
            guard !location.isFallback else {
                errorMessage = "Allow location access so \(car.driver.firstName) knows where to pick you up, or choose another meeting option."
                return
            }
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
        }

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = CreateRideRequest(
            carId: car.car.id,
            startsAt: slot.startsAt,
            durationMinutes: duration,
            meetingPointType: meetingPoint,
            meetingLatitude: latitude,
            meetingLongitude: longitude,
            meetingAddress: meetingPoint == .riderComesToDriver || trimmedAddress.isEmpty ? nil : trimmedAddress,
            note: trimmedNote.isEmpty ? nil : trimmedNote)

        do {
            createdRide = try await rides.request(request)
        } catch let error as APIError where error.code == "slot_unavailable" {
            // Someone else was faster: show fresh times.
            errorMessage = error.localizedDescription
            selectedSlot = nil
            await loadSlots()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Helpers

    /// "2026-10-28" in the driver's time zone, the format the slots endpoint expects.
    private func apiDate(_ day: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static let weekdayNumbers = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7,
    ]
}

extension MeetingPointType {
    /// How the option is worded for the rider.
    func riderTitle(driver: String) -> String {
        switch self {
        case .driverComesToRider: "Pick me up"
        case .riderComesToDriver: "I'll go to \(driver)"
        case .agreedLocation: "We'll agree on a spot"
        }
    }

    func riderSubtitle(driver: String) -> String {
        switch self {
        case .driverComesToRider: "\(driver) comes to your current location."
        case .riderComesToDriver: "The address is shared once \(driver) confirms."
        case .agreedLocation: "Suggest a place now, or sort it out in chat."
        }
    }
}

/// "30 min", "1 h", "1.5 h"…
func durationLabel(_ minutes: Int) -> String {
    minutes < 60 ? "\(minutes) min" : "\((Double(minutes) / 60).formatted(.number.precision(.fractionLength(0...1)))) h"
}
