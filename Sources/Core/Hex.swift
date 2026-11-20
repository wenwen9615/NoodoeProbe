import Foundation

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    var asciiPreview: String {
        let bytes = map { ($0 >= 0x20 && $0 < 0x7F) ? $0 : UInt8(0x2E) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
