import SwiftUI

// MARK: - Primary Button Style (메인 버튼)
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppConstants.Fonts.rounded(size: AppConstants.Fonts.sizeExtraLarge, weight: .bold))
            .foregroundColor(AppConstants.Colors.textLight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(AppConstants.Colors.primary)
            .cornerRadius(AppConstants.UI.cornerRadiusLarge)
            .shadow(
                color: AppConstants.Colors.primary.opacity(AppConstants.Colors.shadowOpacityLight),
                radius: AppConstants.UI.shadowRadius,
                x: 0,
                y: AppConstants.UI.shadowOffsetY
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style (보조 버튼)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppConstants.Fonts.rounded(size: AppConstants.Fonts.sizeExtraLarge, weight: .bold))
            .foregroundColor(AppConstants.Colors.textLight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(AppConstants.Colors.secondary)
            .cornerRadius(AppConstants.UI.cornerRadiusMedium)
            .shadow(
                color: AppConstants.Colors.secondary.opacity(AppConstants.Colors.shadowOpacityLight),
                radius: AppConstants.UI.shadowRadius,
                x: 0,
                y: AppConstants.UI.shadowOffsetY
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Outline Button Style (아웃라인 버튼)
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppConstants.Fonts.rounded(size: AppConstants.Fonts.sizeMedium, weight: .bold))
            .foregroundColor(AppConstants.Colors.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppConstants.Colors.backgroundWhite)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppConstants.Colors.primary, lineWidth: AppConstants.UI.borderWidth)
            )
            .cornerRadius(18)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - View Extension (편의성)
extension View {
    func primaryButtonStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }

    func secondaryButtonStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }

    func outlineButtonStyle() -> some View {
        self.buttonStyle(OutlineButtonStyle())
    }
}
