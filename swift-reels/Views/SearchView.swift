import SwiftUI

struct SearchView: View {
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var searchText = ""
    @State private var searchResults: [VideoModel] = []
    @State private var isSearching = false
    @State private var selectedWorkoutType: WorkoutType = .all
    @State private var searchDebounceTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search workouts...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults.removeAll()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Theme.card)
                .cornerRadius(10)
                .padding()
                
                // Filter Bar
                FilterBar(selectedCategory: $selectedWorkoutType)
                    .padding(.bottom)
                
                // Results
                if isSearching {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No workouts found")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(searchResults) { video in
                                NavigationLink(destination: ReelPlayerView(video: video, isFromSearch: true)) {
                                    VideoCardView(video: video)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Search")
            .onChange(of: searchText) { newValue in
                // Cancel any previous search task
                searchDebounceTask?.cancel()
                
                // If search text is empty, clear results
                if newValue.isEmpty {
                    searchResults = []
                    return
                }
                
                // Create a new debounced search task
                searchDebounceTask = Task {
                    // Wait a brief moment to avoid too many searches while typing
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    if !Task.isCancelled {
                        await performSearch()
                    }
                }
            }
            .onChange(of: selectedWorkoutType) { _ in
                if !searchText.isEmpty {
                    Task {
                        await performSearch()
                    }
                }
            }
        }
    }
    
    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        
        await MainActor.run {
            isSearching = true
        }
        
        do {
            var videos = try await firestoreManager.searchVideos(
                query: searchText,
                workoutType: selectedWorkoutType != .all ? selectedWorkoutType : nil
            )
            
            // Generate thumbnails for videos that don't have one
            for (index, video) in videos.enumerated() {
                if video.thumbnailURL == nil {
                    do {
                        // Save the video to generate thumbnail
                        try await firestoreManager.saveVideo(videoId: video.id)
                        // Get the updated video with thumbnail
                        if let updatedVideo = try await firestoreManager.getVideo(id: video.id) {
                            videos[index] = updatedVideo
                        }
                    } catch {
                        print("❌ Error generating thumbnail for video \(video.id): \(error.localizedDescription)")
                    }
                }
            }
            
            if !Task.isCancelled {
                await MainActor.run {
                    searchResults = videos
                    isSearching = false
                }
            }
        } catch {
            print("❌ Error searching videos: \(error.localizedDescription)")
            if !Task.isCancelled {
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
} 