import UIKit

/// Turns a picked photo into a JPEG small enough to upload (phone photos are several MB).
enum JPEGImage {
    /// Shrinks so the longest side is at most `maxSide` pixels and converts to JPEG. Nil if the data isn't an image.
    static func prepare(_ data: Data, maxSide: CGFloat) -> (jpeg: Data, preview: UIImage)? {
        guard let image = UIImage(data: data) else { return nil }
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
