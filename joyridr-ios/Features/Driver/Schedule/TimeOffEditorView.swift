import SwiftUI

/// "TIME OFF": block out whole days or part of a day.
struct TimeOffEditorView: View {
    let onSave: (Date, Date, String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var allDay = true
    @State private var start = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
    @State private var end = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
    @State private var reason = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var keyboardVisible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    BookingSection(t("ride.when")) {
                        VStack(spacing: 0) {
                            Toggle(t("schedule.preset.all_day"), isOn: $allDay)
                                .tint(Theme.accentRed)
                                .padding(.vertical, 8)
                            Divider().overlay(.white.opacity(0.1))
                            DatePicker(allDay ? t("schedule.first_day") : t("schedule.starts"), selection: $start, in: Date.now...,
                                       displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                                .padding(.vertical, 8)
                            Divider().overlay(.white.opacity(0.1))
                            DatePicker(allDay ? t("schedule.last_day") : t("schedule.ends"), selection: $end, in: start...,
                                       displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                                .padding(.vertical, 8)
                        }
                    }

                    BookingSection(t("schedule.reason")) {
                        TextField("", text: $reason, prompt: Text(t("schedule.reason_prompt")).foregroundStyle(Theme.textSecondary))
                            .submitLabel(.done)
                    }

                    Label(summary, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if !keyboardVisible { bottomBar }
            }
            .trackKeyboard($keyboardVisible)
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(t("schedule.time_off")).displayTitle(18)
                }
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton { dismiss() }
                }
            }
            .onChange(of: start) { _, newStart in
                if end < newStart { end = newStart }
            }
            .animation(.snappy, value: allDay)
            .animation(.snappy, value: errorMessage)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            FormError(message: errorMessage)
            Button(t("schedule.add_time_off")) { Task { await save() } }
                .buttonStyle(.primary(isLoading: isSaving))
                .disabled(isSaving)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    /// The exact period sent to the backend. All-day ends at midnight after the last day.
    private var period: (start: Date, end: Date) {
        let calendar = Calendar.current
        guard allDay else { return (start, end) }
        let first = calendar.startOfDay(for: start)
        let afterLast = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
        return (first, afterLast)
    }

    private var summary: String {
        let days = Calendar.current.dateComponents([.day], from: period.start, to: period.end).day ?? 0
        return allDay
            ? t("schedule.unavailable_days", count: days)
            : t("schedule.unavailable_period")
    }

    private func save() async {
        let (from, to) = period
        guard to > from else {
            errorMessage = t("schedule.error_time_off_order")
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await onSave(from, to, reason)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
