Based on the latest Agora documentation and practices as of February 2025, here's how you can implement video recording for your Swift application:

## Cloud Recording

Agora now offers a robust cloud recording solution, which is the recommended approach for most applications:

1. **Setup**: 
   - Use the Cloud Recording REST API to manage recording sessions.
   - Ensure your Agora project has cloud recording enabled.

2. **Implementation**:
   ```swift
   import AgoraRtcKit
   
   class RecordingManager {
       private let appId = "YOUR_APP_ID"
       private let serverUrl = "YOUR_RECORDING_SERVER_URL"
       
       func startRecording(channelName: String) {
           let url = URL(string: "\(serverUrl)/api/start/call")!
           var request = URLRequest(url: url)
           request.httpMethod = "POST"
           request.addValue("application/json", forHTTPHeaderField: "Content-Type")
           
           let body: [String: Any] = [
               "appId": appId,
               "channel": channelName
           ]
           
           request.httpBody = try? JSONSerialization.data(withJSONObject: body)
           
           URLSession.shared.dataTask(with: request) { data, response, error in
               // Handle response and store recording details
           }.resume()
       }
       
       func stopRecording(channelName: String, rid: String, sid: String, uid: UInt) {
           let url = URL(string: "\(serverUrl)/api/stop/call")!
           var request = URLRequest(url: url)
           request.httpMethod = "POST"
           request.addValue("application/json", forHTTPHeaderField: "Content-Type")
           
           let body: [String: Any] = [
               "channel": channelName,
               "rid": rid,
               "sid": sid,
               "uid": uid
           ]
           
           request.httpBody = try? JSONSerialization.data(withJSONObject: body)
           
           URLSession.shared.dataTask(with: request) { data, response, error in
               // Handle stop recording response
           }.resume()
       }
   }
   ```

3. **Storage**: 
   - Recordings are stored in cloud storage (e.g., Amazon S3).
   - Configure your storage settings in the Agora Console.

## On-Premise Recording

For applications requiring local recording:

1. **Setup**:
   - Import the Agora SDK: `import AgoraRtcKit`
   - Ensure necessary permissions are set in Info.plist.

2. **Implementation**:
   ```swift
   class VideoCallViewController: UIViewController {
       private var agoraKit: AgoraRtcEngineKit?
       private var recordingPath: String?
       
       func startRecording() {
           let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
           let fileName = "AgoraVideoRecording_\(Date()).mp4"
           recordingPath = documentsPath.appendingPathComponent(fileName).path
           
           agoraKit?.startAudioRecording(recordingPath!, quality: .high)
       }
       
       func stopRecording() {
           agoraKit?.stopAudioRecording()
           // Handle the recorded file at `recordingPath`
       }
   }
   ```

3. **Permissions**: 
   Add to Info.plist:
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>We need access to your microphone for recording</string>
   ```

## Best Practices

1. **User Consent**: Always obtain explicit user consent before starting a recording.
2. **Error Handling**: Implement robust error handling for network issues or storage failures.
3. **Scalability**: Cloud recording is more scalable for large-scale applications.
4. **Privacy**: Ensure compliance with privacy regulations when storing recordings.
5. **Testing**: Thoroughly test recording functionality across different network conditions.

Remember to refer to the [official Agora documentation](https://docs.agora.io/en/cloud-recording/overview/product-overview?platform=All%20Platforms) for the most up-to-date information and best practices[22][29].

Since you're using Firebase and don't have a separate server, you can implement video recording and storage directly in your Swift iOS app using Firebase Storage. Here's how you can approach this:

1. Record the video using AVFoundation or UIImagePickerController in your app.

2. Once the video is recorded, upload it directly to Firebase Storage:

```swift
import FirebaseStorage

func uploadVideo(videoURL: URL) {
    let storage = Storage.storage()
    let videoName = UUID().uuidString + ".mp4"
    let storageRef = storage.reference().child("videos/\(videoName)")
    
    storageRef.putFile(from: videoURL, metadata: nil) { metadata, error in
        if let error = error {
            print("Error uploading video: \(error.localizedDescription)")
        } else {
            storageRef.downloadURL { url, error in
                if let downloadURL = url {
                    // Save this downloadURL to Firestore or Realtime Database
                    print("Video uploaded successfully. URL: \(downloadURL)")
                }
            }
        }
    }
}
```

3. After uploading, save metadata about the video (like its download URL) to Firestore or Realtime Database for easy retrieval later.

4. To play the video, use AVPlayer with the download URL:

```swift
import AVKit

func playVideo(url: URL) {
    let player = AVPlayer(url: url)
    let playerViewController = AVPlayerViewController()
    playerViewController.player = player
    present(playerViewController, animated: true) {
        player.play()
    }
}
```

This approach allows you to handle video recording and storage entirely within your iOS app using Firebase, without needing a separate server[21][28][30].

