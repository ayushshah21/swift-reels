# Firebase-Swift-Integration.md

## Firebase iOS SDK Requirements (2025)

- Use Firebase iOS SDK 10.25.0+ (current stable)
- Swift Package Manager setup:

  .package(
    url: "<https://github.com/firebase/firebase-ios-sdk.git>",
    from: "10.25.0"
  )

- Required products:
  - FirebaseFirestore
  - FirebaseFirestoreSwift (automatic with `FirebaseFirestore`)

### Key Changes Since 2024

- Codable support merged into main Firestore module
- @DocumentID/@ServerTimestamp now in FirebaseFirestore
- No separate Swift extensions package needed

**2. Firestore-Codable-Mapping.md**

### Firestore + Swift Codable (2025 Best Practices)
```

struct Video: Codable, Identifiable {
    @DocumentID var id: String?
    let metadata: WorkoutMetadata
    // ...
}

// Simplified conversion
extension Video {
    init?(document: QueryDocumentSnapshot) {
        try? self.init(data: document.data())
        self.id = document.documentID
    }
}

```

### Custom Date Handling:
```

enum FirestoreDateFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
}

```

### Key References:
- [Firestore Swift Codable Docs](https://firebase.google.com/docs/firestore/solutions/swift-codable-data-mapping)
- [2025 SDK Changes](https://firebase.google.com/support/release-notes/ios)
```

**3. SwiftUI-Performance-Optimization.md**

```markdown
### Reels Feed Best Practices
1. **Lazy Loading**
```

LazyVStack {
    ForEach(videos) { video in
        VideoCard(video: video)
            .onAppear { prefetchNextPageIfNeeded() }
    }
}

```

2. **View Recycling**
```

@ViewBuilder
func EquipmentIcon(equipment: Equipment) -> some View {
    Group {
        switch equipment {
        case .dumbbells: Image("dumbbell")
        case .bodyweight: Image("bodyweight")
        // ...
        }
    }
    .equipmentIconStyle() // Custom modifier
}

```

3. **Diffing Optimization**
- Ensure all models conform to `Identifiable`
- Use `@StateObject` for view models
```

**4. Testing-Strategy.md**

```markdown
### Vertical Slice Test Plan
1. **Unit Tests**
```

class WorkoutMetadataTests: XCTestCase {
    func testDifficultyMapping() {
        let advanced = WorkoutMetadata(difficulty: .advanced)
        XCTAssertEqual(advanced.difficultyColor, .red)
    }
}

```

2. **Snapshot Tests**
```

func testWorkoutBadgeLayout() {
    let view = WorkoutBadge(type: .yoga, difficulty: .beginner)
    assertSnapshot(of: view, as: .image)
}

```

3. **Performance Tests**
```

func testFeedScrollPerformance() {
    measure(metrics: [XCTMemoryMetric()]) {
        app.collectionViews.firstMatch.swipeUp(velocity: .fast)
    }
}

```

4. **Firestore Mocks**
```

class MockFirestoreService: FirestoreServiceProtocol {
    func fetchVideos() async throws -> [Video] {
        return VideoModel.mockVideos // Use mock data
    }
}

```
```

**5. Security-Rules.md**

```markdown
### Firestore Rules Template
```

rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /videos/{video} {
      allow read: if true;
      allow write: if request.auth.uid == resource.metadata.creatorUID;

      match /metadata/{metadata} {
        allow read: if true;
        allow write: if false; // Immutable once set
      }
    }
  }
}

```

### Indexing Requirements
- Create composite indexes for:
  - Workout type + difficulty
  - Equipment + duration
```

Would you like me to:

1. Start implementing the WorkoutMetadata models?
2. Show the SwiftUI component designs?
3. Explain the Firestore security rules in more detail?
4. Demonstrate the testing strategy with code examples?

Let me know which aspect you want to tackle first and I'll provide the complete implementation plan for that component.

Citations:
[1] <https://designcode.io/swiftui-advanced-handbook-write-to-firestore/>
[2] <https://firebase.google.com/docs/ios/setup>
[3] <https://www.blog.finotes.com/post/how-to-integrate-firestore-with-swift-and-how-to-use-it-in-ios-apps>
[4] <https://www.dhiwise.com/post/exploring-swift-tuple-codable-a-deep-dive>
[5] <https://towardsdev.com/swiftui-best-practices-for-clean-and-concise-code-a41450065594?gi=e441f425e1a6>
[6] <https://www.hackingwithswift.com/articles/119/codable-cheat-sheet>
[7] <https://www.kodeco.com/books/swiftui-cookbook/v1.0/chapters/8-creating-reusable-swiftui-components>
[8] <https://blog.grio.com/2023/05/building-custom-ui-components-with-swiftui-for-reusable-and-consistent-design.html>
[9] <https://www.kodeco.com/30070603-viewbuilder-tutorial-creating-reusable-swiftui-views>
[10] <https://www.youtube.com/watch?v=aH15GUzk85Y>
[11] <https://app.studyraid.com/en/read/2324/45506/performance-optimization-in-swiftui>
[12] <https://tanaschita.com/testing-ui-swiftui-xctest-framework/>
[13] <https://firebase.google.com/docs/firestore/quickstart>
[14] <https://www.youtube.com/watch?v=BWK_BdwrB1Y>
[15] <https://blog.logrocket.com/firestore-swift-tutorial/>
[16] <https://www.hackingwithswift.com/guide/ios-swiftui/5/2/key-points>
[17] <https://firebase.google.com/support/release-notes/ios>
[18] <https://firebase.google.com/docs/firestore/solutions/swift-codable-data-mapping>
[19] <https://swiftpackageindex.com/firebase/firebase-ios-sdk>
[20] <https://stackoverflow.com/questions/69964394/how-do-i-connect-the-firebase-firestore-to-my-swift-app>
[21] <https://www.youtube.com/watch?v=R3Wp1PWh70c>
[22] <https://stackoverflow.com/questions/79173637/firestore-documents-caching-in-firebase-ios-sdk>
[23] <https://github.com/peterfriese/Swift-Firestore-Guide>
[24] <https://firebase.google.com/docs>
[25] <https://forum.ionicframework.com/t/ios-itms-91061-missing-privacy-manifest/245709>
[26] <https://stackoverflow.com/questions/72680741/how-to-map-a-firebase-document-to-swift>
[27] <https://cloud.google.com/firestore/docs>
[28] <https://developers.google.com/maps/documentation/ios-sdk/release-notes?hl=en>
[29] <https://www.appypie.com/codable-json-swift-how-to>
[30] <https://forums.swift.org/t/best-approach-for-codable-on-types-i-dont-own/28915>
[31] <https://developer.apple.com/pathways/swiftui/>
[32] <https://www.hackingwithswift.com/read/7/3/parsing-json-using-the-codable-protocol>
[33] <https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types>
[34] <https://www.dhiwise.com/blog/design-converter/proven-swiftui-state-management-best-practices-to-use>
[35] <https://codewithchris.com/codable/>
[36] <https://stackoverflow.com/questions/78259820/whats-the-best-practice-to-define-model-in-swift>
[37] <https://www.reddit.com/r/iOSProgramming/comments/1ga0fn5/swiftui_or_uikit_in_2024_2025/>
[38] <https://www.youtube.com/watch?v=jWp6pX_srJw>
[39] <https://www.reddit.com/r/swift/comments/wyly56/best_practices_for_parsing_dynamicunstructured/>
[40] <https://developer.apple.com/tutorials/swiftui/>
[41] <https://betterprogramming.pub/reusable-customisable-views-in-swiftui-db6af84639fa?gi=ad5d5ade88bb>
[42] <https://peterfriese.github.io/Building-SwiftUI-Components-Tutorial/tutorials/tutorial-table-of-contents/>
[43] <https://www.hackingwithswift.com/articles/226/5-steps-to-better-swiftui-views>
[44] <https://www.linkedin.com/pulse/creating-reusable-custom-views-swiftui-dion-james-smith-jno7f>
[45] <https://www.reddit.com/r/swift/comments/1bv3a85/is_there_any_reusable_swift_ui_component_library/>
[46] <https://www.youtube.com/watch?v=mN4mMOBKTJI>
[47] <https://stackoverflow.com/questions/67031970/swiftui-reusable-components-with-links-to-other-views-as-parameters>
[48] <https://www.reddit.com/r/SwiftUI/comments/17nw67l/best_practices_for_swiftui_in_production/>
[49] <https://peterfriese.dev/tutorials/>
[50] <https://www.youtube.com/watch?v=kw6KZqnXejQ>
[51] <https://www.youtube.com/watch?v=PocljzAYFL4>
[52] <https://developer.apple.com/videos/play/wwdc2023/10160/>
[53] <https://www.youtube.com/watch?v=WDRrsEAXvrE>
[54] <https://www.reddit.com/r/SwiftUI/comments/1cvlxet/how_to_optimize_swiftui_app_with_published/>
[55] <https://www.youtube.com/watch?v=vn11z-kxRmE>
[56] <https://www.bugsnag.com/blog/blog-performance-monitoring-for-swiftui/>
[57] <https://fatbobman.com/en/collections/optimization-debugging/>
[58] <https://betterprogramming.pub/swiftui-testing-a-pragmatic-approach-aeb832107fe7?gi=4dc50586701c>
[59] <https://developer.apple.com/documentation/xcode/writing-and-running-performance-tests>
[60] <https://www.sustainablecode.io/blog/10-swiftui-performance-tips>
[61] <https://www.swiftbysundell.com/articles/writing-testable-code-when-using-swiftui/>
[62] <https://developer.apple.com/documentation/xctest/performance-tests>
[63] <https://www.reddit.com/r/SwiftUI/comments/1ast6p0/tips_for_speeding_up_performance_of_swiftuilist/>
[64] <https://stackoverflow.com/questions/66477671/how-to-fetch-the-latest-document-in-collection-from-firebase-cloud-firestore-usi>
[65] <https://github.com/firebase/firebase-ios-sdk>
[66] <https://www.oneclickitsolution.com/blog/swiftui-importants-best-practices-for-developers>
[67] <https://www.youtube.com/watch?v=LpJrQnFLDxY>
[68] <https://forums.swift.org/t/codable-improvements-and-refinements/19426>
[69] <https://www.udemy.com/course/swiftui-masterclass-course-ios-development-with-swift/>
[70] <https://app.studyraid.com/en/read/2324/45491/creating-reusable-components>
[71] <https://www.kodeco.com/books/swiftui-cookbook/v1.0/chapters/8-best-practices-for-state-management-in-swiftui>
[72] <https://www.youtube.com/watch?v=-Jj0gp0Uc8g>
[73] <https://www.youtube.com/watch?v=UhDdtdeW63k>
[74] <https://holyswift.app/a-beginners-guide-to-styling-components-in-swiftui/>
[75] <https://kth.diva-portal.org/smash/get/diva2:1789094/FULLTEXT01.pdf>
[76] <https://canopas.com/swiftui-performance-tuning-tips-and-tricks-a8f9eeb23ec4>
[77] <https://30dayscoding.com/blog/building-ios-apps-with-swiftui-and-unit-testing>
[78] <https://betterprogramming.pub/easter-egg-swiftuis-viewtest-61b86f1e90d?gi=2376665a3c06>
[79] <https://www.browserstack.com/guide/what-is-swift-ui>
