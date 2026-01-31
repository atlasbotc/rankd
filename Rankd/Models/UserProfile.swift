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

}
