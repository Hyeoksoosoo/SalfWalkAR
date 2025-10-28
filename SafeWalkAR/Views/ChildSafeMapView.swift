import SwiftUI
import MapKit
import CoreLocation

struct ChildSafeMapView: UIViewRepresentable {
    @ObservedObject var destinationManager: DestinationManager
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var routeDataManager: RouteDataManager
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // 어린이용 밝고 직관적인 지도 설정
        setupChildFriendlyMap(mapView)
        
        // 경로 데이터 미리 로드 (이미 로드된 경우 스킵)
        if !routeDataManager.isDataLoaded {
            routeDataManager.loadRouteData()
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        print("🔄 ChildSafeMapView updateUIView 호출됨")
        print("   - 현재 목적지: \(destinationManager.currentDestination?.name ?? "없음")")
        print("   - 위치 매니저 상태: \(locationManager.currentLocation != nil ? "위치 있음" : "위치 없음")")
        print("   - 경로 데이터 로드 상태: \(routeDataManager.isDataLoaded)")
        
        // 모든 오버레이와 어노테이션 제거
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // 경로 데이터가 로드되어 있으면 경로 표시
        print("📍 경로 표시 시작")
        displayRouteOnMap(mapView: mapView)
    }
    
    private func setupChildFriendlyMap(_ mapView: MKMapView) {
        // iOS 17+ 최신 API 사용
        if #available(iOS 17.0, *) {
            // 1. 어린이가 이해하기 쉬운 POI만 표시
            let poiFilter = MKPointOfInterestFilter(including: [
                .school,
                .park,
                .publicTransport,
                .hospital
            ])
            mapView.pointOfInterestFilter = poiFilter

            // 2. 밝고 선명한 표준 지도
            mapView.mapType = .standard

            // 3. 교통 정보 숨기기 (복잡도 감소)
            mapView.showsTraffic = false

            // 4. 3D 빌딩 표시 (입체감)
            mapView.showsBuildings = true

            // 5. 기본 컨트롤 표시
            mapView.showsCompass = true
            mapView.showsScale = true
            mapView.showsPointsOfInterest = true

            // 6. iOS 17+ MKStandardMapConfiguration
            let configuration = MKStandardMapConfiguration(emphasisStyle: .default)
            configuration.showsTraffic = false
            configuration.pointOfInterestFilter = poiFilter
            mapView.preferredConfiguration = configuration
        } else {
            // iOS 16 이하 호환성
            if #available(iOS 13.0, *) {
                let poiFilter = MKPointOfInterestFilter(including: [
                    .school,
                    .park,
                    .publicTransport,
                    .hospital
                ])
                mapView.pointOfInterestFilter = poiFilter
                mapView.showsTraffic = false
                mapView.showsBuildings = true
                mapView.showsCompass = true
                mapView.showsScale = true
                mapView.showsPointsOfInterest = true
            }
        }

        // 7. 어린이용 밝은 색상
        mapView.tintColor = UIColor.systemBlue

        // 8. 경로 미리보기용 - 자유 모드 비활성화 (경로만 보는 용도)
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.isUserInteractionEnabled = false
    }
    
    
    private func displayRouteOnMap(mapView: MKMapView) {
        print("🛣️ displayRouteOnMap 호출됨")

        // 1. 경로 데이터 로드 확인
        guard routeDataManager.isDataLoaded else {
            print("⏳ 경로 데이터 로딩 중... 다시 시도")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.displayRouteOnMap(mapView: mapView)
            }
            return
        }

        let jsonCoordinates = routeDataManager.routeCoordinates
        print("✅ 경로 데이터 개수: \(jsonCoordinates.count)")

        // 2. 경로 생성: JSON 노드 데이터를 그대로 사용
        let routeCoordinates = jsonCoordinates

        print("✅ 생성된 경로 좌표 개수: \(routeCoordinates.count)")

        // 3. 폴리라인 생성 및 추가
        let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
        mapView.addOverlay(polyline)

        // 4. 출발지와 목적지 마커 추가 (노드 데이터 기준)
        addStartAndEndMarkersFromNodeData(mapView: mapView)

        // 5. 지도 범위 조정 (경로 길이에 따라 동적으로)
        adjustMapRegionToFitRoute(mapView: mapView, routeCoordinates: routeCoordinates)

        print("✅ 경로 표시 완료")
    }
    
    // 이 함수는 사용되지 않으므로 제거됨 - displayRouteOnMap으로 통합
    
    private func addStartAndEndMarkers(mapView: MKMapView, currentLocation: CLLocation) {
        print("📍 마커 추가 시작")
        
        // 출발지: 내 위치 (현재 위치)
        let startAnnotation = ChildSafeAnnotation(
            coordinate: currentLocation.coordinate,
            title: "출발지 (내 위치)",
            subtitle: "현재 위치에서 시작",
            annotationType: .start
        )
        mapView.addAnnotation(startAnnotation)
        print("✅ 출발지 마커 추가: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)")
        
        // 목적지: JSON 데이터의 마지막 노드
        if let lastCoordinate = routeDataManager.routeCoordinates.last {
            let endAnnotation = ChildSafeAnnotation(
                coordinate: lastCoordinate,
                title: "목적지",
                subtitle: destinationManager.currentDestination?.name ?? "목적지",
                annotationType: .end
            )
            mapView.addAnnotation(endAnnotation)
            print("✅ 목적지 마커 추가: \(destinationManager.currentDestination?.name ?? "목적지") (\(lastCoordinate.latitude), \(lastCoordinate.longitude))")
        }
    }
    
    private func addStartAndEndMarkersFromNodeData(mapView: MKMapView) {
        // 기존 마커 완전 제거
        mapView.removeAnnotations(mapView.annotations)
        
        // 출발지와 목적지: JSON 데이터의 첫 번째와 마지막 노드
        if routeDataManager.isDataLoaded, let startEndPoints = routeDataManager.getStartAndEndPoints() {
            // 출발지: JSON 데이터의 첫 번째 노드
            let startAnnotation = ChildSafeAnnotation(
                coordinate: startEndPoints.start,
                title: "출발지",
                subtitle: "경로 시작점",
                annotationType: .start
            )
            mapView.addAnnotation(startAnnotation)
            print("📍 출발지 마커 추가됨: (\(startEndPoints.start.latitude), \(startEndPoints.start.longitude))")
            
            // 목적지: JSON 데이터의 마지막 노드
            let destinationTitle = destinationManager.destinationName.isEmpty ?
                (destinationManager.currentDestination?.name ?? "목적지") :
                destinationManager.destinationName
            let endAnnotation = ChildSafeAnnotation(
                coordinate: startEndPoints.end,
                title: "목적지",
                subtitle: destinationTitle,
                annotationType: .end
            )
            mapView.addAnnotation(endAnnotation)
            print("📍 목적지 마커 추가됨: \(destinationTitle) (\(startEndPoints.end.latitude), \(startEndPoints.end.longitude))")
        } else {
            print("⏳ 경로 데이터가 아직 로드되지 않아 마커를 추가할 수 없습니다.")
        }
    }
    
    private func addEndMarkerFromJSON(mapView: MKMapView, routeDataManager: RouteDataManager) {
        guard routeDataManager.isDataLoaded,
              let startEndPoints = routeDataManager.getStartAndEndPoints() else {
            // 데이터가 아직 로드되지 않았으면 다시 시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.addEndMarkerFromJSON(mapView: mapView, routeDataManager: routeDataManager)
            }
            return
        }
        
        // 목적지 마커만 추가 (JSON 데이터의 마지막 노드)
        let endAnnotation = ChildSafeAnnotation()
        endAnnotation.coordinate = startEndPoints.end
        endAnnotation.title = "목적지"
        endAnnotation.subtitle = destinationManager.currentDestination?.name ?? "목적지"
        endAnnotation.annotationType = .end
        mapView.addAnnotation(endAnnotation)
        
        print("📍 목적지 마커 추가 완료")
        print("   - 목적지: \(startEndPoints.end.latitude), \(startEndPoints.end.longitude)")
    }
    
    
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ChildSafeMapView
        
        init(_ parent: ChildSafeMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            // 일반 어노테이션 처리
            guard let childAnnotation = annotation as? ChildSafeAnnotation else { return nil }
            
            let identifier = "ChildSafeAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // 어린이용 큰 마커 설정
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = childAnnotation.annotationType == .start ? UIColor.systemGreen : UIColor.systemRed
                markerView.glyphText = childAnnotation.annotationType == .start ? "🏁" : "🎯"
                markerView.glyphTintColor = .white
                markerView.displayPriority = .required
                
                // 어린이용 큰 마커
                markerView.markerTintColor = childAnnotation.annotationType == .start ? 
                    UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0) : // 밝은 초록색
                    UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)   // 밝은 빨간색
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 6.0
                renderer.lineCap = .round
                renderer.lineJoin = .round
                renderer.alpha = 0.9
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
    }
}

