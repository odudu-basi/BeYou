import SwiftUI

struct NumberedSelectionCard: View {
    let number: Int
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text("\(number)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Color(hex: "666666"))
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color.black : Color(hex: "EEEEEE"))
                    .clipShape(Circle())

                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.black : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(HapticButtonStyle())
    }
}
