import SwiftUI

// MARK: - Wake-up Challenge Picker (Screen 21)

struct Onboarding2ChallengePickerView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: (String, [String]) -> Void // (challenge, selectedItems)
    let onBack: (() -> Void)?

    @State private var selectedChallenge: String?
    @State private var showItemPicker = false
    @State private var selectedItems: Set<String> = Set(["Toothbrush", "Running Faucet", "Shoes", "Fridge", "Keys", "Coffee Mug", "Mirror", "Water Bottle", "Toilet", "Book", "Lamp", "TV Remote", "Front Door", "Stove", "Lotion Bottle", "Soap", "Plant", "Plate", "Towel", "Backpack", "Headphones", "Shower", "Tape"])

    private let challenges: [(name: String, icon: String, description: String)] = [
        ("Item Search", "camera.viewfinder", "Find and photograph items around your home"),
        ("Picture of Sky", "sun.max.fill", "Take a photo of the sky outside"),
        ("Make Your Bed", "bed.double.fill", "Take a photo of your made bed"),
        ("Solve Math", "function", "Solve math problems to wake your brain up"),
        ("Touch Grass", "leaf.fill", "Go outside and take a photo of nature"),
        ("Push Ups", "figure.core.training", "Do push-ups facing the camera"),
        ("Squats", "figure.cross.training", "Do squats facing the camera"),
    ]

    var body: some View {
        Onboarding2Template(
            title: "Choose your wake-up challenge",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: selectedChallenge != nil,
            onNext: {
                if let challenge = selectedChallenge {
                    onNext(challenge, Array(selectedItems))
                }
            },
            onBack: onBack
        ) {
            VStack(spacing: 10) {
                Spacer().frame(height: 12)

                ForEach(challenges, id: \.name) { challenge in
                    Button(action: {
                        selectedChallenge = challenge.name
                        if challenge.name == "Item Search" {
                            showItemPicker = true
                        }
                    }) {
                        HStack(spacing: 14) {
                            MissionIcon(mission: challenge.name, systemName: challenge.icon, size: 18, twoTone: true)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color(hex: AlarmItem.colorHex(for: challenge.name)))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(challenge.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Text(challenge.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "999999"))
                            }

                            Spacer()

                            if selectedChallenge == challenge.name {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color.black)
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedChallenge == challenge.name ? Color.black : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(HapticButtonStyle())
                }
            }
        }
        .sheet(isPresented: $showItemPicker) {
            ItemSearchPickerSheet(selectedItems: $selectedItems, isPresented: $showItemPicker)
        }
    }
}

// MARK: - Item Search Picker Sheet

struct ItemSearchPickerSheet: View {
    @Binding var selectedItems: Set<String>
    @Binding var isPresented: Bool

    private let standardItems: [(name: String, emoji: String)] = [
        ("Toothbrush", "🪥"), ("Running Faucet", "🚰"), ("Shoes", "👟"),
        ("Fridge", "🧊"), ("Keys", "🔑"), ("Coffee Mug", "☕"),
        ("Mirror", "🪞"), ("Water Bottle", "💧"), ("Dustpan", "🧹"),
        ("Toilet", "🚽"), ("Book", "📕"), ("Lamp", "💡"),
        ("TV Remote", "📺"), ("Front Door", "🚪"), ("Stove", "🍳"),
        ("Lotion Bottle", "🧴"), ("Soap", "🧼"), ("Plant", "🪴"),
        ("Plate", "🍽️"), ("Towel", "🧖"), ("Backpack", "🎒"),
        ("Headphones", "🎧"), ("Shower", "🚿"), ("Tape", "📦"),
    ]

    private let funItems: [(name: String, emoji: String)] = [
        ("Kim Kardashian", "👩"), ("Snoop Dogg", "🐶"), ("Rubber Duck", "🦆"),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: "DDDDDD"))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("Select Items")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .padding(.top, 12)

            Text("A random item will be chosen each morning")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "999999"))
                .padding(.top, 4)

            // All standard toggle
            HStack {
                Button(action: {
                    let allNames = Set(standardItems.map { $0.name })
                    if selectedItems.isSuperset(of: allNames) {
                        selectedItems.subtract(allNames)
                    } else {
                        selectedItems.formUnion(allNames)
                    }
                }) {
                    HStack {
                        let allSelected = selectedItems.isSuperset(of: Set(standardItems.map { $0.name }))
                        Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(allSelected ? .black : Color(hex: "CCCCCC"))

                        Text("All Household (\(standardItems.count))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1A1A"))

                        Spacer()

                        Text("Deselect all")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "999999"))
                    }
                }
                .buttonStyle(HapticButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Household section
                    Text("Household Items")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "999999"))
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(standardItems, id: \.name) { item in
                            ItemCard(
                                name: item.name,
                                emoji: item.emoji,
                                isSelected: selectedItems.contains(item.name),
                                action: { toggleItem(item.name) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    // Fun section
                    Text("Fun Items")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "999999"))
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(funItems, id: \.name) { item in
                            ItemCard(
                                name: item.name,
                                emoji: item.emoji,
                                isSelected: selectedItems.contains(item.name),
                                action: { toggleItem(item.name) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 80)
                }
            }

            // Done button
            Button(action: { isPresented = false }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(Color(hex: "F8F8F8"))
    }

    private func toggleItem(_ name: String) {
        if selectedItems.contains(name) {
            selectedItems.remove(name)
        } else {
            selectedItems.insert(name)
        }
    }
}

struct ItemCard: View {
    let name: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 40))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)

                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.black : Color(hex: "E8E8E8"), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(HapticButtonStyle())
    }
}
