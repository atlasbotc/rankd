import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $currentPage) {
                RankEverythingPage(onNext: { currentPage = 1 })
                    .tag(0)
                
                TasteQuantifiedPage(onNext: { currentPage = 2 })
                    .tag(1)
                
                NeverForgetPage(onComplete: { hasCompletedOnboarding = true })
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(MarquiMotion.normal, value: currentPage)
            
            // Skip button
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Skip")
                    .font(MarquiTypography.labelLarge)
                    .foregroundStyle(MarquiColors.textTertiary)
                    .padding(.horizontal, MarquiSpacing.lg)
                    .padding(.top, MarquiSpacing.md)
            }
        }
        .background(MarquiColors.background.ignoresSafeArea())
    }
}

// MARK: - Page 1: Rank Everything
private struct RankEverythingPage: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: MarquiSpacing.xl) {
                // Visual mock: two posters with VS
                ComparisonMock()
                
                VStack(spacing: MarquiSpacing.sm) {
                    Text("Rank Everything")
                        .font(MarquiTypography.displayMedium)
                        .foregroundStyle(MarquiColors.textPrimary)
                    
                    Text("Compare two titles head-to-head.\nWe'll build your personal rankings and\ngive you a 1–10 score for every movie and show.")
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            VStack(spacing: MarquiSpacing.md) {
                PageIndicator(current: 0, total: 3)
                OnboardingButton(title: "Next", action: onNext)
            }
            .padding(.bottom, MarquiSpacing.xxl)
        }
        .padding(.horizontal, MarquiSpacing.xl)
    }
}

// MARK: - Page 2: Your Taste, Quantified
private struct TasteQuantifiedPage: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: MarquiSpacing.xl) {
                // Visual mock: score badge + tier dots
                ScoreBadgeMock()
                
                VStack(spacing: MarquiSpacing.sm) {
                    Text("Your Taste, Quantified")
                        .font(MarquiTypography.displayMedium)
                        .foregroundStyle(MarquiColors.textPrimary)
                    
                    Text("See your stats, share your Top 4,\ndiscover patterns in what you love.")
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            VStack(spacing: MarquiSpacing.md) {
                PageIndicator(current: 1, total: 3)
                OnboardingButton(title: "Next", action: onNext)
            }
            .padding(.bottom, MarquiSpacing.xxl)
        }
        .padding(.horizontal, MarquiSpacing.xl)
    }
}

// MARK: - Page 3: Never Forget What to Watch
private struct NeverForgetPage: View {
    let onComplete: () -> Void
    @State private var showLetterboxdImport = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: MarquiSpacing.xl) {
                // Visual mock: mini list
                WatchlistMock()
                
                VStack(spacing: MarquiSpacing.sm) {
                    Text("Never Forget\nWhat to Watch")
                        .font(MarquiTypography.displayMedium)
                        .foregroundStyle(MarquiColors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Build your watchlist, create custom lists,\nand keep a journal of everything you've ranked.")
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            VStack(spacing: MarquiSpacing.md) {
                Button {
                    showLetterboxdImport = true
                } label: {
                    HStack(spacing: MarquiSpacing.xs) {
                        Image(systemName: "square.and.arrow.down")
                            .font(MarquiTypography.bodySmall)
                        Text("Import from Letterboxd")
                            .font(MarquiTypography.bodySmall)
                    }
                    .foregroundStyle(MarquiColors.brand)
                }
                
                PageIndicator(current: 2, total: 3)
                OnboardingButton(title: "Start Ranking", isFinal: true, action: onComplete)
            }
            .padding(.bottom, MarquiSpacing.xxl)
        }
        .padding(.horizontal, MarquiSpacing.xl)
        .sheet(isPresented: $showLetterboxdImport) {
            LetterboxdImportView()
        }
    }
}

// MARK: - Visual Mocks

