import Foundation
import Observation

/// The driver's availability: weekly hours, time off and the "accepting rides" switch.
/// Times are kept as minutes since midnight while editing and sent as "HH:mm:ss".
@Observable
final class ScheduleModel {
    enum LoadState: Equatable {
        case loading, loaded
        case failed(String)
    }

    /// One block of hours on a day, e.g. 10:00–14:00 (600–840).
    struct Window: Hashable, Identifiable {
        var id = UUID()
        var start: Int
        var end: Int

        var minutes: Int { end - start }
        var label: String { "\(ScheduleModel.clock(start))–\(ScheduleModel.clock(end))" }
    }

    struct Day: Hashable, Identifiable {
        /// The backend's name for the day ("monday"…).
        let key: String
        var windows: [Window]

        var id: String { key }
        var title: String { key.prefix(1).uppercased() + key.dropFirst() }
        var short: String { String(key.prefix(3)).uppercased() }
        var totalMinutes: Int { windows.reduce(0) { $0 + $1.minutes } }
        var summary: String {
            windows.isEmpty ? "Day off" : windows.sorted { $0.start < $1.start }.map(\.label).joined(separator: " · ")
        }
    }

    /// Monday first, like a Croatian calendar.
    static let dayKeys = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    /// Start/end times the backend accepts: every 30 minutes, 00:00–23:30.
    static let slots = Array(stride(from: 0, through: 23 * 60 + 30, by: 30))

    private(set) var days: [Day] = ScheduleModel.dayKeys.map { Day(key: $0, windows: []) }
    private(set) var timeOff: [TimeOff] = []
    private(set) var profile: DriverProfile?
    private(set) var timeZoneId = TimeZone.current.identifier
    private(set) var state: LoadState = .loading
    private(set) var unreadMessages = 0
    private(set) var isUpdatingAccepting = false
    var errorMessage: String?

    private let drivers: DriversService
    private let chat: ChatService

    init(drivers: DriversService = DriversService(), chat: ChatService = ChatService()) {
        self.drivers = drivers
        self.chat = chat
    }

    var isAcceptingRides: Bool { profile?.isAcceptingRides ?? true }

    /// "52 h a week"
    var weeklyTotal: String {
        let minutes = days.reduce(0) { $0 + $1.totalMinutes }
        return minutes == 0 ? "No hours set yet" : "\(Self.hours(minutes)) a week"
    }

    /// "Zagreb" from "Europe/Zagreb".
    var timeZoneCity: String {
        timeZoneId.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? timeZoneId
    }

    // MARK: Loading

    func load() async {
        do {
            // All three at the same time.
            async let schedule = drivers.mySchedule()
            async let off = drivers.myTimeOff()
            async let me = drivers.myProfile()
            apply(try await schedule)
            timeOff = try await off
            profile = try await me
            state = .loaded
        } catch {
            if Task.isCancelled { return }
            if state != .loaded { state = .failed(error.localizedDescription) }
        }
        if let count = try? await chat.unreadCount() {
            unreadMessages = count
        }
    }

    // MARK: Weekly hours

    /// Saves one day's hours, also copying them to `alsoApplyTo` days. The backend replaces the whole week.
    func save(_ day: Day, alsoApplyTo extraDays: Set<String>) async throws {
        var week = days
        for index in week.indices where week[index].key == day.key || extraDays.contains(week[index].key) {
            week[index].windows = day.windows.map { Window(start: $0.start, end: $0.end) }
        }
        let windows = week.flatMap { day in
            day.windows.map { WeeklySchedule.Window(dayOfWeek: day.key, startTime: Self.apiTime($0.start), endTime: Self.apiTime($0.end)) }
        }
        apply(try await drivers.replaceMySchedule(windows))
    }

    // MARK: Accepting rides

    func setAcceptingRides(_ isOn: Bool) async {
        guard let profile, !isUpdatingAccepting else { return }
        isUpdatingAccepting = true
        defer { isUpdatingAccepting = false }
        do {
            self.profile = try await drivers.updateMyProfile(UpdateDriverProfileRequest(profile, isAcceptingRides: isOn))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Time off

    func addTimeOff(startsAt: Date, endsAt: Date, reason: String) async throws {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let created = try await drivers.addTimeOff(CreateTimeOffRequest(startsAt: startsAt, endsAt: endsAt, reason: trimmed.isEmpty ? nil : trimmed))
        timeOff = (timeOff + [created]).sorted { $0.startsAt < $1.startsAt }
    }

    func deleteTimeOff(_ item: TimeOff) async {
        do {
            try await drivers.deleteTimeOff(item.id)
            timeOff.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Helpers

    private func apply(_ schedule: WeeklySchedule) {
        timeZoneId = schedule.timeZoneId
        days = Self.dayKeys.map { key in
            Day(key: key, windows: schedule.windows
                .filter { $0.dayOfWeek == key }
                .map { Window(start: Self.minutes($0.startTime), end: Self.minutes($0.endTime)) }
                .sorted { $0.start < $1.start })
        }
    }

    /// "10:30:00" → 630
    static func minutes(_ time: String) -> Int {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        return (parts.first ?? 0) * 60 + (parts.dropFirst().first ?? 0)
    }

    /// 630 → "10:30:00"
    static func apiTime(_ minutes: Int) -> String {
        String(format: "%02d:%02d:00", minutes / 60, minutes % 60)
    }

    /// 630 → "10:30"
    static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// 90 → "1.5 h", 600 → "10 h"
    static func hours(_ minutes: Int) -> String {
        "\((Double(minutes) / 60).formatted(.number.precision(.fractionLength(0...1)))) h"
    }

    /// Checks one day's windows the way the backend does. Returns a message, or nil when they're fine.
    static func validate(_ windows: [Window]) -> String? {
        let sorted = windows.sorted { $0.start < $1.start }
        if sorted.contains(where: { $0.end <= $0.start }) {
            return "Each block has to end after it starts."
        }
        for (previous, next) in zip(sorted, sorted.dropFirst()) where next.start < previous.end {
            return "\(previous.label) and \(next.label) overlap."
        }
        return nil
    }
}
