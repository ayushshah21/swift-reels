import SwiftUI
import FirebaseAuth
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var currentUser: User?
    @State private var savedVideos: [VideoModel] = []
    @State private var isLoadingSaved = true
    @State private var showingSavedVideos = false
    @State private var showingImagePicker = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isUploadingImage = false
    
    private let darkBackground = Color(UIColor.systemBackground)
    private let cardBackground = Color(UIColor.secondarySystemBackground).opacity(0.7)
    private let accentColor = Color(red: 0.35, green: 0.47, blue: 0.95) // Matching the app's accent color
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                darkBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        VStack(spacing: 16) {
                            ZStack(alignment: .bottomTrailing) {
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(accentColor, lineWidth: 2))
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(accentColor)
                                }
                                
                                // Edit button
                                PhotosPicker(selection: $selectedImage, matching: .images) {
                                    Image(systemName: "pencil.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, accentColor)
                                        .font(.title)
                                        .background(Circle().fill(darkBackground))
                                }
                            }
                            
                            Text(currentUser?.username ?? Auth.auth().currentUser?.email ?? "User")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 32)
                        
                        // Loading indicator for image upload
                        if isUploadingImage {
                            ProgressView()
                                .tint(accentColor)
                        }
                        
                        // Stats
                        HStack(spacing: 50) {
                            VStack(spacing: 8) {
                                Text("\(currentUser?.postsCount ?? 0)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Posts")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(spacing: 8) {
                                Text("\(currentUser?.followersCount ?? 0)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Followers")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(spacing: 8) {
                                Text("\(savedVideos.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Saved")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(cardBackground)
                        .cornerRadius(15)
                        .padding(.horizontal)
                        
                        // Saved Videos Button
                        Button(action: { showingSavedVideos = true }) {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                    .font(.title3)
                                Text("Saved Workouts")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(savedVideos.count)")
                                    .foregroundColor(.gray)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(cardBackground)
                            .cornerRadius(15)
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        // Sign Out Button
                        Button(action: {
                            authViewModel.signOut()
                        }) {
                            Text("Sign Out")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(15)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .onChange(of: selectedImage) { newItem in
                guard let item = newItem else { return }
                Task {
                    await loadAndUploadImage(from: item)
                }
            }
            .task {
                if let authUser = Auth.auth().currentUser {
                    do {
                        currentUser = try await firestoreManager.getUser(id: authUser.uid)
                        savedVideos = try await firestoreManager.getSavedVideos()
                        isLoadingSaved = false
                        
                        // Load profile image if available
                        if let imageUrl = currentUser?.profileImageURL {
                            await loadProfileImage(from: imageUrl)
                        }
                    } catch {
                        print("❌ Error fetching user data: \(error.localizedDescription)")
                        isLoadingSaved = false
                    }
                }
            }
            .sheet(isPresented: $showingSavedVideos) {
                SavedVideosView(videos: savedVideos)
            }
        }
    }
    
    private func loadAndUploadImage(from item: PhotosPickerItem) async {
        isUploadingImage = true
        defer { isUploadingImage = false }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            guard let uiImage = UIImage(data: data) else { return }
            
            // Resize image to a reasonable size (e.g., 500x500 max)
            let resizedImage = await resizeImage(uiImage, targetSize: CGSize(width: 500, height: 500))
            guard let imageData = resizedImage.jpegData(compressionQuality: 0.7) else { return }
            
            // Upload to Firebase Storage
            if let userId = Auth.auth().currentUser?.uid {
                let filename = "profile_images/\(userId).jpg"
                let url = try await StorageManager.shared.uploadProfileImage(data: imageData, filename: filename)
                
                // Update user profile in Firestore
                var updatedUser = currentUser ?? User(id: userId, email: Auth.auth().currentUser?.email ?? "")
                updatedUser.profileImageURL = url
                try await firestoreManager.updateUser(updatedUser)
                currentUser = updatedUser
                
                // Update UI
                await MainActor.run {
                    self.profileImage = resizedImage
                }
            }
        } catch {
            print("❌ Error uploading profile image: \(error.localizedDescription)")
        }
    }
    
    private func loadProfileImage(from url: URL) async {
        do {
            let data = try await StorageManager.shared.downloadProfileImage(url: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.profileImage = image
                }
            }
        } catch {
            print("❌ Error loading profile image: \(error.localizedDescription)")
        }
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) async -> UIImage {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let resizedImage = renderer.image { context in
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                }
                continuation.resume(returning: resizedImage)
            }
        }
    }
}

struct SavedVideosView: View {
    let videos: [VideoModel]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerManager = VideoPlayerManager.shared
    @State private var visibleIndices: Set<Int> = []
    
    var body: some View {
        NavigationStack {
            Group {
                if videos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No saved workouts yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                                NavigationLink(destination: ReelPlayerView(video: video, isFromSaved: true)) {
                                    VideoCardView(video: video)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .id(index)
                                .onAppear {
                                    handleVideoAppear(at: index)
                                }
                                .onDisappear {
                                    handleVideoDisappear(at: index)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Saved Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(Color(.systemBackground))
        }
        .onDisappear {
            playerManager.cleanupCache()
        }
    }
    
    private func handleVideoAppear(at index: Int) {
        visibleIndices.insert(index)
        let preloadCount = 2
        for offset in 1...preloadCount {
            let nextIndex = index + offset
            guard nextIndex < videos.count else { break }
            Task {
                await playerManager.preloadVideo(url: videos[nextIndex].videoURL)
            }
        }
    }
    
    private func handleVideoDisappear(at index: Int) {
        visibleIndices.remove(index)
    }
} 