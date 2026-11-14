import SwiftUI

/// Everything about one booking from the driver's side: who the rider is, when and where,
/// the money, and the next step (confirm, start, complete, rate).
/// Opens from a request card or an upcoming ride with a zoom transition.
struct DriverRideDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model: DriverRideModel
    @State private var showChat = false
    @State private var showDecline = false
    @State private var showCancel = false
    @State private var confirmComplete = false
    /// Typed into the decline or cancel alert; the rider sees it.
    @State private var reason = ""
    @FocusState private var commentFocused: Bool

    init(ride: Ride) {
        _model = State(initialValue: DriverRideModel(ride: ride))
    }

    private var ride: Ride { model.ride }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RiderCard(ride: ride) { showChat = true }

                    DriverRideBanner(ride: ride, riderFirstName: model.riderFirstName,
                                     startAvailableAt: model.startAvailableAt)

                    BookingSection(t("ride.details")) {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledValue(label: t("booking.sent.car"), value: ride.car.name)
                            LabeledValue(label: t("ride.when"), value: whenText)
                            LabeledValue(label: t("ride.duration"), value: durationLabel(ride.durationMinutes))
                            meetingPoint
                            if let phone = ride.rider.phoneNumber {
                                HStack {
                                    LabeledValue(label: t("ride.phone_of", ["name": model.riderFirstName]), value: phone)
                                    Spacer()
                                    smallAction(t("ride.call"), systemImage: "phone.fill") {
                                        if let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") { openURL(url) }
                                    }
                                }
                            }
                            if let note = ride.riderNote, !note.isEmpty {
                                LabeledValue(label: t("ride.driver.note_of", ["name": model.riderFirstName]), value: "“\(note)”")
                            }
                        }
                    }

                    BookingSection(t("ride.payment")) {
                        HStack(alignment: .firstTextBaseline) {
                            LabeledValue(label: paymentText, value: ride.price.price(ride.currency))
                            Spacer()
                        }
                    }

                    if ride.canReview || model.reviewSent {
                        BookingSection(t("ride.driver.rate_rider", ["name": model.riderFirstName])) {
                            reviewForm
                        }
                    }

                    // Only shown here when there's no bottom bar to show it in.
                    if !hasBottomBar {
                        FormError(message: model.errorMessage)
                    }

                    if ride.status == .confirmed {
                        Button(role: .destructive) {
                            reason = ""
                            showCancel = true
                        } label: {
                            if model.busyAction == .cancel {
                                ProgressView().tint(.white)
                            } else {
                                Text(t("ride.cancel")).foregroundStyle(Theme.accentRed)
                            }
                        }
                        .buttonStyle(.secondary)
                        .disabled(model.busyAction != nil)
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if hasBottomBar {
                    bottomBar
                }
            }
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(ride.status == .requested ? t("ride.driver.title_request") : t("ride.driver.title")).displayTitle(18)
                }
                // The keyboard covers "Send review", so give it a way out.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(t("common.done")) { commentFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton { dismiss() }
                }
            }
            .refreshable { await model.refresh() }
            .animation(.snappy, value: ride)
            .animation(.snappy, value: model.reviewSent)
            .animation(.snappy, value: model.errorMessage)
        }
        .task { await model.refresh() }
        .alert(t("requests.decline_title"), isPresented: $showDecline) {
            TextField(t("ride.driver.reason"), text: $reason)
            Button(t("requests.decline_ride"), role: .destructive) {
                Task { await model.decline(reason: reason) }
            }
            Button(t("ride.driver.keep_request"), role: .cancel) {}
        } message: {
            Text(t("ride.driver.decline_message", ["name": model.riderFirstName]))
        }
        .alert(t("ride.cancel_confirm_title"), isPresented: $showCancel) {
            TextField(t("ride.driver.reason"), text: $reason)
            Button(t("ride.cancel"), role: .destructive) {
                Task { await model.cancel(reason: reason) }
            }
            Button(t("ride.keep"), role: .cancel) {}
        } message: {
            Text(t("ride.driver.cancel_message", ["name": model.riderFirstName]))
        }
        .confirmationDialog(t("ride.driver.finish_title"), isPresented: $confirmComplete, titleVisibility: .visible) {
            Button(t("ride.driver.complete")) {
                Task { await model.complete() }
            }
        } message: {
            Text(t("ride.driver.finish_message", ["name": model.riderFirstName]))
        }
        .sheet(isPresented: $showChat) {
            ConversationSheet(otherUser: ChatParticipant(
                id: ride.rider.id, displayName: ride.rider.displayName,
                avatarUrl: ride.rider.avatarUrl, isDriver: false))
        }
    }

    // MARK: Bottom bar

    private var hasBottomBar: Bool {
        [.requested, .confirmed, .inProgress].contains(ride.status)
    }

    private var bottomBar: some View {
        // Ticks so "Start ride" turns on by itself 30 minutes before the start.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 10) {
                FormError(message: model.errorMessage)
                switch ride.status {
                case .requested:
                    HStack(spacing: 12) {
                        Button(t("requests.decline")) {
                            reason = ""
                            showDecline = true
                        }
                        .buttonStyle(.secondary)
                        Button(t("requests.confirm")) { Task { await model.confirm() } }
                            .buttonStyle(.primary(isLoading: model.busyAction == .confirm))
                    }
                    if let respondBy = ride.respondBy {
                        // A date with style: .relative counts down by itself.
                        Text("\(Image(systemName: "hourglass")) \(t("requests.respond_within")) \(respondBy, style: .relative)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.accentRed)
                    }
                case .confirmed:
                    let canStart = model.canStart(at: context.date)
                    Button(t("ride.driver.start")) { Task { await model.start() } }
                        .buttonStyle(.primary(isLoading: model.busyAction == .start))
                        .disabled(!canStart)
                        .opacity(canStart ? 1 : 0.5)
                    Text(canStart
                         ? t("ride.driver.start_hint", ["name": model.riderFirstName])
                         : context.date >= ride.endsAt
                         ? t("ride.driver.start_too_late", ["name": model.riderFirstName])
                         : t("ride.driver.start_from", ["time": model.startAvailableAt.localized(startFormat)]))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                default:
                    Button(t("ride.driver.complete")) { confirmComplete = true }
                        .buttonStyle(.primary(isLoading: model.busyAction == .complete))
                    Text(t("ride.driver.ends_at", ["time": ride.endsAt.localized(date: .omitted, time: .shortened)]))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .disabled(model.busyAction != nil)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    /// "09:30" today, "Sat 09:30" on another day.
    private var startFormat: Date.FormatStyle {
        Calendar.current.isDateInToday(model.startAvailableAt)
            ? .dateTime.hour().minute()
            : .dateTime.weekday(.abbreviated).hour().minute()
    }

    // MARK: Pieces

    @ViewBuilder
    private var meetingPoint: some View {
        let point = ride.meetingPoint
        let address = point.address.flatMap { $0.isEmpty ? nil : $0 }
        HStack {
            LabeledValue(label: t("ride.meeting_point"), value: address.map { "\(point.type.title): \($0)" } ?? meetingFallback)
            Spacer()
            if let latitude = point.latitude, let longitude = point.longitude {
                smallAction(t("ride.maps"), systemImage: "map.fill") {
                    if let url = URL(string: "https://maps.apple.com/?daddr=\(latitude),\(longitude)") { openURL(url) }
                }
            }
        }
    }

    /// When there's no address, explain why.
    private var meetingFallback: String {
        let title = ride.meetingPoint.type.title
        switch ride.meetingPoint.type {
        case .riderComesToDriver where ride.status == .requested || ride.status == .awaitingPayment:
            return t("ride.driver.address_after_confirm", ["title": title])
        case .agreedLocation:
            return t("ride.driver.meeting_undecided", ["title": title])
        default:
            return title
        }
    }

    @ViewBuilder
    private var reviewForm: some View {
        if model.reviewSent {
            Label(t("reviews.sent"), systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.available)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                StarRatingPicker(rating: $model.rating)
                TextField("", text: $model.comment,
                          prompt: Text(t("reviews.prompt_rider", ["name": model.riderFirstName])).foregroundStyle(Theme.textSecondary),
                          axis: .vertical)
                    .lineLimit(2...4)
                    .focused($commentFocused)
                    // Return sends the review (a vertical TextField would otherwise add a new line).
                    .submitLabel(.send)
                    .onSubmit { Task { await model.submitReview() } }
                Button(t("reviews.send")) { Task { await model.submitReview() } }
                    .buttonStyle(.primary(isLoading: model.isSubmittingReview))
                    .disabled(model.rating == 0 || model.isSubmittingReview)
                    .opacity(model.rating == 0 ? 0.5 : 1)
            }
        }
    }

    private func smallAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(ChipStyle(isSelected: false))
    }

    // MARK: Text

    private var whenText: String {
        "\(ride.startsAt.localized(.dateTime.weekday(.wide).day().month(.wide))), \(ride.startsAt.localized(date: .omitted, time: .shortened))–\(ride.endsAt.localized(date: .omitted, time: .shortened))"
    }

    private var paymentText: String {
        let rider = model.riderFirstName
        guard let payment = ride.payment else { return t("ride.price") }
        switch payment.status {
        case .pending: return t("ride.driver.payment_status.pending", ["name": rider])
        case .authorized: return t("ride.driver.payment_status.authorized", ["name": rider])
        case .captured: return t("ride.payment_status.captured")
        case .voided: return t("ride.driver.payment_status.voided", ["name": rider])
        case .refunded: return t("ride.driver.payment_status.refunded", ["name": rider])
        case .partiallyRefunded: return t("ride.payment_status.partially_refunded", ["amount": payment.refundedAmount.price(payment.currency)])
        case .failed: return t("ride.payment_status.failed")
        }
    }
}

