import SwiftUI

// MARK: - Color System
// Role-based colors. No raw hex values outside this file.
// Dark theme — warm dark brown base with amber accent.

enum MarquiColors {
    // Backgrounds — dark warm brown
    static let background = Color(red: 0.051, green: 0.043, blue: 0.031)     // #0D0B08
    static let surfacePrimary = Color(red: 0.078, green: 0.071, blue: 0.063)  // #141210
    static let surfaceSecondary = Color(red: 0.110, green: 0.094, blue: 0.071) // #1C1812
    static let surfaceTertiary = Color(red: 0.059, green: 0.051, blue: 0.039)  // #0F0D0A — row background
    
    // Text — warm off-white
    static let textPrimary = Color(red: 0.910, green: 0.886, blue: 0.839)     // #E8E2D6
    static let textSecondary = Color(red: 0.478, green: 0.455, blue: 0.408)   // #7A7468
    static let textTertiary = Color(red: 0.353, green: 0.325, blue: 0.278)    // #5A5347
    static let textQuaternary = Color(red: 0.910, green: 0.886, blue: 0.839).opacity(0.20)
    
    // Brand — warm amber/gold
    static let brand = Color(red: 0.831, green: 0.635, blue: 0.298)           // #D4A24C
    static let brandSubtle = Color(red: 0.831, green: 0.635, blue: 0.298).opacity(0.12)
    static let brandSecondary = Color(red: 0.549, green: 0.416, blue: 0.196)  // #8C6A32 — dim accent
    static let brandGlow = Color(red: 0.831, green: 0.635, blue: 0.298).opacity(0.15)
    
    // Gradient pair for buttons/CTAs (solid)
    static let gradientStart = Color(red: 0.831, green: 0.635, blue: 0.298)       // #D4A24C
    static let gradientEnd = Color(red: 0.549, green: 0.416, blue: 0.196)         // #8C6A32
    
    // Gradient pair for #1 row highlight (subtle)
    static let rowHighlightStart = Color(red: 0.831, green: 0.635, blue: 0.298).opacity(0.08)
    static let rowHighlightEnd = Color(red: 0.831, green: 0.635, blue: 0.298).opacity(0.02)
    
    // Surface warmth — slightly warmer for featured content
    static let surfaceWarm = Color(red: 0.831, green: 0.635, blue: 0.298).opacity(0.08)
    
    // Accent — alias for brand
    static let accent = brand
    static let accentSubtle = brandSubtle
    
    // Tiers — semantic colors (muted for dark theme)
    static let tierGood = Color(red: 0.30, green: 0.65, blue: 0.45)           // Muted green
    static let tierMedium = Color(red: 0.75, green: 0.65, blue: 0.30)         // Muted gold
    static let tierBad = Color(red: 0.75, green: 0.35, blue: 0.35)            // Muted red
    
    // Feedback
    static let success = Color(red: 0.30, green: 0.65, blue: 0.45)
    static let warning = Color(red: 0.75, green: 0.65, blue: 0.30)
    static let error = Color(red: 0.75, green: 0.35, blue: 0.35)
    
    // Medals — podium positions
    static let medalGold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let medalSilver = Color(red: 0.75, green: 0.75, blue: 0.78)
    static let medalBronze = Color(red: 0.80, green: 0.50, blue: 0.20)
    
    // Utility
    static let divider = Color(red: 0.910, green: 0.886, blue: 0.839).opacity(0.06)
    static let shimmer = Color(red: 0.910, green: 0.886, blue: 0.839).opacity(0.04)
    
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
    
    /// Returns the appropriate rank number color based on position
    static func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return accent
        case 2, 3: return textSecondary
        default: return textTertiary
        }
    }
}

// MARK: - Typography Scale
// Strict scale. No in-between sizes.

enum MarquiTypography {
    // Display — hero, feature headers
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
    
    // Rank numbers — heavy monospaced for condensed editorial look
    static let rankLarge = Font.system(size: 32, weight: .heavy, design: .monospaced)
    static let rankMedium = Font.system(size: 24, weight: .heavy, design: .monospaced)
    
