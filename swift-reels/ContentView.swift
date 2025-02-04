//
//  ContentView.swift
//  swift-reels
//
//  Created by Ayush Shah on 2/3/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var videos: [VideoModel] = VideoModel.mockVideos
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // For You Feed
            ReelsFeedView(videos: videos)
                .tabItem {
                    Label("For You", systemImage: "play.fill")
                }
                .tag(0)
            
            // Following Feed (you can implement this later)
            Text("Following")
                .tabItem {
                    Label("Following", systemImage: "person.2.fill")
                }
                .tag(1)
            
            // Profile
            Text("Profile")
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(2)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            firebaseManager.testConnection()
        }
    }
}

#Preview {
    ContentView()
}
