import Foundation
import FirebaseFirestore
import FirebaseAuth
import AVFoundation

// Array extension for chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

@MainActor
class FirestoreManager: ObservableObject {
    static let shared = FirestoreManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - User Operations
    
    func createUser(_ user: User) async throws {
        try await db.collection("users").document(user.id).setData(user.toFirestore())
        print("✅ User document created for: \(user.email)")
    }
    
    func getUser(id: String) async throws -> User? {
        let document = try await db.collection("users").document(id).getDocument()
        return User.fromFirestore(document)
    }
    
    func updateUser(_ user: User) async throws {
        try await db.collection("users").document(user.id).setData(user.toFirestore(), merge: true)
        print("✅ User document updated for: \(user.email)")
    }
    
    // MARK: - Video Operations
    
    /// Fetches paginated videos with optional workout type filter
    func getVideos(workoutType: WorkoutType? = nil, limit: Int = 5) async throws -> [VideoModel] {
        var query = db.collection("videos")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        if let workoutType = workoutType, workoutType != .all {
            query = query.whereField("workout.type", isEqualTo: workoutType.rawValue)
        }
        
        let snapshot = try await query.getDocuments()
        let videos = snapshot.documents.compactMap { VideoModel.fromFirestore($0) }
        print("📱 Fetched \(videos.count) videos for type: \(workoutType?.rawValue ?? "all")")
        return videos
    }
    
    /// Fetches next page of videos after the last video
    func getMoreVideos(after lastVideo: VideoModel, workoutType: WorkoutType? = nil, limit: Int = 5) async throws -> [VideoModel] {
        var query = db.collection("videos")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .start(after: [Timestamp(date: lastVideo.createdAt)])
        
        if let workoutType = workoutType, workoutType != .all {
            query = query.whereField("workout.type", isEqualTo: workoutType.rawValue)
        }
        
        let snapshot = try await query.getDocuments()
        let videos = snapshot.documents.compactMap { VideoModel.fromFirestore($0) }
        print("📱 Fetched \(videos.count) more videos for type: \(workoutType?.rawValue ?? "all")")
        return videos
    }
    
    /// Uploads a video document to Firestore
    func createVideo(_ video: VideoModel) async throws {
        try await db.collection("videos").document(video.id).setData(video.toFirestore())
    }
    
    /// Fetches a single video by ID
    func getVideo(id: String) async throws -> VideoModel? {
        let doc = try await db.collection("videos").document(id).getDocument()
        return VideoModel.fromFirestore(doc)
    }
    
    /// Adds a like to a video
    func likeVideo(videoId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let likeRef = db.collection("videos").document(videoId)
            .collection("likes").document(userId)
        
        try await db.runTransaction { [weak self] transaction, errorPointer in
            guard let self = self else { return nil }
            // Get the video document
            let videoDoc = try? transaction.getDocument(self.db.collection("videos").document(videoId))
            guard let videoDoc = videoDoc,
                  let data = videoDoc.data() else { return nil }
            
            // Check if user already liked
            let likeDoc = try? transaction.getDocument(likeRef)
            let alreadyLiked = likeDoc?.exists ?? false
            
            if alreadyLiked {
                return nil
            }
            
            // Get current like count
            let currentLikeCount = data["likes"] as? Int ?? 0
            
            // Update video document with new like count
            transaction.updateData(["likes": currentLikeCount + 1], forDocument: videoDoc.reference)
            
            // Create like document
            transaction.setData([
                "userId": userId,
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: likeRef)
            
            return nil
        }
    }
    
    /// Removes a like from a video
    func unlikeVideo(videoId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let likeRef = db.collection("videos").document(videoId)
            .collection("likes").document(userId)
        
        try await db.runTransaction { [weak self] transaction, errorPointer in
            guard let self = self else { return nil }
            // Get the video document
            let videoDoc = try? transaction.getDocument(self.db.collection("videos").document(videoId))
            guard let videoDoc = videoDoc,
                  let data = videoDoc.data() else { return nil }
            
            // Check if user already liked
            let likeDoc = try? transaction.getDocument(likeRef)
            let alreadyLiked = likeDoc?.exists ?? false
            
            if !alreadyLiked {
                return nil
            }
            
            // Get current like count
            let currentLikeCount = data["likes"] as? Int ?? 0
            
            // Update video document with new like count
            transaction.updateData(["likes": max(0, currentLikeCount - 1)], forDocument: videoDoc.reference)
            
            // Delete like document
            transaction.deleteDocument(likeRef)
            
            return nil
        }
    }
    
    /// Checks if a user has liked a video
    func hasUserLikedVideo(videoId: String) async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        let likeDoc = try await db.collection("videos").document(videoId)
            .collection("likes").document(userId)
            .getDocument()
        
        return likeDoc.exists
    }
    
