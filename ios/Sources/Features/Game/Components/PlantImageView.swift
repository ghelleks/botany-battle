import SwiftUI

struct PlantImageView: View {
    let plant: Plant
    let mode: GameMode?
    @State private var imageScale: CGFloat = 1.0
    @State private var isLoading = true
    @State private var hasError = false
    @State private var retryCount = 0
    @State private var isOffline = false
    
    private let maxRetries = 3
    
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
                
                // Plant Image with enhanced error handling
                AsyncImage(url: URL(string: currentImageURL)) { phase in
                    switch phase {
                    case .empty:
                        LoadingImageView(isRetrying: retryCount > 0)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(imageScale)
                            .clipped()
                            .onAppear {
                                isLoading = false
                                hasError = false
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    imageScale = 1.0
                                }
                            }
                    case .failure(let error):
                        ErrorImageView(
                            error: error,
                            retryCount: retryCount,
                            maxRetries: maxRetries,
                            onRetry: handleRetry,
                            isOffline: isOffline
                        )
                        .onAppear {
                            isLoading = false
                            hasError = true
                            checkNetworkStatus()
                        }
                    @unknown default:
                        LoadingImageView(isRetrying: false)
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
    
    // MARK: - Helper Methods and Computed Properties
    
    private var currentImageURL: String {
        // Try thumbnail first if available and we're on limited connection
        if isOffline || (retryCount > 1 && plant.thumbnailURL != nil) {
            return plant.thumbnailURL ?? plant.imageURL
        }
        return plant.imageURL
    }
    
    private func handleRetry() {
        guard retryCount < maxRetries else { return }
        retryCount += 1
        hasError = false
        isLoading = true
        
        // Add a small delay before retrying
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount) * 0.5) {
            // The AsyncImage will automatically retry when the URL changes or view updates
        }
    }
    
    private func checkNetworkStatus() {
        // Simple network check - in a real app you might use Network framework
        let url = URL(string: "https://www.apple.com")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        
        URLSession.shared.dataTask(with: request) { _, _, error in
            DispatchQueue.main.async {
                isOffline = (error != nil)
            }
        }.resume()
    }
}

// MARK: - Loading Image View
struct LoadingImageView: View {
    let isRetrying: Bool
    @State private var rotationAngle: Double = 0
    
    init(isRetrying: Bool = false) {
        self.isRetrying = isRetrying
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isRetrying ? "arrow.clockwise" : "leaf.fill")
                .font(.system(size: 40))
                .foregroundColor(isRetrying ? .orange : .botanicalGreen)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
            
            Text(isRetrying ? "Retrying..." : "Loading plant...")
                .botanicalStyle(BotanicalTextStyle.body)
                .foregroundColor(.secondary)
            
            if isRetrying {
                Text("Attempting to load image...")
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Error Image View
struct ErrorImageView: View {
    let error: Error
    let retryCount: Int
    let maxRetries: Int
    let onRetry: () -> Void
    let isOffline: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundColor(iconColor)
            
            Text(errorMessage)
                .botanicalStyle(BotanicalTextStyle.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if retryCount < maxRetries {
                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.botanicalGreen)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .botanicalStyle(BotanicalTextStyle.caption)
            }
            
            if isOffline {
                HStack(spacing: 4) {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                    Text("Offline")
                        .botanicalStyle(BotanicalTextStyle.caption)
                }
                .foregroundColor(.orange)
            }
            
            if retryCount > 0 {
                Text("Retry \(retryCount)/\(maxRetries)")
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var iconName: String {
        if isOffline {
            return "wifi.slash"
        } else if retryCount >= maxRetries {
            return "xmark.circle.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        if isOffline {
            return .orange
        } else if retryCount >= maxRetries {
            return .red
        } else {
            return .orange
        }
    }
    
    private var errorMessage: String {
        if isOffline {
            return "No internet connection"
        } else if retryCount >= maxRetries {
            return "Failed to load image after \(maxRetries) attempts"
        } else {
            return "Unable to load plant image"
        }
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
                        Text(plant.scientificName)
                            .botanicalStyle(BotanicalTextStyle.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .italic()
                        
                        Text("Family: \(plant.family)")
                            .botanicalStyle(BotanicalTextStyle.caption)
                            .foregroundColor(.white.opacity(0.8))
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
            return "Family: \(plant.family)"
        case 2:
            let parts = plant.scientificName.split(separator: " ")
            return "Scientific name starts with: \(parts.first ?? "Unknown")"
        case 3:
            if let region = plant.regions.first {
                return "Native to: \(region)"
            }
            return "This plant is native to specific geographic regions."
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
                scientificName: "Rosa rubiginosa",
                commonNames: ["Rose", "Sweet Briar"],
                family: "Rosaceae",
                genus: "Rosa",
                species: "rubiginosa",
                imageURL: "https://example.com/rose.jpg",
                thumbnailURL: "https://example.com/rose-thumb.jpg",
                description: "Roses have been cultivated for over 5,000 years.",
                difficulty: 25,
                rarity: .common,
                habitat: ["Gardens"],
                regions: ["Asia"],
                characteristics: Plant.Characteristics(
                    leafType: nil,
                    flowerColor: ["Red"],
                    bloomTime: ["Summer"],
                    height: nil,
                    sunRequirement: nil,
                    waterRequirement: nil,
                    soilType: []
                ),
                iNaturalistId: nil
            ),
            mode: .beatTheClock
        )
        .frame(height: 300)
        
        EnhancedPlantImageView(
            plant: Plant(
                id: "2",
                scientificName: "Helianthus annuus",
                commonNames: ["Sunflower", "Common Sunflower"],
                family: "Asteraceae",
                genus: "Helianthus",
                species: "annuus",
                imageURL: "https://example.com/sunflower.jpg",
                thumbnailURL: "https://example.com/sunflower-thumb.jpg",
                description: "Sunflowers can grow up to 12 feet tall.",
                difficulty: 15,
                rarity: .common,
                habitat: ["Fields"],
                regions: ["North America"],
                characteristics: Plant.Characteristics(
                    leafType: nil,
                    flowerColor: ["Yellow"],
                    bloomTime: ["Summer"],
                    height: nil,
                    sunRequirement: nil,
                    waterRequirement: nil,
                    soilType: []
                ),
                iNaturalistId: nil
            ),
            mode: .speedrun,
            showHints: true,
            hintLevel: 1
        )
        .frame(height: 250)
    }
    .padding()
}