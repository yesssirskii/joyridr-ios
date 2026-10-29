import SwiftUI

/// Driver's "Schedule" tab, built like Explore: header, glowing pills, glow cards.
/// Tapping a day (or the time-off pill) zooms its editor out of the tapped element.
struct ScheduleView: View {
    @State private var model = ScheduleModel()
    @State private var editingDay: ScheduleModel.Day?
    @State private var addingTimeOff = false
    @State private var confirmPause = false
    @State private var deletingTimeOff: TimeOff?
    @State private var showProfile = false
    @State private var showChat = false
    @Namespace private var scheduleTransition

    private static let timeOffSourceID = "add-time-off"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader { showProfile = true }

                    HStack(spacing: 14) {
                        Button {
                            if model.isAcceptingRides {
                                confirmPause = true
                            } else {
                                Task { await model.setAcceptingRides(true) }
                            }
                        } label: {
                            FilterPill(systemImage: model.isAcceptingRides ? "checkmark.circle.fill" : "pause.circle.fill",
                                       title: model.isAcceptingRides ? "Accepting rides" : "Paused",
                                       isSelected: model.isAcceptingRides)
                                .overlay(alignment: .trailing) {
                                    if model.isUpdatingAccepting {
                                        ProgressView().tint(.white).padding(.trailing, 14)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(model.profile == nil || model.isUpdatingAccepting)

                        Button {
                            addingTimeOff = true
                        } label: {
                            FilterPill(systemImage: "calendar.badge.minus", title: "Time off", fillsWidth: false)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: Self.timeOffSourceID, in: scheduleTransition)
                    }

                    if !model.isAcceptingRides {
                        PausedBanner()
                    }

                    SectionTitle(title: "Weekly hours", subtitle: "\(model.weeklyTotal) · \(model.timeZoneCity) time")
                    GlowCard { weekList }

                    SectionTitle(title: "Time off", subtitle: "Riders can't book you during these")
                    GlowCard { timeOffList }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
            .background {
                ZStack(alignment: .top) {
                    Theme.background
                    RacingStripes(count: 4, lineWidth: 14, spacing: 36, startX: -0.15, length: 0.4)
                }
                .ignoresSafeArea()
            }
            .overlay(alignment: .bottomTrailing) {
                ChatButton(unreadCount: model.unreadMessages) { showChat = true }
                    .padding(Theme.horizontalPadding)
            }
            .refreshable { await model.load() }
            .task { await model.load() }
            .animation(.snappy, value: model.days)
            .animation(.snappy, value: model.timeOff)
            .animation(.snappy, value: model.isAcceptingRides)
            .sheet(item: $editingDay) { day in
                DayEditorView(day: day, timeZoneCity: model.timeZoneCity) { edited, extraDays in
                    try await model.save(edited, alsoApplyTo: extraDays)
                }
                .navigationTransition(.zoom(sourceID: day.key, in: scheduleTransition))
            }
            .sheet(isPresented: $addingTimeOff) {
                TimeOffEditorView { start, end, reason in
                    try await model.addTimeOff(startsAt: start, endsAt: end, reason: reason)
                }
                .navigationTransition(.zoom(sourceID: Self.timeOffSourceID, in: scheduleTransition))
            }
            .confirmationDialog("Pause new ride requests?", isPresented: $confirmPause, titleVisibility: .visible) {
                Button("Pause requests", role: .destructive) {
                    Task { await model.setAcceptingRides(false) }
                }
            } message: {
                Text("Your cars disappear from search until you turn this back on. Rides you already have aren't affected.")
            }
            .confirmationDialog("Remove this time off?", isPresented: Binding(
                get: { deletingTimeOff != nil },
                set: { if !$0 { deletingTimeOff = nil } }
            ), titleVisibility: .visible, presenting: deletingTimeOff) { item in
                Button("Remove", role: .destructive) {
                    Task { await model.deleteTimeOff(item) }
                }
            } message: { _ in
                Text("Riders will be able to book you during this time again.")
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showChat, onDismiss: { Task { await model.load() } }) {
                InboxView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var weekList: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load your schedule", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded:
            LazyVStack(spacing: 6) {
                ForEach(model.days) { day in
                    Button {
                        editingDay = day
                    } label: {
                        DayRow(day: day)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: day.key, in: scheduleTransition)
                }
            }
        }
    }

    @ViewBuilder
    private var timeOffList: some View {
        if model.timeOff.isEmpty {
            HStack(spacing: 14) {
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("No time off planned")
                        .font(.headline)
                    Text("Going on holiday or the car's in for service? Block it out so nobody books you.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.vertical, 6)
        } else {
            LazyVStack(spacing: 6) {
                ForEach(model.timeOff) { item in
                    TimeOffRow(item: item, timeZoneId: model.timeZoneId) {
                        deletingTimeOff = item
                    }
                }
            }
        }
    }
}

/// One weekday, styled like the car rows: a round badge, the day, its hours and an arrow.
private struct DayRow: View {
    let day: ScheduleModel.Day

    var body: some View {
        HStack(spacing: 14) {
            Text(day.short)
                .font(.caption.weight(.heavy))
                .foregroundStyle(day.windows.isEmpty ? Theme.textSecondary : .white)
                .frame(width: 56, height: 56)
                .background(day.windows.isEmpty ? Color.white.opacity(0.08) : Theme.brandRed, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(day.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(day.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if !day.windows.isEmpty {
                Text(ScheduleModel.hours(day.totalMinutes))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Image(systemName: "arrow.right")
                .font(.title3)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// One block of time off, with a remove button.
private struct TimeOffRow: View {
    let item: TimeOff
    let timeZoneId: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.minus")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(rangeText)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(item.reason?.isEmpty == false ? item.reason! : "Time off")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accentRed)
                    .frame(width: 40, height: 40)
            }
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel("Remove time off")
        }
        .padding(.vertical, 6)
    }

    /// "Sat 1 Nov – Mon 3 Nov", or "Sat 1 Nov, 10:00–14:00" for part of a day. Shown in the driver's time zone.
    private var rangeText: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneId) ?? .current
        var day = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated)
        var time = Date.FormatStyle.dateTime.hour().minute()
        day.timeZone = calendar.timeZone
        time.timeZone = calendar.timeZone

        let startsAtMidnight = calendar.startOfDay(for: item.startsAt) == item.startsAt
        let endsAtMidnight = calendar.startOfDay(for: item.endsAt) == item.endsAt
        if startsAtMidnight && endsAtMidnight {
            // Whole days: the end is midnight after the last day off.
            let lastDay = calendar.date(byAdding: .day, value: -1, to: item.endsAt) ?? item.endsAt
            return calendar.isDate(item.startsAt, inSameDayAs: lastDay)
                ? item.startsAt.formatted(day)
                : "\(item.startsAt.formatted(day)) – \(lastDay.formatted(day))"
        }
        if calendar.isDate(item.startsAt, inSameDayAs: item.endsAt) {
            return "\(item.startsAt.formatted(day)), \(item.startsAt.formatted(time))–\(item.endsAt.formatted(time))"
        }
        return "\(item.startsAt.formatted(day)) \(item.startsAt.formatted(time)) – \(item.endsAt.formatted(day)) \(item.endsAt.formatted(time))"
    }
}

private struct PausedBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "pause.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("New requests are paused")
                    .font(.headline)
                Text("Your cars are hidden from JoyRiders. Tap “Paused” to start taking rides again.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Color.orange.opacity(0.35), lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

#Preview {
    ScheduleView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
