import SwiftUI
import SwiftData

struct ActivityFeedView: View {
    @Query(sort: \Activity.timestamp, order: .reverse)
    private var activities: [Activity]
    
    var body: some View {
        Group {
            if activities.isEmpty {
                emptyState
            } else {
                activityList
            }
        }
        .background(MarquiColors.background)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Activity List
    
    private var activityList: some View {
        ScrollView {
            LazyVStack(spacing: MarquiSpacing.xs) {
                ForEach(activities) { activity in
                    ActivityRow(activity: activity)
                }
            }
            .padding(.horizontal, MarquiSpacing.md)
            .padding(.vertical, MarquiSpacing.sm)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: MarquiSpacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(MarquiColors.textQuaternary)
            
            Text("No Activity Yet")
                .font(MarquiTypography.headingMedium)
                .foregroundStyle(MarquiColors.textPrimary)
            
            Text("Your ranking activity will show up here.\nStart by ranking a movie or show!")
                .font(MarquiTypography.bodySmall)
                .foregroundStyle(MarquiColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MarquiSpacing.xl)
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let activity: Activity
    
    var body: some View {
        HStack(alignment: .top, spacing: MarquiSpacing.sm) {
            // Activity type icon
            Image(systemName: activity.activityType.icon)
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.12))
                )
            
            // Content
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(activityText)
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                
                Text(activity.relativeTimestamp)
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            
            Spacer()
        }
        .padding(MarquiSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.md)
                .fill(MarquiColors.surfacePrimary)
        )
    }
    
    private var activityText: AttributedString {
        var result = AttributedString("You ")
        result.foregroundColor = UIColor(MarquiColors.textSecondary)
        
        var action = AttributedString(activity.displayText)
        action.foregroundColor = UIColor(MarquiColors.textPrimary)
        
        result.append(action)
        return result
    }
    
    private var iconColor: Color {
        switch activity.activityType {
        case .ranked, .reRanked:
            return MarquiColors.brand
        case .addedToWatchlist:
            return MarquiColors.tierGood
        case .createdList, .addedToList:
            return MarquiColors.tierMedium
        }
    }
}

#Preview {
    NavigationStack {
        ActivityFeedView()
    }
    .modelContainer(for: [Activity.self], inMemory: true)
}
