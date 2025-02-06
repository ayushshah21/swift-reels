Here's how to implement a "Fitness Dark Metal" theme in SwiftUI, combining industrial aesthetics with fitness functionality:

### 1. Core Color Palette (Assets.xcassets)
```swift
// Create these Color Sets with Dark/Light variants
- ForgedSteel (Primary): #2E3239 (Dark) / #F4F4F4 (Light)
- BurnishedCopper (Accent): #BF7D4B (Dark) / #8C5C3A (Light)
- IndustrialOrange (CTA): #FF6B35 (Dark) / #D45A2B (Light)
- CarbonFiber (Background): #1A1D21 (Dark) / #EDEDED (Light)
- MetallicEdge (Borders): Linear gradient 45° #3D4148 → #565B63 (Dark)
```

### 2. Key UI Components
**EquipmentIcon.swift**
```swift
struct EquipmentIcon: View {
    let equipment: EquipmentType
    
    var body: some View {
        Image(systemName: equipment.iconName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color("BurnishedCopper"), Color("IndustrialOrange")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("ForgedSteel"))
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
            )
    }
}
```

### 3. Metal Texture Modifier
```swift
struct MetalTexture: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                colorScheme == .dark ?
                LinearGradient(
                    colors: [.black.opacity(0.8), Color("ForgedSteel")],
                    startPoint: .top,
                    endPoint: .bottom
                ) : Color("CarbonFiber")
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color("MetallicEdge"), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
    }
}
```

### 4. Dynamic Theme Control
```swift
class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") var selectedTheme: UIUserInterfaceStyle = .unspecified
    
    func currentScheme() -> ColorScheme? {
        switch selectedTheme {
        case .dark: return .dark
        case .light: return .light
        default: return nil
        }
    }
}

// Usage in root view
WindowGroup {
    ContentView()
        .preferredColorScheme(ThemeManager().currentScheme())
}
```

### 5. Video Card Design (ReelsFeedView)
```swift
struct VideoCard: View {
    let video: Video
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VideoPlayer(url: video.url)
            
            VStack(alignment: .leading) {
                HStack {
                    EquipmentIcon(equipment: video.equipment)
                    DifficultyBadge(level: video.difficulty)
                }
                
                Text(video.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .shadow(radius: 3)
            }
            .padding()
        }
        .modifier(MetalTexture())
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
```

### Implementation Strategy
1. **Start with Assets**  
   Create all color sets with dark/light variants using metallic gradients

2. **Build Base Components**  
   Implement reusable elements like `MetalButtonStyle`, `EquipmentIcon`, and `DifficultyBadge`

3. **Test Contrast Ratios**  
   Use Xcode's Accessibility Inspector to ensure:
   - Minimum 4.5:1 for text
   - 3:1 for graphical elements

4. **Performance Optimization**  
   Add `.drawingGroup()` modifier to complex gradient views

5. **Preview Setup**  
```swift
#Preview("Dark Metal Theme", traits: .fixedLayout(width: 400, height: 800)) {
    ContentView()
        .preferredColorScheme(.dark)
        .environmentObject(ThemeManager())
}
```