/// The rider at the top of the sheet: photo, name, rating and a chat button.
private struct RiderCard: View {
    let ride: Ride
    let onMessage: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(path: ride.rider.avatarUrl, placeholder: "person.fill")
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(ride.rider.displayName)
                    .font(.headline)
                Text(ride.rider.ratingText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            CircleIconButton(systemImage: "bubble.left", size: 40,
                             accessibilityLabel: t("chat.message_name", ["name": ride.rider.displayName]), action: onMessage)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

}

extension RideParticipant {
    /// "★ 4.8 · 12 reviews", or "New rider" before the first review.
    var ratingText: String {
        guard ratingCount > 0 else { return t("reviews.new_rider") }
        let rating = ratingAverage.formatted(.number.locale(Localizer.shared.locale).precision(.fractionLength(1)).locale(Localizer.shared.locale))
        return "★ \(rating) · \(t("reviews.count", count: ratingCount))"
    }
}

/// What's going on with the ride and what the driver should do next.
private struct DriverRideBanner: View {
    let ride: Ride
    let riderFirstName: String
    let startAvailableAt: Date

    var body: some View {
        StatusBanner(icon: ride.status.icon, color: ride.status.color, title: title, message: message)
    }

    /// "today", "tomorrow" or the weekday ("Saturday").
    private var dayText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(ride.startsAt) { return t("common.today") }
        if calendar.isDateInTomorrow(ride.startsAt) { return t("common.tomorrow") }
        return ride.startsAt.localized(.dateTime.weekday(.wide))
    }