    // MARK: - Storage Sync
    
    /// Syncs videos from Firebase Storage to Firestore
    func syncVideosFromStorage() async throws {
        print("🔄 Starting video sync from Storage...")
        
        // Get videos from Storage
        let storageVideos = try await StorageManager.shared.listVideos()
        
        // Get existing videos from Firestore
        let existingSnapshot = try await db.collection("videos").getDocuments()
        let existingURLs = Set(existingSnapshot.documents.compactMap { doc -> String? in
            guard let data = doc.data() as? [String: Any],
                  let urlString = data["videoURL"] as? String else { return nil }
            return urlString
        })
        
        // Add new videos to Firestore
        for (url, metadata) in storageVideos {
            let urlString = url.absoluteString
            
            // Skip if video already exists in Firestore
            guard !existingURLs.contains(urlString) else {
                print("⏭️ Video already exists in Firestore: \(url.lastPathComponent)")
                continue
            }
            
            // Create video document
            let videoId = url.lastPathComponent.replacingOccurrences(of: ".mp4", with: "")
            let title = metadata["title"] ?? videoId.replacingOccurrences(of: "video_", with: "").capitalized
            let workoutType = WorkoutType(rawValue: metadata["workoutType"] ?? "yoga") ?? .yoga
            let level = WorkoutLevel(rawValue: metadata["level"] ?? "beginner") ?? .beginner
            let duration = TimeInterval(metadata["duration"] ?? "300") ?? 300
            let trainer = metadata["trainer"] ?? "Fitness Coach"
            
            let video = VideoModel(
                id: videoId,
                title: title,
                videoURL: url,
                thumbnailURL: nil,
                duration: duration,
                workout: WorkoutMetadata(
                    type: workoutType,
                    level: level,
                    equipment: [],
                    durationSeconds: Int(duration),
                    estimatedCalories: 150
                ),
                likeCount: 0,
                comments: 0,
                isBookmarked: false,
                trainer: trainer
            )
            
            try await createVideo(video)
            print("✅ Added video to Firestore: \(title)")
        }
        
        print("✅ Video sync complete!")
    }
    
    // MARK: - Helper Methods
    
    /// Deletes a video document and all its subcollections
    private func deleteVideoWithSubcollections(_ document: DocumentSnapshot) async throws {
        // First delete all likes
        let likesSnapshot = try await document.reference.collection("likes").getDocuments()
        for likeDoc in likesSnapshot.documents {
            try await likeDoc.reference.delete()
        }
        
        // Then delete all comments
        let commentsSnapshot = try await document.reference.collection("comments").getDocuments()
        for commentDoc in commentsSnapshot.documents {
            try await commentDoc.reference.delete()
        }
        
        // Finally delete the video document itself
        try await document.reference.delete()
        print("🗑️ Deleted video and subcollections: \(document.documentID)")
    }

