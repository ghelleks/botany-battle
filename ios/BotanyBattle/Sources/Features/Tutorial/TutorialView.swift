import SwiftUI

struct TutorialView: View {
    @EnvironmentObject var tutorialFeature: TutorialFeature
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $tutorialFeature.currentStep) {
            ForEach(TutorialStep.allSteps, id: \.self) { step in
                TutorialStepView(step: step)
                    .tag(step)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .overlay(alignment: .bottom) {
            TutorialNavigationBar()
                .environmentObject(tutorialFeature)
        }
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.1), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            tutorialFeature.startTutorial()
        }
    }
}

struct TutorialStepView: View {
    let step: TutorialStep
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: step.icon)
                .font(.system(size: 80))
                .foregroundColor(.green)
                .symbolEffect(.bounce, options: .repeat(.continuous))
            
            // Content
            VStack(spacing: 16) {
                Text(step.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Interactive Demo (if applicable)
            if let demoView = step.demoView {
                demoView
                    .frame(maxHeight: 200)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .animation(.easeInOut, value: step)
    }
}

struct TutorialNavigationBar: View {
    @EnvironmentObject var tutorialFeature: TutorialFeature
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            // Skip Button
            Button("Skip") {
                tutorialFeature.skipTutorial()
                appState.completeTutorial()
            }
            .opacity(tutorialFeature.canSkip ? 1 : 0)
            
            Spacer()
            
            // Progress Indicator
            HStack(spacing: 8) {
                ForEach(TutorialStep.allSteps.indices, id: \.self) { index in
                    Circle()
                        .fill(index == tutorialFeature.currentStepIndex ? .green : .gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            Spacer()
            
            // Next/Done Button
            Button(tutorialFeature.isLastStep ? "Get Started" : "Next") {
                if tutorialFeature.isLastStep {
                    tutorialFeature.completeTutorial()
                    appState.completeTutorial()
                } else {
                    tutorialFeature.nextStep()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .background(.regularMaterial)
    }
}

// MARK: - Tutorial Step Demo Views

struct PlantIdentificationDemo: View {
    @State private var isRevealed = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Mock plant image
            RoundedRectangle(cornerRadius: 12)
                .fill(.green.gradient)
                .frame(height: 100)
                .overlay {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            
            // Mock answer options
            VStack(spacing: 8) {
                ForEach(["Oak Tree", "Maple Tree", "Pine Tree", "Birch Tree"], id: \.self) { option in
                    Button(option) {
                        withAnimation {
                            isRevealed = true
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(option == "Oak Tree" && isRevealed ? .green.opacity(0.2) : .gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            if isRevealed {
                Text("Correct! 🎉")
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isRevealed = false
                }
            }
        }
    }
}

struct GameModeDemo: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(["Practice", "Speedrun", "Beat Clock"], id: \.self) { mode in
                VStack {
                    Image(systemName: iconForMode(mode))
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Text(mode)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private func iconForMode(_ mode: String) -> String {
        switch mode {
        case "Practice":
            return "book.fill"
        case "Speedrun":
            return "stopwatch.fill"
        case "Beat Clock":
            return "clock.fill"
        default:
            return "gamecontroller.fill"
        }
    }
}

struct ProfileDemo: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(.green.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plant Explorer")
                        .font(.headline)
                    Text("Level 5 • 1,250 points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                VStack {
                    Text("15")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Games")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("82%")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("245")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Best Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TutorialView()
        .environmentObject(TutorialFeature(userDefaultsService: UserDefaultsService()))
        .environmentObject(AppState())
}