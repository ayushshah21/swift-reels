//
//  swift_reelsApp.swift
//  swift-reels
//
//  Created by Ayush Shah on 2/3/25.
//

import SwiftUI
import FirebaseCore

@main
struct swift_reelsApp: App {
    init() {
        FirebaseApp.configure()
        print("🔥 Firebase configured!")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
