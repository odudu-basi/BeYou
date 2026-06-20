import SwiftUI
import StoreKit
import UserNotifications

@available(iOS 16.0, *)
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSupportEmail: Bool = false
    @State private var showFeatureRequest: Bool = false
    @State private var showAppIconPicker: Bool = false
    @State private var showAccount: Bool = false
    @State private var showAlarmHelp: Bool = false

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Settings")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .padding(.top, 12)

                    // MARK: Alarm
                    SettingsSection(title: "Alarm") {
                        SettingsRow(
                            icon: "speaker.wave.2.fill",
                            title: "Alarm Volume",
                            subtitle: "iOS Settings → Sounds & Haptics → Ringer & Alerts",
                            accessory: .external
                        ) { openURL(UIApplication.openSettingsURLString) }
                        rowDivider
                        SettingsRow(icon: "exclamationmark.triangle.fill", iconColor: Color(hex: "F5A623"), title: "Alarm not working?") { showAlarmHelp = true }
                        rowDivider
                        SettingsRow(icon: "ant.fill", title: "Report a Bug") { showSupportEmail = true }
                    }

                    // MARK: Widgets (intentionally empty for now)

                    // MARK: Preferences
                    SettingsSection(title: "Preferences") {
                        SettingsRow(icon: "bell.fill", title: "Notifications") { openURL(UIApplication.openSettingsURLString) }
                        rowDivider
                        SettingsRow(icon: "paintpalette.fill", title: "App Icon") { showAppIconPicker = true }
                    }

                    // MARK: Support
                    SettingsSection(title: "Support") {
                        SettingsRow(icon: "lightbulb.fill", title: "Request a Feature") { showFeatureRequest = true }
                        rowDivider
                        SettingsRow(icon: "questionmark.circle.fill", title: "Contact Support") { showSupportEmail = true }
                        rowDivider
                        SettingsRow(icon: "star.fill", iconColor: Color(hex: "F5A623"), title: "Leave a Review") {
                            openURL("https://apps.apple.com/app/id6760232059?action=write-review")
                        }
                    }

                    // MARK: Legal
                    SettingsSection(title: "Legal") {
                        SettingsRow(icon: "lock.shield.fill", title: "Privacy Policy") {
                            openURL("https://docs.google.com/document/d/1ESnv_E88DPpAoXrFlfJdGVffzeaacX1k/edit")
                        }
                        rowDivider
                        SettingsRow(icon: "doc.text.fill", title: "Terms of Service") {
                            openURL("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                        }
                    }

                    // MARK: Account
                    SettingsSection(title: "Account") {
                        SettingsRow(icon: "person.circle.fill", title: "Account Settings") { showAccount = true }
                    }

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .sheet(isPresented: $showSupportEmail) {
            SupportEmailView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showFeatureRequest) {
            FeatureRequestView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showAppIconPicker) {
            AppIconPickerSheet()
        }
        .sheet(isPresented: $showAccount) {
            AccountSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showAlarmHelp) {
            AlarmTroubleshootingSheet()
                .environmentObject(appState)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color(hex: "F0F0F0"))
            .frame(height: 1)
            .padding(.leading, 56)
    }

    private func openURL(_ string: String) {
        if let url = URL(string: string) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Settings Section + Rows

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "999999"))

            VStack(spacing: 0) { content }
                .background(Color.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "EBEBEB"), lineWidth: 1.5)
                )
        }
    }
}

struct SettingsRow: View {
    enum Accessory { case chevron, external, none }

    let icon: String
    var iconColor: Color = Color(hex: "666666")
    let title: String
    var titleColor: Color = Color(hex: "1A1A1A")
    var subtitle: String? = nil
    var value: String? = nil
    var accessory: Accessory = .chevron
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(titleColor)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "999999"))
                    }
                }

                Spacer()

                if let value {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "999999"))
                }

                switch accessory {
                case .chevron:
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "CCCCCC"))
                case .external:
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "CCCCCC"))
                case .none:
                    EmptyView()
                }
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "666666"))
                .frame(width: 26)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "1A1A1A"))

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(hex: "34C759"))
        }
        .padding(16)
    }
}

// MARK: - Account Sheet

