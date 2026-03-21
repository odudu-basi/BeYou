import SwiftUI
import FamilyControls
import ManagedSettings

@available(iOS 16.0, *)
struct AppIntentionCard: View {
    let appTokenData: Data? // Encoded ApplicationToken
    let timesPerDay: Int
    let minutesPerSession: Int
    let currentOpens: Int
    let isExpanded: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    // Decode the ApplicationToken from Data
    private var appToken: ApplicationToken? {
        guard let data = appTokenData,
              let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) else {
            return nil
        }
        return token
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main card row
            HStack(spacing: 12) {
                // Show REAL app icon and name using FamilyControls Label
                if let token = appToken {
                    Label(token)
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Fallback if token can't be decoded
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "94A3B8"))
                            .frame(width: 44, height: 44)

                        Image(systemName: "app.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }

                // App info
                VStack(alignment: .leading, spacing: 3) {
                    // Show real app name from token
                    if let token = appToken {
                        Label(token)
                            .labelStyle(.titleOnly)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    } else {
                        Text("Unknown App")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    }

                    Text("\(currentOpens)/\(timesPerDay) Opens")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(currentOpens > timesPerDay ? Color(hex: "EF4444") : Color(hex: "34C759"))
                }

                Spacer()

                // Chevron indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "999999"))
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            // Expanded action buttons
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                HStack(spacing: 10) {
                    // Edit button
                    Button {
                        onEdit()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .medium))
                            Text("Edit")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "3B82F6"))
                        .cornerRadius(10)
                    }

                    // Remove button
                    Button {
                        onDelete()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .medium))
                            Text("Remove")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "EF4444"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "FEE2E2"))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}
