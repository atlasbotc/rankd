import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    var body: some View {
        TabView(selection: $currentPage) {
            WelcomePage(onNext: { currentPage = 1 })
                .tag(0)
            
            HowItWorksPage(onNext: { currentPage = 2 })
                .tag(1)
            
            GetStartedPage(onComplete: { hasCompletedOnboarding = true })
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(RankdMotion.normal, value: currentPage)
        .background(RankdColors.background.ignoresSafeArea())
    }
}

// MARK: - Welcome Page
private struct WelcomePage: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: RankdSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(RankdColors.surfacePrimary)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "list.number")
                        .font(.system(size: 48))
                        .foregroundStyle(RankdColors.textSecondary)
                }
                
                VStack(spacing: RankdSpacing.sm) {
                    Text("Welcome to Rankd")
                        .font(RankdTypography.displayMedium)
                        .foregroundStyle(RankdColors.textPrimary)
                    
                    Text("Rank the movies and shows you love.\nDiscover what to watch next.")
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            VStack(spacing: RankdSpacing.md) {
                PageIndicator(current: 0, total: 3)
                OnboardingButton(title: "Get Started", action: onNext)
            }
            .padding(.bottom, RankdSpacing.xxl)
        }
        .padding(.horizontal, RankdSpacing.xl)
    }
}

// MARK: - How It Works Page
private struct HowItWorksPage: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: RankdSpacing.xl) {
                Text("How It Works")
                    .font(RankdTypography.displayMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                
                VStack(alignment: .leading, spacing: RankdSpacing.lg) {
                    OnboardingStep(
                        icon: "plus.circle.fill",
                        title: "Add a movie or show",
                        subtitle: "Search or browse trending titles"
                    )
                    
                    OnboardingStep(
                        icon: "arrow.left.arrow.right.circle.fill",
                        title: "Compare it",
                        subtitle: "Quick head-to-head picks find its rank"
                    )
                    
                    OnboardingStep(
                        icon: "trophy.circle.fill",
                        title: "Build your rankings",
                        subtitle: "Your personal top list, always evolving"
                    )
                }
                .padding(.horizontal, RankdSpacing.xs)
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

// MARK: - Get Started Page
private struct GetStartedPage: View {
    let onComplete: () -> Void
    @State private var showLetterboxdImport = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: RankdSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(RankdColors.surfacePrimary)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "film.stack")
                        .font(.system(size: 48))
                        .foregroundStyle(RankdColors.textSecondary)
                }
                
                VStack(spacing: RankdSpacing.sm) {
                    Text("Ready to Rank?")
                        .font(RankdTypography.displayMedium)
                        .foregroundStyle(RankdColors.textPrimary)
                    
                    Text("Start by searching for a movie or show\nyou've seen recently. The more you rank,\nthe smarter your list gets.")
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
                        Text("Already track movies? Import from Letterboxd")
                            .font(RankdTypography.bodySmall)
                    }
                    .foregroundStyle(RankdColors.accent)
                }
                
                PageIndicator(current: 2, total: 3)
                OnboardingButton(title: "Let's Go", action: onComplete)
            }
            .padding(.bottom, RankdSpacing.xxl)
        }
        .padding(.horizontal, RankdSpacing.xl)
        .sheet(isPresented: $showLetterboxdImport) {
            LetterboxdImportView()
        }
    }
}

// MARK: - Shared Components

private struct OnboardingStep: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: RankdSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(RankdColors.textSecondary)
                .frame(width: 48)
            
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(title)
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Text(subtitle)
                    .font(RankdTypography.bodySmall)
                    .foregroundStyle(RankdColors.textSecondary)
            }
        }
    }
}

private struct PageIndicator: View {
    let current: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: RankdSpacing.xs) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == current ? RankdColors.accent : RankdColors.surfaceSecondary)
                    .frame(width: 8, height: 8)
                    .animation(RankdMotion.fast, value: current)
            }
        }
    }
}

private struct OnboardingButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RankdColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
