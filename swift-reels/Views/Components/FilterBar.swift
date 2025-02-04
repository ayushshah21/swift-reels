import SwiftUI

struct FilterBar: View {
    @Binding var selectedCategory: WorkoutType
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WorkoutType.allCases, id: \.self) { category in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    }) {
                        Text(category.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedCategory == category ? .white : .white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 3)
                            .background(
                                selectedCategory == category ?
                                Color.blue.opacity(0.9) :
                                Color.black.opacity(0.6)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
} 