import SwiftUI

@available(iOS 16.0, *)
struct SupportEmailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var isSending: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private var isValid: Bool {
        !email.isEmpty && email.contains("@") && !subject.isEmpty && !message.isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F8F8F8").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How can we help?")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Text("We typically respond within 24 hours")
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

                        // Subject field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))

                            TextField("What's this about?", text: $subject)
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

                        // Message field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))

                            ZStack(alignment: .topLeading) {
                                if message.isEmpty {
                                    Text("Describe your issue or question...")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "CCCCCC"))
                                        .padding(16)
                                }

                                TextEditor(text: $message)
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

                        // Quick info card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "6366F1"))

                                Text("Tip")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "6366F1"))
                            }

                            Text("Include as many details as possible to help us assist you better. Screenshots are welcome!")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "64748B"))
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .background(Color(hex: "EEF2FF"))
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
                            Text("Message Sent!")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Text("We'll get back to you soon")
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
                    Button(action: sendEmail) {
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
            .alert("Error Sending Email", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func sendEmail() {
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
                    // Try to parse error message
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

// MARK: - Email Error

enum EmailError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
