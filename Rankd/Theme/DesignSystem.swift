import SwiftUI

// MARK: - Color System
// Role-based colors. No raw hex values outside this file.
// Light-first design. Muted slate/steel blue brand color.

enum RankdColors {
    // Backgrounds — light-first, warm off-white (no pure white)
    static let background = Color(red: 0.96, green: 0.95, blue: 0.94)       // #F5F3F0 — warm off-white
    static let surfacePrimary = Color(red: 0.99, green: 0.98, blue: 0.97)    // #FDFAF8 — cards, sheets
    static let surfaceSecondary = Color(red: 0.93, green: 0.92, blue: 0.91)  // #EDEBE8 — elevated
    static let surfaceTertiary = Color(red: 0.89, green: 0.88, blue: 0.87)   // #E3E1DE — hover/pressed
    
    // Text — dark but not pure black
    static let textPrimary = Color(red: 0.13, green: 0.13, blue: 0.15)      // #212125
    static let textSecondary = Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.65)
    static let textTertiary = Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.40)
    static let textQuaternary = Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.20)
    
    // Brand — warm copper, cinematic and distinctive
    static let brand = Color(red: 0.77, green: 0.48, blue: 0.23)            // #C47B3B — warm copper
    static let brandSubtle = Color(red: 0.77, green: 0.48, blue: 0.23).opacity(0.12)
    static let brandSecondary = Color(red: 0.55, green: 0.38, blue: 0.31)   // #8C6150 — warm brown
    static let brandGlow = Color(red: 0.95, green: 0.75, blue: 0.45)        // warm gold glow
    
    // Warm gradient pair for hero sections / CTAs
    static let gradientStart = Color(red: 0.77, green: 0.48, blue: 0.23)    // copper
    static let gradientEnd = Color(red: 0.55, green: 0.38, blue: 0.31)      // warm brown
    
    // Surface warmth — slightly warmer card for featured content
    static let surfaceWarm = Color(red: 0.98, green: 0.95, blue: 0.90)
    
    // Accent — alias for brand (backward compatibility)
    static let accent = brand
    static let accentSubtle = brandSubtle
    
    // Tiers — semantic, not decorative (muted for light backgrounds)
    static let tierGood = Color(red: 0.30, green: 0.65, blue: 0.45)         // Muted green
    static let tierMedium = Color(red: 0.75, green: 0.65, blue: 0.30)       // Muted gold
    static let tierBad = Color(red: 0.75, green: 0.35, blue: 0.35)          // Muted red
    
    // Feedback — restrained, not attention-grabbing
    static let success = Color(red: 0.30, green: 0.65, blue: 0.45)
    static let warning = Color(red: 0.75, green: 0.65, blue: 0.30)
    static let error = Color(red: 0.75, green: 0.35, blue: 0.35)
    
    // Medals — podium positions
    static let medalGold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let medalSilver = Color(red: 0.75, green: 0.75, blue: 0.78)
    static let medalBronze = Color(red: 0.80, green: 0.50, blue: 0.20)
    
    // Utility
    static let divider = Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.08)
    static let shimmer = Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.04)
    
    static func tierColor(_ tier: Tier) -> Color {
        switch tier {
        case .good: return tierGood
        case .medium: return tierMedium
        case .bad: return tierBad
        }
    }
    
    static func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return medalGold
        case 2: return medalSilver
        case 3: return medalBronze
        default: return .clear
        }
    }
}

// MARK: - Typography Scale
// Strict scale. No in-between sizes.

enum RankdTypography {
    // Display — hero, feature headers (rounded for warmth + personality)
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
    
    // Headings
    static let headingLarge = Font.system(size: 22, weight: .semibold, design: .rounded)
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
    
    // Section label — tracked uppercase for section headers
    static let sectionLabel = Font.system(size: 11, weight: .bold, design: .default)
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

// MARK: - Shadows (light theme — subtle, not heavy)

enum RankdShadow {
    static let card = Color.black.opacity(0.08)
    static let cardRadius: CGFloat = 12
    static let cardY: CGFloat = 4
    
    static let elevated = Color.black.opacity(0.15)
    static let elevatedRadius: CGFloat = 20
    static let elevatedY: CGFloat = 8
}

// MARK: - View Modifiers

// MARK: - Press Effect Button Style

/// Subtle scale-down on press (0.97) with easeOut spring-back.
/// Use on tappable cards throughout the app.
/// Respects Reduce Motion — disables scale animation when enabled.
struct RankdPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.97 : 1.0))
            .animation(reduceMotion ? nil : RankdMotion.fast, value: configuration.isPressed)
    }
}

// MARK: - Accessibility Helpers

/// Limits Dynamic Type scaling so layouts don't break at very large sizes.
/// Apply to root containers (e.g., tab views, full-screen views).
struct RankdDynamicTypeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

extension View {
    /// Caps Dynamic Type to `.accessibility2` to prevent layout breakage.
    func rankdDynamicTypeLimit() -> some View {
        modifier(RankdDynamicTypeModifier())
    }
}

struct RankdCardStyle: ViewModifier {
    var elevated: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: RankdRadius.lg)
                    .fill(RankdColors.surfacePrimary)
                    .shadow(
                        color: elevated ? RankdShadow.elevated : RankdShadow.card,
                        radius: elevated ? RankdShadow.elevatedRadius : RankdShadow.cardRadius,
                        y: elevated ? RankdShadow.elevatedY : RankdShadow.cardY
                    )
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
