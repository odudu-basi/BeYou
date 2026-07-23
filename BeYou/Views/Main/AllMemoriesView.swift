import SwiftUI

/// Full-screen gallery of ALL morning memories. Opened from the Insights preview (which only shows
/// the latest few); tap any memory here to view it full-screen (`MemoryDetailView`).
@available(iOS 16.0, *)
struct AllMemoriesView: View {
    @Binding var memories: [MorningMemory]
    let save: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMemory: MorningMemory?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(memories) { memory in
                        memoryCell(memory)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer().frame(height: 40)
            }
            .background(Color(hex: "F8F8F8").ignoresSafeArea())
            .navigationTitle("Morning Memories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .fontWeight(.semibold)
                            .fixedSize()          // prevent the "Done…" ellipsis truncation
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedMemory) { memory in
            MemoryDetailView(memory: memory) {
                delete(memory)
                selectedMemory = nil
            }
        }
    }

    private func memoryCell(_ memory: MorningMemory) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let uiImage = UIImage(data: memory.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
            }
            Text(memory.formattedDate)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
                .padding(6)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            Haptics.tap()
            AnalyticsManager.shared.trackMemoryViewed(mission: memory.missionName)
            selectedMemory = memory
        }
        .contextMenu {
            Button(role: .destructive) { delete(memory) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func delete(_ memory: MorningMemory) {
        memories.removeAll { $0.id == memory.id }
        save()
    }
}
