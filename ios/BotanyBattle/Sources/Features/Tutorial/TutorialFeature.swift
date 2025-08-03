import SwiftUI
import Combine

// MARK: - Tutorial Feature

@MainActor
class TutorialFeature: ObservableObject {
    @Published var currentStep = 0
    @Published var isCompleted = false
    @Published var showTutorial = false
    @Published var isTransitioning = false
    
    let userDefaultsService: UserDefaultsService
    let tutorialSteps: [TutorialStep]
    private var cancellables = Set<AnyCancellable>()
    
    init(userDefaultsService: UserDefaultsService) {
        self.userDefaultsService = userDefaultsService
        self.tutorialSteps = TutorialStep.defaultSteps
        
        // Check if tutorial should be shown
        self.showTutorial = userDefaultsService.isFirstLaunch && !userDefaultsService.tutorialCompleted
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Listen for tutorial completion changes
        userDefaultsService.$tutorialCompleted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completed in
                if completed {
                    self?.isCompleted = true
                    self?.showTutorial = false
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Navigation
    
    func nextStep() {
        guard currentStep < tutorialSteps.count - 1 else {
            completeTutorial()
            return
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isTransitioning = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.currentStep += 1
            
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.isTransitioning = false
            }
        }
    }
    
    func previousStep() {
        guard currentStep > 0 else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isTransitioning = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.currentStep -= 1
            
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.isTransitioning = false
            }
        }
    }
    
    func skipTutorial() {
        withAnimation(.easeInOut(duration: 0.5)) {
            completeTutorial()
        }
    }
    
    func completeTutorial() {
        userDefaultsService.tutorialCompleted = true
        userDefaultsService.markFirstLaunchComplete()
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isCompleted = true
            showTutorial = false
        }
        
        // Trigger success haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }
    
    func restartTutorial() {
        currentStep = 0
        isCompleted = false
        showTutorial = true
        userDefaultsService.tutorialCompleted = false
    }
    
    // MARK: - Computed Properties
    
    var currentTutorialStep: TutorialStep {
        guard currentStep < tutorialSteps.count else {
            return tutorialSteps.last ?? TutorialStep.defaultSteps.last!
        }
        return tutorialSteps[currentStep]
    }
    
    var progress: Double {
        guard tutorialSteps.count > 0 else { return 0 }
        return Double(currentStep + 1) / Double(tutorialSteps.count)
    }
    
    var progressText: String {
        return "\(currentStep + 1) of \(tutorialSteps.count)"
    }
    
    var isFirstStep: Bool {
        return currentStep == 0
    }
    
    var isLastStep: Bool {
        return currentStep == tutorialSteps.count - 1
    }
    
    var canGoNext: Bool {
        return currentStep < tutorialSteps.count - 1
    }
    
    var canGoPrevious: Bool {
        return currentStep > 0
    }
}

// MARK: - Tutorial Step Model

struct TutorialStep: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let type: TutorialStepType
    let interactionRequired: Bool
    let customAction: (() -> Void)?
    
    init(
        title: String,
        description: String,
        icon: String,
        type: TutorialStepType = .information,
        interactionRequired: Bool = false,
        customAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.type = type
        self.interactionRequired = interactionRequired
        self.customAction = customAction
    }
    
    static func == (lhs: TutorialStep, rhs: TutorialStep) -> Bool {
        return lhs.id == rhs.id
    }
    
    static let defaultSteps: [TutorialStep] = [
        TutorialStep(
            title: "Welcome to Botany Battle!",
            description: "Test your botanical knowledge in exciting plant identification challenges. Let's take a quick tour to get you started!",
            icon: "leaf.fill",
            type: .welcome
        ),
        
        TutorialStep(
            title: "How to Play",
            description: "You'll see plant images and choose the correct name from multiple options. Answer quickly and correctly to earn points!",
            icon: "gamecontroller.fill",
            type: .gameplay
        ),
        
        TutorialStep(
            title: "Game Modes",
            description: "Practice Mode: Learn at your own pace\nTime Attack: Race against the clock\nSpeedrun: Identify 25 plants as fast as possible",
            icon: "speedometer",
            type: .features
        ),
        
        TutorialStep(
            title: "Earn Trophies",
            description: "Win games to earn trophies! Use them in the Shop to unlock themes, avatars, and special effects.",
            icon: "trophy.fill",
            type: .rewards
        ),
        
        TutorialStep(
            title: "Multiplayer Battles",
            description: "Challenge friends or find random opponents for real-time plant identification battles. Game Center account required.",
            icon: "person.2.fill",
            type: .social
        ),
        
        TutorialStep(
            title: "Ready to Play!",
            description: "You're all set! Start with Practice Mode to get familiar with different plants, then challenge yourself with other modes.",
            icon: "checkmark.circle.fill",
            type: .completion
        )
    ]
}

// MARK: - Tutorial Step Type

