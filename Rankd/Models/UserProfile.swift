import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var displayName: String
    var username: String
    var avatarURLString: String?
    var bio: String
    var joinDate: Date
    var isCurrentUser: Bool
    
    init(
        displayName: String,
        username: String,
        bio: String = "",
        avatarURLString: String? = nil,
        isCurrentUser: Bool = true
    ) {
        self.id = UUID()
        self.displayName = displayName
        self.username = username
        self.avatarURLString = avatarURLString
        self.bio = String(bio.prefix(150))
        self.joinDate = Date()
        self.isCurrentUser = isCurrentUser
    }
    
    var avatarURL: URL? {
        guard let str = avatarURLString else { return nil }
        return URL(string: str)
    }
    
    /// Validate username: 3-20 chars, alphanumeric + underscores only
    static func isValidUsername(_ username: String) -> Bool {
        let pattern = "^[a-zA-Z0-9_]{3,20}$"
        return username.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Formatted handle
    var handle: String {
        "@\(username)"
    }
}