@available(iOS 16.0, *)
struct AccountSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showNameEditor = false
    @State private var editedName = ""
    @State private var showDeleteConfirm = false
    @State private var showCancelReason = false

    var body: some View {
        ZStack {
            Color(hex: "F2F2F7").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Account")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    Spacer()

                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Color.white)
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SettingsSection(title: "SUBSCRIPTION") {
                            SettingsRow(icon: "xmark.circle", title: "Cancel Subscription") { showCancelReason = true }
                            divider
                            SettingsRow(icon: "creditcard", title: "Manage Subscription") { openSubscriptions() }
                        }

                        SettingsSection(title: "ACCOUNT") {
                            SettingsRow(icon: "person", title: "Name", value: appState.onboardingData.name) {
                                editedName = appState.onboardingData.name ?? ""
                                showNameEditor = true
                            }
                            divider
                            SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Log Out") {}
                        }

                        SettingsSection(title: "DANGER ZONE") {
                            SettingsRow(icon: "trash", iconColor: .red, title: "Delete Account", titleColor: .red) {
                                showDeleteConfirm = true
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
        }
        .alert("Your Name", isPresented: $showNameEditor) {
            TextField("Name", text: $editedName)
            Button("Save") {
                let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                appState.onboardingData.name = trimmed.isEmpty ? nil : trimmed
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and data.")
        }
        .sheet(isPresented: $showCancelReason) {
            CancelReasonSheet(onComplete: { openSubscriptions() })
                .presentationDetents([.medium, .large])
        }
        .presentationDetents([.large])
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(hex: "F0F0F0"))
            .frame(height: 1)
            .padding(.leading, 56)
    }

    private func openSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Alarm Troubleshooting Sheet

@available(iOS 16.0, *)
struct AlarmTroubleshootingSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showSupport = false

    var body: some View {
        ZStack {
            Color(hex: "F2F2F7").ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "666666"))
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 6) {
                            Text("Alarm Troubleshooting")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                            Text("Check these if your alarm isn't working")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "999999"))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 8)

                        // Check Your Volume
                        card {
                            header("speaker.wave.2.fill", "Check Your Volume")
                            paragraph("Your alarm volume is controlled by the **Ringtone & Alerts** slider, not the side volume buttons.")
                            bullet("Open **Settings → Sounds & Haptics**")
                            bullet("Drag the **Ringtone and Alerts** slider to max")
                            bullet("Make sure your phone isn't on silent (check the side switch)")
                            paragraph("**If you see the alarm notification but it isn't ringing, try this volume safety automation:**")
                            bullet("Open **Shortcuts → Automation**")
                            bullet("Tap **Create New Automation**")
                            bullet("Choose **Alarm → Goes Off → Any Alarm**")
                            bullet("Select **Run Immediately**, then **New Blank Automation**")
                            bullet("Search **Set Volume**")
                            bullet("Change **Media** to **Ringtone**")
                            bullet("Set volume to your ideal level")
                        }

                        // Permissions
                        card {
                            header("checkmark.shield.fill", "Permissions")
                            permission("alarm.fill", "Alarms", "Required for the alarm to fire")
                            permission("bell.badge.fill", "Notifications", "Required for alarm alerts")
                            permission("camera.fill", "Camera", "Required for photo missions")
                            permission("mic.fill", "Microphone", "Required for audio missions")

                            Button(action: openAppSettings) {
                                HStack(spacing: 8) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 15))
                                    Text("Open App Settings")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(hex: "EFEFEF"))
                                .cornerRadius(14)
                            }
                            .padding(.top, 4)
                        }

                        // How the Alarm Works
                        card {
                            header("info.circle.fill", "How the Alarm Works")
                            bullet("Rings again every few seconds until you complete your mission — this is by design")
                            bullet("Dismissing from the lock screen is temporary — it will ring again")
                            bullet("The only way to stop it is to open the app and finish the mission")
                            bullet("If you leave mid-mission, it re-rings to bring you back")
                        }

                        // Still Not Working
                        card {
                            header("bubble.left.fill", "Still Not Working?")
                            paragraph("If your alarm isn't going off after checking volume and permissions, reach out and we'll help.")
                            Button(action: { showSupport = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "bubble.left")
                                        .font(.system(size: 15))
                                    Text("Contact Support")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: "EA6A2C"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(hex: "EA6A2C").opacity(0.5), lineWidth: 1.5)
                                )
                                .cornerRadius(14)
                            }
                            .padding(.top, 4)
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showSupport) {
            SupportEmailView()
                .environmentObject(appState)
        }
    }

    // MARK: Building blocks

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(18)
    }

    private func header(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "1A1A1A"))
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
        }
    }

    private func paragraph(_ markdown: String) -> some View {
        Text(LocalizedStringKey(markdown))
            .font(.system(size: 15))
            .foregroundColor(Color(hex: "444444"))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bullet(_ markdown: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "BBBBBB"))
            Text(LocalizedStringKey(markdown))
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "444444"))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func permission(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "EA6A2C"))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "999999"))
            }
            Spacer(minLength: 0)
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Cancel Reason Sheet

