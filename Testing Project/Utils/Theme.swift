import SwiftUI

struct WealthyRabbitTheme {
    // Color Palette - Premium Design System v2.0
    // Primary: #37517E (Deep Navy)
    static let primaryColor = Color(hex: "37517E")
    
    // Secondary: #8FB2D9 (Light Steel Blue)
    static let secondaryColor = Color(hex: "8FB2D9")
    
    // Success: #3CB371 (Mild Green)
    static let successColor = Color(hex: "3CB371")
    
    // Warning: #E56B6F (Soft Red)
    static let warningColor = Color(hex: "E56B6F")
    
    // Neutral Light: #F7F8F9
    static let neutralLight = Color(hex: "F7F8F9")
    
    // Neutral Mid: #D7DBDF
    static let neutralMid = Color(hex: "D7DBDF")
    
    // Neutral Dark: #2F2F2F
    static let neutralDark = Color(hex: "2F2F2F")
    
    // Legacy aliases for backward compatibility (mapped to new colors)
    static let mossGreen = primaryColor  // Primary navy
    static let mistBlue = secondaryColor  // Secondary light blue
    static let apricot = secondaryColor  // Secondary light blue (replacing orange)
    static let accentColor = secondaryColor  // Secondary light blue (replacing orange)
    static let terracotta = warningColor  // Warning red
    static let slate = neutralDark  // Dark gray
    static let taupe = neutralMid  // Mid gray
    static let cream = neutralLight  // Off-white
    static let linen = neutralLight  // Off-white
    static let notificationGreen = successColor  // Success green
    static let notificationRed = warningColor  // Warning red

    // Background Gradients
    static let burrowGradient = LinearGradient(
        colors: [neutralLight, neutralLight.opacity(0.95), neutralLight.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let chatBackground = neutralLight

    // Typography
    static let titleFont = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let headingFont = Font.system(size: 20, weight: .semibold, design: .rounded)  // Updated to semibold (600)
    static let bodyFont = Font.system(size: 15, weight: .regular, design: .rounded)
    static let captionFont = Font.system(size: 13, weight: .regular, design: .rounded)
    static let mediumFont = Font.system(size: 15, weight: .medium, design: .rounded)  // For Knowledge Check

    // Spacing
    static let tightSpacing: CGFloat = 8
    static let normalSpacing: CGFloat = 16
    static let relaxedSpacing: CGFloat = 24
    static let airySpacing: CGFloat = 32
}

// Custom View Modifiers
struct CalmCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)  // Increased padding (16-18px)
            .background(WealthyRabbitTheme.neutralLight)
            .cornerRadius(16)  // 14-16px rounded corners
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 2)  // Soft shadow
    }
}

extension View {
    func calmCardStyle() -> some View {
        modifier(CalmCardStyle())
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
