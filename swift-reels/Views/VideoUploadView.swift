import SwiftUI
import PhotosUI
import AVFoundation
import FirebaseAuth

// MARK: - Video Selection View
struct VideoSelectionView: View {
    let isLoading: Bool
    let errorMessage: String?
    let onSelect: () -> Void
    @Binding var selectedItem: PhotosPickerItem?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 40)
            
            Text("Upload a Workout Video")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Share your fitness journey with the community")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            PhotosPicker(
                selection: $selectedItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                Label("Select Video", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            if isLoading {
                ProgressView("Processing video...")
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Spacer()
        }
    }
}

// MARK: - Upload State
enum UploadState: Equatable {
    case idle
    case uploading
    case processing
    case success
    case error(String)
    
    var message: String {
        switch self {
        case .idle: return ""
        case .uploading: return "Uploading video..."
        case .processing: return "Processing..."
        case .success: return "Upload complete!"
        case .error(let message): return message
        }
    }
    
    static func == (lhs: UploadState, rhs: UploadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.uploading, .uploading): return true
        case (.processing, .processing): return true
        case (.success, .success): return true
        case (.error(let lhsMsg), .error(let rhsMsg)): return lhsMsg == rhsMsg
        default: return false
        }
    }
}

// MARK: - Upload Progress View
struct UploadProgressView: View {
    let state: UploadState
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(state == .success ? .green : .blue)
            
            Text(state.message)
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical)
    }
}

// MARK: - Upload Button View
struct UploadButtonView: View {
    let state: UploadState
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            if state == .uploading || state == .processing {
                HStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text(state.message)
                        .padding(.leading, 8)
                }
            } else {
                Text("Upload Workout")
                    .bold()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(state == .success ? Color.green : Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(isDisabled)
    }
}

// MARK: - Metadata Form View
struct MetadataFormView: View {
    @Binding var title: String
    @Binding var selectedType: WorkoutType
    @Binding var selectedLevel: WorkoutLevel
    @Binding var selectedEquipment: Set<WorkoutEquipment>
    let videoDuration: TimeInterval
    let uploadState: UploadState
    let uploadProgress: Double
    let onUpload: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title Section
                titleSection
                
                // Workout Type Section
                workoutTypeSection
                
                // Difficulty Level Section
                difficultySection
                
                // Equipment Section
                equipmentSection
                
                // Duration Section
                durationSection
                
                // Upload Progress and Button
                if uploadState != .idle {
                    UploadProgressView(state: uploadState, progress: uploadProgress)
                }
                