@available(iOS 16.0, *)
struct CancelReasonSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void   // proceed to Apple's subscription page after capturing feedback

    private let reasons = [
        "Too expensive",
        "Alarm didn't work",
        "Missions too hard",
        "Still go back to sleep",
        "Don't need it",
        "Phone not compatible",
        "Other"
    ]

    @State private var selected: String?
    @State private var details: String = ""

    private func prompt(for reason: String) -> String {
        switch reason {
        case "Too expensive": return "What price would make it worth it?"
        case "Alarm didn't work": return "What went wrong with the alarm?"
        case "Missions too hard": return "Which mission was too hard — and what would make it easier?"
        case "Still go back to sleep": return "What happens after the alarm? What would help you stay up?"
        case "Don't need it": return "What changed, or what are you using instead?"
        case "Phone not compatible": return "What phone and iOS version are you on?"
        default: return "Tell us more — what would have kept you?"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "666666"))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "EEEEEE"))
                    .clipShape(Circle())
            }
            .padding(.top, 20)

            Text("Why are you canceling?")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .padding(.top, 20)

            FlowLayout(spacing: 10) {
                ForEach(reasons, id: \.self) { reason in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selected = reason
                        }
                    }) {
                        Text(reason)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(selected == reason ? .white : Color(hex: "1A1A1A"))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(selected == reason ? Color(hex: "1A1A1A") : Color(hex: "EFEFEF"))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(HapticButtonStyle())
                }
            }
            .padding(.top, 24)

            if let selected {
                VStack(alignment: .leading, spacing: 8) {
                    Text(prompt(for: selected))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "666666"))

                    TextField("Optional — but it really helps", text: $details, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(3...6)
                        .padding(14)
                        .background(Color(hex: "F4F4F4"))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "E2E2E2"), lineWidth: 1)
                        )
                }
                .padding(.top, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            Button(action: submit) {
                Text("Submit")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selected == nil ? Color(hex: "CCCCCC") : Color(hex: "1A1A1A"))
                    .cornerRadius(16)
            }
            .disabled(selected == nil)
            .padding(.bottom, 36)
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }

    private func submit() {
        guard let selected else { return }
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        // Quantitative breakdown in Mixpanel + durable free-text rows in Supabase.
        AnalyticsManager.shared.trackCancellationReason(reason: selected, details: trimmed)
        UserProfileService.shared.submitCancellationFeedback(reason: selected, details: trimmed)
        dismiss()
        // Give the sheet a beat to dismiss before opening the App Store page.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onComplete()
        }
    }
}

// MARK: - Widget Setup Sheet

