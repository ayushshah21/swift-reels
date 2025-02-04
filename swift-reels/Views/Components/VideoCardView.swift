import SwiftUI

struct VideoCardView: View {
    let video: VideoModel
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Video Preview
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(Theme.card)
                    .aspectRatio(9/16, contentMode: .fit)
                
                // Gradient overlay
                Theme.gradient
                
                // Video Info Overlay
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // Duration pill
                        Text("\(Int(video.duration/60))min")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        // Difficulty pill
                        Text(video.difficulty.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Title and trainer
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("with \(video.trainer)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Stats
                    HStack(spacing: 16) {
                        Label("\(video.likes)", systemImage: "heart.fill")
                            .foregroundColor(.red)
                        Label("\(video.comments)", systemImage: "message.fill")
                            .foregroundColor(.blue)
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
                .padding()
            }
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