    /// Formats a filename into a nice title
    private func formatTitle(from filename: String) -> String {
        // Remove test prefix if present
        let cleanName = filename.replacingOccurrences(of: "test_", with: "", options: .caseInsensitive)
        
        // Split into words and capitalize each word
        let words = cleanName.components(separatedBy: CharacterSet(charactersIn: "_- "))
            .map { word -> String in
                // If word is all uppercase, treat it as an acronym
                if word.uppercased() == word {
                    return word
                }
                // Otherwise capitalize first letter
                return word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
        
        return words.joined(separator: " ")
    }

    /// Performs a complete cleanup and metadata refresh
    func cleanupAndReuploadVideos() async throws {
        print("🧹 Starting complete video cleanup and refresh...")
        
        // First clean up storage
        try await StorageManager.shared.cleanupStorage()
        
        // Delete all videos and their subcollections from Firestore
        let snapshot = try await db.collection("videos").getDocuments()
        for document in snapshot.documents {
            try await deleteVideoWithSubcollections(document)
        }
        
        // Reupload with proper metadata
        try await reuploadVideosWithMetadata()
        
        print("✨ Complete video cleanup and refresh finished!")
    }
    
    /// Gets the base name of a video file for metadata matching
    private func getBaseVideoName(_ filename: String) -> String {
        return filename
            .replacingOccurrences(of: "video_", with: "")
            .replacingOccurrences(of: "test_", with: "")
            .replacingOccurrences(of: ".mp4", with: "")
            .lowercased() // Normalize for matching
    }
    
    /// Gets the proper document ID for a video
    private func getVideoDocumentId(_ filename: String) -> String {
        let baseName = filename
            .replacingOccurrences(of: "video_", with: "")
            .replacingOccurrences(of: ".mp4", with: "")
        return "video_\(baseName)"
    }

    /// Reuploads all videos with proper metadata
    func reuploadVideosWithMetadata() async throws {
        print("🔄 Starting video metadata update...")
        
        // Get all videos from Storage
        let storageVideos = try await StorageManager.shared.listVideos()
        
        // Create a mapping of base filenames to their proper metadata
        let properMetadata: [String: VideoModel] = Dictionary(uniqueKeysWithValues: VideoModel.mockVideos.map { video in
            let baseName = getBaseVideoName(video.videoURL.lastPathComponent)
            return (baseName, video)
        })
        
        // Update each video in Firestore
        for (url, metadata) in storageVideos {
            let filename = url.lastPathComponent
            let baseName = getBaseVideoName(filename)
            let documentId = getVideoDocumentId(filename)
            
            // If we have proper metadata for this video
            if let properVideo = properMetadata[baseName] {
                // Create a new video model with the fresh URL
                let updatedVideo = VideoModel(
                    id: documentId,
                    title: properVideo.title,
                    videoURL: url, // Use the fresh URL from Storage
                    thumbnailURL: nil,
                    duration: properVideo.duration,
                    workout: properVideo.workout,
                    likeCount: 0,
                    comments: 0,
                    isBookmarked: false,
                    trainer: properVideo.trainer
                )
                
                // Update the video document with fresh metadata
                try await db.collection("videos").document(updatedVideo.id).setData(updatedVideo.toFirestore())
                print("✅ Updated metadata for: \(updatedVideo.title)")
            } else {
                // For videos without proper metadata, create a basic entry
                let title = formatTitle(from: baseName)
                
                let type: WorkoutType
                if baseName.contains("hiit") { type = .hiit }
                else if baseName.contains("strength") { type = .strength }
                else if baseName.contains("yoga") { type = .yoga }
                else if baseName.contains("stretch") { type = .stretching }
                else { type = .other }
                
                let video = VideoModel(
                    id: documentId,
                    title: title,
                    videoURL: url,
                    thumbnailURL: nil,
                    duration: TimeInterval(metadata["duration"] ?? "300") ?? 300,
                    workout: WorkoutMetadata(
                        type: type,
                        level: .intermediate,
                        equipment: [],
                        durationSeconds: Int(metadata["duration"] ?? "300") ?? 300,
                        estimatedCalories: 150
                    ),
                    likeCount: 0,
                    comments: 0,
                    isBookmarked: false,
                    trainer: metadata["trainer"] ?? "Fitness Coach"
                )
                
                try await db.collection("videos").document(video.id).setData(video.toFirestore())
                print("✅ Created basic metadata for: \(title)")
            }
        }
        
        print("✨ Video metadata update complete!")
    }
    
    // MARK: - Real-time Listeners
    
    func addVideoListener(videoId: String, completion: @escaping (VideoModel?) -> Void) -> ListenerRegistration {
        return db.collection("videos").document(videoId).addSnapshotListener { snapshot, error in
            guard let document = snapshot else {
                print("❌ Error fetching video: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            completion(VideoModel.fromFirestore(document))
        }
    }
    
    func addUserListener(userId: String, completion: @escaping (User?) -> Void) -> ListenerRegistration {
        return db.collection("users").document(userId).addSnapshotListener { snapshot, error in
            guard let document = snapshot else {
                print("❌ Error fetching user: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            completion(User.fromFirestore(document))
        }
    }
    
    func addFeedListener(limit: Int = 10, completion: @escaping ([VideoModel]) -> Void) -> ListenerRegistration {
        return db.collection("videos")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("❌ Error fetching feed: \(error?.localizedDescription ?? "Unknown error")")
                    completion([])
                    return
                }
                let videos = documents.compactMap { VideoModel.fromFirestore($0) }
                completion(videos)
            }
    }
    
    // MARK: - Comment Operations
    
    /// Adds a comment to a video
    func addComment(to videoId: String, text: String) async throws {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Get user's username, fallback to email if not found
        let username: String
        if let user = try? await getUser(id: currentUser.uid) {
            username = user.username
        } else {
            username = currentUser.email ?? "Anonymous User"
        }
        
        let commentRef = db.collection("videos").document(videoId)
            .collection("comments").document()
        
        try await db.runTransaction { [weak self] transaction, errorPointer in
            guard let self = self else { return nil }
            
            // Get the video document
            let videoDoc = try? transaction.getDocument(self.db.collection("videos").document(videoId))
            guard let videoDoc = videoDoc,
                  let data = videoDoc.data() else { return nil }
            
            // Get current comment count
            let currentCommentCount = data["comments"] as? Int ?? 0
            
            // Create comment document
            let comment = Comment(
                id: commentRef.documentID,
                videoId: videoId,
                userId: currentUser.uid,
                text: text,
                username: username,
                createdAt: Date()
            )
            
            // Update video document with new comment count
            transaction.updateData(["comments": currentCommentCount + 1], forDocument: videoDoc.reference)
            
            // Add the comment
            transaction.setData(comment.toFirestore(), forDocument: commentRef)
            
            return nil
        }
        
        print("✅ Added comment to video: \(videoId)")
    }
    
    /// Deletes a comment from a video
    func deleteComment(_ commentId: String, from videoId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let commentRef = db.collection("videos").document(videoId)
            .collection("comments").document(commentId)
        
        // Verify comment belongs to user
        let comment = try await commentRef.getDocument()
        guard let commentData = comment.data(),
              let commentUserId = commentData["userId"] as? String,
              commentUserId == userId else {
            throw NSError(domain: "FirestoreManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not authorized to delete this comment"])
        }
        
        try await db.runTransaction { [weak self] transaction, errorPointer in
            guard let self = self else { return nil }
            
            // Get the video document
            let videoDoc = try? transaction.getDocument(self.db.collection("videos").document(videoId))
            guard let videoDoc = videoDoc,
                  let data = videoDoc.data() else { return nil }
            
            // Get current comment count
            let currentCommentCount = data["comments"] as? Int ?? 0
            
            // Update video document with new comment count
            transaction.updateData(["comments": max(0, currentCommentCount - 1)], forDocument: videoDoc.reference)
            
            // Delete the comment
            transaction.deleteDocument(commentRef)
            
            return nil
        }
        
        print("✅ Deleted comment from video: \(videoId)")
    }
    
    /// Fetches comments for a video
    func getComments(for videoId: String, limit: Int = 20) async throws -> [Comment] {
        let snapshot = try await db.collection("videos").document(videoId)
            .collection("comments")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { Comment.fromFirestore($0) }
    }
    
    /// Adds a real-time listener for comments on a video
    func addCommentsListener(videoId: String, completion: @escaping ([Comment]) -> Void) -> ListenerRegistration {
        return db.collection("videos").document(videoId)
            .collection("comments")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("❌ Error fetching comments: \(error?.localizedDescription ?? "Unknown error")")
                    completion([])
                    return
                }
                let comments = documents.compactMap { Comment.fromFirestore($0) }
                completion(comments)
            }
    }
    
