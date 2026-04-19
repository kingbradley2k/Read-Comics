import SwiftUI
import UIKit

enum ReaderSurfaceStyle {
    static func canvasColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(uiColor: .black)
        case .light:
            return Color(uiColor: .systemGroupedBackground)
        @unknown default:
            return Color(uiColor: .systemBackground)
        }
    }

    static func pageColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(uiColor: .secondarySystemBackground)
        case .light:
            return Color(red: 0.973, green: 0.962, blue: 0.925)
        @unknown default:
            return Color(uiColor: .secondarySystemBackground)
        }
    }

    static func pageUIColor(for colorScheme: ColorScheme) -> UIColor {
        switch colorScheme {
        case .dark:
            return .secondarySystemBackground
        case .light:
            return UIColor(red: 0.973, green: 0.962, blue: 0.925, alpha: 1)
        @unknown default:
            return .secondarySystemBackground
        }
    }

    static func chromePrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .primary
    }

    static func chromeSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : .secondary
    }

    static func dividerColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    static func pageStripBackdrop(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.62)
    }
}
