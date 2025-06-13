import SwiftUI

@available(iOS 14.0, macOS 11.0, *)
extension Font {
    static let botanicalLargeTitle = Font.custom("Avenir-Heavy", size: 34, relativeTo: .largeTitle)
    static let botanicalTitle = Font.custom("Avenir-Medium", size: 28, relativeTo: .title)
    static let botanicalTitle2 = Font.custom("Avenir-Medium", size: 22, relativeTo: .title2)
    static let botanicalTitle3 = Font.custom("Avenir-Medium", size: 20, relativeTo: .title3)
    static let botanicalHeadline = Font.custom("Avenir-Medium", size: 17, relativeTo: .headline)
    static let botanicalSubheadline = Font.custom("Avenir-Book", size: 15, relativeTo: .subheadline)
    static let botanicalBody = Font.custom("Avenir-Book", size: 17, relativeTo: .body)
    static let botanicalCallout = Font.custom("Avenir-Book", size: 16, relativeTo: .callout)
    static let botanicalFootnote = Font.custom("Avenir-Book", size: 13, relativeTo: .footnote)
    static let botanicalCaption = Font.custom("Avenir-Book", size: 12, relativeTo: .caption)
    static let botanicalCaption2 = Font.custom("Avenir-Book", size: 11, relativeTo: .caption2)
}

struct BotanicalTextStyle {
    let font: Font
    let color: Color
    let lineSpacing: CGFloat
    let letterSpacing: CGFloat
    
    static let largeTitle = BotanicalTextStyle(
        font: .botanicalLargeTitle,
        color: .textPrimary,
        lineSpacing: 2,
        letterSpacing: -0.5
    )
    
    static let title = BotanicalTextStyle(
        font: .botanicalTitle,
        color: .textPrimary,
        lineSpacing: 1.5,
        letterSpacing: -0.3
    )
    
    static let title2 = BotanicalTextStyle(
        font: .botanicalTitle2,
        color: .textPrimary,
        lineSpacing: 1.2,
        letterSpacing: -0.2
    )
    
    static let title3 = BotanicalTextStyle(
        font: .botanicalTitle3,
        color: .textPrimary,
        lineSpacing: 1,
        letterSpacing: -0.1
    )
    
    static let headline = BotanicalTextStyle(
        font: .botanicalHeadline,
        color: .textPrimary,
        lineSpacing: 1,
        letterSpacing: 0
    )
    
    static let subheadline = BotanicalTextStyle(
        font: .botanicalSubheadline,
        color: .textSecondary,
        lineSpacing: 0.8,
        letterSpacing: 0
    )
    
    static let body = BotanicalTextStyle(
        font: .botanicalBody,
        color: .textPrimary,
        lineSpacing: 1.2,
        letterSpacing: 0
    )
    
    static let callout = BotanicalTextStyle(
        font: .botanicalCallout,
        color: .textSecondary,
        lineSpacing: 1,
        letterSpacing: 0
    )
    
    static let footnote = BotanicalTextStyle(
        font: .botanicalFootnote,
        color: .textTertiary,
        lineSpacing: 0.8,
        letterSpacing: 0
    )
    
    static let caption = BotanicalTextStyle(
        font: .botanicalCaption,
        color: .textTertiary,
        lineSpacing: 0.6,
        letterSpacing: 0.1
    )
    
    static let caption2 = BotanicalTextStyle(
        font: .botanicalCaption2,
        color: .textTertiary,
        lineSpacing: 0.5,
        letterSpacing: 0.1
    )
}

extension Text {
    func botanicalStyle(_ style: BotanicalTextStyle) -> some View {
        self
            .font(style.font)
            .foregroundColor(style.color)
            .lineSpacing(style.lineSpacing)
            .kerning(style.letterSpacing)
    }
}