    /// Resets comment count for a video
    func resetCommentCount(for videoId: String) async throws {
        let commentsSnapshot = try await db.collection("videos").document(videoId)
            .collection("comments")
            .getDocuments()
        
        let actualCount = commentsSnapshot.documents.count
        
        try await db.collection("videos").document(videoId)
            .updateData(["comments": actualCount])
        
        print("✅ Reset comment count for video \(videoId) to \(actualCount)")
    }
    
    /// Resets comment counts for all videos
    func resetAllCommentCounts() async throws {
        print("🔄 Starting comment count reset for all videos...")
        
        // Get all videos
        let videosSnapshot = try await db.collection("videos").getDocuments()
        
        // Reset count for each video
        for document in videosSnapshot.documents {
            try await resetCommentCount(for: document.documentID)
        }
        
        print("✅ Finished resetting all comment counts")
    }
    
    // MARK: - Video Saving Operations
    
    /// Saves a video for a user
    func saveVideo(videoId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Get video details first
        guard let video = try await getVideo(id: videoId) else {
            print("❌ Video not found: \(videoId)")
            return
        }
        
        // Generate and upload thumbnail if not already exists
        if video.thumbnailURL == nil {
            do {
                let thumbnailURL = try await generateAndUploadThumbnail(for: video)
                // Update video document with thumbnail URL
                try await db.collection("videos").document(videoId).updateData([
                    "thumbnailURL": thumbnailURL.absoluteString
                ])
                print("✅ Added thumbnail for video: \(videoId)")
            } catch {
                print("⚠️ Failed to generate thumbnail: \(error.localizedDescription)")
                // Continue saving even if thumbnail generation fails
            }
        }
        
        let userRef = db.collection("users").document(userId)
        
        try await db.runTransaction { [weak self] transaction, errorPointer in
            guard let self = self else { return nil }
            
            // Get current user data
            let userDoc = try? transaction.getDocument(userRef)
            guard let userData = userDoc?.data() else { return nil }
            
            // Get current saved videos
            var savedVideos = userData["savedVideos"] as? [String] ?? []
            
            // Add video if not already saved
            if !savedVideos.contains(videoId) {
                savedVideos.append(videoId)
                transaction.updateData(["savedVideos": savedVideos], forDocument: userRef)
            }
            
            return nil
        }
        
        print("✅ Saved video: \(videoId)")
    }
    
