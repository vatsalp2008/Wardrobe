import SwiftUI

extension Color {
    /// Creates a Color from a hex string such as "#1A56A0", "1A56A0", or "#RGB".
    /// Falls back to `.gray` for unparseable input so the UI never crashes on bad data.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else {
            self = .gray
            return
        }

        let r, g, b, a: Double
        switch cleaned.count {
        case 3: // RGB (12-bit)
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
            a = 1
        case 6: // RRGGBB (24-bit)
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        case 8: // AARRGGBB (32-bit)
            a = Double((value >> 24) & 0xFF) / 255
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default:
            self = .gray
            return
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
