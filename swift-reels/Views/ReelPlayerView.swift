import SwiftUI
import AVKit
import AVFoundation
import FirebaseAuth

extension UIApplication {
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

@MainActor
class VideoPlayerManager: ObservableObject {
    static let shared = VideoPlayerManager()
    private var playerCache: [String: AVPlayer] = [:]
    private var assetCache: [String: AVURLAsset] = [:]
    private var currentPlayingURL: String?
    
    func player(for url: URL) async -> AVPlayer {
        let urlString = url.absoluteString
        
        // Stop previous video's audio if different URL
        if let currentURL = currentPlayingURL, currentURL != urlString {
            stopAudio(for: URL(string: currentURL)!)
        }
        
        if let existingPlayer = playerCache[urlString] {
            currentPlayingURL = urlString
            return existingPlayer
        }
        
        // Use cached asset if available, otherwise create new one
        let asset: AVURLAsset
        if let cachedAsset = assetCache[urlString] {
            asset = cachedAsset
            print("✅ Using cached asset for: \(url.lastPathComponent)")
        } else {
            asset = AVURLAsset(
                url: url,
                options: [
                    AVURLAssetPreferPreciseDurationAndTimingKey: true
                ]
            )
            print("🔄 Creating new asset for: \(url.lastPathComponent)")
        }
        
        // Load essential properties asynchronously
        do {
            // Load all required properties upfront including preferredTransform
            _ = try await asset.load(.isPlayable, .duration, .preferredTransform)
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            player.automaticallyWaitsToMinimizeStalling = true
            playerCache[urlString] = player
            currentPlayingURL = urlString
            return player
        } catch {
            print("❌ Error loading asset: \(error)")
            // Fallback to simple player if asset loading fails
            let player = AVPlayer(playerItem: AVPlayerItem(url: url))
            playerCache[urlString] = player
            currentPlayingURL = urlString
            return player
        }
    }
    
    func preloadVideo(url: URL) async {
        let urlString = url.absoluteString
        
        // Skip if already cached
        guard assetCache[urlString] == nil else {
            print("⏭️ Asset already cached for: \(url.lastPathComponent)")
            return
        }
        
        print("🔄 Preloading video: \(url.lastPathComponent)")
        let asset = AVURLAsset(
            url: url,
            options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true
            ]
        )
        
        do {
            // Preload essential properties
            _ = try await asset.load(.isPlayable, .duration, .preferredTransform)
            assetCache[urlString] = asset
            print("✅ Successfully preloaded: \(url.lastPathComponent)")
        } catch {
            print("❌ Error preloading video: \(error)")
        }
    }
    
    func cleanupPlayer(for url: URL) {
        let urlString = url.absoluteString
        stopAudio(for: url)
        playerCache.removeValue(forKey: urlString)
        assetCache.removeValue(forKey: urlString)
    }
    
    func stopAudio(for url: URL) {
        let urlString = url.absoluteString
        if let player = playerCache[urlString] {
            player.pause()
            player.seek(to: .zero)
            if currentPlayingURL == urlString {
                currentPlayingURL = nil
            }
        }
    }
    
    func cleanupCache() {
        // Clean up old cached assets if cache gets too large
        let maxCacheSize = 5
        if assetCache.count > maxCacheSize {
            print("🧹 Cleaning up asset cache...")
            let sortedKeys = assetCache.keys.sorted()
            let keysToRemove = sortedKeys[..<(sortedKeys.count - maxCacheSize)]
            keysToRemove.forEach { key in
                assetCache.removeValue(forKey: key)
                playerCache.removeValue(forKey: key)
                print("🗑️ Removed cached asset: \(key)")
            }
        }
    }
}

struct ReelPlayerView: View {
    let video: VideoModel
    let isFromSearch: Bool
    let isFromSaved: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerManager = VideoPlayerManager.shared
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isLoading = true
    @State private var showComments = false
    @State private var isLiked = false
    @State private var isBookmarked = false
    @State private var likeCount = 0
    @State private var commentCount = 0
    @State private var showDeleteAlert = false
    @State private var isOwner = false
    @State private var errorMessage: String?
    @State private var showHeartAnimation = false
    @State private var showDeleteOptions = false
    @GestureState private var isDetectingLongPress = false
    
    private var safeAreaBottom: CGFloat {
        UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
    }
    
