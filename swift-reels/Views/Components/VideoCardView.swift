import SwiftUI

struct VideoCardView: View {
    let video: VideoModel
    @State private var isPressed = false
    @State private var isLoadingThumbnail = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Video Thumbnail
            ZStack {
                if let thumbnailURL = video.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .empty:
                            thumbnailPlaceholder
                                .overlay {
                                    ProgressView()
                                        .tint(.white)
                                }
                                .transition(.opacity)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                                .transition(.opacity)
                        case .failure(let error):
                            thumbnailPlaceholder
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.title2)
                                            .foregroundColor(.orange)
                                        Text("Failed to load thumbnail")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                        @unknown default:
                            thumbnailPlaceholder
                        }
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    thumbnailPlaceholder
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Play Button Overlay
                Circle()
                    .fill(.black.opacity(0.5))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    )
                    .shadow(radius: 5)
            }
            
            // Video Info
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("with \(video.trainer)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    Label("\(video.workout.level.rawValue)", systemImage: "flame.fill")
                        .foregroundColor(.orange)
                    Label("\(video.workout.type.rawValue)", systemImage: video.workout.type.icon)
                        .foregroundColor(.blue)
                }
                .font(.caption)
                
                HStack {
                    Label("\(video.likeCount)", systemImage: "heart.fill")
                        .foregroundColor(.red)
                    Label("\(video.comments)", systemImage: "message.fill")
                        .foregroundColor(.blue)
                }
                .font(.caption)
                .padding(.top, 4)
            }
            .padding()
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(Theme.Animation.spring, value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var thumbnailPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.3)
            VStack(spacing: 8) {
                Image(systemName: video.workout.type.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                Text(video.workout.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }
} 