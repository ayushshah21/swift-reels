import Foundation

// Import WorkoutTypes to use its WorkoutDifficulty enum
import FirebaseFirestore

struct VideoModel: Identifiable, Equatable {
    let id: String
    let title: String
    let videoURL: URL
    let thumbnailURL: URL?
    let duration: TimeInterval
    let workout: WorkoutMetadata
    let likes: Int
    let comments: Int
    var isBookmarked: Bool
    let trainer: String
    let createdAt: Date
    
    static func == (lhs: VideoModel, rhs: VideoModel) -> Bool {
        lhs.id == rhs.id
    }
    
    init(id: String, title: String, videoURL: URL, thumbnailURL: URL?, duration: TimeInterval, workout: WorkoutMetadata, likes: Int, comments: Int, isBookmarked: Bool, trainer: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.workout = workout
        self.likes = likes
        self.comments = comments
        self.isBookmarked = isBookmarked
        self.trainer = trainer
        self.createdAt = createdAt
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
            "likes": likes,
            "comments": comments,
            "isBookmarked": isBookmarked,
            "trainer": trainer,
            "createdAt": Timestamp(date: createdAt)
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
              let likes = data["likes"] as? Int,
              let comments = data["comments"] as? Int,
              let isBookmarked = data["isBookmarked"] as? Bool,
              let trainer = data["trainer"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        let thumbnailURLString = data["thumbnailURL"] as? String
        let thumbnailURL = thumbnailURLString.flatMap { URL(string: $0) }
        
        return VideoModel(
            id: document.documentID,
            title: title,
            videoURL: videoURL,
            thumbnailURL: thumbnailURL,
            duration: duration,
            workout: workout,
            likes: likes,
            comments: comments,
            isBookmarked: isBookmarked,
            trainer: trainer,
            createdAt: createdAt
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
            likes: 0,
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
            likes: 0,
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
            likes: 0,
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
            likes: 0,
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
            likes: 0,
            comments: 0,
            isBookmarked: false,
            trainer: "Lisa Flex"
        )
    ]
} 