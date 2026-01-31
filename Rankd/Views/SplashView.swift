import SwiftUI

/// Static branded splash screen shown during app launch.
/// Matches the OS launch screen background, adds the logo mark and wordmark.
struct SplashView: View {
    var body: some View {
        ZStack {
            // Background — warm off-white (#F5F3F0)
            RankdColors.background
                .ignoresSafeArea()
            
            VStack(spacing: RankdSpacing.md) {
                // Logo mark — SF Symbol placeholder
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(RankdColors.brand)
                
                // Wordmark — rounded for brand personality
                Text("Rankd")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(RankdColors.textPrimary)
            }
        }
    }
}

#Preview {
    SplashView()
}
