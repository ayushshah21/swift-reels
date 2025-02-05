import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var firestoreManager = FirestoreManager.shared
    
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
        }
    }
} 