struct WidgetSetupSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(title: String, description: String)] = [
        ("Long press your Home Screen", "Tap and hold on an empty area of your Home Screen until apps start wiggling"),
        ("Tap the '+' button", "Look for the plus button in the top-left corner and tap it"),
        ("Search for 'BeYou'", "Use the search bar at the top to find the BeYou app widgets"),
        ("Select your widget", "Choose the Affirmation widget from the available options"),
        ("Tap 'Add Widget'", "Confirm adding the widget to your Home Screen")
    ]

    var body: some View {
        ZStack {
            Color(hex: "FFF8F0").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()

                    Text("Widget Setup")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    Spacer()

                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(hex: "5B8DEF"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Home screen mockup
                        VStack(spacing: 0) {
                            // Mockup container
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "1A1A1A"))
                                    .frame(height: 200)

                                VStack(spacing: 12) {
                                    // Simulated app grid
                                    HStack(spacing: 16) {
                                        // Placeholder icons
                                        ForEach(0..<4, id: \.self) { _ in
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                        }
                                    }

                                    HStack(spacing: 16) {
                                        // BeYou widget mockup
                                        VStack(spacing: 6) {
                                            Image("be-you-icon")
                                                .resizable()
                                                .frame(width: 48, height: 48)
                                                .cornerRadius(12)

                                            Text("88")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.white)

                                            // Mini progress bar
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(Color.white.opacity(0.2))
                                                        .frame(height: 4)
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(Color(hex: "10B981"))
                                                        .frame(width: geo.size.width * 0.88, height: 4)
                                                }
                                            }
                                            .frame(height: 4)
                                            .frame(width: 80)

                                            Text("BeYou")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(16)

                                        // More placeholder icons
                                        VStack(spacing: 16) {
                                            HStack(spacing: 16) {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.15))
                                                    .frame(width: 44, height: 44)
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.15))
                                                    .frame(width: 44, height: 44)
                                            }
                                            HStack(spacing: 16) {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.15))
                                                    .frame(width: 44, height: 44)
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.15))
                                                    .frame(width: 44, height: 44)
                                            }
                                        }
                                    }
                                }
                                .padding(20)
                            }
                            .padding(.horizontal, 40)
                        }

                        // Title
                        Text("Add BeYou Widget")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))

                        // Steps
                        VStack(spacing: 20) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 16) {
                                    // Number circle
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "5B8DEF"))
                                            .frame(width: 36, height: 36)

                                        Text("\(index + 1)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                    }

                                    // Step content
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.title)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(Color(hex: "1A1A1A"))

                                        Text(step.description)
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "999999"))
                                            .lineSpacing(2)
                                    }

                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Available widgets info
                        VStack(spacing: 12) {
                            Text("Available Widgets")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))

                            HStack(spacing: 20) {
                                // Affirmation widget preview
                                VStack(spacing: 6) {
                                    Image(systemName: "text.quote")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(hex: "5B8DEF"))

                                    Text("Daily\nAffirmation")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "999999"))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.top, 4)

                        // Note
                        HStack(spacing: 6) {
                            Text("Note")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "FF9500"))

                            Text("")
                        }

                        Text("Due to restrictions within Apple's Screen Time system, the widget scores may be slightly different from the live score shown when opening the app")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "999999"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, -20)

                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - App Icon Picker Sheet

struct AppIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIcon: String

    private let icons: [(name: String, imageName: String, iconName: String?)] = [
        ("Default", "be-you-icon", nil),
        ("Blush", "be-you-1-blush", "be-you-1-blush"),
        ("Celestial", "be-you-2-celestial", "be-you-2-celestial"),
        ("Holographic", "be-you-3-holographic", "be-you-3-holographic"),
        ("Starfield", "be-you-4-starfield", "be-you-4-starfield"),
        ("Clouds", "be-you-5-clouds", "be-you-5-clouds"),
        ("Aurora", "be-you-6-aurora", "be-you-6-aurora"),
        ("Peach Lavender", "be-you-7-peach-lavender", "be-you-7-peach-lavender"),
        ("Cream Spark", "be-you-8-cream-spark", "be-you-8-cream-spark"),
        ("Slate Navy", "be-you-9-slate-navy", "be-you-9-slate-navy")
    ]

    init() {
        // Determine which icon is currently active
        let currentIconName = UIApplication.shared.alternateIconName
        if let current = currentIconName {
            _selectedIcon = State(initialValue: current)
        } else {
            _selectedIcon = State(initialValue: "Default")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Close") { dismiss() }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "999999"))

                Spacer()

                Text("App Icon")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Spacer()

                // Invisible spacer for centering
                Text("Close")
                    .font(.system(size: 16, weight: .medium))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(icons, id: \.name) { icon in
                        VStack(spacing: 8) {
                            Image(icon.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isSelected(icon) ? Color.black : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    selectedIcon = icon.iconName ?? "Default"
                                    changeAppIcon(to: icon.iconName)
                                }

                            Text(icon.name)
                                .font(.system(size: 12, weight: isSelected(icon) ? .semibold : .regular))
                                .foregroundColor(isSelected(icon) ? Color(hex: "1A1A1A") : .gray)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private func isSelected(_ icon: (name: String, imageName: String, iconName: String?)) -> Bool {
        if selectedIcon == "Default" {
            return icon.iconName == nil
        }
        return selectedIcon == icon.iconName
    }

    private func changeAppIcon(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Failed to change app icon: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Settings Card

struct SettingsCard: View {
    let emoji: String
    let title: String
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 20))

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "CCCCCC"))
            }
            .padding(18)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "EBEBEB"), lineWidth: 1.5)
            )
        }
        .buttonStyle(HapticButtonStyle())
    }
}