enum TutorialStepType: String, CaseIterable {
    case welcome = "welcome"
    case gameplay = "gameplay"
    case features = "features"
    case rewards = "rewards"
    case social = "social"
    case completion = "completion"
    case information = "information"
    case interactive = "interactive"
    
    var backgroundColor: Color {
        switch self {
        case .welcome: return .green.opacity(0.1)
        case .gameplay: return .blue.opacity(0.1)
        case .features: return .orange.opacity(0.1)
        case .rewards: return .yellow.opacity(0.1)
        case .social: return .purple.opacity(0.1)
        case .completion: return .green.opacity(0.1)
        case .information: return .gray.opacity(0.1)
        case .interactive: return .blue.opacity(0.1)
        }
    }
    
    var accentColor: Color {
        switch self {
        case .welcome: return .green
        case .gameplay: return .blue
        case .features: return .orange
        case .rewards: return .yellow
        case .social: return .purple
        case .completion: return .green
        case .information: return .gray
        case .interactive: return .blue
        }
    }
}

// MARK: - Tutorial Components

struct TutorialStepView: View {
    let step: TutorialStep
    let isTransitioning: Bool
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        let isLandscape = verticalSizeClass == .compact
        
        VStack(spacing: isLandscape ? 16 : 24) {
            // Icon
            Image(systemName: step.icon)
                .font(.system(size: isLandscape ? 50 : 70))
                .foregroundColor(step.type.accentColor)
                .scaleEffect(isTransitioning ? 0.8 : 1.0)
                .opacity(isTransitioning ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isTransitioning)
            
            // Content
            VStack(spacing: isLandscape ? 8 : 12) {
                Text(step.title)
                    .font(isLandscape ? .title2 : .largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                Text(step.description)
                    .font(isLandscape ? .body : .title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(isTransitioning ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.3).delay(0.1), value: isTransitioning)
        }
        .padding(.horizontal, isLandscape ? 24 : 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TutorialProgressView: View {
    let progress: Double
    let progressText: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tutorial")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

struct TutorialNavigationView: View {
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isLastStep: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        let isLandscape = verticalSizeClass == .compact
        
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Previous button
                if canGoPrevious {
                    Button("Previous") {
                        onPrevious()
                    }
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(isLandscape ? 12 : 16)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
                
                // Next/Complete button
                Button(isLastStep ? "Get Started!" : "Next") {
                    onNext()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(isLandscape ? 12 : 16)
                .background(Color.green)
                .cornerRadius(12)
            }
            
            // Skip button
            if !isLastStep {
                Button("Skip Tutorial") {
                    onSkip()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Tutorial Coordinator

struct TutorialCoordinator: View {
    @StateObject private var tutorialFeature: TutorialFeature
    let onComplete: () -> Void
    
    init(userDefaultsService: UserDefaultsService, onComplete: @escaping () -> Void) {
        self._tutorialFeature = StateObject(wrappedValue: TutorialFeature(userDefaultsService: userDefaultsService))
        self.onComplete = onComplete
    }
    
    var body: some View {
        if tutorialFeature.showTutorial && !tutorialFeature.isCompleted {
            TutorialView(
                tutorialFeature: tutorialFeature,
                onComplete: {
                    tutorialFeature.completeTutorial()
                    onComplete()
                }
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.9)),
                removal: .opacity.combined(with: .scale(scale: 1.1))
            ))
        }
    }
}

struct TutorialView: View {
    @ObservedObject var tutorialFeature: TutorialFeature
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            TutorialProgressView(
                progress: tutorialFeature.progress,
                progressText: tutorialFeature.progressText
            )
            
            // Content
            TutorialStepView(
                step: tutorialFeature.currentTutorialStep,
                isTransitioning: tutorialFeature.isTransitioning
            )
            
            // Navigation
            TutorialNavigationView(
                canGoPrevious: tutorialFeature.canGoPrevious,
                canGoNext: tutorialFeature.canGoNext,
                isLastStep: tutorialFeature.isLastStep,
                onPrevious: tutorialFeature.previousStep,
                onNext: tutorialFeature.nextStep,
                onSkip: tutorialFeature.skipTutorial
            )
        }
        .background(tutorialFeature.currentTutorialStep.type.backgroundColor)
        .onChange(of: tutorialFeature.isCompleted) { isCompleted in
            if isCompleted {
                onComplete()
            }
        }
    }
}

// MARK: - Tutorial Helper Extensions

extension UserDefaultsService {
    var shouldShowTutorial: Bool {
        return isFirstLaunch && !tutorialCompleted
    }
}

// MARK: - Preview

#Preview("Tutorial Step") {
    TutorialStepView(
        step: TutorialStep.defaultSteps[0],
        isTransitioning: false
    )
}

#Preview("Tutorial Progress") {
    TutorialProgressView(
        progress: 0.5,
        progressText: "3 of 6"
    )
}

#Preview("Tutorial Navigation") {
    TutorialNavigationView(
        canGoPrevious: true,
        canGoNext: true,
        isLastStep: false,
        onPrevious: {},
        onNext: {},
        onSkip: {}
    )
}