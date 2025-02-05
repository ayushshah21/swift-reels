import Foundation
import FirebaseFirestore

struct Video: Identifiable, Codable {
    let id: String
    let userId: String
    var videoUrl: String
    var thumbnailUrl: String?
    var description: String
    var likeCount: Int
    var commentCount: Int
    var shareCount: Int
    var createdAt: Date
    
    // Workout-specific metadata
    var workout: WorkoutMetadata
    
    // Denormalized user data
    var uploaderName: String
    var uploaderProfilePic: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case videoUrl
        case thumbnailUrl
        case description
        case likeCount
        case commentCount
        case shareCount
        case createdAt
        case workout
        case uploaderName
        case uploaderProfilePic
    }
    
    // Create a new video
    static func new(
        userId: String,
        videoUrl: String,
        description: String,
        workout: WorkoutMetadata,
        uploaderName: String,
        uploaderProfilePic: String?
    ) -> Video {
        Video(
            id: UUID().uuidString,
            userId: userId,
            videoUrl: videoUrl,
            thumbnailUrl: nil,
            description: description,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            workout: workout,
            uploaderName: uploaderName,
            uploaderProfilePic: uploaderProfilePic
        )
    }
    
    // Preview data for development
    static func preview() -> Video {
        Video.new(
            userId: "preview_user",
            videoUrl: "preview_url",
            description: "Quick 5-minute strength workout!",
            workout: WorkoutMetadata.preview(),
            uploaderName: "Fitness Coach",
            uploaderProfilePic: nil
        )
    }
    
    // Convert Firestore document to Video
    static func fromFirestore(_ document: DocumentSnapshot) -> Video? {
        try? document.data(as: Video.self)
    }
    
    // Convert Video to Firestore data
    func toFirestore() -> [String: Any] {
        [
            "id": id,
            "userId": userId,
            "videoUrl": videoUrl,
            "thumbnailUrl": thumbnailUrl as Any,
            "description": description,
            "likeCount": likeCount,
            "commentCount": commentCount,
            "shareCount": shareCount,
            "createdAt": Timestamp(date: createdAt),
            "workout": workout,  // Firestore handles Codable objects
            "uploaderName": uploaderName,
            "uploaderProfilePic": uploaderProfilePic as Any
        ]
    }
} 