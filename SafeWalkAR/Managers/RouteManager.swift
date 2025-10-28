import Foundation
import CoreLocation

// MARK: - 경로 포인트
struct RoutePoint {
    let latitude: Double
    let longitude: Double
    let riskLevel: Int
    let description: String
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 경로 매니저
class RouteManager: ObservableObject {
    @Published var currentRoute: [RoutePoint] = []
    @Published var isNearRoute = false
    @Published var nearestRoutePoint: RoutePoint?
    @Published var distanceToRoute: Double = 0.0
    
    // 근접도 임계값 (미터)
    private let proximityThreshold: Double = 50.0 // 50미터 이내
    
    // 현재 경로 설정 (제공받은 노드 데이터)
    func setRoute(_ coordinates: [[Double]]) {
        // 이미 같은 경로가 설정되어 있으면 중복 설정 방지
        if currentRoute.count == coordinates.count {
            return
        }
        
        DispatchQueue.main.async {
            self.currentRoute = coordinates.enumerated().map { index, coord in
                let riskLevel = self.evaluateRiskLevelForIndex(index, totalCount: coordinates.count)
                let description = self.getDescriptionForIndex(index, totalCount: coordinates.count)
                
                return RoutePoint(
                    latitude: coord[0],
                    longitude: coord[1],
                    riskLevel: riskLevel,
                    description: description
                )
            }
            
            print("📍 경로 설정 완료: \(self.currentRoute.count)개 포인트")
        }
    }
    
    // 현재 위치가 경로 근처에 있는지 확인
    func checkProximityToRoute(currentLocation: CLLocation) {
        guard !currentRoute.isEmpty else {
            DispatchQueue.main.async {
                self.isNearRoute = false
            }
            return
        }
        
        var minDistance = Double.greatestFiniteMagnitude
        var nearestPoint: RoutePoint?
        
        // 모든 경로 포인트와의 거리 계산
        for routePoint in currentRoute {
            let routeLocation = CLLocation(latitude: routePoint.latitude, longitude: routePoint.longitude)
            let distance = currentLocation.distance(from: routeLocation)
            
            if distance < minDistance {
                minDistance = distance
                nearestPoint = routePoint
            }
        }
        
        DispatchQueue.main.async {
            self.distanceToRoute = minDistance
            self.nearestRoutePoint = nearestPoint
            self.isNearRoute = minDistance <= self.proximityThreshold
            
            if self.isNearRoute {
                print("📍 경로 근처에 있음: \(String(format: "%.1f", minDistance))m")
            }
        }
    }
    
    // 경로의 특정 구간 근처에 있는지 확인 (더 정확한 근접도 계산)
    func isNearRouteSegment(currentLocation: CLLocation) -> Bool {
        guard currentRoute.count >= 2 else { return false }
        
        // 연속된 두 포인트 사이의 선분과의 거리 계산
        for i in 0..<(currentRoute.count - 1) {
            let point1 = currentRoute[i]
            let point2 = currentRoute[i + 1]
            
            let distance = distanceToLineSegment(
                point: currentLocation.coordinate,
                lineStart: point1.coordinate,
                lineEnd: point2.coordinate
            )
            
            if distance <= proximityThreshold {
                return true
            }
        }
        
        return false
    }
    
    // 점과 선분 사이의 최단 거리 계산
    private func distanceToLineSegment(point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D) -> Double {
        let A = point.latitude - lineStart.latitude
        let B = point.longitude - lineStart.longitude
        let C = lineEnd.latitude - lineStart.latitude
        let D = lineEnd.longitude - lineStart.longitude
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        if lenSq == 0 {
            // 선분이 점인 경우
            let location1 = CLLocation(latitude: point.latitude, longitude: point.longitude)
            let location2 = CLLocation(latitude: lineStart.latitude, longitude: lineStart.longitude)
            return location1.distance(from: location2)
        }
        
        let param = dot / lenSq
        
        var xx: Double
        var yy: Double
        
        if param < 0 {
            xx = lineStart.latitude
            yy = lineStart.longitude
        } else if param > 1 {
            xx = lineEnd.latitude
            yy = lineEnd.longitude
        } else {
            xx = lineStart.latitude + param * C
            yy = lineStart.longitude + param * D
        }
        
        let location1 = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let location2 = CLLocation(latitude: xx, longitude: yy)
        return location1.distance(from: location2)
    }
    
    // 경로 진행률에 따른 안전도 평가
    private func evaluateRiskLevelForIndex(_ index: Int, totalCount: Int) -> Int {
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
    
    // 경로 진행률에 따른 설명
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
}
