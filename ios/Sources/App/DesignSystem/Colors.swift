import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    static let botanicalGreen = Color(red: 0.2, green: 0.6, blue: 0.2)
    static let botanicalDarkGreen = Color(red: 0.1, green: 0.4, blue: 0.1)
    static let botanicalLightGreen = Color(red: 0.6, green: 0.8, blue: 0.6)
    
    static let earthBrown = Color(red: 0.4, green: 0.3, blue: 0.2)
    static let skyBlue = Color(red: 0.5, green: 0.7, blue: 0.9)
    
    static let successGreen = Color(red: 0.2, green: 0.7, blue: 0.3)
    static let warningOrange = Color(red: 0.9, green: 0.6, blue: 0.2)
    static let errorRed = Color(red: 0.8, green: 0.2, blue: 0.2)
    
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(UIColor.tertiaryLabel)
    
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)
    
    static let cardBackground = Color(UIColor.systemBackground)
    static let cardShadow = Color.black.opacity(0.1)
    
    static let rarityCommon = Color.gray
    static let rarityUncommon = Color.green
    static let rarityRare = Color.blue
    static let rarityVeryRare = Color.purple
    static let rarityLegendary = Color.orange
}

struct ColorTheme {
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let surface: Color
    let success: Color
    let warning: Color
    let error: Color
    
    static let light = ColorTheme(
        primary: .botanicalGreen,
        secondary: .botanicalDarkGreen,
        accent: .skyBlue,
        background: .backgroundPrimary,
        surface: .cardBackground,
        success: .successGreen,
        warning: .warningOrange,
        error: .errorRed
    )
    
    static let dark = ColorTheme(
        primary: .botanicalLightGreen,
        secondary: .botanicalGreen,
        accent: .skyBlue,
        background: .backgroundPrimary,
        surface: .cardBackground,
        success: .successGreen,
        warning: .warningOrange,
        error: .errorRed
    )
}