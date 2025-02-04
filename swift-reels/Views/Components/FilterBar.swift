import SwiftUI

struct FilterBar: View {
    @Binding var selectedCategory: WorkoutCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WorkoutCategory.allCases, id: \.self) { category in
                    Button(action: {
                        withAnimation {
                            selectedCategory = category
                        }
                    }) {
                        Text(category.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == category ?
                                Color.blue.opacity(0.2) :
                                Color.gray.opacity(0.1)
                            )
                            .foregroundColor(
                                selectedCategory == category ?
                                Color.blue :
                                Color.gray
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
} 