/// Two poster placeholders with "VS" between them
private struct ComparisonMock: View {
    var body: some View {
        HStack(spacing: MarquiSpacing.md) {
            // Left poster
            posterPlaceholder(icon: "film", label: "Movie A")
            
            // VS badge
            Text("VS")
                .font(MarquiTypography.headingLarge)
                .foregroundStyle(MarquiColors.brand)
                .padding(.horizontal, MarquiSpacing.xs)
            
            // Right poster
            posterPlaceholder(icon: "tv", label: "Movie B")
        }
    }
    
    private func posterPlaceholder(icon: String, label: String) -> some View {
        VStack(spacing: MarquiSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(MarquiColors.textTertiary)
            Text(label)
                .font(MarquiTypography.labelSmall)
                .foregroundStyle(MarquiColors.textTertiary)
        }
        .frame(width: 110, height: 160)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .stroke(MarquiColors.divider, lineWidth: 1)
        )
    }
}

/// Score badge with tier indicator dots
private struct ScoreBadgeMock: View {
    var body: some View {
        VStack(spacing: MarquiSpacing.lg) {
            // Score badge
            VStack(spacing: MarquiSpacing.xxs) {
                Text("9.2")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(MarquiColors.textPrimary)
                
                Text("YOUR SCORE")
                    .font(MarquiTypography.labelSmall)
                    .foregroundStyle(MarquiColors.textTertiary)
                    .tracking(1.2)
            }
            .frame(width: 120, height: 120)
            .background(
                RoundedRectangle(cornerRadius: MarquiRadius.xl)
                    .fill(MarquiColors.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MarquiRadius.xl)
                    .stroke(MarquiColors.tierGood.opacity(0.4), lineWidth: 2)
            )
            
            // Tier dots
            HStack(spacing: MarquiSpacing.sm) {
                tierDot(color: MarquiColors.tierGood, label: "Great")
                tierDot(color: MarquiColors.tierMedium, label: "Good")
                tierDot(color: MarquiColors.tierBad, label: "Meh")
            }
        }
    }
    
    private func tierDot(color: Color, label: String) -> some View {
        HStack(spacing: MarquiSpacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(MarquiTypography.labelSmall)
                .foregroundStyle(MarquiColors.textSecondary)
        }
    }
}

/// Mini watchlist with a few rows
private struct WatchlistMock: View {
    private let items = [
        ("1", "The Godfather", "9.4"),
        ("2", "Parasite", "8.7"),
        ("3", "Spirited Away", "8.5"),
        ("4", "The Dark Knight", "8.1"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: MarquiSpacing.sm) {
                    // Rank number
                    Text(item.0)
                        .font(MarquiTypography.labelMedium)
                        .foregroundStyle(MarquiColors.textTertiary)
                        .frame(width: 20)
                    
                    // Mini poster placeholder
                    RoundedRectangle(cornerRadius: MarquiRadius.sm)
                        .fill(MarquiColors.surfaceSecondary)
                        .frame(width: MarquiPoster.miniWidth, height: MarquiPoster.miniHeight)
                    
                    // Title
                    Text(item.1)
                        .font(MarquiTypography.headingSmall)
                        .foregroundStyle(MarquiColors.textPrimary)
                    
                    Spacer()
                    
                    // Score
                    Text(item.2)
                        .font(MarquiTypography.labelLarge)
                        .foregroundStyle(MarquiColors.tierGood)
                }
                .padding(.vertical, MarquiSpacing.xs)
                .padding(.horizontal, MarquiSpacing.md)
                
                if index < items.count - 1 {
                    Divider()
                        .background(MarquiColors.divider)
                        .padding(.leading, MarquiSpacing.xl + MarquiPoster.miniWidth)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
        .padding(.horizontal, MarquiSpacing.md)
    }
}

// MARK: - Shared Components

private struct PageIndicator: View {
    let current: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: MarquiSpacing.xs) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? MarquiColors.brand : MarquiColors.surfaceSecondary)
                    .frame(width: index == current ? 24 : 8, height: 8)
                    .animation(MarquiMotion.fast, value: current)
            }
        }
    }
}

private struct OnboardingButton: View {
    let title: String
    var isFinal: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [MarquiColors.gradientStart, MarquiColors.gradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: MarquiColors.brand.opacity(0.4), radius: 8, y: 4)
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
