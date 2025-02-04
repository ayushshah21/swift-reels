import SwiftUI

struct Theme {
    static let primary = Color.blue
    static let background = Color.black
    static let card = Color(white: 0.12)
    static let text = Color.white
    static let secondaryText = Color(white: 0.7)
    
    static let gradient = LinearGradient(
        colors: [.clear, .black.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    struct Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.7)
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.2)
    }
} 