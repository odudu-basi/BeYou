import SwiftUI

struct Onboarding2TimePickerView: View {
    let title: String
    let subtitle: String?
    let currentStep: Int
    let totalSteps: Int
    let buttonText: String
    let dynamicButtonText: Bool
    let onNext: (Date) -> Void
    let onBack: (() -> Void)?

    @State private var selectedTime: Date

    init(
        title: String,
        subtitle: String? = nil,
        currentStep: Int,
        totalSteps: Int,
        buttonText: String = "Continue",
        dynamicButtonText: Bool = false,
        defaultHour: Int = 6,
        defaultMinute: Int = 0,
        onNext: @escaping (Date) -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.buttonText = buttonText
        self.dynamicButtonText = dynamicButtonText
        self.onNext = onNext
        self.onBack = onBack

        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: defaultHour, minute: defaultMinute, second: 0, of: Date()) ?? Date()
        _selectedTime = State(initialValue: date)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: selectedTime)
    }

    private var resolvedButtonText: String {
        if dynamicButtonText {
            return "Commit to \(formattedTime)"
        }
        return buttonText
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "E8E8E8"))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "1A1A1A"))
                            .frame(width: geo.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "888888"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Spacer()

            // Time picker
            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.horizontal, 40)

            Spacer()

            // Button
            Button(action: { onNext(selectedTime) }) {
                Text(resolvedButtonText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(Color(hex: "F8F8F8"))
    }
}
