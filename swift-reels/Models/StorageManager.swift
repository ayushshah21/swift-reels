import Foundation
import FirebaseStorage

@MainActor
class StorageManager: ObservableObject {
    static let shared = StorageManager()
    private let storage = Storage.storage()
    private let pexelsApiKey = "9T5wxzEODLZlNGGURusrPeHtHUnCCM0eAaQQfEh5EU5hoQtUqG9CAuqm"
    
    private init() {}
    
    /// Uploads video data and returns the download URL
    func uploadVideo(data: Data, filename: String, title: String? = nil, workoutType: WorkoutType = .yoga, level: WorkoutLevel = .beginner, duration: TimeInterval? = nil, trainer: String? = nil) async throws -> URL {
        print("📤 Starting upload for: \(filename)")
        
        // Get and verify storage bucket
        let bucket = storage.reference().bucket
        print("📦 Using storage bucket: \(bucket)")
        
        let ref = storage.reference().child("videos/\(filename)")
        print("📍 Upload path: videos/\(filename)")
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        metadata.customMetadata = [
            "title": title ?? filename.replacingOccurrences(of: ".mp4", with: ""),
            "workoutType": workoutType.rawValue,
            "level": level.rawValue,
            "duration": String(Int(duration ?? 300)),
            "trainer": trainer ?? "Fitness Coach",
            "uploadedAt": ISO8601DateFormatter().string(from: Date()),
            "size": "\(data.count)"
        ]
        
        do {
            // Upload the data with metadata
            print("📤 Uploading \(data.count) bytes...")
            let result = try await ref.putDataAsync(data, metadata: metadata)
            print("✅ Upload metadata: \(result.dictionaryRepresentation())")
            
            // Get the download URL
            let url = try await ref.downloadURL()
            print("✅ Video uploaded successfully to: \(url)")
            return url
        } catch {
            print("❌ Upload failed with error: \(error.localizedDescription)")
            if let storageError = error as NSError?,
               storageError.domain == StorageErrorDomain {
                print("   Storage error code: \(storageError.code)")
                print("   Storage error details: \(storageError.userInfo)")
            }
            throw error
        }
    }
    
    /// Uploads video from local URL and returns the download URL
    func uploadVideo(from localURL: URL, filename: String, title: String? = nil, workoutType: WorkoutType = .yoga, level: WorkoutLevel = .beginner, duration: TimeInterval? = nil, trainer: String? = nil) async throws -> URL {
        let data = try Data(contentsOf: localURL)
        return try await uploadVideo(data: data, filename: filename, title: title, workoutType: workoutType, level: level, duration: duration, trainer: trainer)
    }
    
    /// Downloads video data from Firebase Storage
    func downloadVideo(url: URL) async throws -> Data {
        guard let path = url.path.components(separatedBy: "/videos/").last else {
            throw NSError(domain: "StorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
        }
        
        let ref = storage.reference().child("videos/\(path)")
        let data = try await ref.data(maxSize: 50 * 1024 * 1024) // 50MB max
        print("✅ Video downloaded successfully: \(path)")
        return data
    }
    
    /// Deletes a video from storage
    func deleteVideo(url: URL) async throws {
        guard let path = url.path.components(separatedBy: "/videos/").last else {
            throw NSError(domain: "StorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
        }
        
        let ref = storage.reference().child("videos/\(path)")
        try await ref.delete()
        print("✅ Video deleted successfully: \(path)")
    }
    
    /// Helper function to check if a URL is a Firebase Storage URL
    func isFirebaseStorageURL(_ url: URL) -> Bool {
        return url.absoluteString.contains("firebasestorage.googleapis.com")
    }
    
    // MARK: - Sample Video Migration
    
    /// Migrates a sample video from a public URL to Firebase Storage
    func migrateSampleVideo(from sourceURL: URL, filename: String, title: String? = nil, workoutType: WorkoutType = .yoga, level: WorkoutLevel = .beginner, duration: TimeInterval? = nil, trainer: String? = nil) async throws -> URL {
        print("🔄 Starting migration for: \(filename)")
        print("📥 Source: \(sourceURL)")
        
        let videoData: Data
        
        if sourceURL.isFileURL {
            // Load from local file
            print("📂 Loading from local file...")
            videoData = try Data(contentsOf: sourceURL)
            print("✅ Loaded \(videoData.count) bytes from file")
        } else {
            // Download from Pexels API
            print("🌐 Downloading from Pexels...")
            
            // Extract video ID from Pexels URL
            let videoId = sourceURL.pathComponents
                .first { $0.matches(of: #/^\d+$/#).count > 0 } ?? ""
            
            // Create Pexels API request
            let apiURL = URL(string: "https://api.pexels.com/videos/videos/\(videoId)")!
            var request = URLRequest(url: apiURL)
            request.setValue(pexelsApiKey, forHTTPHeaderField: "Authorization")
            
            print("🔑 Using Pexels API URL: \(apiURL)")
            
            // Get video details from Pexels API
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "StorageManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
                )
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                print("❌ Pexels API request failed with status code: \(httpResponse.statusCode)")
                print("Response headers: \(httpResponse.allHeaderFields)")
                
                if let responseData = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseData)")
                }
                
                throw NSError(
                    domain: "StorageManager",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to get video details: HTTP \(httpResponse.statusCode)"]
                )
            }
            
            // Parse video files from response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let videoFiles = json["video_files"] as? [[String: Any]] else {
                throw NSError(
                    domain: "StorageManager",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid Pexels API response format"]
                )
            }
            
            // Find SD quality video file (around 640x360)
            guard let videoFile = videoFiles.first(where: { file in
                guard let quality = file["quality"] as? String,
                      let width = file["width"] as? Int
                else { return false }
                return quality == "sd" && width >= 640
            }),
            let videoURL = videoFile["link"] as? String,
            let downloadURL = URL(string: videoURL) else {
                throw NSError(
                    domain: "StorageManager",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "No suitable video file found"]
                )
            }
            
