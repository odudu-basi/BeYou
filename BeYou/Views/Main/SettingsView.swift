import SwiftUI
import StoreKit
import UserNotifications

@available(iOS 16.0, *)
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("interventionAffirmationCount") private var interventionCount: Int = 3
    @State private var showSupportEmail: Bool = false
    @State private var showFeatureRequest: Bool = false
    @State private var showAppIconPicker: Bool = false
    @State private var showWidgetSetup: Bool = false
    @State private var notificationsEnabled: Bool = true
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .tracking(-0.3)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity)

                    // Name Card
                    HStack(spacing: 14) {
                        Text("👤")
                            .font(.system(size: 20))

                        if isEditingName {
                            TextField("Your name", text: $editedName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .focused($nameFieldFocused)
                                .onSubmit { saveName() }

                            Spacer()

                            Button(action: saveName) {
                                Text("Save")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "1A1A1A"))
                                    .cornerRadius(8)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Name")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "999999"))

                                Text(appState.onboardingData.name ?? "Not set")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                            }

                            Spacer()

                            Button(action: {
                                editedName = appState.onboardingData.name ?? ""
                                isEditingName = true
                                nameFieldFocused = true
                            }) {
                                Text("Edit")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "F0F0F0"))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "EBEBEB"), lineWidth: 1.5)
                    )
                    .padding(.bottom, 10)

                    // Widget Card
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(hex: "FF4444"))
                            .frame(width: 8, height: 8)

                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "666666"))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Widget not set up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Text("Add to Home Screen for quick access")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "999999"))
                        }

                        Spacer()

                        Button(action: { showWidgetSetup = true }) {
                            Text("Set up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(hex: "5B8DEF"))
                                .cornerRadius(8)
                        }
                    }
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "EBEBEB"), lineWidth: 1.5)
                    )
                    .padding(.bottom, notificationsEnabled ? 28 : 10)

                    // Notification Warning Banner
                    if !notificationsEnabled {
                        HStack(spacing: 14) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "F5A623"))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Notifications are off")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Text("Enable to get reminders and motivation")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "999999"))
                            }

                            Spacer()

                            Button(action: openNotificationSettings) {
                                Text("Enable")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "F5A623"))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "F5A623").opacity(0.12))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(18)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "F5A623").opacity(0.5), lineWidth: 1.5)
                        )
                        .padding(.bottom, 28)
                    }

                    // Intervention Style
                    Text("Intervention Style")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .padding(.bottom, 14)

                    HStack(spacing: 14) {
                        Text("📖")
                            .font(.system(size: 22))

                        Text("Affirmations before unlock")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "1A1A1A"))

                        Spacer()

                        HStack(spacing: 12) {
                            Button(action: {
                                if interventionCount > 3 { interventionCount -= 1 }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(interventionCount > 3 ? Color(hex: "1A1A1A") : Color(hex: "CCCCCC"))
                                    .frame(width: 30, height: 30)
                                    .background(Color(hex: "F0F0F0"))
                                    .cornerRadius(8)
                            }

                            Text("\(interventionCount)")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .frame(minWidth: 22)

                            Button(action: {
                                if interventionCount < 10 { interventionCount += 1 }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(interventionCount < 10 ? Color(hex: "1A1A1A") : Color(hex: "CCCCCC"))
                                    .frame(width: 30, height: 30)
                                    .background(Color(hex: "F0F0F0"))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "EBEBEB"), lineWidth: 1.5)
                    )

                    Text("Read \(interventionCount) affirmation\(interventionCount == 1 ? "" : "s") before your blocked apps unlock")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "999999"))
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 28)

                    // App Icon
                    Text("Appearance")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .padding(.bottom, 14)

                    SettingsCard(emoji: "🎨", title: "Choose App Icon") {
                        showAppIconPicker = true
                    }
                    .padding(.bottom, 28)

                    // Support & Feedback
                    Text("Support & Feedback")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .padding(.bottom, 14)

                    VStack(spacing: 10) {
                        SettingsCard(emoji: "❓", title: "Help & Support") {
                            showSupportEmail = true
                        }
                        SettingsCard(emoji: "💡", title: "Feature requests") {
                            showFeatureRequest = true
                        }
                        SettingsCard(emoji: "⭐", title: "Leave a review") {
                            requestReview()
                        }
                        SettingsCard(emoji: "✉️", title: "Contact us") {
                            showSupportEmail = true
                        }
                    }
                    .padding(.bottom, 28)

                    // Legal
                    Text("Legal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .padding(.bottom, 14)

                    VStack(spacing: 10) {
                        SettingsCard(emoji: "🖐️", title: "Privacy policy") {
                            if let url = URL(string: "https://docs.google.com/document/d/1ESnv_E88DPpAoXrFlfJdGVffzeaacX1k/edit") {
                                UIApplication.shared.open(url)
                            }
                        }
                        SettingsCard(emoji: "📄", title: "Terms of service") {
                            if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .padding(.bottom, 28)

                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, 20)
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
        .sheet(isPresented: $showWidgetSetup) {
            WidgetSetupSheet()
        }
        .onAppear { checkNotificationStatus() }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                checkNotificationStatus()
            }
        }
    }

    private func checkNotificationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    private func saveName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.onboardingData.name = trimmed.isEmpty ? nil : trimmed
        isEditingName = false
        nameFieldFocused = false
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
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
        ("Select your widget", "Choose the Discipline Score or Affirmation widget from the available options"),
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
                                // Discipline Score widget preview
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color(hex: "E0E0E0"), lineWidth: 3)
                                            .frame(width: 36, height: 36)

                                        Circle()
                                            .trim(from: 0, to: 0.88)
                                            .stroke(Color(hex: "10B981"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                            .frame(width: 36, height: 36)
                                            .rotationEffect(.degrees(-90))

                                        Text("88")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Color(hex: "1A1A1A"))
                                    }

                                    Text("Discipline\nScore")
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
        .buttonStyle(.plain)
    }
}


