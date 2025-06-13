import SwiftUI

struct BotanicalButton: View {
    let title: String
    let action: () -> Void
    let style: Style
    let size: Size
    let isLoading: Bool
    let isDisabled: Bool
    
    init(
        _ title: String,
        style: Style = .primary,
        size: Size = .medium,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: size.maxWidth)
            .frame(height: size.height)
            .foregroundColor(style.foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(style.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .stroke(style.borderColor, lineWidth: style.borderWidth)
                    )
            )
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.6 : 1.0)
        .scaleEffect(isLoading ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
    
    enum Style {
        case primary
        case secondary
        case tertiary
        case destructive
        case success
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .botanicalGreen
            case .secondary: return .backgroundSecondary
            case .tertiary: return .clear
            case .destructive: return .errorRed
            case .success: return .successGreen
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .textPrimary
            case .tertiary: return .botanicalGreen
            case .destructive: return .white
            case .success: return .white
            }
        }
        
        var borderColor: Color {
            switch self {
            case .primary: return .clear
            case .secondary: return .botanicalGreen.opacity(0.3)
            case .tertiary: return .botanicalGreen
            case .destructive: return .clear
            case .success: return .clear
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .primary, .destructive, .success: return 0
            case .secondary, .tertiary: return 1
            }
        }
    }
    
    enum Size {
        case small
        case medium
        case large
        
        var height: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 44
            case .large: return 52
            }
        }
        
        var font: Font {
            switch self {
            case .small: return .botanicalCallout
            case .medium: return .botanicalBody
            case .large: return .botanicalHeadline
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }
        }
        
        var maxWidth: CGFloat? {
            switch self {
            case .small: return nil
            case .medium: return nil
            case .large: return .infinity
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        BotanicalButton("Primary Button", style: .primary) { }
        BotanicalButton("Secondary Button", style: .secondary) { }
        BotanicalButton("Tertiary Button", style: .tertiary) { }
        BotanicalButton("Loading Button", style: .primary, isLoading: true) { }
        BotanicalButton("Disabled Button", style: .primary, isDisabled: true) { }
        BotanicalButton("Large Button", style: .primary, size: .large) { }
    }
    .padding()
}