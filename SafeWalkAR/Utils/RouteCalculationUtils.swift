import Foundation
import CoreLocation
import MapKit

// MARK: - 경로 계산 유틸리티
struct RouteCalculationUtils {

    /// 두 좌표 간의 거리 계산 (미터)
    static func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// 두 좌표 간의 방위각 계산 (도)
    static func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// 경로의 진행 방향 계산
    static func calculateRouteHeading(from location: CLLocation, route: MKRoute) -> Double? {
        let coordinate = location.coordinate

        // 경로의 polyline에서 가장 가까운 점 찾기
        guard let closestPoint = findClosestPoint(on: route.polyline, to: coordinate) else {
            return nil
        }

        // 가장 가까운 점에서 다음 점으로의 방향 계산
        let points = route.polyline.points()
        let pointCount = route.polyline.pointCount

        guard let closestIndex = (0..<pointCount).min(by: { index1, index2 in
            let point1 = points[index1]
            let point2 = points[index2]
            let coord1 = point1.coordinate
            let coord2 = point2.coordinate

            let distance1 = calculateDistance(from: closestPoint, to: coord1)
            let distance2 = calculateDistance(from: closestPoint, to: coord2)

            return distance1 < distance2
        }), closestIndex < pointCount - 1 else {
            return nil
        }

        let nextPoint = points[closestIndex + 1]
        return calculateBearing(from: closestPoint, to: nextPoint.coordinate)
    }

    /// Polyline에서 가장 가까운 점 찾기
    private static func findClosestPoint(on polyline: MKPolyline, to coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        let points = polyline.points()
        let pointCount = polyline.pointCount

        guard pointCount > 0 else { return nil }

        var minDistance = CLLocationDistanceMax
        var closestCoordinate: CLLocationCoordinate2D?

        for i in 0..<pointCount {
            let point = points[i]
            let distance = calculateDistance(from: coordinate, to: point.coordinate)

            if distance < minDistance {
                minDistance = distance
                closestCoordinate = point.coordinate
            }
        }

        return closestCoordinate
    }

    /// 주어진 좌표에서 특정 거리만큼 앞으로 이동한 좌표 계산
    static func coordinate(from coordinate: CLLocationCoordinate2D, atDistance distance: CLLocationDistance, bearing: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0 // meters
        let bearingRadians = bearing * .pi / 180
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(distance / earthRadius) +
                        cos(lat1) * sin(distance / earthRadius) * cos(bearingRadians))
        let lon2 = lon1 + atan2(sin(bearingRadians) * sin(distance / earthRadius) * cos(lat1),
                                cos(distance / earthRadius) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}
