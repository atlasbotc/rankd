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
                VStack(spacing: MarquiSpacing.lg) {
                    // Header
                    VStack(spacing: MarquiSpacing.sm) {
                        Image(systemName: "sparkles")
                            .font(MarquiTypography.displayLarge)
                            .foregroundStyle(MarquiColors.brand)
                            .padding(.top, MarquiSpacing.xxl)
                        
                        Text("What's New in Marqui \(appVersion)")
                            .font(MarquiTypography.displayMedium)
                            .foregroundStyle(MarquiColors.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, MarquiSpacing.md)
                    
                    // Feature list
                    VStack(spacing: MarquiSpacing.xs) {
                        ForEach(features) { feature in
                            featureRow(feature)
                        }
                    }
                    .padding(.horizontal, MarquiSpacing.md)
                }
                .padding(.bottom, MarquiSpacing.xxl)
            }
            
            // Continue button
            Button {
                dismiss()
            } label: {
                Text("Continue")
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MarquiSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: MarquiRadius.lg)
                            .fill(MarquiColors.brand)
                    )
            }
            .buttonStyle(MarquiPressStyle())
            .padding(.horizontal, MarquiSpacing.md)
            .padding(.bottom, MarquiSpacing.lg)
        }
        .background(MarquiColors.background)
    }
    
    private func featureRow(_ feature: WhatsNewFeature) -> some View {
        HStack(spacing: MarquiSpacing.md) {
            Image(systemName: feature.icon)
                .font(MarquiTypography.headingLarge)
                .foregroundStyle(MarquiColors.brand)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(feature.title)
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                
                Text(feature.description)
                    .font(MarquiTypography.bodySmall)
                    .foregroundStyle(MarquiColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(MarquiSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
    }
}

#Preview {
    WhatsNewView()
}
