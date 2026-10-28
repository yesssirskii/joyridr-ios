import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// Add or edit one car. Number fields are kept as text while typing and checked on save.
@Observable
final class CarEditorModel {
    /// A photo picked for a car that doesn't exist yet; uploaded right after the car is created.
    struct PendingPhoto: Identifiable {
        let id = UUID()
        let jpeg: Data
        let preview: UIImage
    }

    static let maxPhotos = 12

    private(set) var car: CarDetail?

    var make = ""
    var model = ""
    var year = ""
    var color = ""
    var category: CarCategory = .sportsCar
    var transmission: Transmission = .automatic
    var horsepower = ""
    var zeroToHundred = ""
    var topSpeed = ""
    var seats = 1
    var pricePerHour = ""
    var description = ""
    var licensePlate = ""
    var isActive = true

    private(set) var photos: [CarPhoto] = []
    private(set) var pendingPhotos: [PendingPhoto] = []
    private(set) var uploadingCount = 0
    private(set) var isSaving = false
    private(set) var isDeleting = false
    var errorMessage: String?

    private let cars: CarsService

    init(car: CarDetail?, cars: CarsService = CarsService()) {
        self.cars = cars
        guard let car else { return }
        self.car = car
        make = car.make
        model = car.model
        year = String(car.year)
        color = car.color
        category = car.category
        transmission = car.transmission
        horsepower = String(car.horsepower)
        zeroToHundred = car.zeroToHundredSeconds.map { "\($0)" } ?? ""
        topSpeed = car.topSpeedKmh.map(String.init) ?? ""
        seats = car.passengerSeats
        pricePerHour = "\(car.pricePerHour)"
        description = car.description ?? ""
        licensePlate = car.licensePlate ?? ""
        isActive = car.isActive
        photos = car.photos.sorted { $0.sortOrder < $1.sortOrder }
    }

    var isNew: Bool { car == nil }
    var photoCount: Int { photos.count + pendingPhotos.count }
    var canAddPhotos: Bool { photoCount + uploadingCount < Self.maxPhotos }

    // MARK: Photos

    /// Existing cars upload straight away; new cars keep the photos until the car is saved.
    func addPhotos(_ items: [PhotosPickerItem]) async {
        for item in items.prefix(Self.maxPhotos - photoCount - uploadingCount) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let (jpeg, preview) = Self.prepare(data) else {
                errorMessage = "One of the photos couldn't be read."
                continue
            }
            if let car {
                uploadingCount += 1
                do {
                    photos.append(try await cars.uploadPhoto(car.id, jpeg: jpeg))
                } catch {
                    errorMessage = error.localizedDescription
                }
                uploadingCount -= 1
            } else {
                pendingPhotos.append(PendingPhoto(jpeg: jpeg, preview: preview))
            }
        }
    }

    func remove(_ photo: CarPhoto) async {
        guard let car else { return }
        do {
            try await cars.deletePhoto(car.id, photoID: photo.id)
            photos.removeAll { $0.id == photo.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ photo: PendingPhoto) {
        pendingPhotos.removeAll { $0.id == photo.id }
    }

    // MARK: Save / delete

    /// Returns true when the sheet can close.
    func save() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        guard let request = validatedRequest() else { return false }

        isSaving = true
        defer { isSaving = false }
        do {
            if let car {
                self.car = try await cars.update(car.id, request)
                return true
            }
            let created = try await cars.create(request)
            car = created
            var failed = 0
            for photo in pendingPhotos {
                do {
                    photos.append(try await cars.uploadPhoto(created.id, jpeg: photo.jpeg))
                } catch {
                    failed += 1
                }
            }
            pendingPhotos = []
            if failed > 0 {
                // The car exists now, so the sheet switches to editing it and the driver can retry.
                errorMessage = "Your car was added, but \(failed) photo\(failed == 1 ? "" : "s") couldn't be uploaded. Try adding \(failed == 1 ? "it" : "them") again."
                return false
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete() async -> Bool {
        guard let car, !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await cars.delete(car.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: Helpers

    /// Checks the fields with the same limits as the backend, so mistakes show up right away.
    private func validatedRequest() -> UpsertCarRequest? {
        let trimmedMake = make.trimmingCharacters(in: .whitespaces)
        let trimmedModel = model.trimmingCharacters(in: .whitespaces)
        let trimmedColor = color.trimmingCharacters(in: .whitespaces)
        let maxYear = Calendar.current.component(.year, from: .now) + 1

        guard !trimmedMake.isEmpty, !trimmedModel.isEmpty else { return fail("Enter the make and model, e.g. Porsche 911 GT3.") }
        guard let yearValue = Int(year), (1950...maxYear).contains(yearValue) else { return fail("Enter a year between 1950 and \(maxYear).") }
        guard !trimmedColor.isEmpty else { return fail("Enter the car's colour.") }
        guard let hp = Int(horsepower), (1...3000).contains(hp) else { return fail("Enter the horsepower (1–3000).") }

        let acceleration = Self.decimal(zeroToHundred)
        if !zeroToHundred.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let acceleration, acceleration >= 1, acceleration <= 30 else { return fail("0–100 km/h should be between 1 and 30 seconds.") }
        }
        let speed = Int(topSpeed)
        if !topSpeed.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let speed, (50...600).contains(speed) else { return fail("Top speed should be between 50 and 600 km/h.") }
        }
        guard let price = Self.decimal(pricePerHour), price >= 1, price <= 100_000 else { return fail("Enter a price per hour, e.g. 180.") }

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlate = licensePlate.trimmingCharacters(in: .whitespaces)
        return UpsertCarRequest(
            make: trimmedMake, model: trimmedModel, year: yearValue, color: trimmedColor,
            category: category, transmission: transmission, horsepower: hp,
            zeroToHundredSeconds: acceleration, topSpeedKmh: speed, passengerSeats: seats,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            licensePlate: trimmedPlate.isEmpty ? nil : trimmedPlate,
            pricePerHour: price, currency: car?.currency ?? "EUR", isActive: isActive)
    }

    private func fail(_ message: String) -> UpsertCarRequest? {
        errorMessage = message
        return nil
    }

    /// Accepts "3.4" and "3,4" (Croatian keyboards type a comma).
    private static func decimal(_ text: String) -> Decimal? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return cleaned.isEmpty ? nil : Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Shrinks to at most 2000 px and converts to JPEG (the backend allows 10 MB per photo).
    private static func prepare(_ data: Data) -> (Data, UIImage)? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 2000
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.82) else { return nil }
        return (jpeg, resized)
    }
}
