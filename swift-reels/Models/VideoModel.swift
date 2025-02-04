import Foundation

struct VideoModel: Identifiable {
    let id: String
    let title: String
    let videoURL: URL
    let thumbnailURL: URL?
    let duration: TimeInterval
    let difficulty: WorkoutDifficulty
    let category: WorkoutCategory
    let likes: Int
    let comments: Int
    var isBookmarked: Bool
    let trainer: String
    
    // Mock data using Pixabay videos
    static let mockVideos = [
        VideoModel(
            id: "1",
            title: "Intense Boxing Workout",
            videoURL: URL(string: "https://cdn.pixabay.com/video/2023/11/02/187612-880737125_large.mp4")!,
            thumbnailURL: URL(string: "https://cdn.pixabay.com/vimeo/880737125/boxing-187612.jpg?width=1280&hash=e2e0f6c5c4c5c5c5")!,
            duration: 60,
            difficulty: .advanced,
            category: .hiit,
            likes: 12500,
            comments: 245,
            isBookmarked: false,
            trainer: "Mike Tyson"
        ),
        VideoModel(
            id: "2",
            title: "Yoga Flow & Stretch",
            videoURL: URL(string: "https://cdn.pixabay.com/video/2015/08/13/445-136216234_medium.mp4")!,
            thumbnailURL: URL(string: "https://cdn.pixabay.com/vimeo/136216234/yoga-445.jpg?width=1280&hash=a1b2c3d4e5f6g7h8")!,
            duration: 45,
            difficulty: .beginner,
            category: .yoga,
            likes: 8900,
            comments: 132,
            isBookmarked: false,
            trainer: "Sarah Peace"
        ),
        VideoModel(
            id: "3",
            title: "Power Cardio Session",
            videoURL: URL(string: "https://cdn.pixabay.com/video/2019/04/20/22913-336128301_large.mp4")!,
            thumbnailURL: URL(string: "https://cdn.pixabay.com/vimeo/336128301/cardio-22913.jpg?width=1280&hash=9z8y7x6w5v4u3t2s")!,
            duration: 30,
            difficulty: .intermediate,
            category: .cardio,
            likes: 15200,
            comments: 328,
            isBookmarked: false,
            trainer: "John Swift"
        )
    ]
}

enum WorkoutDifficulty: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

enum WorkoutCategory: String, CaseIterable {
    case all = "All"
    case hiit = "HIIT"
    case yoga = "Yoga"
    case strength = "Strength"
    case cardio = "Cardio"
    case pilates = "Pilates"
} 