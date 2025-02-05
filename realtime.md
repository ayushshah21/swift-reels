# Real-Time Social Features

One of the strengths of Firebase is real-time capabilities – changes in the database can be instantly synchronized to clients. In a TikTok-style app, real-time updates enhance the experience (e.g., seeing new comments appear live, like counts updating, or perhaps live presence of viewers). Here we focus on using Firestore to implement real-time interactions, and designing a scalable system for likes and comments that updates in real-time.

Firestore-based Real-Time Interactions
Firestore offers real-time listeners on documents and queries. By attaching a listener, your app will get callback events whenever data changes, usually within a second or two. This is perfect for social features:

Listening on the comments subcollection of a video to update the UI as new comments arrive.
Listening on a video document to observe changes in like count or other metadata (if those can change while the user is viewing).
Possibly listening on a user document for live status updates (e.g., if you show when a user is online or their follower count).
Using Snapshot Listeners in Swift: In Swift, you can use addSnapshotListener on a DocumentReference or a Query. For example, to listen for new comments on a video:

swift
Copy
Edit
let commentsRef = Firestore.firestore()
    .collection("videos").document(videoId)
    .collection("comments").order(by: "timestamp")
commentsRef.addSnapshotListener { querySnapshot, error in
    guard let snapshot = querySnapshot else {
        print("Error listening for comments: \(error?.localizedDescription ?? "Unknown")")
        return
    }
    // Process document changes
    for change in snapshot.documentChanges {
        if change.type == .added {
            let newCommentData = change.document.data()
            // Convert to Comment model and append to local list
        }
        // You can handle .modified or .removed as well if needed
    }
}
When you first attach the listener, it will fetch the current data (e.g., existing comments) and then call again on every new addition. The snapshot provides documentChanges so you know what changed since the last update. This allows you to, say, append a newly added comment to your list view without refetching everything. Firestore guarantees order if you specified an order in the query (like by timestamp), including for incremental updates.

Similarly, to reflect changes in like count, you could set a listener on the video document itself:

swift
Copy
Edit
let videoDocRef = Firestore.firestore().collection("videos").document(videoId)
videoDocRef.addSnapshotListener { docSnapshot, error in
    guard let doc = docSnapshot else { return }
    if let data = doc.data(), let newLikeCount = data["likeCount"] as? Int {
        updateLikeCountLabel(newLikeCount)
    }
}
Now, if anywhere in the database that video’s likeCount field is updated, the UI will update in realtime. This is powerful for scenarios where multiple people could be liking or commenting on the same content around the same time (e.g., a popular video).

Real-time feed updates: If your app’s main feed is just the latest videos, you could also listen to the videos collection (with a query for new videos). For instance, videosRef.order(by: "timestamp", descending: true).limit(10).addSnapshotListener { ... } would let you know if a new video is added (though a new video might not need to appear instantly for all users unless it’s a live feed). Many social apps just pull to refresh for new content, but it’s possible to push new items in realtime.

Advantages of Firestore for realtime: It uses web-sockets under the hood to push updates to clients. This means minimal latency and no polling. It’s also efficient – the SDK will only re-download changed documents, and if you have offline persistence on, it can even handle connectivity dropouts gracefully (caching updates until back online). Do note that each open listener counts as an active connection and incurs read operations whenever updates come in. So don’t put a listener on every single video in a feed concurrently if you don’t need to. Instead, attach listeners when the user is viewing a particular piece of content or when it’s relevant.

Presence and Typing Indicators: Although not explicitly asked, real-time features might include showing if someone is typing a comment or if a user is online. Firestore can do this but sometimes the Realtime Database is used for presence because it has built-in support for onDisconnect. However, you can implement presence in Firestore by updating a field in user docs like lastActive or isOnline and use security rules / Cloud Functions to auto-set offline. This is advanced, but mentionable if building chat or live features.

In summary, using addSnapshotListener on relevant data ensures the app stays up-to-date without user manual refresh. The UI stays lively – new likes reflect immediately, new comments pop in as they’re posted, etc., creating a social experience that feels instant.

Designing a Scalable Likes and Comments System (Real-time)
Earlier we designed the data model for likes and comments. Now let’s focus on how to manage updates to these in real-time and at scale.

Real-time Comments: As shown, listening on the comments subcollection handles live updates nicely. For adding a comment, you’d use something like commentsRef.addDocument(data: ["text": ..., "userId": ..., "timestamp": FieldValue.serverTimestamp()]). Thanks to the listener, the new comment will show up for all users viewing that video. This works well as long as the number of comments coming in is not extremely high per second (Firestore can handle a moderate stream of writes). If a video is receiving hundreds of comments a second (viral scenario), Firestore writes might queue a bit; in such extreme cases, some apps might switch to a streaming solution or buffer comments – but realistically, Firestore will handle typical loads for an app of this nature.

