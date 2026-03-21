import SwiftUI

@available(iOS 16.0, *)
struct FeatureRequestView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var featureTitle: String = ""
    @State private var featureDescription: String = ""
    @State private var email: String = ""
    @State private var selectedCategory: FeatureCategory = .newFeature
    @State private var isSending: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private var isValid: Bool {
        !email.isEmpty && email.contains("@") && !featureTitle.isEmpty && !featureDescription.isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F8F8F8").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Share Your Ideas")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Text("Help us make BeYou better for everyone")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))
                        }
                        .padding(.top, 8)

                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Email")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))

                            TextField("email@example.com", text: $email)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E2E8F0"), lineWidth: 1.5)
                                )
                        }

                        // Category picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))

                            HStack(spacing: 8) {
                                ForEach(FeatureCategory.allCases, id: \.self) { category in
                                    CategoryPill(
                                        category: category,
                                        isSelected: selectedCategory == category
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }

                        // Feature title field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Feature Title")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))

                            TextField("E.g., Dark mode for intervention screens", text: $featureTitle)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E2E8F0"), lineWidth: 1.5)
                                )
                        }

                        // Description field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))

                            ZStack(alignment: .topLeading) {
                                if featureDescription.isEmpty {
                                    Text("Describe how this feature would help you...")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "CCCCCC"))
                                        .padding(16)
                                }

                                TextEditor(text: $featureDescription)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                                    .frame(minHeight: 150)
                                    .padding(12)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "E2E8F0"), lineWidth: 1.5)
                                    )
                            }
                        }

                        // Inspiration card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "F59E0B"))

                                Text("Great Ideas Include")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "F59E0B"))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                BulletPoint(text: "What problem it solves")
                                BulletPoint(text: "How you'd use it")
                                BulletPoint(text: "Why it would help you")
                            }
                        }
                        .padding(16)
                        .background(Color(hex: "FFFBEB"))
                        .cornerRadius(12)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }

                // Success overlay
                if showSuccess {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showSuccess = false
                            dismiss()
                        }

                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "10B981"))
                                .frame(width: 80, height: 80)

                            Image(systemName: "checkmark")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 8) {
                            Text("Thank You!")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Text("We'll review your idea soon")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "64748B"))
                        }

                        Button(action: {
                            showSuccess = false
                            dismiss()
                        }) {
                            Text("Done")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(hex: "1A1A1A"))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                    }
                    .padding(32)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.2), radius: 20)
                    .padding(.horizontal, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "64748B"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: sendFeatureRequest) {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "6366F1")))
                        } else {
                            Text("Send")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(isValid ? Color(hex: "6366F1") : Color(hex: "CCCCCC"))
                        }
                    }
                    .disabled(!isValid || isSending)
                }
            }
            .alert("Error Sending Request", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func sendFeatureRequest() {
        isSending = true

        Task {
            do {
                // Get user info for context
                let userName = appState.onboardingData.name ?? "User"
                let userId = SharedDataManager.shared.loadUserID() ?? "Unknown"

                // Prepare request
                guard let url = URL(string: "\(Secrets.supabaseURL)/functions/v1/send-support-email") else {
                    throw EmailError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

                let subject = "💡 Feature Request: \(featureTitle)"
                let message = """
                Category: \(selectedCategory.rawValue)

                Description:
                \(featureDescription)
                """

                let body: [String: Any] = [
                    "email": email,
                    "subject": subject,
                    "message": message,
                    "userName": userName,
                    "userId": userId
                ]

                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                // Send request
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw EmailError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    await MainActor.run {
                        isSending = false
                        showSuccess = true
                    }
                } else {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? String {
                        throw EmailError.serverError(error)
                    } else {
                        throw EmailError.serverError("Status code: \(httpResponse.statusCode)")
                    }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Feature Category

enum FeatureCategory: String, CaseIterable {
    case newFeature = "New Feature"
    case improvement = "Improvement"
    case design = "Design"

    var emoji: String {
        switch self {
        case .newFeature: return "✨"
        case .improvement: return "🔧"
        case .design: return "🎨"
        }
    }

    var color: String {
        switch self {
        case .newFeature: return "6366F1"
        case .improvement: return "10B981"
        case .design: return "F59E0B"
        }
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let category: FeatureCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(category.emoji)
                    .font(.system(size: 14))

                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Color(hex: category.color))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color(hex: category.color) : Color(hex: category.color).opacity(0.1))
            .cornerRadius(20)
        }
    }
}

// MARK: - Bullet Point

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "F59E0B"))

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "78716C"))
        }
    }
}
