import SwiftUI
import AVKit
import AVFoundation

@MainActor
class VideoPlayerManager: ObservableObject {
    static let shared = VideoPlayerManager()
    private var playerCache: [String: AVPlayer] = [:]
    
    func player(for url: URL) async -> AVPlayer {
        let urlString = url.absoluteString
        if let existingPlayer = playerCache[urlString] {
            return existingPlayer
        }
        
        // Create asset with options for network optimization
        let asset = AVURLAsset(
            url: url,
            options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true
            ]
        )
        
        // Load essential properties asynchronously
        do {
            _ = try await asset.load(.isPlayable, .duration)
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            player.automaticallyWaitsToMinimizeStalling = true
            playerCache[urlString] = player
            return player
        } catch {
            print("Error loading asset: \(error)")
            // Fallback to simple player if asset loading fails
            let player = AVPlayer(playerItem: AVPlayerItem(url: url))
            playerCache[urlString] = player
            return player
        }
    }
    
    func preloadVideo(url: URL) async {
        let asset = AVURLAsset(url: url)
        do {
            // Preload essential properties
            let status = try await asset.load(.isPlayable, .duration)
            print("Preloaded video with status: \(status)")
        } catch {
            print("Error preloading video: \(error)")
        }
    }
    
    func cleanupPlayer(for url: URL) {
        let urlString = url.absoluteString
        if let player = playerCache[urlString] {
            player.pause()
            player.replaceCurrentItem(with: nil)
            playerCache.removeValue(forKey: urlString)
        }
    }
}

struct ReelPlayerView: View {
    let video: VideoModel
    @StateObject private var playerManager = VideoPlayerManager.shared
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isBookmarked: Bool
    @State private var showComments = false
    @State private var isLoading = true
    
    init(video: VideoModel) {
        self.video = video
        _isBookmarked = State(initialValue: video.isBookmarked)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                CustomVideoPlayer(player: player)
                    .onTapGesture {
                        if isPlaying {
                            player.pause()
                        } else {
                            player.play()
                        }
                        isPlaying.toggle()
                    }
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            }
            
            // Overlay Controls
            VStack {
                Spacer()
                
                // Side Action Bar
                HStack(alignment: .bottom) {
                    // Video Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title)
                            .font(.title3)
                            .bold()
                        Text("with \(video.trainer)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        HStack {
                            Label(video.difficulty.rawValue, systemImage: "flame.fill")
                                .foregroundColor(.orange)
                            Label(video.category.rawValue, systemImage: "figure.run")
                                .foregroundColor(.blue)
                        }
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Action Buttons
                    VStack(spacing: 20) {
                        Button(action: {
                            // Like action
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.title)
                                Text("\(video.likes)")
                                    .font(.caption)
                                    .bold()
                            }
                        }
                        .foregroundColor(.white)
                        
                        Button(action: {
                            showComments.toggle()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "message.fill")
                                    .font(.title)
                                Text("\(video.comments)")
                                    .font(.caption)
                                    .bold()
                            }
                        }
                        .foregroundColor(.white)
                        
                        Button(action: {
                            withAnimation {
                                isBookmarked.toggle()
                            }
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
                }
                .padding(.horizontal)
                .padding(.bottom, 100) // Add extra padding for tab bar
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
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
        }
        .onDisappear {
            player?.pause()
            Task {
                await player?.seek(to: .zero)
            }
        }
        .sheet(isPresented: $showComments) {
            NavigationStack {
                CommentsView(videoID: video.id)
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