// MARK: - 어린이용 어노테이션 클래스
class ChildSafeAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var annotationType: AnnotationType
    
    enum AnnotationType {
        case start
        case end
    }
    
    init(coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(), title: String? = nil, subtitle: String? = nil, annotationType: AnnotationType = .start) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.annotationType = annotationType
    }
}

#Preview {
    ChildSafeMapView(
        destinationManager: DestinationManager(),
        
        locationManager: LocationManager(),
        routeDataManager: RouteDataManager()
    )
}

// MARK: - 지도 범위 조정 함수
extension ChildSafeMapView {
    private func adjustMapRegionToFitRoute(mapView: MKMapView, routeCoordinates: [CLLocationCoordinate2D]) {
        guard !routeCoordinates.isEmpty else { return }
        
        // 경로의 경계 상자 계산
        let latitudes = routeCoordinates.map { $0.latitude }
        let longitudes = routeCoordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        // 경로의 중심점 계산
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        
        // 경로의 크기 계산 (도 단위)
        let latSpan = maxLat - minLat
        let lonSpan = maxLon - minLon
        
        // 경로의 실제 거리 계산 (미터 단위)
        let latSpanMeters = latSpan * 111000 // 위도 1도 ≈ 111km
        let lonSpanMeters = lonSpan * 111000 * cos(centerLat * .pi / 180) // 경도는 위도에 따라 조정
        
        // 경로의 대각선 거리 계산
        let diagonalDistance = sqrt(latSpanMeters * latSpanMeters + lonSpanMeters * lonSpanMeters)
        
        // 적절한 범위 설정 (경로 크기에 따라)
        let minRange: Double = 300   // 최소 300m (매우 짧은 경로용)
        let maxRange: Double = 5000  // 최대 5km (매우 긴 경로용)
        
        // 경로 크기에 40% 여백 추가 (더 넓은 시야)
        let rangeWithPadding = diagonalDistance * 1.4
        
        // 최소/최대 범위 내에서 조정
        let finalRange = max(minRange, min(maxRange, rangeWithPadding))
        
        // 경로가 매우 짧은 경우 (100m 미만) 특별 처리
        if diagonalDistance < 100 {
            // 짧은 경로는 더 가깝게 보여주되, 최소 300m는 유지
            let shortRange = max(300, diagonalDistance * 2.0)
            let adjustedRange = min(shortRange, 800) // 최대 800m까지만
            print("📍 짧은 경로 감지: \(Int(diagonalDistance))m → \(Int(adjustedRange))m로 조정")
            mapView.setRegion(MKCoordinateRegion(
                center: center,
                latitudinalMeters: adjustedRange,
                longitudinalMeters: adjustedRange
            ), animated: true)
            return
        }
        
        // 지도 범위 설정 (정사각형 영역)
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: finalRange,
            longitudinalMeters: finalRange
        )
        
        mapView.setRegion(region, animated: true)
        
        print("📍 지도 범위 조정 완료:")
        print("   - 중심점: \(centerLat), \(centerLon)")
        print("   - 경로 크기: \(Int(latSpanMeters))m × \(Int(lonSpanMeters))m")
        print("   - 대각선 거리: \(Int(diagonalDistance))m")
        print("   - 설정된 범위: \(Int(finalRange))m × \(Int(finalRange))m")
    }
}
