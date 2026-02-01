import SwiftUI

struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "number.circle.fill",
            title: "1-10 Scores",
            description: "Every ranked item gets a score based on your tier and position"
        ),
        WhatsNewFeature(
            icon: "theatermasks.fill",
            title: "Taste Personality",
            description: "Discover your viewer archetype from 11 personality types"
        ),
        WhatsNewFeature(
            icon: "square.and.arrow.up.fill",
            title: "Share Cards",
            description: "Share your Top 4 Movies, Top 4 Shows, Top 10 lists"
        ),
        WhatsNewFeature(
            icon: "list.bullet.rectangle.fill",
            title: "Custom Lists",
            description: "Create themed collections with templates"
        ),
        WhatsNewFeature(
            icon: "play.tv.fill",
            title: "Watch Providers",
            description: "See where to stream any movie or show"
        ),
        WhatsNewFeature(
            icon: "widget.small",
            title: "Home Screen Widget",
            description: "Your top rankings on your home screen"
        ),
    ]
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: RankdSpacing.lg) {
                    // Header
                    VStack(spacing: RankdSpacing.sm) {
                        Image(systemName: "sparkles")
                            .font(RankdTypography.displayLarge)
                            .foregroundStyle(RankdColors.brand)
                            .padding(.top, RankdSpacing.xxl)
                        
                        Text("What's New in Marqui \(appVersion)")
                            .font(RankdTypography.displayMedium)
                            .foregroundStyle(RankdColors.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, RankdSpacing.md)
                    
                    // Feature list
                    VStack(spacing: RankdSpacing.xs) {
                        ForEach(features) { feature in
                            featureRow(feature)
                        }
                    }
                    .padding(.horizontal, RankdSpacing.md)
                }
                .padding(.bottom, RankdSpacing.xxl)
            }
            
            // Continue button
            Button {
                dismiss()
            } label: {
                Text("Continue")
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RankdSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: RankdRadius.lg)
                            .fill(RankdColors.brand)
                    )
            }
            .buttonStyle(RankdPressStyle())
            .padding(.horizontal, RankdSpacing.md)
            .padding(.bottom, RankdSpacing.lg)
        }
        .background(RankdColors.background)
    }
    
    private func featureRow(_ feature: WhatsNewFeature) -> some View {
        HStack(spacing: RankdSpacing.md) {
            Image(systemName: feature.icon)
                .font(RankdTypography.headingLarge)
                .foregroundStyle(RankdColors.brand)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(feature.title)
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Text(feature.description)
                    .font(RankdTypography.bodySmall)
                    .foregroundStyle(RankdColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(RankdSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
    }
}

#Preview {
    WhatsNewView()
}
