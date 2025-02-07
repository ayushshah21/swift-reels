import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var agoraManager = AgoraManager.shared
    @State private var selectedTab = 0
    @State private var showUploadSheet = false
    @State private var previousTab = 0  // Track previous tab
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        ReelsFeedView()
                    }
                    .tabItem {
                        VStack {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                    }
                    .tag(0)
                    
                    SearchView()
                        .tabItem {
                            VStack {
                                Image(systemName: "magnifyingglass")
                                Text("Discover")
                            }
                        }
                        .tag(1)
                    
                    NavigationStack {
                        LiveStreamingView()
                    }
                    .tabItem {
                        VStack {
                            Image(systemName: "video.fill")
                            Text("Live")
                        }
                    }
                    .tag(2)
                    
                    NavigationStack {
                        PartnerSessionsView()
                    }
                    .tabItem {
                        VStack {
                            Image(systemName: "figure.2.arms.open")
                            Text("Partners")
                        }
                    }
                    .tag(3)
                    
                    NavigationStack {
                        CommunityReelsView()
                    }
                    .tabItem {
                        VStack {
                            Image(systemName: "film")
                            Text("Community")
                        }
                    }
                    .tag(4)
                    
                    ProfileView()
                        .tabItem {
                            VStack {
                                Image(systemName: "person.fill")
                                Text("Me")
                            }
                        }
                        .tag(5)
                }
                .tint(.primary)
                .sheet(isPresented: $showUploadSheet) {
                    VideoUploadView()
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
            
            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = .systemBackground
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
} 
