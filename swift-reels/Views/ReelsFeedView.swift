import SwiftUI
import FirebaseFirestore
import AVKit

// Extracted ReelItem view to simplify the main view hierarchy
private struct ReelItem: View {
    let video: VideoModel
    let isVisible: Bool
    let onAppear: () -> Void
    let onVisibilityChanged: (Bool) -> Void
    @StateObject private var playerManager = VideoPlayerManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            let isCurrentlyVisible = isVideoVisible(frame)
            
            ReelPlayerView(
                video: video,
                isVisible: isVisible && isCurrentlyVisible
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onChange(of: isCurrentlyVisible) { newValue in
                onVisibilityChanged(newValue)
            }
            .onAppear {
                onAppear()
            }
        }
        .frame(height: UIScreen.main.bounds.height)
    }
    
    private func isVideoVisible(_ frame: CGRect) -> Bool {
        let minY = frame.minY
        let maxY = frame.maxY
        let screenHeight = UIScreen.main.bounds.height
        return minY >= -50 && maxY <= screenHeight + 50
    }
}

struct ReelsFeedView: View {
    @State private var currentIndex = 0
    @State private var displayedVideos: [VideoModel] = []
    @State private var selectedWorkoutType: WorkoutType = .all
    @StateObject private var playerManager = VideoPlayerManager.shared
    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var reelQuizManager = ReelQuizManager.shared
    @State private var isLoadingMore = false
    @State private var hasMoreVideos = true
    @State private var visibleVideoId: String? = nil
    private let videosPerPage = 5
    
    var body: some View {
        ZStack(alignment: .top) {
            if displayedVideos.isEmpty {
                emptyStateView
            } else {
                mainContentView
            }
            
            filterBarOverlay
        }
        .sheet(isPresented: $reelQuizManager.shouldShowQuiz, onDismiss: {
            // Resume video playback when quiz is dismissed
            if let visibleId = visibleVideoId,
               let video = displayedVideos.first(where: { $0.id == visibleId }) {
                Task {
                    let player = await playerManager.player(for: video.videoURL)
                    player.play()
                }
            }
        }) {
            if let quiz = reelQuizManager.currentQuiz {
                ReelQuizView(quiz: quiz)
            }
        }
        .onChange(of: reelQuizManager.shouldShowQuiz) { showQuiz in
            if showQuiz {
                // Pause video when quiz appears
                playerManager.stopAllPlayback()
            }
        }
        .task {
            await loadVideos()
        }
        .onChange(of: selectedWorkoutType) { _ in
            Task {
                displayedVideos = []
                hasMoreVideos = true
                await loadVideos()
            }
        }
        // --------------- KEY CHANGE BELOW ---------------
        .onAppear {
            reelQuizManager.setReelsFeedActive(true)
            
            // If no reel is marked visible, default to the first one
            if visibleVideoId == nil, !displayedVideos.isEmpty {
                visibleVideoId = displayedVideos[0].id
            }
            
            // Resume playback of currently visible reel
            if let visibleId = visibleVideoId,
               let video = displayedVideos.first(where: { $0.id == visibleId }) {
                Task {
                    let player = await playerManager.player(for: video.videoURL)
                    player.play()
                }
            }
        }
        .onDisappear {
            reelQuizManager.setReelsFeedActive(false)
            // Stop playback when leaving the view
            playerManager.stopAllPlayback()
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            if isLoadingMore {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                Text("No videos found")
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
    
    private var mainContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(displayedVideos) { video in
                    ReelItem(
                        video: video,
                        isVisible: visibleVideoId == video.id,
                        onAppear: {
                            handleVideoAppear(video)
                        },
                        onVisibilityChanged: { isVisible in
                            handleVisibilityChange(video, isVisible: isVisible)
                        }
                    )
                }
                
                if isLoadingMore {
                    ProgressView()
                        .frame(height: 50)
                        .padding()
                }
            }
        }
        .scrollTargetBehavior(.paging)
        .scrollDisabled(false)
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
    }
    
