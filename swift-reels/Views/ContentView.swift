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
                    
                    // Center upload button - just a placeholder view
                    Color.clear
                        .tabItem {
                            VStack {
                                Image(systemName: "plus.square.fill")
                                    .environment(\.symbolVariants, .none)
                                Text("Upload")
                            }
                        }
                        .tag(3)
                    
                    ProfileView()
                        .tabItem {
                            VStack {
                                Image(systemName: "person.fill")
                                Text("Me")
                            }
                        }
                        .tag(4)
                }
                .tint(.primary)
                .onChange(of: selectedTab) { newValue in
                    if newValue == 3 {
                        // Store current tab before showing upload sheet
                        previousTab = selectedTab
                        // Show upload sheet and return to previous tab
                        showUploadSheet = true
                        selectedTab = previousTab
                    }
                }
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
