import SwiftUI
import UIKit

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case nightDark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return L10n.t("Auto", "跟随系统", "跟隨系統")
        case .light: return L10n.t("Day", "日间", "日間")
        case .nightDark: return L10n.t("Night Shift", "夜班护眼", "夜班護眼")
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .nightDark: return .dark
        }
    }
}

enum ShiftTheme {
    // Brand industrial palette
    static let midnightIndigo = Color(red: 19/255, green: 27/255, blue: 46/255)      // #131B2E
    static let midnightElevated = Color(red: 28/255, green: 39/255, blue: 64/255)    // #1C2740
    static let cobalt = Color(red: 37/255, green: 99/255, blue: 235/255)             // #2563EB
    static let cobaltSoft = Color(red: 37/255, green: 99/255, blue: 235/255).opacity(0.14)
    static let shiftMint = Color(red: 16/255, green: 185/255, blue: 129/255)         // #10B981
    static let overtimeAmber = Color(red: 245/255, green: 158/255, blue: 11/255)     // #F59E0B
    static let nightViolet = Color(red: 124/255, green: 58/255, blue: 237/255)       // #7C3AED
    static let swingTeal = Color(red: 13/255, green: 148/255, blue: 136/255)         // #0D9488
    static let ptoRose = Color(red: 225/255, green: 29/255, blue: 72/255)            // #E11D48
    static let offSlate = Color(red: 100/255, green: 116/255, blue: 139/255)         // #64748B

    // Adaptive Day / Night-Shift Surfaces
    static let canvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 11/255, green: 16/255, blue: 27/255, alpha: 1)    // #0B101B
            : UIColor(red: 244/255, green: 246/255, blue: 250/255, alpha: 1) // #F4F6FA
    })

    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 19/255, green: 27/255, blue: 46/255, alpha: 1)    // #131B2E
            : UIColor.white
    })

    static let cardElevated = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 28/255, green: 39/255, blue: 64/255, alpha: 1)    // #1C2740
            : UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1) // #F8FAFC
    })

    static let ink = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1) // #F8FAFC
            : UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1)    // #0F172A
    })

    static let muted = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1) // #94A3B8
            : UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1) // #64748B
    })

    static let border = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 39/255, green: 52/255, blue: 78/255, alpha: 1)    // #27344E
            : UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1) // #E2E8F0
    })
}

struct ShiftCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ShiftTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ShiftTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func shiftCard(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        modifier(ShiftCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        if cleaned.count == 6 {
            (r, g, b) = (int >> 16, (int >> 8) & 0xFF, int & 0xFF)
        } else {
            (r, g, b) = (37, 99, 235)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
