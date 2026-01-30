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
            .animation(RankdMotion.normal, value: currentPage)
            
            // Skip button
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Skip")
                    .font(RankdTypography.labelLarge)
                    .foregroundStyle(RankdColors.textTertiary)
                    .padding(.horizontal, RankdSpacing.lg)
                    .padding(.top, RankdSpacing.md)
            }
        }
        .background(RankdColors.background.ignoresSafeArea())
    }
}

// MARK: - Page 1: Rank Everything
private struct RankEverythingPage: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: RankdSpacing.xl) {
                // Visual mock: two posters with VS
                ComparisonMock()
                
                VStack(spacing: RankdSpacing.sm) {
                    Text("Rank Everything")
                        .font(RankdTypography.displayMedium)
                        .foregroundStyle(RankdColors.textPrimary)
                    
                    Text("Compare two titles head-to-head.\nWe'll build your personal rankings and\ngive you a 1–10 score for every movie and show.")
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            VStack(spacing: RankdSpacing.md) {
                PageIndicator(current: 0, total: 3)
                OnboardingButton(title: "Next", action: onNext)
            }
            .padding(.bottom, RankdSpacing.xxl)
        }
        .padding(.horizontal, RankdSpacing.xl)
    }
}

// MARK: - Page 2: Your Taste, Quantified
private struct TasteQuantifiedPage: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: RankdSpacing.xl) {
                // Visual mock: score badge + tier dots
                ScoreBadgeMock()
                
                VStack(spacing: RankdSpacing.sm) {
                    Text("Your Taste, Quantified")
                        .font(RankdTypography.displayMedium)
                        .foregroundStyle(RankdColors.textPrimary)
                    
                    Text("See your stats, share your Top 4,\ndiscover patterns in what you love.")
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            VStack(spacing: RankdSpacing.md) {
                PageIndicator(current: 1, total: 3)
                OnboardingButton(title: "Next", action: onNext)
            }
            .padding(.bottom, RankdSpacing.xxl)
        }
        .padding(.horizontal, RankdSpacing.xl)
    }
}

// MARK: - Page 3: Never Forget What to Watch
private struct NeverForgetPage: View {
    let onComplete: () -> Void
    @State private var showLetterboxdImport = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: RankdSpacing.xl) {
                // Visual mock: mini list
                WatchlistMock()
                
                VStack(spacing: RankdSpacing.sm) {
                    Text("Never Forget\nWhat to Watch")
                        .font(RankdTypography.displayMedium)
                        .foregroundStyle(RankdColors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Build your watchlist, create custom lists,\nand keep a journal of everything you've ranked.")
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            VStack(spacing: RankdSpacing.md) {
                Button {
                    showLetterboxdImport = true
                } label: {
                    HStack(spacing: RankdSpacing.xs) {
                        Image(systemName: "square.and.arrow.down")
                            .font(RankdTypography.bodySmall)
                        Text("Import from Letterboxd")
                            .font(RankdTypography.bodySmall)
                    }
                    .foregroundStyle(RankdColors.brand)
                }
                
                PageIndicator(current: 2, total: 3)
                OnboardingButton(title: "Start Ranking", isFinal: true, action: onComplete)
            }
            .padding(.bottom, RankdSpacing.xxl)
        }
        .padding(.horizontal, RankdSpacing.xl)
        .sheet(isPresented: $showLetterboxdImport) {
            LetterboxdImportView()
        }
    }
}

// MARK: - Visual Mocks

/// Two poster placeholders with "VS" between them
private struct ComparisonMock: View {
    var body: some View {
        HStack(spacing: RankdSpacing.md) {
            // Left poster
            posterPlaceholder(icon: "film", label: "Movie A")
            
            // VS badge
            Text("VS")
                .font(RankdTypography.headingLarge)
                .foregroundStyle(RankdColors.brand)
                .padding(.horizontal, RankdSpacing.xs)
            
            // Right poster
            posterPlaceholder(icon: "tv", label: "Movie B")
        }
    }
    
    private func posterPlaceholder(icon: String, label: String) -> some View {
        VStack(spacing: RankdSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(RankdColors.textTertiary)
            Text(label)
                .font(RankdTypography.labelSmall)
                .foregroundStyle(RankdColors.textTertiary)
        }
        .frame(width: 110, height: 160)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .stroke(RankdColors.divider, lineWidth: 1)
        )
    }
}

/// Score badge with tier indicator dots
private struct ScoreBadgeMock: View {
    var body: some View {
        VStack(spacing: RankdSpacing.lg) {
            // Score badge
            VStack(spacing: RankdSpacing.xxs) {
                Text("9.2")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(RankdColors.textPrimary)
                
                Text("YOUR SCORE")
                    .font(RankdTypography.labelSmall)
                    .foregroundStyle(RankdColors.textTertiary)
                    .tracking(1.2)
            }
            .frame(width: 120, height: 120)
            .background(
                RoundedRectangle(cornerRadius: RankdRadius.xl)
                    .fill(RankdColors.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RankdRadius.xl)
                    .stroke(RankdColors.tierGood.opacity(0.4), lineWidth: 2)
            )
            
            // Tier dots
            HStack(spacing: RankdSpacing.sm) {
                tierDot(color: RankdColors.tierGood, label: "Great")
                tierDot(color: RankdColors.tierMedium, label: "Good")
                tierDot(color: RankdColors.tierBad, label: "Meh")
            }
        }
    }
    
    private func tierDot(color: Color, label: String) -> some View {
        HStack(spacing: RankdSpacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(RankdTypography.labelSmall)
                .foregroundStyle(RankdColors.textSecondary)
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
                HStack(spacing: RankdSpacing.sm) {
                    // Rank number
                    Text(item.0)
                        .font(RankdTypography.labelMedium)
                        .foregroundStyle(RankdColors.textTertiary)
                        .frame(width: 20)
                    
                    // Mini poster placeholder
                    RoundedRectangle(cornerRadius: RankdRadius.sm)
                        .fill(RankdColors.surfaceSecondary)
                        .frame(width: RankdPoster.miniWidth, height: RankdPoster.miniHeight)
                    
                    // Title
                    Text(item.1)
                        .font(RankdTypography.headingSmall)
                        .foregroundStyle(RankdColors.textPrimary)
                    
                    Spacer()
                    
                    // Score
                    Text(item.2)
                        .font(RankdTypography.labelLarge)
                        .foregroundStyle(RankdColors.tierGood)
                }
                .padding(.vertical, RankdSpacing.xs)
                .padding(.horizontal, RankdSpacing.md)
                
                if index < items.count - 1 {
                    Divider()
                        .background(RankdColors.divider)
                        .padding(.leading, RankdSpacing.xl + RankdPoster.miniWidth)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
        .padding(.horizontal, RankdSpacing.md)
    }
}

// MARK: - Shared Components

private struct PageIndicator: View {
    let current: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: RankdSpacing.xs) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? RankdColors.brand : RankdColors.surfaceSecondary)
                    .frame(width: index == current ? 24 : 8, height: 8)
                    .animation(RankdMotion.fast, value: current)
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
                .font(RankdTypography.headingSmall)
                .foregroundStyle(isFinal ? .white : RankdColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RankdColors.brand)
                .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
