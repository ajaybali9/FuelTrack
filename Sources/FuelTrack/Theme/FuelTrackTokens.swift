import SwiftUI

enum FuelTrackTokens {
    static let accent = Color(red: 0.22, green: 0.56, blue: 0.67) // #388EAB
    static let accentWarm = Color(red: 0.92, green: 0.52, blue: 0.22) // #EB8538
    static let deep = Color(red: 0.05, green: 0.10, blue: 0.18)
    static let ink = Color(red: 0.08, green: 0.14, blue: 0.22)
    static let success = Color(red: 0.18, green: 0.48, blue: 0.29)
    static let warning = Color(red: 0.77, green: 0.48, blue: 0.10)
    static let error = Color(red: 0.72, green: 0.23, blue: 0.18)

    static let sectionSpacing: CGFloat = 12
    static let horizontalPadding: CGFloat = 16
    static let fieldMinHeight: CGFloat = 52
    static let cardRadius: CGFloat = 20
    static let chipRadius: CGFloat = 14
    static let plateRadius: CGFloat = 12

    static func labelFont() -> Font {
        .caption2.weight(.semibold)
    }

    static func valueFont() -> Font {
        .body.weight(.medium)
    }

    static func numericFont(size: Font.TextStyle = .title3) -> Font {
        .system(size, design: .monospaced).weight(.semibold)
    }

    static func plateFont() -> Font {
        .system(.title3, design: .monospaced).weight(.bold)
    }
}
