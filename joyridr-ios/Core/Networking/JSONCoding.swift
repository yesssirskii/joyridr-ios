import Foundation

extension JSONDecoder {
    /// Decodes the backend's ISO 8601 dates, with or without fractional seconds
    /// (.NET sends up to 7 decimals, which the built-in `.iso8601` strategy can't read).
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        let format = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = try? format.parse(string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognised date: \(string)")
        }
        return decoder
    }()
}

extension JSONEncoder {
    static let api: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
