import SwiftUI

struct WealthyRabbitTheme {
    // Color Palette - Muted Pastels
    static let mistBlue = Color(red: 0.7, green: 0.8, blue: 0.85)
    static let apricot = Color(red: 0.95, green: 0.85, blue: 0.75)
    static let terracotta = Color(red: 0.85, green: 0.65, blue: 0.55)
    static let mossGreen = Color(red: 0.75, green: 0.82, blue: 0.70)
    static let slate = Color(red: 0.65, green: 0.7, blue: 0.75)
    static let taupe = Color(red: 0.85, green: 0.8, blue: 0.75)
    static let cream = Color(red: 0.98, green: 0.96, blue: 0.93)
    static let linen = Color(red: 0.96, green: 0.94, blue: 0.90)

    // Background Gradients
    static let burrowGradient = LinearGradient(
        colors: [cream, linen, Color(red: 0.93, green: 0.90, blue: 0.88)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let chatBackground = linen

    // Typography
    static let titleFont = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let headingFont = Font.system(size: 20, weight: .medium, design: .rounded)
    static let bodyFont = Font.system(size: 15, weight: .regular, design: .rounded)
    static let captionFont = Font.system(size: 13, weight: .regular, design: .rounded)

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
            .padding(WealthyRabbitTheme.normalSpacing)
            .background(Color.white.opacity(0.6))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func calmCardStyle() -> some View {
        modifier(CalmCardStyle())
    }
}
