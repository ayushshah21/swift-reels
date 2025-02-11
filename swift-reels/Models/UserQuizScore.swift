import Foundation
import FirebaseFirestore

struct UserQuizScore: Codable, Identifiable {
    var id: String { userId }  // Use userId as the identifier
    let userId: String
    let username: String
    let profileImageURL: URL?
    let totalQuizzesTaken: Int
    let totalCorrectAnswers: Int
    let averageScore: Double
    let lastQuizDate: Date
    
    // Firestore encoding
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "username": username,
            "totalQuizzesTaken": totalQuizzesTaken,
            "totalCorrectAnswers": totalCorrectAnswers,
            "averageScore": averageScore,
            "lastQuizDate": Timestamp(date: lastQuizDate)
        ]
        
        if let profileImageURL = profileImageURL {
            data["profileImageURL"] = profileImageURL.absoluteString
        }
        
        return data
    }
    
    // Firestore decoding
    static func fromFirestore(_ document: DocumentSnapshot) -> UserQuizScore? {
        guard let data = document.data(),
              let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let totalQuizzesTaken = data["totalQuizzesTaken"] as? Int,
              let totalCorrectAnswers = data["totalCorrectAnswers"] as? Int,
              let averageScore = data["averageScore"] as? Double,
              let lastQuizDate = (data["lastQuizDate"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        let profileImageURLString = data["profileImageURL"] as? String
        let profileImageURL = profileImageURLString.flatMap { URL(string: $0) }
        
        return UserQuizScore(
            userId: userId,
            username: username,
            profileImageURL: profileImageURL,
            totalQuizzesTaken: totalQuizzesTaken,
            totalCorrectAnswers: totalCorrectAnswers,
            averageScore: averageScore,
            lastQuizDate: lastQuizDate
        )
    }
} 