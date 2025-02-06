import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var agoraManager = AgoraManager.shared
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                TabView {
                    NavigationStack {
                        ReelsFeedView()
                    }
                    .tabItem {
                        Label("Feed", systemImage: "play.square")
                    }
                    
                    SearchView()
                        .tabItem {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                    
                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person")
                        }
                }
            } else {
                AuthView()
            }
        }
        .environmentObject(authViewModel)
        .onAppear {
            print("🔄 ContentView appeared, authViewModel initialized")
            if agoraManager.isInitialized {
                print("✅ Agora SDK initialized successfully")
            } else if let error = agoraManager.error {
                print("❌ Agora SDK initialization failed: \(error)")
            }
        }
    }
} 