    private var title: String {
        switch ride.status {
        case .awaitingPayment: t("ride.driver.banner.awaiting_payment")
        case .requested: t("ride.driver.banner.requested")
        case .confirmed: t("ride.status.confirmed")
        case .inProgress: t("ride.banner.in_progress")
        case .completed: t("ride.banner.completed")
        case .declined: t("ride.driver.banner.declined")
        case .cancelled where ride.isTimedOut: t("ride.driver.banner.timed_out")
        case .cancelled: ride.cancelledByMe == true ? t("ride.banner.you_cancelled") : t("ride.banner.other_cancelled", ["name": riderFirstName])
        case .expired: t("ride.banner.expired")
        }
    }

    private var message: String {
        switch ride.status {
        case .awaitingPayment:
            return t("ride.driver.message.awaiting_payment", ["name": riderFirstName])
        case .requested:
            if let respondBy = ride.respondBy {
                return t("ride.driver.message.requested_until", ["time": respondBy.localized(.dateTime.weekday(.abbreviated).hour().minute()), "name": riderFirstName])
            }
            return t("ride.driver.message.requested", ["name": riderFirstName])
        case .confirmed:
            return t("ride.driver.message.confirmed", ["name": riderFirstName, "day": dayText, "time": ride.startsAt.localized(date: .omitted, time: .shortened), "start": startAvailableAt.localized(date: .omitted, time: .shortened)])
        case .inProgress:
            return t("ride.driver.message.in_progress", ["time": ride.endsAt.localized(date: .omitted, time: .shortened)])
        case .completed:
            return ride.canReview ? t("ride.driver.message.completed_review", ["name": riderFirstName]) : t("ride.driver.message.completed")
        case .declined:
            let reason = ride.declineReason.flatMap { $0.isEmpty ? nil : "“\($0)” " } ?? ""
            return reason + t("ride.driver.message.not_charged", ["name": riderFirstName])
        case .cancelled where ride.isTimedOut:
            return t("ride.driver.message.timed_out", ["name": riderFirstName])
        case .cancelled:
            let money: String = switch ride.payment?.status {
            case .refunded: t("ride.driver.message.refunded", ["name": riderFirstName])
            case .voided: t("ride.driver.message.not_charged", ["name": riderFirstName])
            case .captured: t("ride.driver.message.late_cancel")
            default: ""
            }
            let reason = ride.cancellationReason.flatMap { $0.isEmpty ? nil : "“\($0)” " } ?? ""
            return "\(reason)\(money)"
        case .expired:
            return t("ride.driver.message.expired", ["name": riderFirstName])
        }
    }
}
