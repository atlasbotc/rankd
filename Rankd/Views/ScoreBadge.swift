import SwiftUI

/// Reusable pill badge showing a 1–10 score, colored by tier.
struct ScoreBadge: View {
    let score: Double
    let tier: Tier
    
    /// Compact variant for tight spaces
    var compact: Bool = false
    
    /// Whether to animate in on appear (fade + scale)
    var animated: Bool = true
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var backgroundColor: Color {
        RankdColors.tierColor(tier)
    }
    
    /// Yellow tier needs dark text for contrast; green/red use white.
    private var textColor: Color {
        switch tier {
        case .medium: return RankdColors.textPrimary
        case .good, .bad: return .white
        }
    }
    
    private var shouldAnimate: Bool {
        animated && !reduceMotion
    }
    
    var body: some View {
        Text(String(format: "%.1f", score))
            .font(RankdTypography.labelSmall)
            .foregroundStyle(textColor)
            .padding(.horizontal, RankdSpacing.xs)
            .padding(.vertical, compact ? 2 : RankdSpacing.xxs)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .scaleEffect(shouldAnimate ? (isVisible ? 1.0 : 0.5) : 1.0)
            .opacity(shouldAnimate ? (isVisible ? 1.0 : 0.0) : 1.0)
            .onAppear {
                guard shouldAnimate else { return }
                withAnimation(RankdMotion.slow) {
                    isVisible = true
                }
            }
            .onChange(of: score) { _, _ in
                guard shouldAnimate else { return }
                isVisible = false
                withAnimation(RankdMotion.slow) {
                    isVisible = true
                }
            }
            .accessibilityLabel("Score \(String(format: "%.1f", score)) out of 10")
    }
}

/// Larger score display for detail views.
struct ScoreDisplay: View {
    let score: Double
    let tier: Tier
    
    var body: some View {
        HStack(spacing: RankdSpacing.xs) {
            Text("Your Score:")
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textSecondary)
            
            ScoreBadge(score: score, tier: tier)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ScoreBadge(score: 9.2, tier: .good)
        ScoreBadge(score: 5.5, tier: .medium)
        ScoreBadge(score: 2.1, tier: .bad)
        ScoreBadge(score: 8.0, tier: .good, compact: true)
        ScoreDisplay(score: 9.2, tier: .good)
    }
    .padding()
    .background(RankdColors.background)
}
