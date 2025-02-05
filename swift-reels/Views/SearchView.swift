import SwiftUI

struct SearchView: View {
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var searchText = ""
    @State private var searchResults: [VideoModel] = []
    @State private var isSearching = false
    @State private var selectedWorkoutType: WorkoutType = .all
    
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
                        .onSubmit {
                            performSearch()
                        }
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
            .onChange(of: selectedWorkoutType) { _ in
                if !searchText.isEmpty {
                    performSearch()
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        Task {
            do {
                let videos = try await firestoreManager.searchVideos(
                    query: searchText,
                    workoutType: selectedWorkoutType != .all ? selectedWorkoutType : nil
                )
                await MainActor.run {
                    searchResults = videos
                    isSearching = false
                }
            } catch {
                print("❌ Error searching videos: \(error.localizedDescription)")
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
} 