    private var filterBarOverlay: some View {
        FilterBar(selectedCategory: $selectedWorkoutType)
            .padding(.top, 2)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.3), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .ignoresSafeArea(edges: .top)
            )
            .ignoresSafeArea(edges: .horizontal)
    }
    
    private func handleVideoAppear(_ video: VideoModel) {
        if let index = displayedVideos.firstIndex(of: video) {
            currentIndex = index
            if index >= displayedVideos.count - 2 && hasMoreVideos && !isLoadingMore {
                Task {
                    await loadMoreVideos()
                }
            }
        }
    }
    
    private func handleVisibilityChange(_ video: VideoModel, isVisible: Bool) {
        if isVisible {
            visibleVideoId = video.id
            Task {
                if let subtitles = try? await firestoreManager.getSubtitles(for: video.id) {
                    // Combine all segment texts into a single transcript
                    let transcript = subtitles.segments
                        .map { $0.text }
                        .joined(separator: " ")
                    
                    print("📝 Adding transcript to ReelQuizManager")
                    print("   Video ID: \(video.id)")
                    print("   Transcript length: \(transcript.count) characters")
                    print("   Videos watched since last quiz: \(reelQuizManager.videosWatchedSinceLastQuiz)")
                    
                    reelQuizManager.addTranscript(transcript)
                } else {
                    print("⚠️ No subtitles found for video \(video.id), skipping quiz generation")
                }
            }
            
            // Preload next video if available
            if let nextIndex = displayedVideos.firstIndex(of: video).map({ $0 + 1 }),
               nextIndex < displayedVideos.count {
                Task {
                    await playerManager.preloadVideo(url: displayedVideos[nextIndex].videoURL)
                }
            }
        } else if visibleVideoId == video.id {
            visibleVideoId = nil
        }
    }
    
    private func loadVideos() async {
        isLoadingMore = true
        do {
            let videos = try await firestoreManager.getVideos(
                workoutType: selectedWorkoutType != .all ? selectedWorkoutType : nil,
                limit: videosPerPage
            )
            
            await MainActor.run {
                displayedVideos = videos
                hasMoreVideos = videos.count == videosPerPage
                isLoadingMore = false
                
                // If we just loaded videos fresh and have none marked visible, pick the first
                if !videos.isEmpty, visibleVideoId == nil {
                    visibleVideoId = videos[0].id
                    // Preload the second video if available
                    if videos.count > 1 {
                        Task {
                            await playerManager.preloadVideo(url: videos[1].videoURL)
                        }
                    }
                }
            }
        } catch {
            print("❌ Error loading videos: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingMore = false
            }
        }
    }
    
    private func loadMoreVideos() async {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        print("📱 Loading more videos after: \(displayedVideos.last?.id ?? "none")")
        
        do {
            if let lastVideo = displayedVideos.last {
                let newVideos = try await firestoreManager.getMoreVideos(
                    after: lastVideo,
                    workoutType: selectedWorkoutType != .all ? selectedWorkoutType : nil,
                    limit: videosPerPage
                )
                
                await MainActor.run {
                    if !newVideos.isEmpty {
                        print("📱 Loaded \(newVideos.count) new videos")
                        displayedVideos.append(contentsOf: newVideos)
                    } else {
                        // If no new videos, recycle the existing ones by adding them again
                        print("📱 Recycling videos for infinite scroll")
                        let startIndex = max(0, displayedVideos.count - videosPerPage)
                        let videosToRecycle = Array(displayedVideos[..<startIndex])
                        if !videosToRecycle.isEmpty {
                            displayedVideos.append(contentsOf: videosToRecycle)
                            print("📱 Recycled \(videosToRecycle.count) videos")
                        }
                    }
                    // Always keep hasMoreVideos true since we're recycling
                    hasMoreVideos = true
                    isLoadingMore = false
                }
            } else {
                // If there's no last video, load initial videos
                await loadVideos()
            }
        } catch {
            print("❌ Error loading more videos: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingMore = false
            }
        }
    }
}
