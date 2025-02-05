# ReelAI Firebase Schema Design

Below is the Firestore schema design for ReelAI, a TikTok-style short video app. The schema is organized into main collections with efficient subcollections for scalability.

## 1. `users` Collection

Each authenticated user has a corresponding document with matching `userId`:

```
users (collection)
 └─ {userId} (document)
     ├─ email: String           // From Firebase Auth
     ├─ username: String        // Display name
     ├─ profilePicUrl: String?  // Optional profile picture
     ├─ bio: String?           // Optional user bio
     ├─ followersCount: Int    // Denormalized counter
     ├─ followingCount: Int    // Denormalized counter
     ├─ postsCount: Int        // Number of videos posted
     ├─ createdAt: Timestamp   // Account creation date
     └─ following (subcollection)
          └─ {followedUserId} (document)
               └─ followedAt: Timestamp
```

## 2. `videos` Collection

Each video post is stored as a document with metadata and engagement subcollections:

```
videos (collection)
 └─ {videoId} (document)
     ├─ userId: String         // Reference to uploader
     ├─ videoUrl: String      // Firebase Storage URL
     ├─ thumbnailUrl: String? // Optional preview image
     ├─ description: String   // Video caption/description
     ├─ likeCount: Int       // Denormalized counter
     ├─ commentCount: Int    // Denormalized counter
     ├─ shareCount: Int      // Track shares
     ├─ createdAt: Timestamp // Upload time
     │
     ├─ // Denormalized uploader data for quick display
     ├─ uploaderName: String
     ├─ uploaderProfilePic: String?
     │
     ├─ comments (subcollection)
     │    └─ {commentId} (document)
     │         ├─ userId: String
     │         ├─ text: String
     │         ├─ timestamp: Timestamp
     │         ├─ commenterName: String      // Denormalized
     │         └─ commenterProfilePic: String? // Denormalized
     │
     └─ likes (subcollection)
          └─ {userId} (document)
               └─ likedAt: Timestamp
```

## Implementation Notes

1. **Authentication Flow**:
   - User signs up/in through Firebase Auth
   - Create corresponding user document in `users` collection
   - Use Auth UID as document ID for direct reference

2. **Video Upload Flow**:
   - Upload video file to Firebase Storage
   - Create video document with metadata
   - Update user's `postsCount`

3. **Engagement Actions**:
   - Likes: Add/remove document in `likes` subcollection
   - Comments: Add to `comments` subcollection
   - Following: Add to user's `following` subcollection

4. **Query Patterns**:
   - Feed: Query `videos` collection ordered by `createdAt`
   - User Profile: Query `videos` where `userId` matches
   - Likes: Check existence in `likes` subcollection
   - Comments: Paginate through `comments` subcollection

5. **Denormalization Strategy**:
   - Store uploader info in video documents for feed display
   - Store commenter info in comment documents
   - Maintain counter fields for quick stats display

This schema supports:

- Efficient video feed queries
- User profile views
- Social interactions (likes, comments, follows)
- Quick access to engagement metrics
- Scalable structure for future features

Future Considerations:

- Add hashtags/categories for video discovery
- Implement video processing status tracking
- Add user preferences and settings
- Support for notifications system
