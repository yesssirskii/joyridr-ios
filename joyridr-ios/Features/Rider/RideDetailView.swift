import SwiftUI

/// Everything about one booking: status, when and where, payment, and what the rider can do next.
/// Opens from the ride's row in My rides with a zoom transition.
struct RideDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model: RideDetailModel
    @State private var showCarInfo = false
    @State private var confirmCancel = false
    @State private var showChat = false
    @FocusState private var commentFocused: Bool

    init(ride: Ride) {
        _model = State(initialValue: RideDetailModel(ride: ride))
    }

    private var ride: Ride { model.ride }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CarSummaryCard(
                        photoPath: ride.car.photoUrl ?? ride.driver.avatarUrl,
                        title: ride.car.name,
                        subtitle: "\(ride.driver.displayName) · \(driverRatingText)",
                        onInfo: { showCarInfo = true })

                    RideStatusBanner(ride: ride, driverFirstName: model.driverFirstName)

                    BookingSection(t("ride.details")) {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledValue(label: t("ride.when"), value: whenText)
                            LabeledValue(label: t("ride.duration"), value: durationLabel(ride.durationMinutes))
                            meetingPoint
                            if let phone = ride.driver.phoneNumber {
                                HStack {
                                    LabeledValue(label: t("ride.phone_of", ["name": model.driverFirstName]), value: phone)
                                    Spacer()
                                    smallAction(t("ride.call"), systemImage: "phone.fill") {
                                        if let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") { openURL(url) }
                                    }
                                }
                            }
                            if let note = ride.riderNote, !note.isEmpty {
                                LabeledValue(label: t("ride.rider.your_note"), value: note)
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
                        BookingSection(t("ride.rate")) {
                            reviewForm
                        }
                    }

                    FormError(message: model.errorMessage)

                    actions
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(t("ride.rider.title")).displayTitle(18)
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
        }
        .task { await model.refresh() }
        .sheet(isPresented: $showCarInfo) {
            CarInfoSheet(carID: ride.car.id, driverID: ride.driver.id)
        }
        .confirmationDialog(t("ride.cancel_confirm_title"), isPresented: $confirmCancel, titleVisibility: .visible) {
            Button(t("ride.cancel"), role: .destructive) {
                Task { await model.cancel() }
            }
            Button(t("ride.keep"), role: .cancel) {}
        } message: {
            Text(model.cancelConsequence)
        }
        .sheet(isPresented: $showChat) {
            ConversationSheet(otherUser: ChatParticipant(
                id: ride.driver.id, displayName: ride.driver.displayName,
                avatarUrl: ride.driver.avatarUrl, isDriver: true))
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var meetingPoint: some View {
        let point = ride.meetingPoint
        let title = point.type.riderTitle(driver: model.driverFirstName)
        let address = point.address.flatMap { $0.isEmpty ? nil : $0 }
        HStack {
            LabeledValue(label: t("ride.meeting_point"), value: address.map { "\(title): \($0)" } ?? meetingFallback(title))
            Spacer()
            if let latitude = point.latitude, let longitude = point.longitude {
                smallAction(t("ride.maps"), systemImage: "map.fill") {
                    if let url = URL(string: "https://maps.apple.com/?daddr=\(latitude),\(longitude)") { openURL(url) }
                }
            }
        }
    }

    /// When there's no address yet, explain why.
    private func meetingFallback(_ title: String) -> String {
        switch ride.meetingPoint.type {
        case .riderComesToDriver where ride.status == .requested || ride.status == .awaitingPayment:
            t("ride.rider.address_after_confirm", ["title": title, "driver": model.driverFirstName])
        case .agreedLocation:
            t("ride.meeting_undecided", ["title": title])
        default:
            title
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
                          prompt: Text(t("reviews.prompt", ["name": model.driverFirstName])).foregroundStyle(Theme.textSecondary),
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

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                showChat = true
            } label: {
                Label(t("chat.message_name", ["name": model.driverFirstName]), systemImage: "bubble.left.fill")
            }
            .buttonStyle(.secondary)

            if model.canCancel {
                Button(role: .destructive) {
                    confirmCancel = true
                } label: {
                    if model.isCancelling {
                        ProgressView().tint(.white)
                    } else {
                        Text(t("ride.cancel")).foregroundStyle(Theme.accentRed)
                    }
                }
                .buttonStyle(.secondary)
                .disabled(model.isCancelling)
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

    private var driverRatingText: String {
        ride.driver.ratingCount == 0
            ? t("reviews.new")
            : "★ \(ride.driver.ratingAverage.formatted(.number.locale(Localizer.shared.locale).precision(.fractionLength(1)))) (\(ride.driver.ratingCount))"
    }

    private var whenText: String {
        "\(ride.startsAt.localized(.dateTime.weekday(.wide).day().month(.wide))), \(ride.startsAt.localized(date: .omitted, time: .shortened))–\(ride.endsAt.localized(date: .omitted, time: .shortened))"
    }

    private var paymentText: String {
        guard let payment = ride.payment else { return t("ride.price") }
        switch payment.status {
        case .pending: return t("ride.payment_status.pending")
        case .authorized: return t("ride.payment_status.authorized")
        case .captured: return t("ride.payment_status.captured")
        case .voided: return t("ride.payment_status.voided")
        case .refunded: return t("ride.payment_status.refunded")
        case .partiallyRefunded: return t("ride.payment_status.partially_refunded", ["amount": payment.refundedAmount.price(payment.currency)])
        case .failed: return t("ride.payment_status.failed")
        }
    }
}

/// Coloured banner at the top of the ride: what's going on and what happens next.
private struct RideStatusBanner: View {
    let ride: Ride
    let driverFirstName: String

    var body: some View {
        StatusBanner(icon: ride.status.icon, color: ride.status.color, title: title, message: message)
    }

    private var title: String {
        switch ride.status {
        case .awaitingPayment: t("ride.rider.banner.awaiting_payment")
        case .requested: t("ride.rider.banner.requested", ["driver": driverFirstName])
        case .confirmed: t("ride.rider.banner.confirmed")
        case .inProgress: t("ride.banner.in_progress")
        case .completed: t("ride.banner.completed")
        case .declined: t("ride.rider.banner.declined")
        case .cancelled where ride.isTimedOut: t("ride.rider.banner.timed_out")
        case .cancelled: ride.cancelledByMe == true ? t("ride.banner.you_cancelled") : t("ride.banner.other_cancelled", ["name": driverFirstName])
        case .expired: t("ride.banner.expired")
        }
    }

    private var message: String {
        switch ride.status {
        case .awaitingPayment:
            return t("ride.rider.message.awaiting_payment")
        case .requested:
            if let respondBy = ride.respondBy {
                return t("ride.rider.waiting_until", ["driver": driverFirstName, "time": respondBy.localized(.dateTime.weekday(.abbreviated).hour().minute())])
            }
            return t("ride.rider.message.requested", ["driver": driverFirstName])
        case .confirmed:
            return t("ride.rider.message.confirmed", ["day": ride.startsAt.localized(.dateTime.weekday(.wide)), "time": ride.startsAt.localized(date: .omitted, time: .shortened)])
        case .inProgress:
            return t("ride.rider.message.in_progress", ["car": ride.car.name, "time": ride.endsAt.localized(date: .omitted, time: .shortened)])
        case .completed:
            return ride.canReview ? t("ride.rider.message.completed_review", ["driver": driverFirstName]) : t("ride.rider.message.completed")
        case .declined:
            let reason = ride.declineReason.flatMap { $0.isEmpty ? nil : "“\($0)” " } ?? ""
            return reason + t("ride.rider.message.declined", ["driver": driverFirstName])
        case .cancelled where ride.isTimedOut:
            return t("ride.rider.message.timed_out", ["driver": driverFirstName])
        case .cancelled:
            let refund: String = switch ride.payment?.status {
            case .refunded: t("ride.rider.message.refunded")
            case .voided: t("ride.rider.message.not_charged")
            case .captured: t("ride.rider.message.late_cancel")
            default: ""
            }
            let reason = ride.cancellationReason.flatMap { $0.isEmpty ? nil : "“\($0)” " } ?? ""
            return "\(reason)\(refund)"
        case .expired:
            return t("ride.rider.message.expired", ["driver": driverFirstName])
        }
    }
}
