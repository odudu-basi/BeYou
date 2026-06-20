import SwiftUI
import FamilyControls

/// Configuration sheet for the App Block: block other apps when an alarm fires,
/// optionally prevent app deletion, and pick which apps stay usable.
@available(iOS 16.0, *)
struct AppBlockSheet: View {
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @Environment(\.dismiss) var dismiss

    @AppStorage("appBlockEnabled") private var blockEnabled: Bool = false
    @AppStorage("appBlockDenyDeletion") private var denyDeletion: Bool = false

    @State private var allowedSelection = AppBlockStore.allowedSelection
    @State private var showPicker = false

    private var allowedCount: Int { allowedSelection.applicationTokens.count }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Block app deletion
                    settingCard {
                        toggleRow(
                            icon: "trash.slash.fill",
                            title: "Block app deletion",
                            subtitle: "Prevents BeYou from being deleted during the mission.",
                            isOn: $denyDeletion
                        )
                    }

                    // Block apps + allow-list
                    settingCard {
                        VStack(spacing: 0) {
                            toggleRow(
                                icon: "square.grid.2x2.fill",
                                title: "Block apps",
                                subtitle: "Blocks your apps when your alarm goes off — until you speak some positivity to uplift your day.",
                                isOn: $blockEnabled
                            )

                            if blockEnabled {
                                Divider().padding(.leading, 56)

                                Button(action: { showPicker = true }) {
                                    HStack(spacing: 14) {
                                        Image(systemName: "checkmark.circle")
                                            .font(.system(size: 18))
                                            .foregroundColor(Color(hex: "6C5CE7"))
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Allow specific apps")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "1A1A1A"))
                                            Text(allowedCount == 0
                                                 ? "Pick apps that stay usable during the block"
                                                 : "\(allowedCount) app\(allowedCount == 1 ? "" : "s") allowed")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "999999"))
                                                .multilineTextAlignment(.leading)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: "CCCCCC"))
                                    }
                                    .padding(16)
                                }
                                .buttonStyle(HapticButtonStyle())
                            }
                        }
                    }

                    Text("App Block uses Screen Time to prevent workarounds during your alarm. You'll be asked to authorize with Face ID.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "999999"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(hex: "F2F2F7").ignoresSafeArea())
            .navigationTitle("App Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $allowedSelection)
            .onChange(of: allowedSelection) { newValue in
                AppBlockStore.allowedSelection = newValue
                screenTimeManager.refreshAppBlockIfActive()
            }
            .onChange(of: blockEnabled) { enabled in
                if enabled {
                    // Check Screen Time access; prompt for it if we don't have it yet.
                    Task { @MainActor in
                        screenTimeManager.updateAuthorizationStatus()
                        if screenTimeManager.authorizationStatus != .approved {
                            try? await screenTimeManager.requestAuthorization()
                        }
                        // If they declined, don't leave the feature looking armed.
                        if screenTimeManager.authorizationStatus != .approved {
                            blockEnabled = false
                        }
                    }
                } else {
                    // Turning the feature off lifts any block that's currently up.
                    screenTimeManager.deactivateAppBlock()
                }
            }
            .onChange(of: denyDeletion) { _ in
                screenTimeManager.refreshAppBlockIfActive()
            }
        }
    }

    // MARK: - Components

    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color.white)
            .cornerRadius(16)
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "1A1A1A"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "999999"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color(hex: "34C759"))
        }
        .padding(16)
    }
}
