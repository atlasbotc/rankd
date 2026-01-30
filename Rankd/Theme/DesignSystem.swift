import SwiftUI

// MARK: - Color System
// Role-based colors. No raw hex values outside this file.

enum RankdColors {
    // Backgrounds (darkest → lightest surface)
    static let background = Color(red: 0.06, green: 0.06, blue: 0.07)       // #0F0F12 — true dark
    static let surfacePrimary = Color(red: 0.10, green: 0.10, blue: 0.12)    // #1A1A1E — cards, sheets
    static let surfaceSecondary = Color(red: 0.14, green: 0.14, blue: 0.16)  // #242428 — elevated
    static let surfaceTertiary = Color(red: 0.18, green: 0.18, blue: 0.20)   // #2E2E33 — hover/pressed
    
    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let textTertiary = Color.white.opacity(0.40)
    static let textQuaternary = Color.white.opacity(0.20)
    
    // Accent — used <5%, action-only
    static let accent = Color(red: 1.0, green: 0.58, blue: 0.0)             // #FF9500
    static let accentSubtle = Color(red: 1.0, green: 0.58, blue: 0.0).opacity(0.12)
    
    // Tiers — semantic, not decorative
    static let tierGood = Color(red: 0.30, green: 0.78, blue: 0.47)         // Muted green
    static let tierMedium = Color(red: 0.90, green: 0.78, blue: 0.30)       // Muted gold
    static let tierBad = Color(red: 0.90, green: 0.35, blue: 0.35)          // Muted red
    
    // Feedback
    static let success = Color(red: 0.30, green: 0.78, blue: 0.47)
    static let warning = Color(red: 0.90, green: 0.78, blue: 0.30)
    static let error = Color(red: 0.90, green: 0.35, blue: 0.35)
    
    // Utility
    static let divider = Color.white.opacity(0.08)
    static let shimmer = Color.white.opacity(0.06)
    
    static func tierColor(_ tier: Tier) -> Color {
        switch tier {
        case .good: return tierGood
        case .medium: return tierMedium
        case .bad: return tierBad
        }
    }
}

// MARK: - Typography Scale
// Strict scale. No in-between sizes.

enum RankdTypography {
    // Display — hero, feature headers
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .default)
    static let displayMedium = Font.system(size: 28, weight: .bold, design: .default)
    
    // Headings
    static let headingLarge = Font.system(size: 22, weight: .semibold, design: .default)
    static let headingMedium = Font.system(size: 18, weight: .semibold, design: .default)
    static let headingSmall = Font.system(size: 16, weight: .semibold, design: .default)
    
    // Body
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
    
    // Labels
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
    
    // Caption
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
}

// MARK: - Spacing Scale
// Fixed 4px base. Use only these values.

enum RankdSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Radius Scale

enum RankdRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let full: CGFloat = 999
}

// MARK: - Motion
// 100-300ms. Ease-out or ease-in-out. No bounce.

enum RankdMotion {
    static let fast = Animation.easeOut(duration: 0.15)
    static let normal = Animation.easeOut(duration: 0.25)
    static let slow = Animation.easeInOut(duration: 0.35)
    
    // For chart/data animations
    static let reveal = Animation.easeOut(duration: 0.5)
}

// MARK: - Poster Sizes

enum RankdPoster {
    // Standard horizontal scroll
    static let standardWidth: CGFloat = 140
    static let standardHeight: CGFloat = 210
    
    // Large / featured
    static let largeWidth: CGFloat = 180
    static let largeHeight: CGFloat = 270
    
    // Thumbnail (lists, search rows)
    static let thumbWidth: CGFloat = 56
    static let thumbHeight: CGFloat = 84
    
    // Mini (journal, compact rows)
    static let miniWidth: CGFloat = 44
    static let miniHeight: CGFloat = 66
    
    static let cornerRadius: CGFloat = RankdRadius.md
}

// MARK: - Shadows

enum RankdShadow {
    static let card = Color.black.opacity(0.3)
    static let cardRadius: CGFloat = 12
    static let cardY: CGFloat = 4
    
    static let elevated = Color.black.opacity(0.5)
    static let elevatedRadius: CGFloat = 20
    static let elevatedY: CGFloat = 8
}

// MARK: - View Modifiers

struct RankdCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: RankdRadius.lg)
                    .fill(RankdColors.surfacePrimary)
            )
    }
}

struct RankdSurfaceStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RankdColors.background)
            .foregroundStyle(RankdColors.textPrimary)
    }
}

extension View {
    func rankdCard() -> some View {
        modifier(RankdCardStyle())
    }
    
    func rankdSurface() -> some View {
        modifier(RankdSurfaceStyle())
    }
}
