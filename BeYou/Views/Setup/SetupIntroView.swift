import SwiftUI

struct SetupIntroView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.green)

                Text("Let's set up your\ndigital boundaries")
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)

                Text("This will only take a minute")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: onNext) {
                Text("Let's Go")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(Color(hex: "F8F8F8"))
    }
}
