import Foundation
import FirebaseFirestore
import FirebaseAuth

struct User: Identifiable, Codable {
    let id: String  // Firebase Auth UID
    let email: String
    var username: String
    var profileImageURL: URL?  // New property for profile image
    var bio: String?
    var postsCount: Int
    var followersCount: Int
    var followingCount: Int
    var savedVideos: [String]  // Array of video IDs
    var createdAt: Date
    
    init(id: String, email: String, username: String? = nil, profileImageURL: URL? = nil, postsCount: Int = 0, followersCount: Int = 0, followingCount: Int = 0, savedVideos: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.email = email
        // Generate username from email if none provided
        if let providedUsername = username {
            self.username = providedUsername
        } else {
            // Convert email to username: example@email.com -> example
            self.username = email.components(separatedBy: "@").first ?? "user"
        }
        self.profileImageURL = profileImageURL
        self.postsCount = postsCount
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.savedVideos = savedVideos
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case profileImageURL
        case bio
        case postsCount
        case followersCount
        case followingCount
        case savedVideos
        case createdAt
    }
    
    // Convert Firestore document to User
    static func fromFirestore(_ document: DocumentSnapshot) -> User? {
        guard let data = document.data(),
              let email = data["email"] as? String,
              let username = data["username"] as? String,
              let postsCount = data["postsCount"] as? Int,
              let followersCount = data["followersCount"] as? Int,
              let followingCount = data["followingCount"] as? Int,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            print("❌ Failed to parse user document: \(document.documentID)")
            return nil
        }
        
        let savedVideos = data["savedVideos"] as? [String] ?? []
        let profileImageURLString = data["profileImageURL"] as? String
        let profileImageURL = profileImageURLString.flatMap { URL(string: $0) }
        
        return User(
            id: document.documentID,
            email: email,
            username: username,
            profileImageURL: profileImageURL,
            postsCount: postsCount,
            followersCount: followersCount,
            followingCount: followingCount,
            savedVideos: savedVideos,
            createdAt: createdAt
        )
    }
    
    // Convert User to Firestore data
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "email": email,
            "username": username,
            "postsCount": postsCount,
            "followersCount": followersCount,
            "followingCount": followingCount,
            "savedVideos": savedVideos,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        // Only include profileImageURL if it exists
        if let profileImageURL = profileImageURL {
            data["profileImageURL"] = profileImageURL.absoluteString
        }
        
        return data
    }
    
    static func fromFirebaseUser(_ firebaseUser: FirebaseAuth.User) -> User {
        return User(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "unknown@email.com",
            username: firebaseUser.displayName
        )
    }
} 