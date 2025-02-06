import SwiftUI
import AgoraRtcKit

struct AgoraVideoView: UIViewRepresentable {
    @StateObject private var agoraManager = AgoraManager.shared
    
    func makeUIView(context: Context) -> UIView {
        print("\n📱 Creating AgoraVideoView")
        print("   Current role: \(agoraManager.currentRole == .broadcaster ? "broadcaster" : "audience")")
        print("   Is in channel: \(agoraManager.isInChannel)")
        print("   Channel name: \(agoraManager.currentChannelName ?? "none")")
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        containerView.backgroundColor = .black
        
        if agoraManager.currentRole == .audience {
            print("\n🔄 Setting up audience view...")
            
            // Create remote view with explicit size
            let remoteView = UIView(frame: containerView.bounds)
            remoteView.backgroundColor = .clear
            remoteView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.addSubview(remoteView)
            
            print("   Container view frame: \(containerView.frame)")
            print("   Remote view frame: \(remoteView.frame)")
            print("   Remote view in hierarchy: \(remoteView.superview != nil)")
            
            // Force layout if needed
            containerView.layoutIfNeeded()
            
            // Important: Set up remote video IMMEDIATELY after adding to view hierarchy
            print("   Setting up remote video container immediately")
            agoraManager.setupInitialRemoteVideo(view: remoteView)
            
            print("✅ Audience view setup complete")
        } else if agoraManager.currentRole == .broadcaster {
            print("\n🔄 Setting up broadcaster view...")
            agoraManager.setupLocalVideo(view: containerView)
            print("✅ Broadcaster view setup complete")
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        print("\n🔄 UpdateUIView called")
        print("   Current role: \(agoraManager.currentRole == .broadcaster ? "broadcaster" : "audience")")
        print("   Is in channel: \(agoraManager.isInChannel)")
        print("   Channel name: \(agoraManager.currentChannelName ?? "none")")
        print("   View frame: \(uiView.frame)")
        
        if agoraManager.currentRole == .audience {
            // Ensure remote view is properly set up
            if let remoteView = uiView.subviews.first {
                remoteView.frame = uiView.bounds
                print("   Remote view frame updated: \(remoteView.frame)")
            }
        }
    }
} 