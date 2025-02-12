import Foundation
import FirebaseFirestore
import FirebaseAuth

// Import WorkoutTypes to use its WorkoutDifficulty enum

struct VideoModel: Identifiable, Equatable {
    let id: String
    let title: String
    let videoURL: URL
    let thumbnailURL: URL?
    let duration: TimeInterval
    let workout: WorkoutMetadata
    let likeCount: Int
    let comments: Int
    var isBookmarked: Bool
    let trainer: String
    let createdAt: Date
    let userId: String
    
    static func == (lhs: VideoModel, rhs: VideoModel) -> Bool {
        lhs.id == rhs.id
    }
    
    init(id: String, title: String, videoURL: URL, thumbnailURL: URL?, duration: TimeInterval, workout: WorkoutMetadata, likeCount: Int, comments: Int, isBookmarked: Bool, trainer: String, createdAt: Date = Date(), userId: String = Auth.auth().currentUser?.uid ?? "") {
        self.id = id
        self.title = title
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.workout = workout
        self.likeCount = likeCount
        self.comments = comments
        self.isBookmarked = isBookmarked
        self.trainer = trainer
        self.createdAt = createdAt
        self.userId = userId
    }
    
    // MARK: - Firestore Conversion
    
    func toFirestore() -> [String: Any] {
        return [
            "id": id,
            "title": title,
            "videoURL": videoURL.absoluteString,
            "thumbnailURL": thumbnailURL?.absoluteString as Any,
            "duration": duration,
            "workout": workout.toFirestore(),
            "likes": likeCount,
            "comments": comments,
            "isBookmarked": isBookmarked,
            "trainer": trainer,
            "createdAt": Timestamp(date: createdAt),
            "userId": userId
        ]
    }
    
    static func fromFirestore(_ document: DocumentSnapshot) -> VideoModel? {
        guard let data = document.data() else { return nil }
        
        guard let title = data["title"] as? String,
              let videoURLString = data["videoURL"] as? String,
              let videoURL = URL(string: videoURLString),
              let duration = data["duration"] as? TimeInterval,
              let workoutData = data["workout"] as? [String: Any],
              let workout = WorkoutMetadata.fromFirestore(workoutData),
              let comments = data["comments"] as? Int,
              let isBookmarked = data["isBookmarked"] as? Bool,
              let trainer = data["trainer"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            print("❌ Failed to parse video document: \(document.documentID)")
            print("   Data: \(data)")
            return nil
        }
        
        // Get userId with fallback to empty string
        let userId = data["userId"] as? String ?? ""
        
        // Handle both 'likes' and 'likeCount' fields for backward compatibility
        let likeCount: Int
        if let likes = data["likes"] as? Int {
            likeCount = likes
        } else if let likes = data["likeCount"] as? Int {
            likeCount = likes
        } else {
            likeCount = 0
        }
        
        let thumbnailURLString = data["thumbnailURL"] as? String
        let thumbnailURL = thumbnailURLString.flatMap { URL(string: $0) }
        
        print("✅ Parsed video: \(title) with type: \(workout.type.rawValue)")
        
        return VideoModel(
            id: document.documentID,
            title: title,
            videoURL: videoURL,
            thumbnailURL: thumbnailURL,
            duration: duration,
            workout: workout,
            likeCount: likeCount,
            comments: comments,
            isBookmarked: isBookmarked,
            trainer: trainer,
            createdAt: createdAt,
            userId: userId
        )
    }
    
    // Mock data using Firebase Storage videos
    static let mockVideos = [
        VideoModel(
            id: "video_yoga1",
            title: "Morning Yoga Flow",
            videoURL: URL(string: "https://firebasestorage.googleapis.com/v0/b/swift-reels-97d1e.firebasestorage.app/o/videos%2Fvideo_yoga1.mp4?alt=media&token=9dd1b746-fcda-4114-a386-e64ad77707d4")!,
            thumbnailURL: nil,
            duration: 348,
            workout: WorkoutMetadata(
                type: .yoga,
                level: .beginner,
                equipment: [.yogaMat],
                durationSeconds: 348,
                estimatedCalories: 100
            ),
            likeCount: 0,
            comments: 0,
            isBookmarked: false,
            trainer: "Sarah Peace"
        ),
        VideoModel(
            id: "video_yoga2",
            title: "Sunset Beach Yoga",
            videoURL: URL(string: "https://firebasestorage.googleapis.com/v0/b/swift-reels-97d1e.firebasestorage.app/o/videos%2Fvideo_yoga2.mp4?alt=media&token=4a368372-962a-4521-9852-10afd82e6def")!,
            thumbnailURL: nil,
            duration: 420,
            workout: WorkoutMetadata(
                type: .yoga,
                level: .intermediate,
                equipment: [.yogaMat],
                durationSeconds: 420,
                estimatedCalories: 150
            ),
            likeCount: 0,
            comments: 0,
            isBookmarked: false,
            trainer: "Emma Flow"
        ),
        VideoModel(
            id: "video_yoga3",
            title: "Power Yoga Session",
            videoURL: URL(string: "https://firebasestorage.googleapis.com/v0/b/swift-reels-97d1e.firebasestorage.app/o/videos%2Fvideo_yoga3.mp4?alt=media&token=e0b0c186-5b8e-4eef-9f79-533dfff7f675")!,
            thumbnailURL: nil,
            duration: 360,
            workout: WorkoutMetadata(
                type: .yoga,
                level: .advanced,
                equipment: [.yogaMat],
                durationSeconds: 360,
                estimatedCalories: 200
            ),
            likeCount: 0,
            comments: 0,
            isBookmarked: false,
            trainer: "Mike Zen"
        ),
        VideoModel(
            id: "video_hiit2",
            title: "Advanced HIIT Circuit",
            videoURL: URL(string: "https://firebasestorage.googleapis.com/v0/b/swift-reels-97d1e.firebasestorage.app/o/videos%2Fvideo_hiit2.mp4?alt=media&token=0f52712f-8337-4d27-a748-0311d8f852a9")!,
            thumbnailURL: nil,
            duration: 348,
            workout: WorkoutMetadata(
                type: .hiit,
                level: .advanced,
                equipment: [],
                durationSeconds: 348,
                estimatedCalories: 250
            ),
            likeCount: 0,
            comments: 0,
            isBookmarked: false,
            trainer: "Chris Burn"
        ),
        VideoModel(
            id: "video_stretch1",
            title: "Full Body Stretch",
            videoURL: URL(string: "https://firebasestorage.googleapis.com/v0/b/swift-reels-97d1e.firebasestorage.app/o/videos%2Fvideo_stretch1.mp4?alt=media&token=63f01942-1de5-4b4e-9a0e-9f01823b4a28")!,
            thumbnailURL: nil,
            duration: 348,
            workout: WorkoutMetadata(
                type: .stretching,
                level: .beginner,
                equipment: [.yogaMat],
                durationSeconds: 348,
                estimatedCalories: 80
            ),
            likeCount: 0,
            comments: 0,
            isBookmarked: false,
            trainer: "Lisa Flex"
        )
    ]
}

struct SubtitleSegment: Codable, Identifiable {
    var id: String { "\(startTime)-\(endTime)" }
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

struct VideoSubtitles: Codable, Identifiable {
    let id: String  // Same as video ID
    let segments: [SubtitleSegment]
    let isComplete: Bool
    let lastUpdated: Date
    
    static func empty(for videoId: String) -> VideoSubtitles {
        VideoSubtitles(
            id: videoId,
            segments: [],
            isComplete: false,
            lastUpdated: Date()
        )
    }
} 