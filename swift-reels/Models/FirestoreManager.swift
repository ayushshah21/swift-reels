import Foundation
import FirebaseFirestore
import FirebaseAuth

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
} 