import Foundation
import CoreLocation
import SwiftUI

// MARK: - 앱 상수 정의
struct AppConstants {

    // MARK: - 지도 관련 상수
    struct Map {
        // 개선된 3D 카메라 설정
        static let defaultAltitude: CLLocationDistance = 60.0 // 도보용 기본 고도
        static let defaultPitch: Double = 60.0 // 건물 가림 방지를 위한 완화된 각도
        static let defaultHeading: CLLocationDirection = 0.0

        // 동적 고도 설정
        static let walkingAltitude: CLLocationDistance = 60.0 // 도보 (2m/s 미만)
        static let cyclingAltitude: CLLocationDistance = 100.0 // 자전거 (2-10m/s)
        static let drivingAltitude: CLLocationDistance = 150.0 // 차량 (10m/s 이상)

        // 카메라 중심점 보정
        static let forwardDistance: CLLocationDistance = 25.0 // 사용자 앞 25m 지점을 중심으로

        // 기존 설정
        static let routeDeviationThreshold: CLLocationDistance = 50.0
        static let userLocationUpdateThreshold: CLLocationDistance = 100.0
    }

    // MARK: - 코인 관련 상수
    struct Coin {
        static let interval: CLLocationDistance = 10.0 // 10m 간격
        static let value: Int = 10
        static let defaultRiskLevel: Int = 1
    }

    // MARK: - 내비게이션 관련 상수
    struct Navigation {
        static let walkingSpeed: Double = 3000.0 / 3600.0 // m/s (어린이 기준)
        static let maxRouteNodes: Int = 50
        static let animationDuration: Double = 0.3
    }

    // MARK: - UI 관련 상수
    struct UI {
        static let buttonSize: CGFloat = 50.0
        static let cornerRadius: CGFloat = 20.0  // 기존 값 유지 (하위 호환성)
        static let padding: CGFloat = 20.0

        // 코너 반경 (Corner Radius)
        static let cornerRadiusSmall: CGFloat = 12.0
        static let cornerRadiusMedium: CGFloat = 15.0
        static let cornerRadiusLarge: CGFloat = 20.0

        // 그림자 (Shadow)
        static let shadowOpacity: Double = 0.9
        static let shadowRadius: CGFloat = 8.0
        static let shadowOffsetY: CGFloat = 4.0

        // 테두리 (Border)
        static let borderWidth: CGFloat = 2.5
    }

    // MARK: - 색상 상수 (Color Constants)
    struct Colors {
        // Primary Colors (앱 메인 색상)
        static let primary = Color(red: 0.37, green: 0.87, blue: 0.90) // #5FDDE5 (청록색)
        static let secondary = Color(red: 0.97, green: 0.53, blue: 0.38) // #F78860 (주황색)

        // Text Colors (텍스트 색상)
        static let textDark = Color(red: 0.18, green: 0.33, blue: 0.31) // #2D5550 (진한 녹색)
        static let textMedium = Color(red: 0.40, green: 0.65, blue: 0.54) // #65A78A (중간 녹색)
        static let textLight = Color.white

        // Background Colors (배경 색상)
        static let backgroundLight = Color(red: 0.95, green: 0.95, blue: 0.95)
        static let backgroundWhite = Color.white
        static let backgroundClear = Color.clear

        // Gradient Colors (그라데이션 색상)
        static let gradientTop = Color(red: 0.37, green: 0.87, blue: 0.90) // Primary
        static let gradientMidTop = Color(red: 0.32, green: 0.79, blue: 0.82)
        static let gradientMidBottom = Color(red: 0.85, green: 0.95, blue: 0.96)
        static let gradientBottom = Color.white

        // Icon/Status Colors (아이콘/상태 색상)
        static let iconPrimary = Color(red: 0.37, green: 0.87, blue: 0.90)
        static let iconSecondary = Color(red: 0.97, green: 0.53, blue: 0.38)
        static let iconGray = Color.gray
        static let iconRed = Color.red

        // Opacity Values (투명도 값)
        static let shadowOpacity: Double = 0.9
        static let shadowOpacityLight: Double = 0.4
        static let backgroundOpacity: Double = 0.2
    }

    // MARK: - 폰트 상수 (Font Constants)
    struct Fonts {
        // Font Sizes
        static let sizeExtraSmall: CGFloat = 12
        static let sizeSmall: CGFloat = 14
        static let sizeMedium: CGFloat = 16
        static let sizeLarge: CGFloat = 18
        static let sizeExtraLarge: CGFloat = 20
        static let sizeTitle: CGFloat = 32

        // Font Weights
        static let weightRegular: Font.Weight = .regular
        static let weightMedium: Font.Weight = .medium
        static let weightSemibold: Font.Weight = .semibold
        static let weightBold: Font.Weight = .bold
        static let weightHeavy: Font.Weight = .heavy

        // Common Font Styles
        static func rounded(size: CGFloat, weight: Font.Weight) -> Font {
            return .system(size: size, weight: weight, design: .rounded)
        }

        static func `default`(size: CGFloat, weight: Font.Weight) -> Font {
            return .system(size: size, weight: weight, design: .default)
        }

        static func monospaced(size: CGFloat, weight: Font.Weight) -> Font {
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }
}