### Key References
1. [Apple Dark Mode Guidelines](https://developer.apple.com/design/human-interface-guidelines/dark-mode)  
2. [Metal UI Inspiration](https://dribbble.com/tags/dark-metal)  
3. [SwiftUI Performance Optimization](https://developer.apple.com/videos/play/wwdc2023/10160/)

Would you like me to:  
1. Show specific component implementations?  
2. Demonstrate theme switching animation?  
3. Provide Firebase design system integration?  
4. Create metal texture image assets?  

Let me know which aspect you want to tackle first!

Citations:
[1] https://dribbble.com/shots/9836543-Fitness-App-Dark-and-Light
[2] https://www.behance.net/search/projects/black%20metal?locale=en_US
[3] https://stackoverflow.com/questions/58476048/implement-dark-mode-switch-in-swiftui-app
[4] https://app.studyraid.com/en/read/2324/45493/implementing-dark-mode-support
[5] https://designcode.io/swiftui-handbook-light-and-dark-modes/
[6] https://zappycode.com/tutorials/dark-mode-in-swiftui
[7] https://www.justinmind.com/ui-design/neumorphism
[8] https://startbase.dev/components/swiftui/dark-mode
[9] https://dribbble.com/tags/dark-fitness-app
[10] https://medium.muz.li/63-beautiful-dark-ui-examples-design-inspiration-8abaa1b86969?gi=1def89724d05
[11] https://muz.li/inspiration/dark-mode
[12] https://www.uxstudioteam.com/ux-blog/ui-trends-2019
[13] https://www.halo-lab.com/blog/dark-ui-design-11-tips-for-dark-mode-design
[14] https://dribbble.com/tags/fitness-app-dark-theme
[15] https://dribbble.com/tags/dark-metal
[16] https://www.behance.net/gallery/179085483/Fitness-App-Design-Dark-theme?locale=en_US
[17] https://www.pinterest.com/pin/dark-theme-fitness-app--536702480588564625/
[18] https://dribbble.com/search/dark-metal
[19] https://in.pinterest.com/pin/fitness-app-dark--573786808777830165/
[20] https://in.pinterest.com/pin/brushed-metal-dark-ui-in-2024--789748484685895385/
[21] https://www.behance.net/gallery/107566249/Most-Popular-Dark-UI-Design-for-Fitness-App?locale=en_US
[22] https://www.pinterest.com/LinnTse/dark-ui/
[23] https://dribbble.com/shots/15432483-Fitness-Pro-Light-Dark-Theme
[24] https://stablediffusionweb.com/prompts/dark-metal-ui-elements
[25] https://www.reddit.com/r/iOSProgramming/comments/nmuleb/implementing_dark_mode_in_swiftui/
[26] https://forums.developer.apple.com/forums/thread/658818
[27] https://tanaschita.com/supporting-dark-mode-programmatically/
[28] https://startbase.dev/components/swiftui/dark-mode
[29] https://developer.apple.com/design/human-interface-guidelines/dark-mode
[30] https://developer.apple.com/documentation/uikit/supporting-dark-mode-in-your-interface
[31] https://www.waldo.com/blog/swiftui-dark-mode
[32] https://bugfender.com/blog/swiftui-color/
[33] https://www.reddit.com/r/SwiftUI/comments/qj7sor/is_it_possible_to_force_my_app_into_dark_mode/
[34] https://www.youtube.com/watch?v=JCCImOLui5E
[35] https://dribbble.com/search/metal-ui
[36] https://www.youtube.com/watch?v=DB5uNhIea-o
[37] https://www.reddit.com/r/SwiftUI/comments/18ahfj7/best_way_to_implement_three_themes/
[38] https://www.pinterest.com/mn8er/minimal-dark-ui/
[39] https://stablediffusionweb.com/prompts/aesthetic-ui
[40] https://www.behance.net/search/projects/aesthetic%20ui?locale=en_US
[41] https://www.shutterstock.com/search/metal-ui?page=18
[42] https://www.reddit.com/r/UI_Design/comments/1232aap/fitness_app_whats_too_saturated_vs_just_right_in/
[43] https://design4users.com/user-friendly-app-design-concepts/
[44] https://www.youtube.com/watch?v=QbmcMGX23Jo
[45] https://www.freepik.com/free-photos-vectors/metal-ui
[46] https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-dark-mode
[47] https://stackoverflow.com/questions/63230569/swiftui-force-view-to-use-light-or-dark-mode/63230699
[48] https://designcode.io/swiftui-handbook-light-and-dark-modes/
[49] https://zappycode.com/tutorials/dark-mode-in-swiftui
[50] https://www.kodeco.com/books/swiftui-cookbook/v1.0/chapters/6-implementing-dark-mode-accessibility-in-swiftui
[51] https://stackoverflow.com/questions/58476048/implement-dark-mode-switch-in-swiftui-app
[52] https://app.studyraid.com/en/read/2324/45493/implementing-dark-mode-support
[53] https://forums.developer.apple.com/forums/thread/740489