    /// Generates and uploads a thumbnail for a video
    private func generateAndUploadThumbnail(for video: VideoModel) async throws -> URL {
        print("🖼️ Generating thumbnail for video: \(video.id)")
        
        // Create AVAsset
        let asset = AVURLAsset(url: video.videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        // Get thumbnail at 1 second or video duration midpoint
        let duration = try await asset.load(.duration)
        let time = CMTime(seconds: min(1.0, duration.seconds / 2), preferredTimescale: 600)
        
        do {
            let cgImage = try await generator.image(at: time).image
            let uiImage = UIImage(cgImage: cgImage)
            
            // Convert to data with medium quality JPEG
            guard let imageData = uiImage.jpegData(compressionQuality: 0.7) else {
                throw NSError(domain: "FirestoreManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert thumbnail to JPEG"])
            }
            
            // Upload to Firebase Storage
            let filename = "thumbnails/\(video.id).jpg"
            return try await StorageManager.shared.uploadThumbnail(data: imageData, filename: filename)
        } catch {
            print("❌ Error generating thumbnail: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Regenerates thumbnails for all videos that don't have one
    func regenerateMissingThumbnails() async throws {
        print("🔄 Starting thumbnail regeneration...")
        
        let snapshot = try await db.collection("videos").getDocuments()
        var updatedCount = 0
        
        for document in snapshot.documents {
            guard let video = VideoModel.fromFirestore(document) else { continue }
            
            if video.thumbnailURL == nil {
                do {
                    let thumbnailURL = try await generateAndUploadThumbnail(for: video)
                    try await db.collection("videos").document(video.id).updateData([
                        "thumbnailURL": thumbnailURL.absoluteString
                    ])
                    updatedCount += 1
                    print("✅ Generated thumbnail for: \(video.title)")
                } catch {
                    print("❌ Failed to generate thumbnail for \(video.id): \(error.localizedDescription)")
                }
            }
        }
        
        print("✨ Thumbnail regeneration complete. Updated \(updatedCount) videos.")
    }
    
    /// Unsaves a video for a user
    func unsaveVideo(videoId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let userRef = db.collection("users").document(userId)
        
        try await db.runTransaction { [weak self] transaction, errorPointer in
            guard let self = self else { return nil }
            
            // Get current user data
            let userDoc = try? transaction.getDocument(userRef)
            guard let userData = userDoc?.data() else { return nil }
            
            // Get current saved videos
            var savedVideos = userData["savedVideos"] as? [String] ?? []
            
            // Remove video if saved
            if let index = savedVideos.firstIndex(of: videoId) {
                savedVideos.remove(at: index)
                transaction.updateData(["savedVideos": savedVideos], forDocument: userRef)
            }
            
            return nil
        }
        
        print("✅ Unsaved video: \(videoId)")
    }
    
    /// Checks if a video is saved by the user
    func isVideoSaved(_ videoId: String) async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userData = userDoc.data() else { return false }
        
        let savedVideos = userData["savedVideos"] as? [String] ?? []
        return savedVideos.contains(videoId)
    }
    
    /// Gets all saved videos for a user
    func getSavedVideos() async throws -> [VideoModel] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }
        
        // Get user's saved video IDs
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userData = userDoc.data(),
              let savedVideoIds = userData["savedVideos"] as? [String] else {
            return []
        }
        
        // If no saved videos, return empty array
        if savedVideoIds.isEmpty {
            return []
        }
        
        // Get all saved videos
        let chunkedIds = savedVideoIds.chunked(into: 10) // Process in chunks to avoid large queries
        var savedVideos: [VideoModel] = []
        
        for chunk in chunkedIds {
            let snapshot = try await db.collection("videos")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            
            let videos = snapshot.documents.compactMap { VideoModel.fromFirestore($0) }
            savedVideos.append(contentsOf: videos)
        }
        
        return savedVideos
    }
    
