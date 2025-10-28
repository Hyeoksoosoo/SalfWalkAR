import Foundation
import SwiftUI
import CoreLocation
import AudioToolbox

struct Coin: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var isCollected: Bool = false
    let value: Int = 10
    let riskLevel: Int
}

class CoinManager: ObservableObject {
    @Published var coins: [Coin] = []
    @Published var collectedCoins: Int = 0
    @Published var totalCoins: Int = 0
    @Published var remainingSteps: Int = 0
    @Published var currentProgress: Double = 0.0
    
    private var totalDistance: Double = 0.0
    
    // UI 즉시 갱신을 위한 콜백
    var onCoinCollected: (() -> Void)?
    
    func generateCoins(from pathPoints: [PathPoint]) {
        coins.removeAll()
        collectedCoins = 0
        
        // 모든 경로 포인트에 코인 배치 (coords 배열의 모든 좌표)
        for (index, pathPoint) in pathPoints.enumerated() {
            let coin = Coin(
                coordinate: pathPoint.coordinate,
                riskLevel: pathPoint.riskLevel
            )
            coins.append(coin)
            print("🪙 코인 배치: 노드 \(index) (모든 좌표에 배치)")
        }
        
        totalCoins = coins.count
        remainingSteps = calculateTotalSteps()
        updateProgress()
        
        print("🪙 총 코인 개수: \(totalCoins)개 (모든 좌표에 배치)")
    }
    
    // MARK: - 2D 지도용 코인 추가
    func addCoin(at coordinate: CLLocationCoordinate2D, riskLevel: Int = AppConstants.Coin.defaultRiskLevel) {
        let coin = Coin(
            coordinate: coordinate,
            riskLevel: riskLevel
        )
        coins.append(coin)
    }
    
    // MARK: - 2D 지도용 코인 수집
    func collectCoin(at coordinate: CLLocationCoordinate2D) -> Bool {
        print("🪙 CoinManager.collectCoin 호출됨 - 현재 위치: (\(coordinate.latitude), \(coordinate.longitude))")
        
        // 가장 가까운 코인 찾기
        guard let nearestCoinIndex = findNearestCoin(to: coordinate) else { 
            print("🪙 가장 가까운 코인을 찾을 수 없음")
            return false 
        }
        
        let coin = coins[nearestCoinIndex]
        print("🪙 가장 가까운 코인 발견 - 인덱스: \(nearestCoinIndex), 위치: (\(coin.coordinate.latitude), \(coin.coordinate.longitude))")
        
        // 수집 가능한 거리인지 확인 (20미터 이내)
        let distance = calculateDistance(from: coordinate, to: coin.coordinate)
        print("🪙 코인까지의 거리: \(Int(distance))m")
        
        guard distance <= 20.0 else { 
            print("🪙 코인 수집 불가 - 거리 초과: \(Int(distance))m > 20m")
            return false 
        }
        
        // 메인 스레드에서 상태 갱신하여 SwiftUI 즉시 반영
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 배열 전체를 재할당하여 SwiftUI 변경 감지 유도
            var updatedCoins = self.coins
            updatedCoins[nearestCoinIndex].isCollected = true
            self.coins = updatedCoins  // @Published 배열 전체 재할당
            
            // 다른 @Published 프로퍼티들도 업데이트
            self.collectedCoins += 1
            self.remainingSteps = self.calculateRemainingSteps()
            self.updateProgress()
            
            print("🪙 코인 수집 처리 완료 - 수집된 코인: \(self.collectedCoins)개 / \(self.totalCoins)개")
            print("🪙 SwiftUI 상태 갱신 완료 - 메인 스레드에서 처리됨")
            
            // 코인 수집 시 진동 피드백
            self.triggerCoinCollectionHaptic()
            
            // 특별한 코인 수집 시 추가 피드백
            if self.collectedCoins == self.totalCoins {
                print("🎉 모든 코인 수집 완료!")
                // 모든 코인 수집 완료 시 특별한 진동
                self.triggerSpecialHaptic(for: .allCoinsCollected)
            } else if self.collectedCoins % 10 == 0 {
                print("🎯 코인 수집 마일스톤: \(self.collectedCoins)개 달성!")
                // 10개마다 특별한 진동
                self.triggerSpecialHaptic(for: .milestone)
            }
            
            print("✅ 코인 수집 완료: \(self.collectedCoins)/\(self.totalCoins)")
            
            // UI 즉시 갱신을 위한 콜백 호출
            self.onCoinCollected?()
        }
        
        return true
    }
    
    private func findNearestCoin(to coordinate: CLLocationCoordinate2D) -> Int? {
        var nearestIndex: Int?
        var minDistance: CLLocationDistance = Double.greatestFiniteMagnitude
        
        for (index, coin) in coins.enumerated() {
            if coin.isCollected { continue }

            let distance = calculateDistance(from: coordinate, to: coin.coordinate)
            if distance < minDistance {
                minDistance = distance
                nearestIndex = index
            }
        }
        
        return nearestIndex
    }
    
    
    private func calculateTotalSteps() -> Int {
        // 총 걸음 수 계산 (대략적으로 1걸음 = 0.7m)
        return Int(totalDistance / 0.7)
    }
    
    private func calculateRemainingSteps() -> Int {
        let remainingCoins = totalCoins - collectedCoins
        let progressRatio = Double(collectedCoins) / Double(totalCoins)
        return Int(Double(calculateTotalSteps()) * (1.0 - progressRatio))
    }
    
    private func updateProgress() {
        currentProgress = Double(collectedCoins) / Double(totalCoins)
    }
    
    
    func getGameStatistics() -> (collectedCoins: Int, totalCoins: Int, progress: Double, remainingSteps: Int) {
        return (
            collectedCoins: collectedCoins,
            totalCoins: totalCoins,
            progress: currentProgress,
            remainingSteps: remainingSteps
        )
    }

    // MARK: - Helper Methods
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    // MARK: - 코인 수집 진동 피드백
    private func triggerCoinCollectionHaptic() {
        // 코인 수집 시 특별한 진동 패턴
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // 짧은 지연 후 두 번째 진동 (코인 수집의 만족감 증대)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let secondFeedback = UIImpactFeedbackGenerator(style: .light)
            secondFeedback.impactOccurred()
        }
        
        // 시스템 사운드 재생 (코인 수집 사운드)
        AudioServicesPlaySystemSound(1057) // 코인 수집 사운드 ID
        
        print("📳 코인 수집 진동 피드백 실행됨 - 이중 진동 패턴")
    }
    
    // MARK: - 특별한 진동 피드백
    private func triggerSpecialHaptic(for type: SpecialHapticType) {
        switch type {
        case .allCoinsCollected:
            // 모든 코인 수집 완료 시 연속 진동
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                    let feedback = UIImpactFeedbackGenerator(style: .heavy)
                    feedback.impactOccurred()
                }
            }
            // 특별한 사운드
            AudioServicesPlaySystemSound(1016) // 성공 사운드
            print("🎉 모든 코인 수집 완료! 특별한 진동 패턴 실행")
            
        case .milestone:
            // 10개마다 특별한 진동
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let secondFeedback = UIImpactFeedbackGenerator(style: .medium)
                secondFeedback.impactOccurred()
            }
            
            AudioServicesPlaySystemSound(1054) // 알림 사운드
            print("🏆 \(collectedCoins)개 코인 수집 달성! 마일스톤 진동")
        }
    }
    
    // MARK: - 특별한 진동 타입
    private enum SpecialHapticType {
        case allCoinsCollected
        case milestone
    }
}
