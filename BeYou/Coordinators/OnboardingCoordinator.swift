import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case referral = 0
    case name
    case gender
    case goals
    case currentScreenTime
    case goalTime
    case timeWasters
    case hardToQuit
    case feelings
    case transform
    case age
    case loadingPlan
    case currentRate
    case goodNews
    case triedBefore
    case affirmations
    case relationship
    case religion
    case beliefs
    case affirmationsInfo
    case familiar
    case positivity
    case notificationPermission
    case mood
    case studies
    case improve
    case review
    case clearVision
    case journey
    case believe
    case reality
    case categories
    case iconStyle
    case commitment

    var next: OnboardingStep? {
        let allCases = Self.allCases
        guard let currentIndex = allCases.firstIndex(of: self),
              currentIndex + 1 < allCases.count else {
            return nil
        }
        return allCases[currentIndex + 1]
    }

    var previous: OnboardingStep? {
        let allCases = Self.allCases
        guard let currentIndex = allCases.firstIndex(of: self),
              currentIndex > 0 else {
            return nil
        }
        return allCases[currentIndex - 1]
    }
}

@available(iOS 16.0, *)
struct OnboardingCoordinator: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep: OnboardingStep = .referral

    private var currentStepNumber: Int {
        return currentStep.rawValue + 1
    }

    private let totalSteps = 34

    var body: some View {
        Group {
            switch currentStep {
            case .referral:
                OnboardingReferralView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: nil)
            case .name:
                OnboardingNameView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .gender:
                OnboardingGenderView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .goals:
                OnboardingGoalsView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .currentScreenTime:
                OnboardingScreenTimeView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .goalTime:
                OnboardingGoalTimeView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .timeWasters:
                OnboardingTimeWastersView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .hardToQuit:
                OnboardingHardToQuitView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .feelings:
                OnboardingFeelingsView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .transform:
                OnboardingTransformView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .age:
                OnboardingAgeView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .loadingPlan:
                OnboardingLoadingPlanView(onNext: advance)
            case .currentRate:
                OnboardingCurrentRateView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .goodNews:
                OnboardingGoodNewsView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .triedBefore:
                OnboardingTriedBeforeView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .affirmations:
                OnboardingAffirmationsView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .relationship:
                OnboardingRelationshipView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .religion:
                OnboardingReligionView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .beliefs:
                OnboardingBeliefsView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .affirmationsInfo:
                OnboardingAffirmationsInfoView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .familiar:
                OnboardingFamiliarView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .positivity:
                OnboardingPositivityView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .notificationPermission:
                OnboardingNotificationPermissionView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .mood:
                OnboardingMoodView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .studies:
                OnboardingStudiesView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .improve:
                OnboardingImproveView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .review:
                OnboardingReviewView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .clearVision:
                OnboardingClearVisionView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .journey:
                OnboardingJourneyView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .believe:
                OnboardingBelieveView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .reality:
                OnboardingRealityView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .categories:
                OnboardingCategoriesView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .iconStyle:
                OnboardingIconStyleView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: advance, onBack: goBack)
            case .commitment:
                OnboardingCommitmentView(currentStep: currentStepNumber, totalSteps: totalSteps, onNext: finishOnboarding, onBack: goBack)
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    private func advance() {
        withAnimation {
            if let nextStep = currentStep.next {
                // Skip beliefs page if user is not religious
                if nextStep == .beliefs && appState.onboardingData.religion != "yes" {
                    currentStep = .affirmationsInfo
                // Skip notification permission page if user already granted notifications
                } else if nextStep == .notificationPermission && NotificationManager.shared.isAuthorized {
                    currentStep = .mood
                } else {
                    currentStep = nextStep
                }
            } else {
                finishOnboarding()
            }
        }
    }

    private func goBack() {
        withAnimation {
            if let previousStep = currentStep.previous {
                // Skip beliefs page going back if user is not religious
                if previousStep == .beliefs && appState.onboardingData.religion != "yes" {
                    currentStep = .religion
                // Skip notification permission page going back if already authorized
                } else if previousStep == .notificationPermission && NotificationManager.shared.isAuthorized {
                    currentStep = .positivity
                } else {
                    currentStep = previousStep
                }
            }
        }
    }

    private func finishOnboarding() {
        // Save onboarding data and mark as completed
        SharedDataManager.shared.saveOnboardingData(appState.onboardingData)
        SharedDataManager.shared.saveHasCompletedOnboarding(true)

        // Track onboarding completion
        AnalyticsManager.shared.trackOnboardingCompleted(data: appState.onboardingData)

        // Save user profile to Supabase (fire-and-forget)
        UserProfileService.shared.saveOnboardingProfile(appState.onboardingData)

        appState.navigateTo(.paywall)
    }
}

// Placeholder for screens not yet implemented
struct PlaceholderOnboardingView: View {
    let step: OnboardingStep
    let currentStepNumber: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        OnboardingTemplate(
            title: "\(step)".capitalized,
            subtitle: "This screen will collect user information",
            currentStep: currentStepNumber,
            totalSteps: totalSteps,
            onNext: onNext,
            onBack: onBack
        ) {
            Text("Placeholder for \(step)")
                .foregroundColor(.gray)
        }
    }
}
