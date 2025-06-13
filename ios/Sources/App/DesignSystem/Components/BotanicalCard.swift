import SwiftUI

struct BotanicalCard<Content: View>: View {
    let content: Content
    let style: Style
    let padding: EdgeInsets
    
    init(
        style: Style = .default,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.style = style
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(style.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cornerRadius)
                            .stroke(style.borderColor, lineWidth: style.borderWidth)
                    )
                    .shadow(
                        color: style.shadowColor,
                        radius: style.shadowRadius,
                        x: style.shadowOffset.x,
                        y: style.shadowOffset.y
                    )
            )
    }
    
    enum Style {
        case `default`
        case elevated
        case outlined
        case plant
        case game
        
        var backgroundColor: Color {
            switch self {
            case .default: return .cardBackground
            case .elevated: return .cardBackground
            case .outlined: return .clear
            case .plant: return .botanicalLightGreen.opacity(0.1)
            case .game: return .skyBlue.opacity(0.1)
            }
        }
        
        var borderColor: Color {
            switch self {
            case .default: return .clear
            case .elevated: return .clear
            case .outlined: return .botanicalGreen.opacity(0.3)
            case .plant: return .botanicalGreen.opacity(0.2)
            case .game: return .skyBlue.opacity(0.3)
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .default, .elevated: return 0
            case .outlined, .plant, .game: return 1
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .default, .outlined: return 12
            case .elevated: return 16
            case .plant, .game: return 14
            }
        }
        
        var shadowColor: Color {
            switch self {
            case .default: return .cardShadow
            case .elevated: return .cardShadow.opacity(0.15)
            case .outlined, .plant, .game: return .clear
            }
        }
        
        var shadowRadius: CGFloat {
            switch self {
            case .default: return 2
            case .elevated: return 8
            case .outlined, .plant, .game: return 0
            }
        }
        
        var shadowOffset: CGSize {
            switch self {
            case .default: return CGSize(width: 0, height: 1)
            case .elevated: return CGSize(width: 0, height: 4)
            case .outlined, .plant, .game: return .zero
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            BotanicalCard(style: .default) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Card")
                        .botanicalStyle(.headline)
                    Text("This is a default card with basic styling and subtle shadow.")
                        .botanicalStyle(.body)
                }
            }
            
            BotanicalCard(style: .elevated) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Elevated Card")
                        .botanicalStyle(.headline)
                    Text("This is an elevated card with more prominent shadow.")
                        .botanicalStyle(.body)
                }
            }
            
            BotanicalCard(style: .outlined) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Outlined Card")
                        .botanicalStyle(.headline)
                    Text("This is an outlined card with a border and no shadow.")
                        .botanicalStyle(.body)
                }
            }
            
            BotanicalCard(style: .plant) {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .font(.title2)
                        .foregroundColor(.botanicalGreen)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rosa damascena")
                            .botanicalStyle(.headline)
                        Text("Damask Rose")
                            .botanicalStyle(.subheadline)
                    }
                    
                    Spacer()
                }
            }
            
            BotanicalCard(style: .game) {
                HStack(spacing: 12) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.title2)
                        .foregroundColor(.skyBlue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Game")
                            .botanicalStyle(.headline)
                        Text("Round 3 of 5")
                            .botanicalStyle(.subheadline)
                    }
                    
                    Spacer()
                    
                    Text("2:30")
                        .botanicalStyle(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.skyBlue.opacity(0.2))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
    }
}