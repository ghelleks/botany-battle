import SwiftUI
import ComposableArchitecture

struct TutorialView: View {
    let store: StoreOf<TutorialFeature>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Bar
                TutorialProgressBar(
                    currentStep: store.currentStep,
                    totalSteps: TutorialFeature.State.TutorialStep.allCases.count
                )
                
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 40)
                        
                        // Step Icon
                        Image(systemName: store.currentStep.imageName)
                            .font(.system(size: 60))
                            .foregroundColor(.botanicalGreen)
                        
                        // Step Content
                        VStack(spacing: 16) {
                            Text(store.currentStep.title)
                                .botanicalStyle(BotanicalTextStyle.largeTitle)
                                .multilineTextAlignment(.center)
                            
                            Text(store.currentStep.description)
                                .botanicalStyle(BotanicalTextStyle.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        
                        // Interactive Demo (for specific steps)
                        if store.currentStep == .gameplay {
                            TutorialGameplayDemo()
                        } else if store.currentStep == .scoring {
                            TutorialScoringDemo()
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 32)
                }
                
                // Navigation Buttons
                TutorialNavigationButtons(store: store)
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Tutorial Progress Bar
struct TutorialProgressBar: View {
    let currentStep: TutorialFeature.State.TutorialStep
    let totalSteps: Int
    
    private var progress: Double {
        Double(currentStep.rawValue) / Double(totalSteps - 1)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tutorial")
                    .botanicalStyle(BotanicalTextStyle.headline)
                
                Spacer()
                
                Text("\(currentStep.rawValue + 1) of \(totalSteps)")
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .tint(.botanicalGreen)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Tutorial Navigation Buttons
struct TutorialNavigationButtons: View {
    let store: StoreOf<TutorialFeature>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Previous Button
                if store.currentStep.previous != nil {
                    BotanicalButton("Previous", style: .secondary, size: .medium) {
                        store.send(.previousStep)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
                
                // Next/Complete Button
                if store.currentStep == .complete {
                    BotanicalButton("Start Playing!", style: .primary, size: .medium) {
                        store.send(.completeTutorial)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    BotanicalButton("Next", style: .primary, size: .medium) {
                        store.send(.nextStep)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Skip Button
            if store.canSkip && store.currentStep != .complete {
                Button("Skip Tutorial") {
                    store.send(.skipTutorial)
                }
                .botanicalStyle(BotanicalTextStyle.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Tutorial Gameplay Demo
struct TutorialGameplayDemo: View {
    @State private var selectedAnswer: String?
    @State private var showResult = false
    
    private let demoPlant = "Monstera deliciosa"
    private let demoOptions = [
        "Monstera deliciosa",
        "Philodendron hederaceum",
        "Epipremnum aureum",
        "Ficus lyrata"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Try it out!")
                .botanicalStyle(BotanicalTextStyle.headline)
            
            // Mock plant image
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.botanicalGreen.opacity(0.2))
                .frame(height: 120)
                .overlay(
                    VStack {
                        Image(systemName: "leaf.fill")
                            .font(.largeTitle)
                            .foregroundColor(.botanicalGreen)
                        Text("Demo Plant")
                            .botanicalStyle(BotanicalTextStyle.caption)
                    }
                )
            
            // Demo answer options
            VStack(spacing: 8) {
                ForEach(demoOptions, id: \.self) { option in
                    Button(action: {
                        selectedAnswer = option
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showResult = true
                        }
                    }) {
                        HStack {
                            Text(option)
                                .botanicalStyle(BotanicalTextStyle.body)
                                .foregroundColor(getOptionColor(option))
                            
                            Spacer()
                            
                            if selectedAnswer == option && showResult {
                                Image(systemName: option == demoPlant ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(option == demoPlant ? .green : .red)
                            }
                        }
                        .padding()
                        .background(getOptionBackground(option))
                        .cornerRadius(8)
                    }
                    .disabled(showResult)
                }
            }
            
            if showResult {
                VStack(spacing: 8) {
                    if selectedAnswer == demoPlant {
                        Text("Correct! 🎉")
                            .botanicalStyle(BotanicalTextStyle.headline)
                            .foregroundColor(.green)
                    } else {
                        Text("That's okay, you'll learn!")
                            .botanicalStyle(BotanicalTextStyle.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Button("Try Again") {
                        selectedAnswer = nil
                        showResult = false
                    }
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.botanicalGreen)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getOptionColor(_ option: String) -> Color {
        if !showResult || selectedAnswer != option {
            return .primary
        }
        return option == demoPlant ? .white : .white
    }
    
    private func getOptionBackground(_ option: String) -> Color {
        if !showResult || selectedAnswer != option {
            return Color(.systemBackground)
        }
        return option == demoPlant ? .green : .red
    }
}

// MARK: - Tutorial Scoring Demo
struct TutorialScoringDemo: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Scoring Examples")
                .botanicalStyle(BotanicalTextStyle.headline)
            
            VStack(spacing: 12) {
                ScoringExampleRow(
                    scenario: "Both correct, you faster",
                    yourAnswer: "✓ (2.3s)",
                    opponentAnswer: "✓ (3.1s)",
                    result: "You win! +1 point",
                    resultColor: .green
                )
                
                ScoringExampleRow(
                    scenario: "You correct, opponent wrong",
                    yourAnswer: "✓ Correct",
                    opponentAnswer: "✗ Wrong",
                    result: "You win! +1 point",
                    resultColor: .green
                )
                
                ScoringExampleRow(
                    scenario: "Both wrong",
                    yourAnswer: "✗ Wrong",
                    opponentAnswer: "✗ Wrong",
                    result: "No points awarded",
                    resultColor: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Scoring Example Row
struct ScoringExampleRow: View {
    let scenario: String
    let yourAnswer: String
    let opponentAnswer: String
    let result: String
    let resultColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scenario)
                .botanicalStyle(BotanicalTextStyle.subheadline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("You: \(yourAnswer)")
                        .botanicalStyle(BotanicalTextStyle.caption)
                    Text("Opponent: \(opponentAnswer)")
                        .botanicalStyle(BotanicalTextStyle.caption)
                }
                
                Spacer()
                
                Text(result)
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(resultColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

#Preview {
    TutorialView(
        store: Store(
            initialState: TutorialFeature.State(),
            reducer: { TutorialFeature() }
        )
    )
}