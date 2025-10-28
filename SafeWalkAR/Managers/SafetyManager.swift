import Foundation
import CoreLocation

class SafetyManager: ObservableObject {
    @Published var safetyScore: Int = 100
    @Published var warnings: [String] = []
    
    func evaluateSafety(for location: CLLocation) -> SafetyEvaluation {
        // 간단한 안전도 평가 로직
        let currentHour = Calendar.current.component(.hour, from: Date())
        var score = 100
        var warnings: [String] = []
        
        // 시간대별 안전도 평가
        if currentHour < 6 || currentHour > 22 {
            score -= 20
            warnings.append("야간 시간대입니다. 주의하세요.")
        }
        
        // 위치별 안전도 평가 (예시)
        if location.coordinate.latitude < 37.35 || location.coordinate.latitude > 37.36 {
            score -= 10
            warnings.append("안전 구역을 벗어났습니다.")
        }
        
        self.safetyScore = max(0, score)
        self.warnings = warnings
        
        return SafetyEvaluation(
            score: self.safetyScore,
            warnings: warnings,
            riskLevel: getRiskLevel(from: score)
        )
    }
    
    private func getRiskLevel(from score: Int) -> RiskLevel {
        switch score {
        case 80...100:
            return .low
        case 60..<80:
            return .medium
        case 40..<60:
            return .high
        default:
            return .critical
        }
    }
}

struct SafetyEvaluation {
    let score: Int
    let warnings: [String]
    let riskLevel: RiskLevel
}

enum RiskLevel {
    case low
    case medium
    case high
    case critical
    
    var description: String {
        switch self {
        case .low:
            return "안전"
        case .medium:
            return "보통"
        case .high:
            return "주의"
        case .critical:
            return "위험"
        }
    }
    
    var color: String {
        switch self {
        case .low:
            return "green"
        case .medium:
            return "yellow"
        case .high:
            return "orange"
        case .critical:
            return "red"
        }
    }
}