            // Download the actual video file
            print("📥 Downloading video file from: \(downloadURL)")
            let (downloadedData, videoResponse) = try await URLSession.shared.data(from: downloadURL)
            
            guard let videoHttpResponse = videoResponse as? HTTPURLResponse,
                  (200...299).contains(videoHttpResponse.statusCode) else {
                throw NSError(
                    domain: "StorageManager",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to download video file"]
                )
            }
            
            videoData = downloadedData
        }
        
        print("✅ Got video data: \(videoData.count) bytes")
        
        // Upload to Firebase Storage with metadata
        let storageURL = try await uploadVideo(
            data: videoData,
            filename: filename,
            title: title,
            workoutType: workoutType,
            level: level,
            duration: duration,
            trainer: trainer
        )
        print("✅ Upload complete: \(storageURL)")
        
        return storageURL
    }
    
    /// Checks if a video needs migration (is not already on Firebase Storage)
    func needsMigration(_ url: URL) -> Bool {
        return !isFirebaseStorageURL(url)
    }
    
    // MARK: - Video Listing
    
    /// Lists all videos in Firebase Storage with their metadata
    func listVideos(prefix: String = "videos/", maxResults: Int64 = 100) async throws -> [(URL, [String: String])] {
        print("📂 Listing videos from Firebase Storage...")
        let ref = storage.reference().child(prefix)
        
        let result = try await ref.list(maxResults: maxResults)
        var videos: [(URL, [String: String])] = []
        
        for item in result.items {
            if item.name.hasSuffix(".mp4") {
                let metadata = try await item.getMetadata()
                let downloadURL = try await item.downloadURL()
                videos.append((downloadURL, metadata.customMetadata ?? [:]))
            }
        }
        
        print("✅ Found \(videos.count) videos in storage")
        return videos
    }
    
    // MARK: - Cleanup Functions
    
    /// Cleans up storage by removing duplicate videos and standardizing names
    func cleanupStorage() async throws {
        print("🧹 Starting storage cleanup...")
        
        // List all videos
        let ref = storage.reference().child("videos/")
        let result = try await ref.list(maxResults: 100)
        
        // Group videos by their base name (removing 'video_' prefix and '.mp4' extension)
        var videoGroups: [String: [StorageReference]] = [:]
        
        for item in result.items {
            if item.name.hasSuffix(".mp4") {
                let baseName = item.name
                    .replacingOccurrences(of: "video_", with: "")
                    .replacingOccurrences(of: ".mp4", with: "")
                
                if videoGroups[baseName] == nil {
                    videoGroups[baseName] = []
                }
                videoGroups[baseName]?.append(item)
            }
        }
        
        // For each group of videos with the same base name
        for (baseName, refs) in videoGroups {
            if refs.count > 1 {
                print("🔍 Found \(refs.count) versions of '\(baseName)'")
                
                // Create tuples of refs and their metadata
                var refsWithMetadata: [(StorageReference, StorageMetadata)] = []
                for ref in refs {
                    let metadata = try await ref.getMetadata()
                    refsWithMetadata.append((ref, metadata))
                }
                
                // Sort based on creation date and name prefix
                let sortedRefs = refsWithMetadata.sorted { item1, item2 in
                    let (ref1, meta1) = item1
                    let (ref2, meta2) = item2
                    
                    // Compare creation dates if available
                    if let time1 = meta1.timeCreated,
                       let time2 = meta2.timeCreated,
                       time1 != time2 {
                        return time1 > time2
                    }
                    
                    // If dates are equal or not available, prefer the one with 'video_' prefix
                    return ref1.name.hasPrefix("video_") && !ref2.name.hasPrefix("video_")
                }.map { $0.0 } // Extract just the references
                
                // Keep the most recent/preferred version, delete others
                let keepRef = sortedRefs[0]
                print("✅ Keeping: \(keepRef.name)")
                
                for ref in sortedRefs.dropFirst() {
                    try await ref.delete()
                    print("🗑️ Deleted duplicate: \(ref.name)")
                }
                
                // If the kept video doesn't have the standard prefix, rename it
                if !keepRef.name.hasPrefix("video_") {
                    let newName = "video_\(baseName).mp4"
                    let metadata = try await keepRef.getMetadata()
                    let data = try await keepRef.data(maxSize: 50 * 1024 * 1024)
                    
                    // Upload with new name
                    let newRef = storage.reference().child("videos/\(newName)")
                    _ = try await newRef.putDataAsync(data, metadata: metadata)
                    
                    // Delete old version
                    try await keepRef.delete()
                    print("♻️ Renamed \(keepRef.name) to \(newName)")
                }
            }
        }
        
        print("✨ Storage cleanup complete!")
    }
} 