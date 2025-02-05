import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Equatable {
    let id: String
    let videoId: String
    let userId: String
    let text: String
    let username: String  // Cache username to avoid extra user lookups
    let createdAt: Date
    
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Firestore Conversion
    
    func toFirestore() -> [String: Any] {
        return [
            "videoId": videoId,
            "userId": userId,
            "text": text,
            "username": username,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    static func fromFirestore(_ document: DocumentSnapshot) -> Comment? {
        guard let data = document.data(),
              let videoId = data["videoId"] as? String,
              let userId = data["userId"] as? String,
              let text = data["text"] as? String,
              let username = data["username"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            print("❌ Failed to parse comment document: \(document.documentID)")
            return nil
        }
        
        return Comment(
            id: document.documentID,
            videoId: videoId,
            userId: userId,
            text: text,
            username: username,
            createdAt: createdAt
        )
    }
} 