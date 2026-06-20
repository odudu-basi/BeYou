import SwiftUI

enum MainTab: String, CaseIterable {
    case home
    case alarms
    case insights
    case settings

    var label: String {
        switch self {
        case .home: return "Home"
        case .alarms: return "Alarms"
        case .insights: return "Insights"
        case .settings: return "Settings"
        }
    }

    var sfSymbol: String {
        switch self {
        case .home: return "house.fill"
        case .alarms: return "alarm.fill"
        case .insights: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach([MainTab.home, .alarms, .insights, .settings], id: \.self) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
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
