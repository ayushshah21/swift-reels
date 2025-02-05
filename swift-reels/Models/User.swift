import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    let id: String  // Firebase Auth UID
    var email: String
    var username: String
    var profilePicUrl: String?
    var bio: String?
    var followersCount: Int
    var followingCount: Int
    var postsCount: Int
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case profilePicUrl
        case bio
        case followersCount
        case followingCount
        case postsCount
        case createdAt
    }
    
    // Create a new user from Firebase Auth data
    static func new(id: String, email: String) -> User {
        User(
            id: id,
            email: email,
            username: email.components(separatedBy: "@")[0], // Default username from email
            profilePicUrl: nil,
            bio: nil,
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
            createdAt: Date()
        )
    }
    
    // Convert Firestore document to User
    static func fromFirestore(_ document: DocumentSnapshot) -> User? {
        try? document.data(as: User.self)
    }
    
    // Convert User to Firestore data
    func toFirestore() -> [String: Any] {
        [
            "id": id,
            "email": email,
            "username": username,
            "profilePicUrl": profilePicUrl as Any,
            "bio": bio as Any,
            "followersCount": followersCount,
            "followingCount": followingCount,
            "postsCount": postsCount,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
} 