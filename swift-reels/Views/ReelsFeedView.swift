import SwiftUI
import FirebaseFirestore

struct ReelsFeedView: View {
    @State private var currentIndex = 0
    @State private var displayedVideos: [VideoModel] = []
    @State private var selectedWorkoutType: WorkoutType = .all
    @StateObject private var playerManager = VideoPlayerManager.shared
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var isLoadingMore = false
    @State private var hasMoreVideos = true
    private let videosPerPage = 5 // Increased for better pagination
    
    var body: some View {
        ZStack(alignment: .top) {
            if displayedVideos.isEmpty {
                // Show loading or empty state
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
            } else {
                // Main Content
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedVideos) { video in
                            GeometryReader { geometry in
                                ReelPlayerView(video: video)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .rotation3DEffect(
                                        .degrees(0),
                                        axis: (x: 0, y: 0, z: 0)
                                    )
                                    .task {
                                        if let nextIndex = displayedVideos.firstIndex(of: video).map({ $0 + 1 }),
                                           nextIndex < displayedVideos.count {
                                            Task.detached {
                                                await playerManager.preloadVideo(url: displayedVideos[nextIndex].videoURL)
                                            }
                                        }
                                    }
                                    .onAppear {
                                        if let index = displayedVideos.firstIndex(of: video) {
                                            currentIndex = index
                                            // Check if we need to load more videos
                                            if index >= displayedVideos.count - 2 && hasMoreVideos && !isLoadingMore {
                                                Task {
                                                    await loadMoreVideos()
                                                }
                                            }
                                        }
                                    }
                            }
                            .frame(height: UIScreen.main.bounds.height)
                        }
                        
                        if isLoadingMore {
                            ProgressView()
                                .frame(height: 50)
                                .padding()
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .ignoresSafeArea()
            }
            
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
        .task {
            // Initial load of videos
            await loadVideos()
        }
        .onChange(of: selectedWorkoutType) { _ in
            // Reset and reload videos when filter changes
            Task {
                displayedVideos = []
                hasMoreVideos = true
                await loadVideos()
            }
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