    /// Increments a user's post count
    func incrementUserPostCount(userId: String) async throws {
        let userRef = db.collection("users").document(userId)
        try await userRef.updateData([
            "postsCount": FieldValue.increment(Int64(1))
        ])
        print("✅ Incremented post count for user: \(userId)")
    }
    
    /// Deletes a video and its associated storage file
    func deleteVideo(_ videoId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirestoreManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // First get the video to verify ownership and get the URL
        guard let video = try await getVideo(id: videoId) else {
            throw NSError(domain: "FirestoreManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Video not found"])
        }
        
        // Verify the user owns this video by checking against the trainer field
        // In a production app, you'd want a proper owner field, but we're using trainer for now
        guard let currentUser = try await getUser(id: userId),
              currentUser.username == video.trainer else {
            throw NSError(domain: "FirestoreManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Not authorized to delete this video"])
        }
        
        // Delete from Storage first
        try await StorageManager.shared.deleteVideo(url: video.videoURL)
        
        // If there's a thumbnail, delete that too
        if let thumbnailURL = video.thumbnailURL {
            try await StorageManager.shared.deleteThumbnail(url: thumbnailURL)
        }
        
        // Delete the Firestore document and all subcollections
        let document = try await db.collection("videos").document(videoId).getDocument()
        try await deleteVideoWithSubcollections(document)
        
        // Decrement user's post count
        try await db.collection("users").document(userId).updateData([
            "postsCount": FieldValue.increment(Int64(-1))
        ])
        
        print("✅ Successfully deleted video: \(videoId)")
    }
    
    // MARK: - Video Search Operations
    
    /// Searches for videos based on title, trainer name, and workout type
    func searchVideos(query searchText: String, workoutType: WorkoutType? = nil) async throws -> [VideoModel] {
        print("🔍 Searching videos with query: '\(searchText)', workoutType: \(String(describing: workoutType))")
        
        // Create base query
        var firestoreQuery = db.collection("videos").order(by: "createdAt", descending: true)
        
        // Apply workout type filter if specified
        if let workoutType = workoutType, workoutType != .all {
            firestoreQuery = firestoreQuery.whereField("workout.type", isEqualTo: workoutType.rawValue)
        }
        
        // Get all videos that match the workout type (or all videos if no type specified)
        let snapshot = try await firestoreQuery.getDocuments()
        let allVideos = snapshot.documents.compactMap { VideoModel.fromFirestore($0) }
        
        // If search text is empty, return all videos
        guard !searchText.isEmpty else {
            return allVideos
        }
        
        // Split the search text into terms and convert to lowercase for case-insensitive matching
        let searchTerms = searchText.lowercased().split(separator: " ").map(String.init)
        
        // Filter videos based on search terms
        let filteredVideos = allVideos.filter { video in
            let titleLower = video.title.lowercased()
            let trainerLower = video.trainer.lowercased()
            
            // Check if any search term is a prefix of any word in the title or trainer name
            return searchTerms.allSatisfy { term in
                titleLower.contains(term) || 
                trainerLower.contains(term) ||
                titleLower.split(separator: " ").contains { $0.hasPrefix(term) } ||
                trainerLower.split(separator: " ").contains { $0.hasPrefix(term) }
            }
        }
        
        print("🎯 Found \(filteredVideos.count) matching videos")
        return filteredVideos
    }
    
    // MARK: - Live Session Operations
    
    /// Creates a new live session
    func createLiveSession(hostId: String, hostName: String, channelId: String) async throws -> LiveSession {
        print("🎥 Creating live session for host: \(hostName)")
        
        let session = LiveSession(
            hostId: hostId,
            hostName: hostName,
            channelId: channelId,
            isActive: true,
            createdAt: Date(),
            viewerCount: 0,
            viewers: []
        )
        
        let docRef = try await db.collection("liveSessions").addDocument(data: session.toFirestore())
        var createdSession = session
        createdSession.id = docRef.documentID
        print("✅ Created live session: \(docRef.documentID)")
        return createdSession
    }
    
    /// Ends a live session
    func endLiveSession(_ sessionId: String) async throws {
        print("🎥 Ending live session: \(sessionId)")
        try await db.collection("liveSessions").document(sessionId).updateData([
            "isActive": false
        ])
        print("✅ Ended live session: \(sessionId)")
    }
    
    /// Gets all active live sessions
    func getActiveLiveSessions() async throws -> [LiveSession] {
        print("🔍 Fetching active live sessions...")
        let snapshot = try await db.collection("liveSessions")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        
        print("📄 Raw documents found: \(snapshot.documents.count)")
        for doc in snapshot.documents {
            print("   Document ID: \(doc.documentID)")
            print("   Data: \(doc.data())")
        }
        
        let sessions = snapshot.documents.compactMap { LiveSession.fromFirestore($0) }
        print("✅ Found \(sessions.count) active sessions")
        return sessions
    }
    
    /// Provides real-time updates for a live session
    func liveSessionUpdates(sessionId: String) -> AsyncStream<LiveSession> {
        AsyncStream { continuation in
            let listener = db.collection("liveSessions").document(sessionId)
                .addSnapshotListener { documentSnapshot, error in
                    guard let document = documentSnapshot else {
                        print("❌ Error fetching live session updates: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    
                    if let session = LiveSession.fromFirestore(document) {
                        continuation.yield(session)
                    }
                }
            
            // Store listener reference to prevent it from being deallocated
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    // MARK: - Partner Session Operations
    
    /// Creates a new partner workout session
    func createPartnerSession(hostId: String, workoutType: WorkoutType, durationMinutes: Int) async throws -> PartnerSession {
        print("🤝 Creating partner session for host: \(hostId)")
        
        let channelId = "partner_\(UUID().uuidString)"
        let session = PartnerSession(
            id: nil,
            hostId: hostId,
            partnerId: nil,
            channelId: channelId,
            isActive: true,
            createdAt: Date(),
            status: .waiting,
            workoutType: workoutType,
            durationMinutes: durationMinutes
        )
        
        let docRef = try await db.collection("partnerSessions").addDocument(data: session.toFirestore())
        var createdSession = session
        createdSession.id = docRef.documentID
        print("✅ Created partner session: \(docRef.documentID)")
        return createdSession
    }
    
    /// Joins an existing partner session
    func joinPartnerSession(_ sessionId: String, partnerId: String) async throws {
        print("🤝 Joining partner session: \(sessionId)")
        
        try await db.collection("partnerSessions").document(sessionId).updateData([
            "partnerId": partnerId,
            "status": PartnerSession.SessionStatus.inProgress.rawValue
        ])
        print("✅ Joined partner session: \(sessionId)")
    }
    
    /// Ends a partner session
    func endPartnerSession(_ sessionId: String) async throws {
        print("👋 Ending partner session: \(sessionId)")
        
        try await db.collection("partnerSessions").document(sessionId).updateData([
            "isActive": false,
            "status": PartnerSession.SessionStatus.ended.rawValue
        ])
        print("✅ Ended partner session: \(sessionId)")
    }
    
    /// Gets all available partner sessions
    func getAvailablePartnerSessions() async throws -> [PartnerSession] {
        print("🔍 Fetching available partner sessions...")
        
        let snapshot = try await db.collection("partnerSessions")
            .whereField("isActive", isEqualTo: true)
            .whereField("status", isEqualTo: PartnerSession.SessionStatus.waiting.rawValue)
            .getDocuments()
        
        let sessions = snapshot.documents.compactMap { PartnerSession.fromFirestore($0) }
        print("✅ Found \(sessions.count) available sessions")
        return sessions
    }
    
    /// Gets a specific partner session
    func getPartnerSession(id: String) async throws -> PartnerSession? {
        let doc = try await db.collection("partnerSessions").document(id).getDocument()
        return PartnerSession.fromFirestore(doc)
    }
    
    /// Provides real-time updates for a partner session
    func partnerSessionUpdates(sessionId: String) -> AsyncStream<PartnerSession> {
        AsyncStream { continuation in
            let listener = db.collection("partnerSessions").document(sessionId)
                .addSnapshotListener { documentSnapshot, error in
                    guard let document = documentSnapshot else {
                        print("❌ Error fetching partner session updates: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    
                    if let session = PartnerSession.fromFirestore(document) {
                        continuation.yield(session)
                    }
                }
            
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    // MARK: - User Ratings
    
    /// Submits a rating for a user after a partner workout
    func submitUserRating(userId: String, rating: Int) async throws {
        print("⭐️ Submitting rating \(rating) for user: \(userId)")
        
        let userRef = db.collection("users").document(userId)
        
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDoc: DocumentSnapshot
            do {
                userDoc = try transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // Get current rating data
            let currentTotal = userDoc.data()?["totalRatings"] as? Int ?? 0
            let currentSum = userDoc.data()?["ratingSum"] as? Int ?? 0
            
            // Update rating data
            transaction.updateData([
                "totalRatings": currentTotal + 1,
                "ratingSum": currentSum + rating
            ], forDocument: userRef)
            
            return nil
        })
        
        print("✅ Rating submitted successfully")
    }
    
    // MARK: - Community Reels
    
    /// Creates a new community reel from a partner workout session
    func createCommunityReel(videoURL: URL, thumbnailURL: URL?, participants: [String], duration: TimeInterval, workoutType: WorkoutType) async throws -> CommunityReel {
        print("🎬 Creating community reel")
        
        let reel = CommunityReel(
            id: nil,
            videoURL: videoURL,
            thumbnailURL: thumbnailURL,
            participants: participants,
            duration: duration,
            workoutType: workoutType,
            createdAt: Date(),
            likeCount: 0,
            commentCount: 0
        )
        
        let docRef = try await db.collection("communityReels").addDocument(data: reel.toFirestore())
        var createdReel = reel
        createdReel.id = docRef.documentID
        print("✅ Created community reel: \(docRef.documentID)")
        return createdReel
    }
    
    /// Gets all community reels, ordered by creation date
    func getCommunityReels(limit: Int = 20) async throws -> [CommunityReel] {
        print("🔍 Fetching community reels...")
        
        let snapshot = try await db.collection("communityReels")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let reels = snapshot.documents.compactMap { CommunityReel.fromFirestore($0) }
        print("✅ Found \(reels.count) community reels")
        return reels
    }
    
    /// Gets community reels for a specific user
    func getCommunityReels(forUser userId: String, limit: Int = 20) async throws -> [CommunityReel] {
        print("🔍 Fetching community reels for user: \(userId)")
        
        let snapshot = try await db.collection("communityReels")
            .whereField("participants", arrayContains: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let reels = snapshot.documents.compactMap { CommunityReel.fromFirestore($0) }
        print("✅ Found \(reels.count) community reels for user")
        return reels
    }
    
    /// Deletes a community reel
    func deleteCommunityReel(_ reelId: String) async throws {
        print("🗑️ Deleting community reel: \(reelId)")
        
        // Get the reel first to get the video URL
        guard let reel = try await getCommunityReel(reelId) else {
            throw NSError(domain: "FirestoreManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Reel not found"])
        }
        
        // Delete video from storage
        try await StorageManager.shared.deleteVideo(url: reel.videoURL)
        
        // Delete thumbnail if exists
        if let thumbnailURL = reel.thumbnailURL {
            try await StorageManager.shared.deleteThumbnail(url: thumbnailURL)
        }
        
        // Delete Firestore document
        try await db.collection("communityReels").document(reelId).delete()
        print("✅ Deleted community reel")
    }
    
    /// Gets a specific community reel
    func getCommunityReel(_ reelId: String) async throws -> CommunityReel? {
        let doc = try await db.collection("communityReels").document(reelId).getDocument()
        return CommunityReel.fromFirestore(doc)
    }
    
    /// Provides real-time updates for community reels
    func communityReelsUpdates() -> AsyncStream<[CommunityReel]> {
        AsyncStream { continuation in
            let listener = db.collection("communityReels")
                .order(by: "createdAt", descending: true)
                .limit(to: 20)
                .addSnapshotListener { snapshot, error in
                    guard let documents = snapshot?.documents else {
                        print("❌ Error fetching community reels: \(error?.localizedDescription ?? "Unknown error")")
                        continuation.yield([])
                        return
                    }
                    
                    let reels = documents.compactMap { CommunityReel.fromFirestore($0) }
                    continuation.yield(reels)
                }
            
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
} 