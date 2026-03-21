import SwiftUI

struct ProgressBar: View {
    let current: Int
    let total: Int

    private var percentage: CGFloat {
        return CGFloat(current) / CGFloat(total)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Color(hex: "#E0E0E0"))
                    .frame(height: 5)
                    .cornerRadius(3)

                // Fill
                Rectangle()
                    .fill(Color(hex: "#1A1A1A"))
                    .frame(width: geometry.size.width * percentage, height: 5)
                    .cornerRadius(3)
            }
        }
        .frame(height: 5)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}
