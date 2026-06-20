import SwiftUI

struct ComingSoonView: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "CCCCCC"))

                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text("Coming Soon")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "6C5CE7"))

                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "999999"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
                Spacer()
            }
        }
    }
}
