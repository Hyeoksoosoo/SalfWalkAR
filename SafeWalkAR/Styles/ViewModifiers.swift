import SwiftUI

// MARK: - Card Style Modifier (카드 스타일)
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(AppConstants.Colors.backgroundWhite)
            .cornerRadius(AppConstants.UI.cornerRadiusLarge)
            .shadow(
                color: AppConstants.Colors.primary.opacity(AppConstants.Colors.shadowOpacity),
                radius: AppConstants.UI.shadowRadius,
                x: 0,
                y: AppConstants.UI.shadowOffsetY
            )
    }
}

// MARK: - Rounded Border Modifier (둥근 테두리)
struct RoundedBorderModifier: ViewModifier {
    var color: Color = AppConstants.Colors.primary
    var lineWidth: CGFloat = AppConstants.UI.borderWidth
    var cornerRadius: CGFloat = AppConstants.UI.cornerRadiusMedium

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(AppConstants.Colors.backgroundWhite)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color, lineWidth: lineWidth)
            )
            .cornerRadius(cornerRadius)
    }
}

// MARK: - Primary Shadow Modifier (메인 그림자)
struct PrimaryShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(
                color: AppConstants.Colors.primary.opacity(AppConstants.Colors.shadowOpacityLight),
                radius: AppConstants.UI.shadowRadius,
                x: 0,
                y: AppConstants.UI.shadowOffsetY
            )
    }
}

// MARK: - View Extensions (편의성)
extension View {
    /// 카드 스타일 적용
    func cardStyle() -> some View {
        self.modifier(CardModifier())
    }

    /// 둥근 테두리 적용
    func roundedBorder(
        color: Color = AppConstants.Colors.primary,
        lineWidth: CGFloat = AppConstants.UI.borderWidth,
        cornerRadius: CGFloat = AppConstants.UI.cornerRadiusMedium
    ) -> some View {
        self.modifier(RoundedBorderModifier(color: color, lineWidth: lineWidth, cornerRadius: cornerRadius))
    }

    /// Primary 그림자 적용
    func primaryShadow() -> some View {
        self.modifier(PrimaryShadowModifier())
    }
}
