# Implementing Partner Workout Video Reels in Swift

This document outlines a roadmap for taking your partner workout feature to the next level by automatically recording live sessions and posting short (≤2-minute) workout videos as community reels. This guide uses **AVFoundation** for recording, **Agora** for live streaming, and **Firebase** for storage and data management.

## Table of Contents

1. [Automatically Record Partner Workouts](#automatically-record-partner-workouts)
2. [Upload & Store the Video](#upload--store-the-video)
3. [Implement a Community Feed for Reels](#implement-a-community-feed-for-reels)
4. [Optimize Performance](#optimize-performance)
5. [References](#references)

---

## 1. Automatically Record Partner Workouts

### a. Setup AVFoundation Capture

- **Create an AVCaptureSession** and add inputs:
  - **Video Input:** Use `AVCaptureDeviceInput` with the built-in camera.
  - **Audio Input:** Use `AVCaptureDeviceInput` with the device microphone.
- **Add an AVCaptureMovieFileOutput** to record video files.
- Ensure you include the proper usage descriptions in your `Info.plist` (e.g., `NSCameraUsageDescription` and `NSMicrophoneUsageDescription`).

### b. Start Recording When the Session Begins

- Start recording once the workout session starts (e.g., when both partners join the Agora channel).  
- Example:

  ```swift
  // Prepare a fresh file URL (e.g. in a temporary directory)
  let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("workout.mp4")
  if FileManager.default.fileExists(atPath: fileURL.path) {
      try? FileManager.default.removeItem(at: fileURL)
  }
  movieOutput.startRecording(to: fileURL, recordingDelegate: self)
  isRecording = true
  ```

- Implement `AVCaptureFileOutputRecordingDelegate` to handle recording start, finish, and errors.

### c. Stop Recording on Session End

- When the workout ends (or when the 2‑minute cap is reached), call:

  ```swift
  movieOutput.stopRecording()
  isRecording = false
  ```

- The delegate method `fileOutput(_:didFinishRecordingTo:from:error:)` will be invoked once final writing is complete.

### d. Enforce a 2‑Minute Hard Cap

- Set the maximum recorded duration:

  ```swift
  let maxDuration = CMTimeMake(value: 120, timescale: 1) // 120 seconds
  movieOutput.maxRecordedDuration = maxDuration
  ```

- This ensures that only recordings shorter than or equal to 2 minutes are produced.

---

## 2. Upload & Store the Video

### a. Compress & Optimize the Video

- Use an `AVAssetExportSession` to compress the video before upload:

  ```swift
  func compressVideo(inputURL: URL, outputURL: URL, completion: @escaping (URL?)->Void) {
      let asset = AVURLAsset(url: inputURL)
      guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
          completion(nil)
          return
      }
      exportSession.outputURL = outputURL
      exportSession.outputFileType = .mp4
      exportSession.shouldOptimizeForNetworkUse = true
      exportSession.exportAsynchronously {
          if exportSession.status == .completed {
              completion(outputURL)
          } else {
              completion(nil)
          }
      }
  }
  ```

- The `shouldOptimizeForNetworkUse` flag ensures the file’s metadata is placed at the beginning (fast-start streaming).

### b. Upload to Firebase Storage

- After compression, upload the file to Firebase:

  ```swift
  let storageRef = Storage.storage().reference()
  let videoRef = storageRef.child("reels/\(UUID().uuidString).mp4")
  let metadata = StorageMetadata()
  metadata.contentType = "video/mp4"
  
  videoRef.putFile(from: outputURL, metadata: metadata) { meta, error in
      if let error = error {
          print("Upload error: \(error)")
          return
      }
      videoRef.downloadURL { url, error in
          if let downloadURL = url {
              // Proceed to save metadata in Firestore
          }
      }
  }
  ```

### c. Save Video Metadata in Firestore

- Create a new document in the `communityReels` collection:

  ```swift
  let db = Firestore.firestore()
  let reelData: [String: Any] = [
      "videoURL": downloadURL.absoluteString,
      "duration": 120,  // actual duration in seconds
      "participants": [currentUserId, partnerUserId],
      "timestamp": FieldValue.serverTimestamp()
  ]
  db.collection("communityReels").addDocument(data: reelData) { err in
      if let err = err {
          print("Error adding reel document: \(err)")
      }
  }
  ```

- **Access Control:** Ensure that only users who participated in the session can post a reel. This can be enforced via client logic and Firestore Security Rules.

---

## 3. Implement a Community Feed for Reels

### a. Fetching Reels from Firestore

- Query the `communityReels` collection, ordered by timestamp:

  ```swift
  db.collection("communityReels")
    .order(by: "timestamp", descending: true)
    .limit(to: 20)
    .getDocuments { snapshot, error in
        // Parse documents into your reel model
  }
  ```

- Optionally, set up a real‑time listener for dynamic updates.

### b. Displaying Videos

- In SwiftUI (iOS 14+), you can use `VideoPlayer`:

  ```swift
  import AVKit
  
  VideoPlayer(player: AVPlayer(url: videoURL))
      .frame(height: 300)
  ```

- For more customization or in UIKit, embed an `AVPlayerLayer` or present an `AVPlayerViewController`.

### c. Streaming Playback

- Since the Firebase download URL is a streaming URL for an MP4 file (with the moov atom optimized for network use), simply assign that URL to an `AVPlayer` to allow progressive streaming.

---

## 4. Optimize Performance

- **Video Compression:** Compress the video (using `AVAssetExportSession`) before upload to reduce file size.
- **Streaming-Friendly Format:** Ensure the video is encoded as H.264 MP4 and optimized for network use.
- **Limit Duration:** With a 2‑minute cap, file sizes remain manageable.
- **Background Processing:** Perform compression and uploads off the main thread to keep the UI responsive.
- **Efficient Firestore Queries:** Use query limits and pagination when fetching community reels.
- **Cache & Thumbnails:** Consider generating and storing thumbnail images to improve feed performance. Use caching where possible.
- **Firebase Security Rules:** Enforce that only session participants can write to the `communityReels` collection.

---

## 5. References

- **AVFoundation Overview:**  
  [https://developer.apple.com/documentation/avfoundation](https://developer.apple.com/documentation/avfoundation)

- **AVCaptureSession Documentation:**  
  [https://developer.apple.com/documentation/avfoundation/avcapturesession](https://developer.apple.com/documentation/avfoundation/avcapturesession)

- **AVCaptureMovieFileOutput Documentation:**  
  [https://developer.apple.com/documentation/avfoundation/avcapturermoviefileoutput](https://developer.apple.com/documentation/avfoundation/avcapturermoviefileoutput)

- **Firebase Storage Documentation:**  
  [https://firebase.google.com/docs/storage](https://firebase.google.com/docs/storage)

- **Firebase Firestore Documentation:**  
  [https://firebase.google.com/docs/firestore](https://firebase.google.com/docs/firestore)

- **Agora Documentation:**  
  [https://docs.agora.io/en/](https://docs.agora.io/en/)

---

## Summary

This guide details how to:

- **Automatically record** partner workout sessions with AVFoundation and enforce a 2‑minute cap.
- **Compress and upload** the recorded video to Firebase Storage.
- **Save metadata** (video URL, duration, participants, timestamp) in Firestore under a `communityReels` collection.
- **Build a community feed** for session reels and stream the video using AVPlayer.
- **Optimize performance** through compression, efficient queries, and proper caching.

Following these steps and utilizing the provided documentation will help you build a robust, next‑level partner workout reels feature in your app.

*Happy coding!*

```

---

Simply save the above text in a file (e.g., `PartnerWorkoutReels.md`) and adjust code snippets as needed for your project.
