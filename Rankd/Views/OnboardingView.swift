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
        .animation(.easeInOut, value: currentPage)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
    
    private var gradientColors: [Color] {
        switch currentPage {
        case 0: return [Color.orange.opacity(0.15), Color(.systemBackground)]
        case 1: return [Color.blue.opacity(0.1), Color(.systemBackground)]
        default: return [Color.green.opacity(0.1), Color(.systemBackground)]
        }
    }
}

// MARK: - Welcome Page
private struct WelcomePage: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "list.number")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                }
                
                // Title
                VStack(spacing: 12) {
                    Text("Welcome to Rankd")
                        .font(.largeTitle.bold())
                    
                    Text("Rank the movies and shows you love.\nDiscover what to watch next.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                PageIndicator(current: 0, total: 3)
                
                OnboardingButton(title: "Get Started", action: onNext)
            }
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - How It Works Page
private struct HowItWorksPage: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                Text("How It Works")
                    .font(.largeTitle.bold())
                
                VStack(alignment: .leading, spacing: 24) {
                    OnboardingStep(
                        icon: "plus.circle.fill",
                        color: .blue,
                        title: "Add a movie or show",
                        subtitle: "Search or browse trending titles"
                    )
                    
                    OnboardingStep(
                        icon: "arrow.left.arrow.right.circle.fill",
                        color: .orange,
                        title: "Compare it",
                        subtitle: "Quick head-to-head picks find its rank"
                    )
                    
                    OnboardingStep(
                        icon: "trophy.circle.fill",
                        color: .yellow,
                        title: "Build your rankings",
                        subtitle: "Your personal top list, always evolving"
                    )
                }
                .padding(.horizontal, 8)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                PageIndicator(current: 1, total: 3)
                
                OnboardingButton(title: "Next", action: onNext)
            }
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Get Started Page
private struct GetStartedPage: View {
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "film.stack")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                }
                
                VStack(spacing: 12) {
                    Text("Ready to Rank?")
                        .font(.largeTitle.bold())
                    
                    Text("Start by searching for a movie or show\nyou've seen recently. The more you rank,\nthe smarter your list gets.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                PageIndicator(current: 2, total: 3)
                
                OnboardingButton(title: "Let's Go", action: onComplete)
            }
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Shared Components

private struct OnboardingStep: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(color)
                .frame(width: 48)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PageIndicator: View {
    let current: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.orange : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: current)
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
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
