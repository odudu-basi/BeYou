import SwiftUI

enum MainTab: String, CaseIterable {
    case home
    case schedules
    case motivation
    case screentime
    case settings

    var label: String {
        switch self {
        case .home: return "Home"
        case .schedules: return "Schedules"
        case .motivation: return "BeYou"
        case .screentime: return "Screen Time"
        case .settings: return "Settings"
        }
    }

    var sfSymbol: String {
        switch self {
        case .home: return "house.fill"
        case .schedules: return "calendar"
        case .motivation: return "" // Uses logo image instead
        case .screentime: return "hourglass"
        case .settings: return "gearshape.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        ZStack {
            // Tab bar background
            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    if tab == .motivation {
                        // Empty space for the center logo
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                    } else {
                        TabBarItem(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: { selectedTab = tab }
                        )
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 24)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)

            // Center floating logo button
            Button(action: { selectedTab = .motivation }) {
                Image("be-you-icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .rotationEffect(.degrees(-8))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                selectedTab == .motivation ? Color(hex: "1A1A1A") : Color.white.opacity(0.6),
                                lineWidth: selectedTab == .motivation ? 2.5 : 1.5
                            )
                            .rotationEffect(.degrees(-8))
                    )
            }
            .offset(y: -22)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

struct TabBarItem: View {
    let tab: MainTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.sfSymbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "1A1A1A") : Color(hex: "999999"))
                    .frame(width: 36, height: 28)

                Text(tab.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Color(hex: "1A1A1A") : Color(hex: "999999"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }
}
