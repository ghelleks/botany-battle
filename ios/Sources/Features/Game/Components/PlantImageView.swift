import SwiftUI

struct PlantImageView: View {
    let plant: Plant
    let mode: GameMode?
    @State private var imageScale: CGFloat = 1.0
    @State private var isLoading = true
    
    init(plant: Plant, mode: GameMode? = nil) {
        self.plant = plant
        self.mode = mode
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemGray6),
                                Color(.systemGray5)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                // Plant Image
                AsyncImage(url: URL(string: plant.imageURL)) { phase in
                    switch phase {
                    case .empty:
                        LoadingImageView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(imageScale)
                            .clipped()
                            .onAppear {
                                isLoading = false
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    imageScale = 1.0
                                }
                            }
                    case .failure(_):
                        ErrorImageView()
                    @unknown default:
                        LoadingImageView()
                    }
                }
                .cornerRadius(12)
                
                // Mode-specific overlays
                if let mode = mode {
                    ModeOverlayView(mode: mode, plant: plant)
                }
                
                // Plant info overlay (bottom)
                if !isLoading {
                    PlantInfoOverlay(plant: plant)
                }
            }
        }
        .onAppear {
            imageScale = 0.9
        }
    }
}

// MARK: - Loading Image View
struct LoadingImageView: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 40))
                .foregroundColor(.botanicalGreen)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
            
            Text("Loading plant...")
                .botanicalStyle(BotanicalTextStyle.body)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Error Image View
struct ErrorImageView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Unable to load image")
                .botanicalStyle(BotanicalTextStyle.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Mode Overlay View
struct ModeOverlayView: View {
    let mode: GameMode
    let plant: Plant
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                // Mode indicator badge
                HStack(spacing: 4) {
                    Image(systemName: modeIcon)
                        .font(.caption)
                    Text(mode.displayName)
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(modeColor.opacity(0.9))
                )
                .foregroundColor(.white)
            }
            .padding(12)
            
            Spacer()
        }
    }
    
    private var modeIcon: String {
        switch mode {
        case .multiplayer: return "person.2.fill"
        case .beatTheClock: return "timer"
        case .speedrun: return "bolt.fill"
        }
    }
    
    private var modeColor: Color {
        switch mode {
        case .multiplayer: return .botanicalGreen
        case .beatTheClock: return .orange
        case .speedrun: return .blue
        }
    }
}

// MARK: - Plant Info Overlay
struct PlantInfoOverlay: View {
    let plant: Plant
    @State private var showDetails = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if showDetails {
                        if let scientificName = plant.scientificName {
                            Text(scientificName)
                                .botanicalStyle(BotanicalTextStyle.caption)
                                .foregroundColor(.white.opacity(0.9))
                                .italic()
                        }
                        
                        if let family = plant.family {
                            Text("Family: \(family)")
                                .botanicalStyle(BotanicalTextStyle.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showDetails.toggle()
                    }
                }) {
                    Image(systemName: showDetails ? "info.circle.fill" : "info.circle")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .cornerRadius(12)
    }
}

// MARK: - Enhanced Plant Display (for specific modes)
struct EnhancedPlantImageView: View {
    let plant: Plant
    let mode: GameMode
    let showHints: Bool
    let hintLevel: Int
    @State private var hintOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            PlantImageView(plant: plant, mode: mode)
            
            if showHints {
                HintOverlayView(
                    plant: plant,
                    hintLevel: hintLevel,
                    opacity: hintOpacity
                )
                .onAppear {
                    withAnimation(.easeIn(duration: 0.5)) {
                        hintOpacity = 1.0
                    }
                }
            }
        }
    }
}

// MARK: - Hint Overlay View
struct HintOverlayView: View {
    let plant: Plant
    let hintLevel: Int
    let opacity: Double
    
    var body: some View {
        VStack {
            Spacer()
            
            if hintLevel > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hint:")
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .foregroundColor(.yellow)
                        .fontWeight(.semibold)
                    
                    Text(hintText)
                        .botanicalStyle(BotanicalTextStyle.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.8))
                )
                .padding()
            }
        }
        .opacity(opacity)
    }
    
    private var hintText: String {
        switch hintLevel {
        case 1:
            return plant.family ?? "This plant belongs to a specific botanical family."
        case 2:
            if let scientificName = plant.scientificName {
                let parts = scientificName.split(separator: " ")
                return "Scientific name starts with: \(parts.first ?? "")"
            }
            return "This plant has a unique scientific classification."
        case 3:
            return plant.nativeRegion ?? "This plant is native to a specific geographic region."
        default:
            return "Look closely at the plant's distinctive features."
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PlantImageView(
            plant: Plant(
                id: "1",
                primaryCommonName: "Rose",
                scientificName: "Rosa rubiginosa",
                family: "Rosaceae",
                imageURL: "https://example.com/rose.jpg",
                interestingFact: "Roses have been cultivated for over 5,000 years.",
                nativeRegion: "Asia"
            ),
            mode: .beatTheClock
        )
        .frame(height: 300)
        
        EnhancedPlantImageView(
            plant: Plant(
                id: "2",
                primaryCommonName: "Sunflower",
                scientificName: "Helianthus annuus",
                family: "Asteraceae",
                imageURL: "https://example.com/sunflower.jpg",
                interestingFact: "Sunflowers can grow up to 12 feet tall.",
                nativeRegion: "North America"
            ),
            mode: .speedrun,
            showHints: true,
            hintLevel: 1
        )
        .frame(height: 250)
    }
    .padding()
}