                UploadButtonView(
                    state: uploadState,
                    isDisabled: uploadState == .uploading || uploadState == .processing || title.isEmpty,
                    action: onUpload
                )
            }
            .padding()
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading) {
            Text("Title")
                .font(.headline)
            TextField("e.g., Morning Yoga Flow", text: $title)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var workoutTypeSection: some View {
        VStack(alignment: .leading) {
            Text("Workout Type")
                .font(.headline)
            Picker("Type", selection: $selectedType) {
                ForEach(WorkoutType.allCases.filter { $0 != .all }, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var difficultySection: some View {
        VStack(alignment: .leading) {
            Text("Difficulty")
                .font(.headline)
            Picker("Level", selection: $selectedLevel) {
                ForEach(WorkoutLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var equipmentSection: some View {
        VStack(alignment: .leading) {
            Text("Equipment Needed")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(WorkoutEquipment.allCases, id: \.self) { equipment in
                        Toggle(isOn: Binding(
                            get: { selectedEquipment.contains(equipment) },
                            set: { isSelected in
                                if isSelected {
                                    selectedEquipment.insert(equipment)
                                } else {
                                    selectedEquipment.remove(equipment)
                                }
                            }
                        )) {
                            Label(equipment.rawValue, systemImage: equipment.icon)
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
    
    private var durationSection: some View {
        VStack(alignment: .leading) {
            Text("Duration")
                .font(.headline)
            Text(formatDuration(videoDuration))
                .foregroundColor(.gray)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Main View
struct VideoUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storageManager = StorageManager.shared
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var uploadProgress: Double = 0
    @State private var uploadState: UploadState = .idle
    
    // Metadata form states
    @State private var title = ""
    @State private var selectedType: WorkoutType = .yoga
    @State private var selectedLevel: WorkoutLevel = .beginner
    @State private var selectedEquipment: Set<WorkoutEquipment> = []
    @State private var videoDuration: TimeInterval = 0
    @State private var showMetadataForm = false
    @State private var currentUsername: String = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if showMetadataForm {
                    MetadataFormView(
                        title: $title,
                        selectedType: $selectedType,
                        selectedLevel: $selectedLevel,
                        selectedEquipment: $selectedEquipment,
                        videoDuration: videoDuration,
                        uploadState: uploadState,
                        uploadProgress: uploadProgress,
                        onUpload: handleUpload
                    )
                } else {
                    VideoSelectionView(
                        isLoading: isLoading,
                        errorMessage: errorMessage,
                        onSelect: { },
                        selectedItem: $selectedItem
                    )
                }
            }
            .navigationTitle(showMetadataForm ? "Workout Details" : "Upload Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(showMetadataForm ? "Back" : "Cancel") {
                        if showMetadataForm {
                            showMetadataForm = false
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(uploadState == .uploading || uploadState == .processing)
                }
            }
        }
        .task {
            if let userId = Auth.auth().currentUser?.uid,
               let user = try? await firestoreManager.getUser(id: userId) {
                currentUsername = user.username
                print("👤 Current username loaded: \(currentUsername)")
            }
        }
        .onChange(of: selectedItem) { _ in
            handleSelection()
        }
    }
    
    private func handleSelection() {
        guard let item = selectedItem else { return }
        
        Task {
            do {
                isLoading = true
                errorMessage = nil
                
                guard let movie = try await item.loadTransferable(type: MovieTransferable.self) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load video"])
                }
                
                // Get video duration
                let asset = AVAsset(url: movie.url)
                videoDuration = try await asset.load(.duration).seconds
                
                selectedVideoURL = movie.url
                showMetadataForm = true
                print("✅ Video selected successfully")
                
            } catch {
                errorMessage = error.localizedDescription
                print("❌ Error selecting video: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
    
    private func handleUpload() {
        guard let videoURL = selectedVideoURL else {
            uploadState = .error("No video selected")
            return
        }
        
        // Start optimistic UI updates
        uploadState = .uploading
        
        Task {
            do {
                // Generate a unique filename
                let fileExtension = videoURL.pathExtension
                let filename = "video_\(UUID().uuidString).\(fileExtension)"
                
                // Start upload with progress tracking
                let downloadURL = try await withProgress { progress in
                    uploadProgress = progress
                } operation: {
                    try await storageManager.uploadVideo(
                        from: videoURL,
                        filename: filename,
                        title: title,
                        workoutType: selectedType,
                        level: selectedLevel,
                        duration: videoDuration,
                        trainer: currentUsername
                    )
                }
                
                // Update UI to processing state
                await MainActor.run {
                    uploadState = .processing
                }
                
                // Create video document in Firestore
                let video = VideoModel(
                    id: filename.replacingOccurrences(of: ".\(fileExtension)", with: ""),
                    title: title,
                    videoURL: downloadURL,
                    thumbnailURL: nil,
                    duration: videoDuration,
                    workout: WorkoutMetadata(
                        type: selectedType,
                        level: selectedLevel,
                        equipment: Array(selectedEquipment),
                        durationSeconds: Int(videoDuration),
                        estimatedCalories: estimateCalories(duration: videoDuration, type: selectedType, level: selectedLevel)
                    ),
                    likeCount: 0,
                    comments: 0,
                    isBookmarked: false,
                    trainer: currentUsername,
                    userId: Auth.auth().currentUser?.uid ?? ""
                )
                
                try await firestoreManager.createVideo(video)
                
                // Update user's post count
                if let userId = Auth.auth().currentUser?.uid {
                    try await firestoreManager.incrementUserPostCount(userId: userId)
                }
                
                // Clean up local file
                try? FileManager.default.removeItem(at: videoURL)
                
                // Show success state briefly before dismissing
                await MainActor.run {
                    uploadState = .success
                    uploadProgress = 1.0
                    
                    // Dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        dismiss()
                    }
                }
                
            } catch {
                await MainActor.run {
                    uploadState = .error(error.localizedDescription)
                }
            }
        }
    }
    
    private func withProgress<T>(
        _ progressHandler: @escaping (Double) -> Void,
        operation: () async throws -> T
    ) async throws -> T {
        // Start progress updates
        let progressTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    // Simulate progress if actual progress is not available
                    if uploadProgress < 0.95 {
                        uploadProgress += 0.05
                    }
                }
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        defer {
            progressTask.cancel()
        }
        
        return try await operation()
    }
    
    private func estimateCalories(duration: TimeInterval, type: WorkoutType, level: WorkoutLevel) -> Int {
        // Basic calorie estimation based on workout type, duration, and intensity
        let minutes = duration / 60
        let baseRate: Double
        
        switch type {
        case .hiit:
            baseRate = 12 // ~720 calories per hour
        case .strength:
            baseRate = 8 // ~480 calories per hour
        case .cardio:
            baseRate = 10 // ~600 calories per hour
        case .yoga, .pilates:
            baseRate = 6 // ~360 calories per hour
        case .stretching:
            baseRate = 3 // ~180 calories per hour
        case .bodyweight:
            baseRate = 7 // ~420 calories per hour
        case .other:
            baseRate = 5 // ~300 calories per hour
        case .all:
            baseRate = 5 // Should never happen, but providing a default
        }
        
        // Adjust for difficulty
        let intensityMultiplier: Double
        switch level {
        case .beginner:
            intensityMultiplier = 0.8
        case .intermediate:
            intensityMultiplier = 1.0
        case .advanced:
            intensityMultiplier = 1.2
        }
        
        return Int(minutes * baseRate * intensityMultiplier)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// Helper for loading video data
struct MovieTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "video.mov")
            
            if FileManager.default.fileExists(atPath: copy.path()) {
                try FileManager.default.removeItem(at: copy)
            }
            
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
} 