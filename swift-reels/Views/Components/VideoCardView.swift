import SwiftUI

struct VideoCardView: View {
    let video: VideoModel
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Video Thumbnail
            ZStack {
                if let thumbnailURL = video.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                } else {
                    Color.gray.opacity(0.3)
                }
                
                Image(systemName: "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .shadow(radius: 5)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
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
                    Label("\(video.workout.type.rawValue)", systemImage: "figure.run")
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
} 