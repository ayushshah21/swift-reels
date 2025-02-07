import Foundation
import FirebaseFirestore

struct CommunityReel: Identifiable, Codable {
    var id: String?
    let videoURL: URL
    let thumbnailURL: URL?
    let participants: [String]  // User IDs of participants
    let duration: TimeInterval
    let workoutType: WorkoutType
    let createdAt: Date
    var likeCount: Int
    var commentCount: Int
    
    // Firestore encoding
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "videoURL": videoURL.absoluteString,
            "participants": participants,
            "duration": duration,
            "workoutType": workoutType.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "likeCount": likeCount,
            "commentCount": commentCount
        ]
        
        if let thumbnailURL = thumbnailURL {
            data["thumbnailURL"] = thumbnailURL.absoluteString
        }
        
        return data
    }
    
    // Firestore decoding
    static func fromFirestore(_ snapshot: DocumentSnapshot) -> CommunityReel? {
        guard let data = snapshot.data(),
              let videoURLString = data["videoURL"] as? String,
              let videoURL = URL(string: videoURLString),
              let participants = data["participants"] as? [String],
              let duration = data["duration"] as? TimeInterval,
              let workoutTypeString = data["workoutType"] as? String,
              let workoutType = WorkoutType(rawValue: workoutTypeString),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        let thumbnailURLString = data["thumbnailURL"] as? String
        let thumbnailURL = thumbnailURLString.flatMap { URL(string: $0) }
        
        return CommunityReel(
            id: snapshot.documentID,
            videoURL: videoURL,
            thumbnailURL: thumbnailURL,
            participants: participants,
            duration: duration,
            workoutType: workoutType,
            createdAt: createdAt,
            likeCount: data["likeCount"] as? Int ?? 0,
            commentCount: data["commentCount"] as? Int ?? 0
        )
    }
} 