import Foundation
import FirebaseCore
import FirebaseAnalytics
import FirebaseAuth

@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    private let auth: Auth
    
    @Published var isConnected = false
    
    private init() {
        self.auth = Auth.auth()
    }
    
    func testConnection() {
        // Test Analytics
        Analytics.logEvent("app_opened", parameters: [
            "platform": "iOS",
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ])
        print("✅ Analytics configured")
        
        // Test Auth
        if let user = auth.currentUser {
            print("✅ User already signed in: \(user.uid)")
        } else {
            print("ℹ️ No user signed in (this is normal)")
        }
    }
}

