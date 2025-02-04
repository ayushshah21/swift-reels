import SwiftUI

struct ReelsFeedView: View {
    @State private var currentIndex = 0
    @State private var displayedVideos: [VideoModel]
    @State private var selectedWorkoutType: WorkoutType = .all
    @StateObject private var playerManager = VideoPlayerManager.shared
    let videos: [VideoModel]
    
    init(videos: [VideoModel]) {
        self.videos = videos
        _displayedVideos = State(initialValue: videos)
    }
    
    // Wrapper struct to provide unique identification for repeated videos
    private struct UniqueVideo: Identifiable {
        let video: VideoModel
        let uniqueId: String
        
        var id: String { uniqueId }
        
        init(video: VideoModel, index: Int) {
            self.video = video
            self.uniqueId = "\(video.id)_\(index)"
        }
    }
    
    private var filteredVideos: [VideoModel] {
        guard selectedWorkoutType != .all else { return displayedVideos }
        return displayedVideos.filter { $0.workout.type == selectedWorkoutType }
    }
    
    private var infiniteVideos: [UniqueVideo] {
        guard !filteredVideos.isEmpty else { return [] }
        return filteredVideos.enumerated().map { index, video in
            UniqueVideo(video: video, index: index)
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main Content
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(infiniteVideos) { uniqueVideo in
                        GeometryReader { geometry in
                            ReelPlayerView(video: uniqueVideo.video)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .rotation3DEffect(
                                    .degrees(0),
                                    axis: (x: 0, y: 0, z: 0)
                                )
                                .task {
                                    if let currentIndex = infiniteVideos.firstIndex(where: { $0.id == uniqueVideo.id }),
                                       currentIndex + 1 < infiniteVideos.count {
                                        Task.detached {
                                            await playerManager.preloadVideo(url: infiniteVideos[currentIndex + 1].video.videoURL)
                                        }
                                    }
                                }
                                .onAppear {
                                    if let index = infiniteVideos.firstIndex(where: { $0.id == uniqueVideo.id }) {
                                        currentIndex = index
                                        if index >= infiniteVideos.count - 3 {
                                            appendMoreVideos()
                                        }
                                    }
                                }
                        }
                        .frame(height: UIScreen.main.bounds.height)
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .ignoresSafeArea()
            
            // Filter Bar Overlay
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
    }
    
    private func appendMoreVideos() {
        DispatchQueue.main.async {
            withAnimation {
                displayedVideos.append(contentsOf: videos)
            }
        }
    }
} 