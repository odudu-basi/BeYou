import SwiftUI
import FamilyControls

@available(iOS 16.0, *)
struct SetupSelectAppsView: View {
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var isPickerPresented = false

    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        OnboardingTemplate(
            title: "Select apps to manage",
            subtitle: "Choose which apps to limit",
            onNext: {
                if screenTimeManager.hasSelectedApps() {
                    onNext()
                }
            },
            onBack: onBack
        ) {
            VStack(spacing: 20) {
                Button(action: {
                    isPickerPresented = true
                }) {
                    HStack {
                        Image(systemName: "app.badge.checkmark")
                            .foregroundColor(.black)

                        Text(screenTimeManager.hasSelectedApps() ? "Apps Selected" : "Select Apps")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(12)
                }

                if screenTimeManager.hasSelectedApps() {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Apps selected successfully")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.top, 20)
        }
        .familyActivityPicker(
            isPresented: $isPickerPresented,
            selection: $screenTimeManager.activitySelection
        )
    }
}
