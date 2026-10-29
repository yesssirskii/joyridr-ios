import SwiftUI

/// "MONDAY": the hours you're available on one weekday, optionally copied to other days.
struct DayEditorView: View {
    let timeZoneCity: String
    let onSave: (ScheduleModel.Day, Set<String>) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var day: ScheduleModel.Day
    @State private var alsoApplyTo: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(day: ScheduleModel.Day, timeZoneCity: String, onSave: @escaping (ScheduleModel.Day, Set<String>) async throws -> Void) {
        _day = State(initialValue: day)
        self.timeZoneCity = timeZoneCity
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    BookingSection("Hours") {
                        VStack(alignment: .leading, spacing: 14) {
                            if day.windows.isEmpty {
                                Label("Day off: riders can't book you on \(day.title)s.", systemImage: "moon.zzz.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            ForEach($day.windows) { $window in
                                WindowRow(window: $window) {
                                    day.windows.removeAll { $0.id == window.id }
                                }
                            }
                            Button {
                                addWindow()
                            } label: {
                                Label(day.windows.isEmpty ? "Add hours" : "Add another block", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(ChipStyle(isSelected: false))
                            .disabled(!canAddWindow)

                            Text("Times are in \(timeZoneCity) time, in 30-minute steps. Split your day into blocks for breaks.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    BookingSection("Quick presets") {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                preset("All day", [(8 * 60, 22 * 60)])
                                preset("9 to 5", [(9 * 60, 17 * 60)])
                                preset("Afternoon", [(13 * 60, 20 * 60)])
                                preset("Evening", [(17 * 60, 22 * 60)])
                                preset("Day off", [])
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    BookingSection("Also apply to") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                ForEach(ScheduleModel.dayKeys, id: \.self) { key in
                                    let isThisDay = key == day.key
                                    Button(String(key.prefix(2)).capitalized) {
                                        if alsoApplyTo.contains(key) { alsoApplyTo.remove(key) } else { alsoApplyTo.insert(key) }
                                    }
                                    .buttonStyle(ChipStyle(isSelected: isThisDay || alsoApplyTo.contains(key), fillsWidth: true))
                                    .disabled(isThisDay)
                                    .accessibilityLabel(key.capitalized)
                                }
                            }
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    Button("Weekdays") { select(Array(ScheduleModel.dayKeys.prefix(5))) }
                                    Button("Weekend") { select(["saturday", "sunday"]) }
                                    Button("Every day") { select(ScheduleModel.dayKeys) }
                                    Button("Clear") { alsoApplyTo = [] }
                                }
                                .buttonStyle(ChipStyle(isSelected: false))
                            }
                            .scrollIndicators(.hidden)
                        }
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(day.title).displayTitle(18)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .animation(.snappy, value: day.windows)
            .animation(.snappy, value: errorMessage)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            FormError(message: errorMessage)
            Button(saveTitle) { Task { await save() } }
                .buttonStyle(.primary(isLoading: isSaving))
                .disabled(isSaving)
            Text("Rides you already have aren't affected.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var saveTitle: String {
        alsoApplyTo.isEmpty ? "Save \(day.title)" : "Save \(alsoApplyTo.count + 1) days"
    }

    /// There's room for another block if the day isn't full up to 23:30.
    private var canAddWindow: Bool {
        (day.windows.map(\.end).max() ?? 0) < 23 * 60
    }

    private func addWindow() {
        // Start where the last block ends (or 10:00), and run for 4 hours if there's room.
        let start = day.windows.map(\.end).max().map { min($0 + 60, 23 * 60) } ?? 10 * 60
        let end = min(start + 4 * 60, 23 * 60 + 30)
        day.windows.append(.init(start: start, end: end))
    }

    private func preset(_ title: String, _ blocks: [(Int, Int)]) -> some View {
        Button(title) {
            day.windows = blocks.map { .init(start: $0.0, end: $0.1) }
        }
        .buttonStyle(ChipStyle(isSelected: false))
    }

    private func select(_ keys: [String]) {
        alsoApplyTo = Set(keys).subtracting([day.key])
    }

    private func save() async {
        if let problem = ScheduleModel.validate(day.windows) {
            errorMessage = problem
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await onSave(day, alsoApplyTo)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// "From 10:00 to 14:00" with a remove button.
private struct WindowRow: View {
    @Binding var window: ScheduleModel.Window
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TimeMenu(label: "From", minutes: $window.start)
            Image(systemName: "arrow.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.textSecondary)
            TimeMenu(label: "To", minutes: $window.end)
            Spacer(minLength: 0)
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Theme.accentRed)
            }
            .accessibilityLabel("Remove \(window.label)")
        }
    }
}

/// A time on the 30-minute grid. Tapping it shows a small wheel that opens at the current time.
private struct TimeMenu: View {
    let label: String
    @Binding var minutes: Int
    @State private var isPicking = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(ScheduleModel.clock(minutes))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(isPicking ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(ScheduleModel.clock(minutes))")
        .popover(isPresented: $isPicking) {
            Picker(label, selection: $minutes) {
                ForEach(ScheduleModel.slots, id: \.self) { Text(ScheduleModel.clock($0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 180, height: 180)
            // Show as a small bubble next to the field, not a full sheet.
            .presentationCompactAdaptation(.popover)
        }
    }
}
