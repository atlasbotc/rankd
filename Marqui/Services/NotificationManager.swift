import Foundation
import UserNotifications

// MARK: - Reminder Option

enum ReminderOption: String, CaseIterable, Identifiable {
    case tonight = "Tonight"
    case tomorrow = "Tomorrow"
    case thisWeekend = "This Weekend"
    case custom = "Custom Date"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .tonight: return "moon.fill"
        case .tomorrow: return "sunrise.fill"
        case .thisWeekend: return "calendar.badge.clock"
        case .custom: return "calendar"
        }
    }
    
    /// Returns the trigger date for this option, using the user's local calendar.
    func triggerDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .tonight:
            // Today at 8pm local
            return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)
        case .tomorrow:
            // Tomorrow at 10am local
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
            return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow)
        case .thisWeekend:
            // Next Saturday at 11am local
            let weekday = calendar.component(.weekday, from: now)
            let daysUntilSaturday = (7 - weekday) % 7
            let offset = daysUntilSaturday == 0 ? 7 : daysUntilSaturday
            guard let saturday = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            return calendar.date(bySettingHour: 11, minute: 0, second: 0, of: saturday)
        case .custom:
            return nil // Handled by date picker
        }
    }
}

// MARK: - Notification Manager

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {
        Task { await refreshAuthorizationStatus() }
    }
    
    // MARK: - Authorization
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            return false
        }
    }
    
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
    
    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }
    
    var isDenied: Bool {
        authorizationStatus == .denied
    }
    
    // MARK: - Watchlist Reminders
    
    /// Schedule a watchlist reminder for a specific item.
    func scheduleWatchlistReminder(
        itemId: String,
        title: String,
        mediaType: String,
        posterPath: String?,
        at date: Date
    ) async {
        // Ensure we have permission
        if !isAuthorized {
            let granted = await requestPermission()
            guard granted else { return }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to watch!"
        content.body = "\"\(title)\" is waiting for you. Ready to watch this \(mediaType)?  🍿"
        content.sound = .default
        content.categoryIdentifier = "WATCHLIST_REMINDER"
        content.userInfo = ["itemId": itemId, "type": "watchlist"]
        
        // Attempt poster attachment
        if let posterPath = posterPath,
           let url = URL(string: "https://image.tmdb.org/t/p/w200\(posterPath)") {
            if let attachment = await downloadAttachment(from: url, identifier: itemId) {
                content.attachments = [attachment]
            }
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = "watchlist-\(itemId)"
        // Remove any existing reminder for this item first
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
    
    /// Cancel a watchlist reminder for a specific item.
    func cancelWatchlistReminder(itemId: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["watchlist-\(itemId)"])
    }
    
    // MARK: - Streak Reminders
    
    /// Schedule a streak reminder based on current ranking activity.
    /// - Parameters:
    ///   - streak: Current streak count
    ///   - rankedToday: Whether the user has ranked something today
    func scheduleStreakReminder(streak: Int, rankedToday: Bool) async {
        guard streak > 0, isAuthorized else { return }
        
        // Remove any existing streak reminders
        cancelStreakReminders()
        
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = "STREAK_REMINDER"
        content.userInfo = ["type": "streak"]
        
        let calendar = Calendar.current
        var triggerComponents: DateComponents
        
        if rankedToday {
            // Ranked today → remind tomorrow at 7pm to keep it going
            content.title = "Keep your streak alive! 🔥"
            content.body = "You're on a \(streak) day streak. Don't let it slip!"
            
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else { return }
            triggerComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            triggerComponents.hour = 19
            triggerComponents.minute = 0
        } else {
            // Haven't ranked today but have active streak → urgent reminder at 8pm
            content.title = "Don't lose your \(streak) day streak!"
            content.body = "Rank something quick before the day ends 🔥"
            
            triggerComponents = calendar.dateComponents([.year, .month, .day], from: Date())
            triggerComponents.hour = 20
            triggerComponents.minute = 0
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak-reminder",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }
    
    /// Cancel all streak reminders.
    func cancelStreakReminders() {
        center.removePendingNotificationRequests(withIdentifiers: ["streak-reminder"])
    }
    
    // MARK: - Cancel All
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Helpers
    
    private func downloadAttachment(from url: URL, identifier: String) async -> UNNotificationAttachment? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("\(identifier).jpg")
            try data.write(to: fileURL)
            let attachment = try UNNotificationAttachment(
                identifier: identifier,
                url: fileURL,
                options: [UNNotificationAttachmentOptionsTypeHintKey: "public.jpeg"]
            )
            return attachment
        } catch {
            return nil
        }
    }
}
