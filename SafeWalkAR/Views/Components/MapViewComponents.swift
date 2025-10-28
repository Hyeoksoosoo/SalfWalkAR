import SwiftUI
import MapKit
import CoreLocation
import AudioToolbox

// MARK: - 현재 위치로 돌아가기 버튼
struct ReturnToLocationButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: AppConstants.UI.buttonSize, height: AppConstants.UI.buttonSize)
                .background(Color(red: 0.2, green: 0.4, blue: 0.8))
                .clipShape(Circle())
                .shadow(
                    color: Color.black.opacity(AppConstants.Colors.shadowOpacity),
                    radius: AppConstants.UI.shadowRadius,
                    x: 0,
                    y: 2
                )
        }
        .padding(.trailing, AppConstants.UI.padding)
        .padding(.bottom, 100) // 하단 패널 위에 위치하도록 여백 추가
    }
}

// MARK: - 내비게이션 정보 패널
struct NavigationInfoPanel: View {
    let currentStep: MKRoute.Step?
    let remainingDistance: CLLocationDistance
    let estimatedArrivalTime: Date?
    let isNavigating: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("집으로 가는 길")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    if let destination = currentStep?.instructions {
                        Text(destination)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.8))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // 거리 및 시간 정보
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDistance(remainingDistance))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    if let arrivalTime = estimatedArrivalTime {
                        Text("도착 예정: \(formatTime(arrivalTime))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // 진행률 바
            ProgressView(value: isNavigating ? 0.3 : 0.0)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 0.2, green: 0.4, blue: 0.8)))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding(AppConstants.UI.padding)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                .stroke(Color(red: 0.4, green: 0.7, blue: 0.9), lineWidth: 2)
        )
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - 거리 포맷팅
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    // MARK: - 시간 포맷팅
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Turn-by-Turn 안내 패널
struct TurnByTurnPanel: View {
    let currentStep: MKRoute.Step?
    let remainingDistance: CLLocationDistance
    let estimatedArrivalTime: Date?
    let isNavigating: Bool
    let collectedCoins: Int
    let totalCoins: Int
    let onReturnToCurrentLocation: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // 현재 위치로 돌아가기 버튼
                Button(action: {
                    // 터치 피드백
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    onReturnToCurrentLocation()
                }) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: AppConstants.UI.buttonSize, height: AppConstants.UI.buttonSize)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.2, green: 0.4, blue: 0.8),
                                    Color(red: 0.1, green: 0.3, blue: 0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(
                            color: Color.black.opacity(0.2),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 0.1), value: false)
                
                // 안내 텍스트
                VStack(alignment: .leading, spacing: 4) {
                    Text(getDirectionText())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Text(formatDistance(remainingDistance))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                        
                        if let arrivalTime = estimatedArrivalTime {
                            Text("도착 예정: \(formatTime(arrivalTime))")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 코인 수집 정보
                    HStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.yellow)
                        
                        Text("코인 \(collectedCoins)/\(totalCoins)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.black)
                    }
                }
                
                Spacer()
            }
        }
        .padding(AppConstants.UI.padding)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                .stroke(Color(red: 0.4, green: 0.7, blue: 0.9), lineWidth: 2)
        )
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    
    // MARK: - 방향 텍스트 가져오기
    private func getDirectionText() -> String {
        guard let step = currentStep else { return "경로를 따라 이동하세요" }
        return step.instructions
    }
    
    // MARK: - 거리 포맷팅
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    // MARK: - 시간 포맷팅
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
