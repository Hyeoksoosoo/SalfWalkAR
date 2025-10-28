import Foundation
import CoreLocation
import MapKit

struct PathPoint: Identifiable, Codable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let riskLevel: Int // 1-5 (1: 매우 안전, 5: 위험)
    let description: String
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lng"
        case riskLevel
        case description
    }
}


// MARK: - AR 요소 모델
struct ARElement: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let type: ARElementType
    let height: Double
    var isCollected: Bool
    
    enum ARElementType: String, CaseIterable {
        case coin = "coin"
        case marker = "marker"
        case safetyPoint = "safetyPoint"
    }
}

class PathDataManager: ObservableObject {
    @Published var pathPoints: [PathPoint] = []
    @Published var coinPathPoints: [PathPoint] = []  // 코인 배치용 PathPoint (route_coords 기반)
    @Published var isPathLoaded = false
    @Published var isLoading = false
    @Published var walkingRoute: MKRoute?
    @Published var arElements: [ARElement] = []

    private let routeDataManager: RouteDataManager

    init(routeDataManager: RouteDataManager) {
        self.routeDataManager = routeDataManager
    }

    func loadSamplePath() {
        // 이미 경로 데이터가 있으면 그것을 사용 (API로 받은 데이터 우선)
        if routeDataManager.isDataLoaded {
            print("✅ 경로 데이터 이미 로드됨 - PathPoint 변환만 진행")
            convertRouteDataToPathPoints()
            return
        }

        // JSON 파일에서 경로 데이터 로드 (Fallback)
        print("📂 경로 데이터 없음 - RouteData.json 파일 로드")
        routeDataManager.loadRouteData()

        // 경로 데이터가 로드되면 PathPoint로 변환
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.convertRouteDataToPathPoints()
        }
    }
    
    private func convertRouteDataToPathPoints() {
        guard routeDataManager.isDataLoaded else {
            // 데이터가 아직 로드되지 않았으면 다시 시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.convertRouteDataToPathPoints()
            }
            return
        }

        let coordinates = routeDataManager.routeCoordinates

        pathPoints = coordinates.enumerated().map { index, coordinate in
            let riskLevel = evaluateRiskLevelForIndex(index, totalCount: coordinates.count)
            let description = getDescriptionForIndex(index, totalCount: coordinates.count)

            return PathPoint(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                riskLevel: riskLevel,
                description: description
            )
        }

        // 코인 배치용 PathPoint 생성 (route_coords 기반)
        let coinCoordinates = routeDataManager.coinCoordinates
        coinPathPoints = coinCoordinates.enumerated().map { index, coordinate in
            let riskLevel = evaluateRiskLevelForIndex(index, totalCount: coinCoordinates.count)
            let description = getDescriptionForIndex(index, totalCount: coinCoordinates.count)

            return PathPoint(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                riskLevel: riskLevel,
                description: description
            )
        }

        isPathLoaded = true
        print("📍 JSON 경로 데이터 로드 완료: \(pathPoints.count)개 포인트")
        print("🪙 코인 배치용 데이터 생성 완료: \(coinPathPoints.count)개 포인트")
        print("   - 출발지: \(coordinates.first?.latitude ?? 0), \(coordinates.first?.longitude ?? 0)")
        print("   - 도착지: \(coordinates.last?.latitude ?? 0), \(coordinates.last?.longitude ?? 0)")
    }
    
    private func evaluateRiskLevelForIndex(_ index: Int, totalCount: Int) -> Int {
        // 경로의 위치에 따라 안전도 평가
        let progress = Double(index) / Double(totalCount - 1)
        
        if progress < 0.2 {
            return 1 // 시작 구간 - 매우 안전
        } else if progress < 0.4 {
            return 2 // 초기 구간 - 안전
        } else if progress < 0.6 {
            return 2 // 중간 구간 - 안전
        } else if progress < 0.8 {
            return 3 // 후반 구간 - 보통
        } else {
            return 1 // 도착 구간 - 매우 안전
        }
    }
    
    private func getDescriptionForIndex(_ index: Int, totalCount: Int) -> String {
        let progress = Double(index) / Double(totalCount - 1)
        
        if progress < 0.1 {
            return "출발지 인근"
        } else if progress < 0.3 {
            return "안전한 보도"
        } else if progress < 0.5 {
            return "신호등 있는 횡단보도"
        } else if progress < 0.7 {
            return "목적지 구역 진입"
        } else if progress < 0.9 {
            return "목적지 근처"
        } else {
            return "목적지 도착"
        }
    }
    
    
    
    private func evaluateRiskLevel(trafficState: Int, trafficSpeed: Double) -> Int {
        // 교통 상태와 속도를 기반으로 안전도 평가
        switch trafficState {
        case 0: return 1 // 원활
        case 1: return 2 // 서행
        case 2: return 3 // 지체
        case 3: return 4 // 정체
        default: return 2
        }
    }
    
    
    private func filterPathPoints(_ points: [PathPoint], interval: Double) -> [PathPoint] {
        guard !points.isEmpty else { return [] }
        
        var filteredPoints: [PathPoint] = [points[0]] // 시작점 포함
        
        for i in 1..<points.count {
            let currentPoint = points[i]
            let lastFilteredPoint = filteredPoints.last!
            
            let distance = CLLocation(latitude: lastFilteredPoint.latitude, longitude: lastFilteredPoint.longitude)
                .distance(from: CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude))
            
            if distance >= interval {
                filteredPoints.append(currentPoint)
            }
        }
        
        return filteredPoints
    }
    
    func getPathStatistics() -> (formattedDistance: String, riskLevel: String, pointCount: Int) {
        let totalDistance = calculateTotalDistance()
        let averageRisk = pathPoints.map { $0.riskLevel }.reduce(0, +) / pathPoints.count
        
        let riskText = switch averageRisk {
        case 1: "매우 안전"
        case 2: "안전"
        case 3: "보통"
        case 4: "주의"
        case 5: "위험"
        default: "알 수 없음"
        }
        
        return (
            formattedDistance: String(format: "%.1f km", totalDistance),
            riskLevel: riskText,
            pointCount: pathPoints.count
        )
    }
    
    private func calculateTotalDistance() -> Double {
        guard pathPoints.count > 1 else { return 0.0 }
        
        var totalDistance: Double = 0.0
        for i in 0..<pathPoints.count - 1 {
            let start = CLLocation(latitude: pathPoints[i].latitude, longitude: pathPoints[i].longitude)
            let end = CLLocation(latitude: pathPoints[i + 1].latitude, longitude: pathPoints[i + 1].longitude)
            totalDistance += start.distance(from: end)
        }
        
        return totalDistance / 1000.0 // km로 변환
    }
}