    init(video: VideoModel, isFromSearch: Bool = false, isFromSaved: Bool = false) {
        self.video = video
        self.isFromSearch = isFromSearch
        self.isFromSaved = isFromSaved
        _isBookmarked = State(initialValue: video.isBookmarked)
        _likeCount = State(initialValue: video.likeCount)
        _commentCount = State(initialValue: video.comments)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                CustomVideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        if isPlaying {
                            player.pause()
                        } else {
                            player.play()
                        }
                        isPlaying.toggle()
                    }
                    // Add long press gesture for delete option
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .updating($isDetectingLongPress) { currentState, gestureState, _ in
                                gestureState = currentState
                            }
                            .onEnded { _ in
                                if isOwner {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showDeleteOptions = true
                                    }
                                }
                            }
                    )
                    // Add double tap gesture for liking
                    .onTapGesture(count: 2) {
                        handleLikeAction()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            showHeartAnimation = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation {
                                showHeartAnimation = false
                            }
                        }
                    }
            }
            
            // Delete Options Overlay
            if showDeleteOptions {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation {
                            showDeleteOptions = false
                        }
                    }
                
                VStack(spacing: 20) {
                    Button(action: { showDeleteAlert = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                            Text("Delete Video")
                        }
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        withAnimation {
                            showDeleteOptions = false
                        }
                    }) {
                        Text("Cancel")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            }
            
            // Heart animation overlay
            if showHeartAnimation {
                Image(systemName: "heart.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.red)
                    .scaleEffect(showHeartAnimation ? 1.0 : 0.5)
                    .opacity(showHeartAnimation ? 1 : 0)
            }
            
            // Overlay Controls
            VStack {
                Spacer()
                
                // Video Info
                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title)
                            .font(.title3)
                            .bold()
                        Text("with \(video.trainer)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        HStack {
                            Label(video.workout.level.rawValue, systemImage: "flame.fill")
                                .foregroundColor(.orange)
                            Label(video.workout.type.rawValue, systemImage: "figure.run")
                                .foregroundColor(.blue)
                        }
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(y: isFromSearch ? 30 : (isFromSaved ? 50 : 0))
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            handleLikeAction()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.title)
                                Text("\(likeCount)")
                                    .font(.caption)
                                    .bold()
                            }
                        }
                        .foregroundColor(isLiked ? .red : .white)
                        
                        Button(action: {
                            showComments.toggle()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "message.fill")
                                    .font(.title)
                                Text("\(commentCount)")
                                    .font(.caption)
                                    .bold()
                            }
                        }
                        .foregroundColor(.white)
                        
                        Button(action: {
                            handleBookmarkAction()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                    .font(.title)
                                Text("Save")
                                    .font(.caption)
                                    .bold()
                            }
                        }
                        .foregroundColor(isBookmarked ? Theme.primary : .white)
                    }
                    .offset(y: isFromSearch ? 0 : (isFromSaved ? 20 : -30))
                }
                .padding(.horizontal)
                .padding(.bottom, isFromSearch ? safeAreaBottom + 20 : (isFromSaved ? safeAreaBottom + 50 : 100))
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .alert("Delete Video", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteVideo()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this video? This action cannot be undone.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") {
                errorMessage = nil
            }
        }, message: {
            if let error = errorMessage {
                Text(error)
            }
        })
        .task {
            isLoading = true
            // Initialize player when view appears
            let player = await playerManager.player(for: video.videoURL)
            player.actionAtItemEnd = .none
            player.isMuted = false
            
            // Add observer for video end
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                Task {
                    await player.seek(to: .zero)
                    player.play()
                }
            }
            
            self.player = player
            player.play()
            isPlaying = true
            isLoading = false
            
            // Check if user has liked and saved this video
            do {
                isLiked = try await firestoreManager.hasUserLikedVideo(videoId: video.id)
                isBookmarked = try await firestoreManager.isVideoSaved(video.id)
                
                // Setup real-time listener for video updates
                firestoreManager.addVideoListener(videoId: video.id) { updatedVideo in
                    if let updatedVideo = updatedVideo {
                        withAnimation(.spring()) {
                            likeCount = updatedVideo.likeCount
                            commentCount = updatedVideo.comments
                        }
                    }
                }
            } catch {
                print("❌ Error checking video status: \(error.localizedDescription)")
            }
            
            // Check if current user is the owner
            if let currentUserId = Auth.auth().currentUser?.uid {
                isOwner = currentUserId == video.userId
                print("👤 Ownership check - Current userId: \(currentUserId), Video userId: \(video.userId), isOwner: \(isOwner)")
            } else {
                print("❌ Could not get current user ID for ownership check")
            }
        }
        .onDisappear {
            if let player = player {
                player.pause()
                Task {
                    await player.seek(to: .zero)
                    playerManager.stopAudio(for: video.videoURL)
                }
            }
        }
        .sheet(isPresented: $showComments) {
            NavigationStack {
                CommentsView(videoID: video.id)
            }
        }
    }
    
    private func handleLikeAction() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        Task {
            do {
                if isLiked {
                    try await firestoreManager.unlikeVideo(videoId: video.id)
                    withAnimation(.spring()) {
                        isLiked = false
                    }
                } else {
                    try await firestoreManager.likeVideo(videoId: video.id)
                    withAnimation(.spring()) {
                        isLiked = true
                    }
                }
            } catch {
                print("❌ Error handling like action: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleBookmarkAction() {
        Task {
            do {
                if isBookmarked {
                    try await firestoreManager.unsaveVideo(videoId: video.id)
                    withAnimation(.spring()) {
                        isBookmarked = false
                    }
                } else {
                    try await firestoreManager.saveVideo(videoId: video.id)
                    withAnimation(.spring()) {
                        isBookmarked = true
                    }
                }
            } catch {
                print("❌ Error handling bookmark action: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteVideo() {
        Task {
            do {
                try await firestoreManager.deleteVideo(video.id)
                // Instead of dismissing, let the parent view handle navigation
                NotificationCenter.default.post(name: .init("VideoDeleted"), object: nil)
            } catch {
                print("❌ Error deleting video: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.allowsPictureInPicturePlayback = false
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
} 