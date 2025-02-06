import SwiftUI
import AgoraRtcKit

struct AgoraVideoView: UIViewRepresentable {
    @StateObject private var agoraManager = AgoraManager.shared
    
    func makeUIView(context: Context) -> UIView {
        print("\n📱 Creating AgoraVideoView")
        print("   Current role: \(agoraManager.currentRole == .broadcaster ? "broadcaster" : "audience")")
        print("   Is in channel: \(agoraManager.isInChannel)")
        print("   Channel name: \(agoraManager.currentChannelName ?? "none")")
        
        let view = UIView()
        view.backgroundColor = .black
        
        if agoraManager.currentRole == .audience {
            print("\n🔄 Setting up audience view...")
            
            // For audience, set up the remote container view immediately
            let remoteView = UIView()
            remoteView.frame = view.bounds
            remoteView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(remoteView)
            
            print("   Remote view frame: \(remoteView.frame)")
            print("   Main view frame: \(view.frame)")
            print("   Remote view in hierarchy: \(remoteView.superview != nil)")
            
            // Important: Set up remote video AFTER adding to view hierarchy
            print("   Scheduling async remote video setup...")
            DispatchQueue.main.async {
                print("\n🔄 Starting async setup of remote video container")
                print("   Remote view frame (async): \(remoteView.frame)")
                print("   Remote view in hierarchy (async): \(remoteView.superview != nil)")
                agoraManager.setupInitialRemoteVideo(view: remoteView)
            }
            print("✅ Audience view setup initiated")
        } else if agoraManager.currentRole == .broadcaster {
            print("\n🔄 Setting up broadcaster view...")
            // For broadcaster, set up local video
            agoraManager.setupLocalVideo(view: view)
            print("✅ Broadcaster view setup complete")
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        print("\n🔄 UpdateUIView called")
        print("   Current role: \(agoraManager.currentRole == .broadcaster ? "broadcaster" : "audience")")
        print("   Is in channel: \(agoraManager.isInChannel)")
        print("   Channel name: \(agoraManager.currentChannelName ?? "none")")
        print("   View frame: \(uiView.frame)")
    }
} 