One consideration: pagination of comments. If a video has thousands of comments, you won’t want to load them all at once. You might initially query the first 20 or 50, and then paginate. Real-time listeners can be applied to a query with limit(), but if you want to get updates only for the first page, that can complicate things when older comments exist. A common approach is to listen for new comments (those with timestamp greater than when you loaded initial batch). You can achieve that by remembering the timestamp of the last loaded comment and then using a query like .order(by: "timestamp").start(after: lastTimestamp). This way your listener only fires for comments beyond the current view (essentially streaming new ones). For simplicity, you might not need this unless comment volume is very high.

Real-time Likes: For likes, if we have a counter on the video doc, updating it via FieldValue.increment will trigger any listener on that doc (as shown). The increment is atomic on the server – two people liking at nearly the same time will both be applied, and the final count reflects both​
REDDIT.COM
. However, the intermediate steps might not be seen by clients if updates are too fast; usually not an issue unless dozens of likes per second. If using a sharded counter, then the video doc might not have the direct count (the count might be computed by summing sub-shards). In that case, a little more work is needed – possibly a Cloud Function that updates the main count periodically. But let's assume for now a single counter suffices. When a user taps “like,” you increment locally for snappier UI (optimistic update) and send the update to Firestore. The server value will confirm and propagate to others. If someone else’s like comes in, the listener will adjust the count.

If you opted for a likes subcollection approach, you might not want to listen to every like document addition (if a video has thousands of likes, you don't want to pull all those in real-time). Instead, use the presence/absence of current user’s like and the count:

For the current user, you can listen specifically to their like doc: videoRef.collection("likes").document(myUserId).addSnapshotListener – this will tell you if that document is created or deleted (i.e., like or unlike by this user, potentially from another device).
For the count, still rely on the aggregated field on the video doc. That field can be updated by a Cloud Function to keep it correct: e.g., a function triggers on create/delete in likes subcollection and does videoRef.update({likeCount: FieldValue.increment(...)} ). This ensures even if multiple likes happen, each triggers an accurate increment​
REDDIT.COM
. Cloud Functions run sequentially per document, so it avoids race conditions on the counter.
Concurrency Considerations: Firestore transactions could also be used when multiple fields or docs need to update together. For example, if we wanted to ensure that a like’s creation and the increment of the counter happen atomically, one could use Firestore.firestore().runTransaction to create the like doc and increment the field in one transaction. This is an advanced but useful tool. However, for simplicity, many rely on the eventual consistency model: create like doc (if not exists) -> increment count. If an increment fails (maybe a security rule triggers, etc.), you’d handle the error.

Scaling Many Listeners: Each real-time listener is an open channel. Mobile apps can handle several safely, but you wouldn’t, for instance, want to have 100 active listeners for 100 videos simultaneously on a client (that would be inefficient). Design the app to listen only to what the user is currently engaging with (e.g., the comments for the video currently open, maybe likes for a video on screen). For the feed list of 10 videos, you might not need a live listener on all 10 like counts – you could just show the like count as of when fetched, and maybe update when the user opens the detail or double-taps to like. If you did want the feed to update counts live, you could attach listeners to those 10 docs and remove them as items scroll out of view, etc., but that’s optional complexity.

Latency and Offline: Firestore’s realtime updates usually come very fast (often under 1 second). If the network is offline, the SDK will serve data from cache and queue writes. This means a user could like a video while offline – the UI can update to liked state immediately (because you optimistically set it, and Firestore will mark the doc as changed locally). When network resumes, the like will be sent to server. This is nice for user experience (app doesn’t feel stuck when offline). However, other users obviously won’t see it until it actually goes through. This is usually fine.

Firestore vs. Realtime Database for Chat/Comments: Some developers wonder if Firestore is good for real-time chat or should they use the older Realtime Database. Firestore is generally fine for chat and comments – it handles real-time updates and scales better with large data sets. The older RTDB has simpler sharding but more limited querying. Since we already are using Firestore for everything else, it makes sense to keep using it for consistency.

Notification of new content: If implementing features like a global live feed or notifications (“someone commented on your video”), real-time listeners or Cloud Functions can help. For example, a Cloud Function can listen to new comment docs and send a push notification via FCM to the video’s owner. Or you could have the app listen on a users/{uid}/notifications collection where new entries are added when things happen. This strays into backend logic beyond Firestore, but it’s enabled by these real-time triggers.

In summary, Firestore’s real-time capabilities, combined with a proper data structure, allow you to create a highly interactive app. By using listeners on comments and likes, you ensure that the social interactions remain instant and synchronized across users, which is essential for engagement. Just keep an eye on the volume of updates and use batching or sharding if necessary to stay within Firestore’s throughput limits at scale.