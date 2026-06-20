import SwiftUI

// MARK: - Generic numbered question view

struct Onboarding2QuestionView: View {
    let title: String
    let options: [String]
    let currentStep: Int
    let totalSteps: Int
    let onNext: (String) -> Void
    let onBack: (() -> Void)?
    var allowMultiple: Bool = false

    @State private var selectedOption: String?
    @State private var selectedOptions: Set<String> = []

    var body: some View {
        Onboarding2Template(
            title: title,
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: allowMultiple ? !selectedOptions.isEmpty : selectedOption != nil,
            onNext: {
                if allowMultiple {
                    onNext(selectedOptions.joined(separator: ","))
                } else if let selected = selectedOption {
                    onNext(selected)
                }
            },
            onBack: onBack
        ) {
            VStack(spacing: 10) {
                Spacer().frame(height: 40)

                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    NumberedSelectionCard(
                        number: index + 1,
                        title: option,
                        isSelected: allowMultiple ? selectedOptions.contains(option) : selectedOption == option
                    ) {
                        if allowMultiple {
                            if selectedOptions.contains(option) {
                                selectedOptions.remove(option)
                            } else {
                                selectedOptions.insert(option)
                            }
                        } else {
                            selectedOption = option
                        }
                    }
                }
            }
        }
    }
}
