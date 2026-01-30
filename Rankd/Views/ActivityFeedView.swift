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
        .background(RankdColors.background)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Activity List
    
    private var activityList: some View {
        ScrollView {
            LazyVStack(spacing: RankdSpacing.xs) {
                ForEach(activities) { activity in
                    ActivityRow(activity: activity)
                }
            }
            .padding(.horizontal, RankdSpacing.md)
            .padding(.vertical, RankdSpacing.sm)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: RankdSpacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(RankdColors.textQuaternary)
            
            Text("No Activity Yet")
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
            
            Text("Your ranking activity will show up here.\nStart by ranking a movie or show!")
                .font(RankdTypography.bodySmall)
                .foregroundStyle(RankdColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(RankdSpacing.xl)
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let activity: Activity
    
    var body: some View {
        HStack(alignment: .top, spacing: RankdSpacing.sm) {
            // Activity type icon
            Image(systemName: activity.activityType.icon)
                .font(RankdTypography.headingSmall)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.12))
                )
            
            // Content
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(activityText)
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Text(activity.relativeTimestamp)
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textTertiary)
            }
            
            Spacer()
        }
        .padding(RankdSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.md)
                .fill(RankdColors.surfacePrimary)
        )
    }
    
    private var activityText: AttributedString {
        var result = AttributedString("You ")
        result.foregroundColor = UIColor(RankdColors.textSecondary)
        
        var action = AttributedString(activity.displayText)
        action.foregroundColor = UIColor(RankdColors.textPrimary)
        
        result.append(action)
        return result
    }
    
    private var iconColor: Color {
        switch activity.activityType {
        case .ranked, .reRanked:
            return RankdColors.brand
        case .addedToWatchlist:
            return RankdColors.tierGood
        case .createdList, .addedToList:
            return RankdColors.tierMedium
        }
    }
}

#Preview {
    NavigationStack {
        ActivityFeedView()
    }
    .modelContainer(for: [Activity.self], inMemory: true)
}