    // Score display — monospaced for editorial precision
    static let scoreLarge = Font.system(size: 48, weight: .heavy, design: .monospaced)
    static let scoreMedium = Font.system(size: 28, weight: .bold, design: .monospaced)
    static let scoreSmall = Font.system(size: 22, weight: .bold, design: .monospaced)
    
    // Headings
    static let headingLarge = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let headingMedium = Font.system(size: 18, weight: .semibold, design: .default)
    static let headingSmall = Font.system(size: 16, weight: .semibold, design: .default)
    
    // Film titles — serif italic (like Instrument Serif)
    static let filmTitle = Font.system(size: 15, design: .serif).italic()
    static let filmTitleLarge = Font.system(size: 28, design: .serif).italic()
    
    // Body
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
    
    // Labels
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
    
    // Caption — monospace for metadata
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let captionMono = Font.system(size: 9, weight: .medium, design: .monospaced)
    
    // Section label — tracked uppercase
    static let sectionLabel = Font.system(size: 11, weight: .bold, design: .default)
    
    // Logo — monospaced condensed for editorial masthead feel
    static let logo = Font.system(size: 32, weight: .black, design: .monospaced)
    static let logoSubtitle = Font.system(size: 8, weight: .medium, design: .monospaced)
}

// MARK: - Spacing Scale
// Fixed 4px base. Use only these values.

enum MarquiSpacing {
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

enum MarquiRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let full: CGFloat = 999
}

// MARK: - Motion
// 100-300ms. Ease-out or ease-in-out. No bounce.

enum MarquiMotion {
    static let fast = Animation.easeOut(duration: 0.15)
    static let normal = Animation.easeOut(duration: 0.25)
    static let slow = Animation.easeInOut(duration: 0.35)
    
    // For chart/data animations
    static let reveal = Animation.easeOut(duration: 0.5)
}

// MARK: - Poster Sizes

enum MarquiPoster {
    // Standard horizontal scroll
    static let standardWidth: CGFloat = 140
    static let standardHeight: CGFloat = 210
    
    // Large / featured
    static let largeWidth: CGFloat = 180
    static let largeHeight: CGFloat = 270
    
    // Thumbnail (lists, search rows)
    static let thumbWidth: CGFloat = 56
    static let thumbHeight: CGFloat = 84
    
    // Mini (journal, compact rows) — 48px wide for new design
    static let miniWidth: CGFloat = 48
    static let miniHeight: CGFloat = 72
    
    static let cornerRadius: CGFloat = MarquiRadius.sm
}

// MARK: - Shadows (dark theme — subtle glow instead of drop shadow)

enum MarquiShadow {
    // Cards on dark get subtle glow, not drop shadow
    static let card = Color.black.opacity(0.4)
    static let cardRadius: CGFloat = 16
    static let cardY: CGFloat = 8
    
    static let elevated = Color.black.opacity(0.6)
    static let elevatedRadius: CGFloat = 24
    static let elevatedY: CGFloat = 12
}

// MARK: - View Modifiers

/// Subtle scale-down on press (0.97) with easeOut spring-back.
struct MarquiPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.97 : 1.0))
            .animation(reduceMotion ? nil : MarquiMotion.fast, value: configuration.isPressed)
    }
}

// MARK: - Accessibility Helpers

struct MarquiDynamicTypeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

extension View {
    func marquiDynamicTypeLimit() -> some View {
        modifier(MarquiDynamicTypeModifier())
    }
}

struct MarquiCardStyle: ViewModifier {
    var elevated: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: MarquiRadius.lg)
                    .fill(MarquiColors.surfacePrimary)
                    .shadow(
                        color: elevated ? MarquiShadow.elevated : MarquiShadow.card,
                        radius: elevated ? MarquiShadow.elevatedRadius : MarquiShadow.cardRadius,
                        y: elevated ? MarquiShadow.elevatedY : MarquiShadow.cardY
                    )
            )
    }
}

struct MarquiSurfaceStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(MarquiColors.background)
            .foregroundStyle(MarquiColors.textPrimary)
    }
}

extension View {
    func marquiCard() -> some View {
        modifier(MarquiCardStyle())
    }
    
    func marquiSurface() -> some View {
        modifier(MarquiSurfaceStyle())
    }
}
