import SwiftUI
import MapKit
import CoreLocation
import CoreMotion
import AudioToolbox

struct TurnByTurnNavigationView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var destinationManager: DestinationManager
    @ObservedObject var routeDataManager: RouteDataManager
    @ObservedObject var pathDataManager: PathDataManager
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var coinManager = CoinManager()
    
    @State private var currentRoute: MKRoute?
    @State private var currentStep: MKRoute.Step?
    @State private var remainingDistance: CLLocationDistance = 0
    @State private var estimatedArrivalTime: Date?
    @State private var isNavigating = false
    @State private var isRouteOffTrack = false
    @State private var isMapMoved = false // 지도 이동 상태 추적
    @State private var mapView: MKMapView? // 지도 뷰 참조
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 메인 지도 뷰
                TurnByTurnMapView(
                    locationManager: locationManager,
                    destinationManager: destinationManager,
                    routeDataManager: routeDataManager,
                    navigationManager: navigationManager,
                    coinManager: coinManager,
                    pathDataManager: pathDataManager,
                    currentRoute: $currentRoute,
                    currentStep: $currentStep,
                    remainingDistance: $remainingDistance,
                    estimatedArrivalTime: $estimatedArrivalTime,
                    isNavigating: $isNavigating,
                    isRouteOffTrack: $isRouteOffTrack,
                    isMapMoved: $isMapMoved,
                    onMapViewCreated: { mapView in
                        self.mapView = mapView
                    }
                )
                .ignoresSafeArea()
                
                
                // 하단 Turn-by-Turn 안내 패널
                VStack {
                    Spacer()
                    
                    TurnByTurnPanel(
                        currentStep: currentStep,
                        remainingDistance: remainingDistance,
                        estimatedArrivalTime: estimatedArrivalTime,
                        isNavigating: isNavigating,
                        collectedCoins: coinManager.collectedCoins,
                        totalCoins: coinManager.totalCoins,
                        onReturnToCurrentLocation: {
                            returnToCurrentLocation()
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            print("🚀 TurnByTurnNavigationView onAppear 시작")
            
            // RouteData.json 로드 (이미 로드된 경우 스킵)
            if !routeDataManager.isDataLoaded {
                print("📂 RouteData.json 로드 시작")
                routeDataManager.loadRouteData()
            } else {
                print("✅ RouteData.json 이미 로드됨")
            }
            
            // 기본 목적지 설정
            if destinationManager.currentDestination == nil {
                print("🎯 기본 목적지 설정")
                if let defaultDestination = destinationManager.predefinedDestinations.first {
                    destinationManager.setDestination(defaultDestination)
                    print("   설정된 목적지: \(defaultDestination.name)")
                }
            } else {
                print("✅ 목적지 이미 설정됨: \(destinationManager.currentDestination?.name ?? "없음")")
            }
            
            // 경로 데이터 로드 및 코인 생성
            pathDataManager.loadSamplePath()
            // 코인은 route_coords 기반 coinPathPoints로 생성
            coinManager.generateCoins(from: pathDataManager.coinPathPoints)
            
            startNavigation()
            print("🚀 TurnByTurnNavigationView onAppear 완료")
        }
    }
    
    private func returnToCurrentLocation() {
        guard let userLocation = locationManager.currentLocation else { return }
        
        print("📍 현재 위치로 복귀 요청 - 자동 추적 모드 재개")
        print("🗺️ 자유 탐색 모드에서 자동 추적 모드로 전환")
        print("🎯 길찾기 자동 추적 모드 활성화")
        
        // 지도 이동 상태를 리셋하여 자동으로 현재 위치로 이동하도록 함
        isMapMoved = false
        
        // 부드러운 애니메이션과 함께 현재 위치로 이동
        DispatchQueue.main.async {
            // 개선된 3D 카메라로 현재 위치 복귀
            if let mapView = self.mapView {
                // 자동차 내비게이션 스타일 3D 카메라 설정
                let camera = MKMapCamera()
                
                // 사용자 기준 25m 앞 좌표 계산 (건물 가림 방지)
                let forwardCoordinate = RouteCalculationUtils.coordinate(
                    from: userLocation.coordinate,
                    atDistance: AppConstants.Map.forwardDistance,
                    bearing: userLocation.course >= 0 ? userLocation.course : 0
                )
                camera.centerCoordinate = forwardCoordinate
                
                // 동적 고도 설정 (이동 속도 기반)
                let speed = userLocation.speed
                if speed < 2.0 {
                    camera.altitude = AppConstants.Map.walkingAltitude // 도보
                } else if speed < 10.0 {
                    camera.altitude = AppConstants.Map.cyclingAltitude // 자전거
                } else {
                    camera.altitude = AppConstants.Map.drivingAltitude // 차량
                }
                
                // 개선된 피치 설정 (건물 가림 방지)
                camera.pitch = AppConstants.Map.defaultPitch // 60도
                
                // 진행 방향 헤딩 (경로 우선, 없으면 사용자 이동 방향)
                if let currentStep = self.currentStep {
                    let stepCoordinate = currentStep.polyline.coordinate
                    let bearing = self.calculateBearing(from: userLocation.coordinate, to: stepCoordinate)
                    camera.heading = bearing
                } else if let route = self.currentRoute {
                    if let routeHeading = RouteCalculationUtils.calculateRouteHeading(from: userLocation, route: route) {
                        camera.heading = routeHeading
                    } else {
                        camera.heading = userLocation.course >= 0 ? userLocation.course : 0
                    }
                } else {
                    camera.heading = userLocation.course >= 0 ? userLocation.course : 0
                }
                
                // 적용
                mapView.setCamera(camera, animated: true)
            }
        }
        
        print("✅ 자동 추적 모드 재개 완료 - 카메라가 현재 위치 중심으로 이동")
        print("🎯 이제 사용자 이동에 따라 자동으로 3D 카메라가 따라갑니다")
        print("🗺️ 길찾기 자동 추적 모드 활성화 완료")
    }
    
    // MARK: - 방향 계산 함수
    private func calculateBearing(from fromCoord: CLLocationCoordinate2D, to toCoord: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = fromCoord.latitude.toRadians()
        let lon1 = fromCoord.longitude.toRadians()
        let lat2 = toCoord.latitude.toRadians()
        let lon2 = toCoord.longitude.toRadians()
        
        let deltaLon = lon2 - lon1
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x).toDegrees()
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    private func startNavigation() {
        guard let destination = destinationManager.currentDestination else { return }
        
        // 현재 위치를 출발지로 설정
        guard let startCoordinate = locationManager.currentLocation?.coordinate else {
            print("현재 위치를 가져올 수 없습니다.")
            return
        }
        
        navigationManager.startNavigation(
            from: startCoordinate,
            to: destination.coordinate
        ) { route in
            DispatchQueue.main.async {
                self.currentRoute = route
                self.isNavigating = true
                self.isMapMoved = false // 길찾기 시작 시 자동 추적 모드로 설정
                self.updateNavigationInfo()
                print("🎯 길찾기 시작 - 자동 추적 모드 활성화")
            }
        }
    }
    
    private func updateNavigationInfo() {
        guard let route = currentRoute else { return }
        
        // 남은 거리 계산
        remainingDistance = route.distance
        
        // 예상 도착 시간 계산 (어린이 도보 속도 3km/h 기준)
        let walkingSpeed: Double = 3000 / 3600 // m/s (어린이 기준)
        let estimatedTime = remainingDistance / walkingSpeed
        estimatedArrivalTime = Date().addingTimeInterval(estimatedTime)
        
        // 현재 단계 업데이트
        if let firstStep = route.steps.first {
            currentStep = firstStep
        }
    }
}



// MARK: - Turn-by-Turn 지도 뷰
struct TurnByTurnMapView: UIViewRepresentable {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var destinationManager: DestinationManager
    @ObservedObject var routeDataManager: RouteDataManager
    @ObservedObject var navigationManager: NavigationManager
    @ObservedObject var coinManager: CoinManager
    @ObservedObject var pathDataManager: PathDataManager
    
    @Binding var currentRoute: MKRoute?
    @Binding var currentStep: MKRoute.Step?
    @Binding var remainingDistance: CLLocationDistance
    @Binding var estimatedArrivalTime: Date?
    @Binding var isNavigating: Bool
    @Binding var isRouteOffTrack: Bool
    @Binding var isMapMoved: Bool // 지도 이동 상태 추적
    
    // 지도 뷰 참조를 위한 클로저
    let onMapViewCreated: (MKMapView) -> Void
    
    // 로그 제한은 Coordinator에서 관리
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // 코인 수집 시 즉시 UI 갱신을 위한 콜백 설정
        coinManager.onCoinCollected = {
            DispatchQueue.main.async {
                self.forceUpdateCoinAnnotations(on: mapView)
            }
        }
        
        // 내비게이션용 지도 설정
        setupNavigationMap(mapView)
        
        // 지도 뷰 참조 전달
        onMapViewCreated(mapView)
        
        // 사용자 위치 표시 - 더 잘 보이도록 설정
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none // 수동으로 카메라 제어하여 더 정확한 확대
        
        // 지도 초기화 시에는 기존 상태 유지 (자동 추적 모드는 길찾기 시작 시에만 설정)
        print("🎯 지도 초기화 완료 - 기존 모드 상태 유지")
        
        // 초기 3D 카메라 설정 (위치가 있을 때, 자동 추적 모드에서만)
        if !isMapMoved {
            if let userLocation = locationManager.currentLocation {
                setupInitial3DCamera(mapView: mapView, userLocation: userLocation)
            }
        }
        
        // 확대/축소 제스처 활성화
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 디버깅 로그 (너무 빈번한 호출 방지를 위해 간소화)
        let now = Date()
        if now.timeIntervalSince(context.coordinator.lastLogTime) > 5.0 { // 5초마다만 로그 출력
            print("🔄 TurnByTurnNavigationView updateUIView 호출됨 - SwiftUI 상태 변경 감지")
            print("   - 현재 목적지: \(destinationManager.currentDestination?.name ?? "없음")")
            print("   - CoinManager.collectedCoins: \(coinManager.collectedCoins)개")
            context.coordinator.lastLogTime = now
        }
        
        // 지도 제스처 설정 유지 (매번 확인)
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        
        // 초기 3D 카메라 설정 (위치가 있고 아직 설정되지 않았을 때, 자동 추적 모드에서만)
        if !isMapMoved {
            if let userLocation = locationManager.currentLocation {
                let currentCamera = mapView.camera
                let isInitialCamera = currentCamera.altitude > 1000 || currentCamera.pitch < 10 // 기본 카메라인지 확인
                
                if isInitialCamera {
                    setupInitial3DCamera(mapView: mapView, userLocation: userLocation)
                }
            }
        }
        
        // 무한 루프 방지: 경로와 코인이 이미 표시되어 있는지 확인
        let hasAnnotations = !mapView.annotations.isEmpty
        let hasOverlays = !mapView.overlays.isEmpty
        
        // 경로와 코인이 없을 때만 표시 (무한 루프 방지)
        if !hasAnnotations || !hasOverlays {
            if now.timeIntervalSince(context.coordinator.lastLogTime) > 5.0 {
                print("📍 JSON 노드 데이터로 경로 표시")
            }
            displayRouteFromNodeData(on: mapView)
        } else {
            // 코인 수집을 위해 CoinManager.coins 배열이 비어있으면 다시 채우기
            if coinManager.coins.isEmpty && routeDataManager.isDataLoaded {
                if now.timeIntervalSince(context.coordinator.lastLogTime) > 5.0 {
                    print("🪙 CoinManager.coins 배열이 비어있음 - 코인 데이터 복원")
                }
                restoreCoinDataFromRouteData(routeDataManager: routeDataManager)
            }
        }
        
        // 사용자 위치 업데이트 (상태 변경을 비동기로 처리)
        if let userLocation = locationManager.currentLocation {
            DispatchQueue.main.async {
                self.updateUserLocation(userLocation, on: mapView, context: context)
            }
        }
        
        // 디바이스 방향에 따른 지도 카메라 업데이트 (자동 추적 모드에서만)
        if !isMapMoved {
            updateMapCameraForDeviceOrientation(mapView)
        }
        
        // 경로 이탈 감지 및 리라우팅 (상태 변경을 비동기로 처리)
        DispatchQueue.main.async {
            self.checkRouteDeviation(mapView)
        }
    }
    
    private func setupNavigationMap(_ mapView: MKMapView) {
        // iOS 17+ 최신 API 사용
        if #available(iOS 17.0, *) {
            // 1. 모든 POI 숨기기 (내비게이션용 깔끔한 지도)
            let poiFilter = MKPointOfInterestFilter.excludingAll
            mapView.pointOfInterestFilter = poiFilter
            
            // 2. 지도 타입을 표준으로 설정 (밝은 톤)
            mapView.mapType = .standard
            
            // 3. 교통 정보 숨기기
            mapView.showsTraffic = false
            
            // 4. 3D 빌딩 표시 조정 (어린 사용자 친화적, 코인/경로 가림 방지)
            mapView.showsBuildings = false
            
            // 5. 기타 불필요한 요소들 숨기기
            mapView.showsCompass = false
            mapView.showsScale = false
            mapView.showsPointsOfInterest = false
            
            // 6. iOS 17+ MKStandardMapConfiguration 사용
            let configuration = MKStandardMapConfiguration()
            configuration.showsTraffic = false
            configuration.pointOfInterestFilter = poiFilter
            mapView.preferredConfiguration = configuration
            
            // 7. 3D 카메라 설정은 setupInitial3DCamera에서 처리
        } else {
            // iOS 16 이하 호환성
            if #available(iOS 13.0, *) {
                let poiFilter = MKPointOfInterestFilter(including: [])
                mapView.pointOfInterestFilter = poiFilter
                mapView.showsTraffic = false
                mapView.showsBuildings = false // 어린 사용자 친화적, 코인/경로 가림 방지
                mapView.showsCompass = false
                mapView.showsScale = false
                mapView.showsPointsOfInterest = false
            }
            
            // iOS 16 이하에서도 3D 카메라 설정은 setupInitial3DCamera에서 처리
        }
        
        // 7. 내비게이션용 색상 테마
        mapView.tintColor = UIColor.systemBlue
    }
    
    // MARK: - 초기 3D 카메라 설정
    private func setupInitial3DCamera(mapView: MKMapView, userLocation: CLLocation) {
        let camera = MKMapCamera()
        
        // 사용자 기준 25m 앞 좌표 계산 (건물 가림 방지)
        let forwardCoordinate = RouteCalculationUtils.coordinate(
            from: userLocation.coordinate,
            atDistance: AppConstants.Map.forwardDistance,
            bearing: userLocation.course >= 0 ? userLocation.course : 0
        )
        camera.centerCoordinate = forwardCoordinate
        
        // 동적 고도 설정 (이동 속도 기반)
        let speed = userLocation.speed
        if speed < 2.0 {
            camera.altitude = AppConstants.Map.walkingAltitude // 도보
        } else if speed < 10.0 {
            camera.altitude = AppConstants.Map.cyclingAltitude // 자전거
        } else {
            camera.altitude = AppConstants.Map.drivingAltitude // 차량
        }
        
        // 개선된 피치 설정 (건물 가림 방지)
        camera.pitch = AppConstants.Map.defaultPitch // 60도
        camera.heading = userLocation.course >= 0 ? userLocation.course : 0 // 사용자 이동 방향
        
        mapView.setCamera(camera, animated: false)
        print("🎯 초기 3D 카메라 설정 완료 - 길찾기 시작")
    }
    
    // MARK: - 개선된 동적 카메라 업데이트 함수
    private func updateCameraForUserLocation(_ location: CLLocation, mapView: MKMapView, animated: Bool = true) {
        let camera = MKMapCamera()
        
        // ① 사용자 기준 25m 앞 좌표 계산 (건물 가림 방지)
        let forwardCoordinate = RouteCalculationUtils.coordinate(
            from: location.coordinate,
            atDistance: AppConstants.Map.forwardDistance,
            bearing: location.course >= 0 ? location.course : 0
        )
        camera.centerCoordinate = forwardCoordinate
        
        // ② 동적 고도 설정 (이동 속도 기반)
        let speed = location.speed
        if speed < 2.0 {
            camera.altitude = AppConstants.Map.walkingAltitude // 도보
        } else if speed < 10.0 {
            camera.altitude = AppConstants.Map.cyclingAltitude // 자전거
        } else {
            camera.altitude = AppConstants.Map.drivingAltitude // 차량
        }
        
        // ③ 개선된 피치 설정 (건물 가림 방지)
        camera.pitch = AppConstants.Map.defaultPitch // 60도
        
        // ④ 진행 방향 헤딩 (경로 우선, 없으면 사용자 이동 방향)
        if let currentStep = currentStep {
            let stepCoordinate = currentStep.polyline.coordinate
            let bearing = RouteCalculationUtils.calculateBearing(from: location.coordinate, to: stepCoordinate)
            camera.heading = bearing
        } else if let route = currentRoute {
            if let routeHeading = RouteCalculationUtils.calculateRouteHeading(from: location, route: route) {
                camera.heading = routeHeading
            } else {
                camera.heading = location.course >= 0 ? location.course : 0
            }
        } else {
            camera.heading = location.course >= 0 ? location.course : 0
        }
        
        // ⑤ 적용
        mapView.setCamera(camera, animated: animated)
        
        if animated {
            print("🎯 개선된 3D 카메라 업데이트 - 고도: \(Int(camera.altitude))m, 피치: \(Int(camera.pitch))°, 속도: \(String(format: "%.1f", speed))m/s")
        }
    }
    
    private func displayRouteFromNodeData(on mapView: MKMapView) {
        print("🛣️ TurnByTurnNavigationView에서 JSON 노드 데이터로 경로 표시")
        
        // 기존 오버레이와 어노테이션 제거 (사용자 위치 제외)
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // 데이터 로딩 확인
        guard routeDataManager.isDataLoaded else {
            print("⏳ JSON 노드 데이터 로딩 중... 다시 시도")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.displayRouteFromNodeData(on: mapView)
            }
            return
        }
        
        let jsonCoordinates = routeDataManager.routeCoordinates
        print("✅ JSON 노드 데이터 개수: \(jsonCoordinates.count)")
        
        // 폴리라인 생성 및 추가
        let polyline = MKPolyline(coordinates: jsonCoordinates, count: jsonCoordinates.count)
        mapView.addOverlay(polyline, level: .aboveRoads)
        
        // 출발지와 목적지 마커 추가
        addNavigationMarkersFromNodeData(on: mapView, routeDataManager: routeDataManager)
        
        // 코인 마커 추가 (한 번만 생성)
        addCoinsFromRouteDataOnce(on: mapView, routeDataManager: routeDataManager)
        
        // 지도 범위 조정
        let region = MKCoordinateRegion(polyline.boundingMapRect)
        mapView.setRegion(region, animated: true)
        
        print("✅ JSON 노드 데이터 경로 표시 완료")
    }
    
    private func displayRoute(_ route: MKRoute, on mapView: MKMapView) {
        // 기존 오버레이 제거
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // 경로 폴리라인 추가
        mapView.addOverlay(route.polyline, level: .aboveRoads)
        
        // 출발지와 목적지 마커 추가
        addNavigationMarkers(for: route, on: mapView)
        
        // 경로 표시만 하고 카메라 조정은 하지 않음 (사용자 위치 중심으로 유지)
        // displayRoute는 경로를 그리는 용도로만 사용
    }
    
    private func addNavigationMarkersFromNodeData(on mapView: MKMapView, routeDataManager: RouteDataManager) {
        // 출발지와 목적지: JSON 노드 데이터의 첫 번째와 마지막 노드
        if let startEndPoints = routeDataManager.getStartAndEndPoints() {
            // 출발지 마커 (JSON 데이터의 첫 번째 노드)
            let startAnnotation = NavigationAnnotation()
            startAnnotation.coordinate = startEndPoints.start
            startAnnotation.title = "출발지"
            startAnnotation.subtitle = "경로 시작점"
            startAnnotation.annotationType = .start
            mapView.addAnnotation(startAnnotation)
            
            // 목적지 마커 (JSON 데이터의 마지막 노드)
            let endAnnotation = NavigationAnnotation()
            endAnnotation.coordinate = startEndPoints.end
            endAnnotation.title = "목적지"
            endAnnotation.subtitle = destinationManager.currentDestination?.name ?? "목적지"
            endAnnotation.annotationType = .end
            mapView.addAnnotation(endAnnotation)
            
            print("📍 내비게이션 마커 추가 완료")
            print("   - 출발지: \(startEndPoints.start.latitude), \(startEndPoints.start.longitude)")
            print("   - 목적지: \(startEndPoints.end.latitude), \(startEndPoints.end.longitude)")
        }
    }
    
    private func addNavigationMarkers(for route: MKRoute, on mapView: MKMapView) {
        // 출발지 마커 (현재 위치)
        guard let userLocation = locationManager.currentLocation else { return }
        let startAnnotation = NavigationAnnotation()
        startAnnotation.coordinate = userLocation.coordinate
        startAnnotation.title = "출발지"
        startAnnotation.subtitle = "현재 위치"
        startAnnotation.annotationType = .start
        mapView.addAnnotation(startAnnotation)
        
        // 목적지 마커
        let endAnnotation = NavigationAnnotation()
        endAnnotation.coordinate = destinationManager.currentDestination?.coordinate ??
            CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780) // Fallback: 서울시청
        endAnnotation.title = "목적지"
        endAnnotation.subtitle = destinationManager.currentDestination?.name ?? "목적지"
        endAnnotation.annotationType = .end
        mapView.addAnnotation(endAnnotation)
    }
    
    private func updateUserLocation(_ location: CLLocation, on mapView: MKMapView, context: Context) {
        // 사용자 위치 기반 내비게이션 업데이트
        navigationManager.updateUserLocation(location)
        
        // 현재 단계 업데이트
        if let newStep = navigationManager.getCurrentStep() {
            DispatchQueue.main.async {
                self.currentStep = newStep
                self.remainingDistance = navigationManager.getRemainingDistance()
            }
        }
        
        // 초기 3D 카메라 설정 (첫 번째 위치 업데이트 시, 자동 추적 모드에서만)
        if !isMapMoved {
            let currentCamera = mapView.camera
            let isInitialCamera = currentCamera.altitude > 1000 || currentCamera.pitch < 10 // 기본 카메라인지 확인
            
            if isInitialCamera {
                setupInitial3DCamera(mapView: mapView, userLocation: location)
            }
        }
        
        // 코인 수집 체크
        checkCoinCollection(at: location.coordinate, coordinator: context.coordinator, mapView: mapView)
        
        // 자동 추적 모드: 사용자가 지도를 이동하지 않았을 때만 자동으로 현재 위치로 이동
        // 자유 탐색 모드에서는 자동 추적을 완전히 비활성화
        if !isMapMoved {
            // 개선된 3D 카메라 자동 추적 (건물 가림 방지, 동적 고도 조정)
            updateCameraForUserLocation(location, mapView: mapView, animated: true)
        } else {
            // 자유 탐색 모드: 사용자가 설정한 지도 상태를 유지
            // 자동으로 현재 위치로 이동하지 않음
            // 로그 빈도 제한 (5초마다만 출력)
            let now = Date()
            if now.timeIntervalSince(context.coordinator.lastLogTime) > 5.0 {
                print("🗺️ 자유 탐색 모드 - 지도 상태 유지 (자동 추적 비활성화)")
                context.coordinator.lastLogTime = now
            }
        }
        
    }
    
    // MARK: - 어노테이션 강제 갱신
    private func forceUpdateCoinAnnotations(on mapView: MKMapView) {
        // 코인 어노테이션들을 제거하고 다시 추가하여 시각적 갱신 강제
        let coinAnnotations = mapView.annotations.compactMap { $0 as? CoinAnnotation }
        
        DispatchQueue.main.async {
            // 기존 코인 어노테이션 제거
            mapView.removeAnnotations(coinAnnotations)
            
            // 약간의 지연 후 다시 추가 (시각적 갱신을 위해)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                mapView.addAnnotations(coinAnnotations)
                print("🔄 코인 어노테이션 갱신 완료 - \(coinAnnotations.count)개")
            }
        }
    }
    
    // MARK: - 코인 수집 체크
    private func checkCoinCollection(at coordinate: CLLocationCoordinate2D, coordinator: Coordinator, mapView: MKMapView) {
        // 코인 수집 체크 로그 최적화 (너무 빈번한 로그 방지)
        let now = Date()
        let shouldLog = now.timeIntervalSince(coordinator.lastCoinCheckLogTime) > 3.0 // 3초마다만 로그 출력
        
        if shouldLog {
            print("🪙 코인 수집 체크 시작 - 현재 위치: (\(coordinate.latitude), \(coordinate.longitude))")
            print("🪙 CoinManager.coins 배열 크기: \(coinManager.coins.count)개")
            print("🪙 현재 수집된 코인: \(coinManager.collectedCoins)개 / \(coinManager.totalCoins)개")
            coordinator.lastCoinCheckLogTime = now
        }
        
        // 가장 가까운 코인 찾기
        var nearestCoin: Coin?
        var minDistance: CLLocationDistance = Double.greatestFiniteMagnitude
        
        for coin in coinManager.coins {
            if coin.isCollected { continue }
            
            let distance = RouteCalculationUtils.calculateDistance(from: coordinate, to: coin.coordinate)
            if distance < minDistance {
                minDistance = distance
                nearestCoin = coin
            }
        }
        
        if let coin = nearestCoin {
            if shouldLog {
                print("🪙 가장 가까운 코인 발견 - 거리: \(Int(minDistance))m")
                print("🪙 코인 위치: (\(coin.coordinate.latitude), \(coin.coordinate.longitude))")
            }
            
            // 20미터 이내에 코인이 있으면 수집
            if minDistance <= 20.0 {
                if shouldLog {
                    print("🪙 코인 수집 시도 - 거리: \(Int(minDistance))m (20m 이내)")
                }
                let collected = coinManager.collectCoin(at: coordinate)
                if collected {
                    print("🎉 코인 수집 성공!") // 수집 성공은 항상 로그 출력
                    print("🪙 수집 후 상태: \(coinManager.collectedCoins)개 / \(coinManager.totalCoins)개")
                    
                    // 코인 수집 성공 시 어노테이션 강제 갱신
                    forceUpdateCoinAnnotations(on: mapView)
                    
                    // 코인 수집 성공 시 사용자에게 알림
                    showCoinCollectionNotification()
                }
            } else {
                if shouldLog {
                    print("🪙 코인 수집 불가 - 거리: \(Int(minDistance))m (20m 초과)")
                }
            }
        } else {
            if shouldLog {
                print("🪙 수집 가능한 코인이 없음")
            }
        }
    }
    
    // MARK: - 코인 수집 알림
    private func showCoinCollectionNotification() {
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 사운드 피드백 (시스템 사운드)
        AudioServicesPlaySystemSound(1057) // 코인 수집 사운드
        
        print("코인 수집! 총 \(coinManager.collectedCoins)개 수집됨")
    }
    
    // MARK: - 코인 수집 상태 확인
    private func checkIfCoinIsCollected(coinAnnotation: CoinAnnotation) -> Bool {
        // CoinManager에서 해당 좌표의 코인 찾기
        for coin in coinManager.coins {
            let distance = RouteCalculationUtils.calculateDistance(
                from: coinAnnotation.coordinate, 
                to: coin.coordinate
            )
            
            if distance < 1.0 { // 1미터 이내면 같은 코인으로 간주
                return coin.isCollected
            }
        }
        return false // 코인을 찾을 수 없으면 수집되지 않은 것으로 간주
    }
    
    // MARK: - 방향 계산
    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    // MARK: - 현재 위치로 돌아가기
    func returnToCurrentLocation(_ mapView: MKMapView) {
        guard let userLocation = locationManager.currentLocation else { return }
        
        // 3D 느낌을 위한 카메라 설정으로 현재 위치로 이동
        let camera = MKMapCamera()
        camera.centerCoordinate = userLocation.coordinate
        camera.altitude = 200 // 200m 고도로 입체감 연출
        camera.pitch = 45 // 45도 각도로 3D 느낌
        
        // 경로 방향에 따라 heading 조정
        if let currentStep = currentStep {
            let stepCoordinate = currentStep.polyline.coordinate
            let bearing = calculateBearing(from: userLocation.coordinate, to: stepCoordinate)
            camera.heading = bearing
        } else {
            camera.heading = 0 // 기본값
        }
        
        mapView.setCamera(camera, animated: true)
        
        // isMapMoved 상태는 상위 컴포넌트에서 관리
        print("📍 TurnByTurnMapView에서 현재 위치로 카메라 이동 완료")
    }
    
    // MARK: - 경로 방향 기반 지도 카메라 업데이트
    private func updateMapCameraForDeviceOrientation(_ mapView: MKMapView) {
        // 사용자가 지도를 조작하지 않았을 때만 경로 방향에 따라 카메라 업데이트
        guard !isMapMoved else { return }
        
        // 현재 경로의 방향을 따라가도록 설정
        guard let route = currentRoute,
              let userLocation = locationManager.currentLocation else { return }
        
        // 현재 경로 단계에서 다음 방향 계산
        let routeHeading = calculateRouteHeading(from: userLocation, route: route)
        
        // 현재 카메라 설정 가져오기
        let currentCamera = mapView.camera
        let newCamera = MKMapCamera()
        
        // 카메라 위치와 거리 유지
        newCamera.centerCoordinate = currentCamera.centerCoordinate
        newCamera.altitude = currentCamera.altitude
        
        // 경로 방향에 따른 헤딩 설정 (경로 직진 방향)
        newCamera.heading = routeHeading
        
        // 부드러운 애니메이션으로 카메라 업데이트
        mapView.setCamera(newCamera, animated: true)
    }
    
    // MARK: - 경로 방향 계산
    private func calculateRouteHeading(from userLocation: CLLocation, route: MKRoute) -> CLLocationDirection {
        // 현재 위치에서 가장 가까운 경로 점 찾기
        var closestPoint: CLLocationCoordinate2D?
        var minDistance: CLLocationDistance = Double.infinity
        
        for step in route.steps {
            for i in 0..<step.polyline.pointCount {
                let point = step.polyline.points()[i]
                let pointLocation = CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
                let distance = userLocation.distance(from: pointLocation)
                
                if distance < minDistance {
                    minDistance = distance
                    closestPoint = point.coordinate
                }
            }
        }
        
        guard let closest = closestPoint else { return 0 }
        
        // 가장 가까운 점에서 다음 경로 점까지의 방향 계산
        var nextPoint: CLLocationCoordinate2D?
        var nextMinDistance: CLLocationDistance = Double.infinity
        
        for step in route.steps {
            for i in 0..<step.polyline.pointCount {
                let point = step.polyline.points()[i]
                let pointLocation = CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
                let distance = userLocation.distance(from: pointLocation)
                
                // 현재 위치보다 앞에 있는 점 중에서 가장 가까운 점 찾기
                if distance > minDistance && distance < nextMinDistance {
                    nextMinDistance = distance
                    nextPoint = point.coordinate
                }
            }
        }
        
        guard let next = nextPoint else { return 0 }
        
        // 두 점 사이의 방향 계산
        let fromLocation = CLLocation(latitude: closest.latitude, longitude: closest.longitude)
        let toLocation = CLLocation(latitude: next.latitude, longitude: next.longitude)
        
        let bearing = calculateBearing(from: fromLocation, to: toLocation)
        return bearing
    }
    
    // MARK: - 방향 계산 헬퍼 함수
    private func calculateBearing(from: CLLocation, to: CLLocation) -> CLLocationDirection {
        let lat1 = from.coordinate.latitude * .pi / 180
        let lat2 = to.coordinate.latitude * .pi / 180
        let deltaLon = (to.coordinate.longitude - from.coordinate.longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    // MARK: - 경로 이탈 감지 및 리라우팅
    private func checkRouteDeviation(_ mapView: MKMapView) {
        guard let userLocation = locationManager.currentLocation,
              let route = currentRoute else { return }
        
        // 현재 위치에서 경로까지의 최단 거리 계산
        let userCoordinate = userLocation.coordinate
        var minDistance: CLLocationDistance = Double.infinity
        
        // 경로의 모든 좌표점과 비교
        for step in route.steps {
            for i in 0..<step.polyline.pointCount {
                let point = step.polyline.points()[i]
                let stepCoordinate = point.coordinate
                let distance = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
                    .distance(from: CLLocation(latitude: stepCoordinate.latitude, longitude: stepCoordinate.longitude))
                
                minDistance = min(minDistance, distance)
            }
        }
        
        // 경로 이탈 감지 (50m 이상 벗어나면)
        let isOffTrack = minDistance > 50.0
        
        DispatchQueue.main.async {
            self.isRouteOffTrack = isOffTrack
            
            if isOffTrack {
                // 경로 이탈 시 리라우팅
                self.recalculateRoute(from: userLocation, on: mapView)
            }
        }
    }
    
    // MARK: - 리라우팅
    private func recalculateRoute(from userLocation: CLLocation, on mapView: MKMapView) {
        guard let destination = destinationManager.currentDestination else { return }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = .walking
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first else { return }
            
            DispatchQueue.main.async {
                self.currentRoute = route
                self.displayRoute(route, on: mapView)
                self.isRouteOffTrack = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TurnByTurnMapView
        var lastLogTime = Date()
        var lastCoinCheckLogTime = Date()
        var lastAnnotationLogTime = Date()
        
        init(_ parent: TurnByTurnMapView) {
            self.parent = parent
        }
        
        // MARK: - 지도 이동 감지
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // 사용자가 지도를 이동/확대/축소할 때 호출
            // 이벤트 발생 시에만 로그 출력 (중복 방지)
            if !self.parent.isMapMoved {
                print("🗺️ 자유 탐색 모드 활성화 - 사용자 지도 조작 감지")
            }
            DispatchQueue.main.async {
                let wasInAutoTracking = !self.parent.isMapMoved
                self.parent.isMapMoved = true
                if wasInAutoTracking {
                    print("✅ 자유 탐색 모드로 전환 완료 - 자동 추적 중지")
                    print("🗺️ 이제 지도를 자유롭게 탐색할 수 있습니다 (무제한 범위)")
                    print("🎯 길찾기 자동 추적 모드 비활성화")
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                // 도보 안내용 강조된 경로 스타일
                renderer.strokeColor = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0) // 선명한 파란색
                renderer.lineWidth = 10.0 // 더 굵은 선 (도보 안내용)
                renderer.lineCap = .round
                renderer.lineJoin = .round
                renderer.alpha = 1.0 // 완전 불투명
                
                // 그림자 효과는 MKPolylineRenderer에서 지원하지 않으므로 제거
                
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 사용자 위치 업데이트 시 내비게이션 정보 갱신
            parent.navigationManager.updateUserLocation(userLocation.location!)
            
            // 사용자 위치 마커를 더 크게 표시
            if let annotationView = mapView.view(for: userLocation) {
                annotationView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 어노테이션 뷰 생성/업데이트 로그 (너무 빈번한 로그 방지)
            if annotation is CoinAnnotation {
                let now = Date()
                if now.timeIntervalSince(lastAnnotationLogTime) > 10.0 { // 10초마다만 로그 출력
                    print("🔄 CoinAnnotation viewFor 호출됨 - 어노테이션 새로고침")
                    lastAnnotationLogTime = now
                }
            }
            
            // 사용자 위치 마커 커스터마이징
            if annotation is MKUserLocation {
                let userLocationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "userLocation")
                userLocationView.image = UIImage(systemName: "location.circle.fill")
                userLocationView.tintColor = .systemBlue
                userLocationView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5) // 더 크게
                return userLocationView
            }
            
            // 코인 어노테이션 처리
            if let coinAnnotation = annotation as? CoinAnnotation {
                let identifier = "CoinAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }
                
                // 코인 마커 설정
                if let markerView = annotationView as? MKMarkerAnnotationView {
                    // CoinManager에서 해당 코인의 실제 수집 상태 확인
                    let isActuallyCollected = parent.checkIfCoinIsCollected(coinAnnotation: coinAnnotation)
                    
                    // 메인 스레드에서 UI 업데이트 보장
                    DispatchQueue.main.async {
                        if isActuallyCollected {
                            // 수집된 코인: 초록색 배경, 체크마크 아이콘
                            markerView.markerTintColor = UIColor.systemGreen
                            markerView.glyphText = "✓"
                            markerView.glyphTintColor = UIColor.white
                            markerView.alpha = 0.7 // 약간 투명하게
                        } else {
                            // 수집되지 않은 코인: 노란색 배경, 코인 아이콘
                            markerView.markerTintColor = UIColor.systemYellow
                            markerView.glyphText = "🪙"
                            markerView.glyphTintColor = UIColor.white
                            markerView.alpha = 1.0 // 완전 불투명
                        }
                        markerView.displayPriority = .defaultHigh
                    }
                }
                
                return annotationView
            }
            
            guard !(annotation is MKUserLocation) else { return nil }
            
            guard let navAnnotation = annotation as? NavigationAnnotation else { return nil }
            
            let identifier = "NavigationAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // 내비게이션용 마커 설정
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = navAnnotation.annotationType == .start ? 
                    UIColor.systemGreen : UIColor.systemRed
                markerView.glyphText = navAnnotation.annotationType == .start ? "🏁" : "🎯"
                markerView.glyphTintColor = .white
                markerView.displayPriority = .required
            }
            
            return annotationView
        }
    }
    
    // MARK: - 코인 마커 업데이트
    private func updateCoinMarkers(on mapView: MKMapView) {
        // 기존 코인 마커 제거
        let existingCoinAnnotations = mapView.annotations.compactMap { $0 as? CoinAnnotation }
        mapView.removeAnnotations(existingCoinAnnotations)
        
        // 항상 RouteData.json의 실제 노드 데이터 사용 (하드코딩된 경로 데이터)
        if routeDataManager.isDataLoaded {
            addCoinsFromRouteData(on: mapView)
        } else {
            // RouteData.json이 로드되지 않은 경우 기존 로직 사용
            addCoinsFromPathData(on: mapView)
        }
    }
    
    private func addCoinsFromRouteData(on mapView: MKMapView) {
        print("🪙 내비게이션 지도에서 RouteData 기반 코인 마커 추가 시작")
        
        // RouteDataManager에서 실제 노드 데이터 가져오기
        let routeDataManager = RouteDataManager()
        routeDataManager.loadRouteData()
        
        // 경로 데이터가 로드될 때까지 대기
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if routeDataManager.isDataLoaded {
                self.generateCoinsFromRouteData(on: mapView, routeDataManager: routeDataManager)
            } else {
                // 데이터가 아직 로드되지 않았으면 다시 시도
                self.addCoinsFromRouteData(on: mapView)
            }
        }
    }
    
    private func addCoinsFromRouteDataOnce(on mapView: MKMapView, routeDataManager: RouteDataManager) {
        print("🪙 내비게이션 지도에서 RouteData 기반 코인 마커 추가 시작")
        print("   - 코인 배치용 좌표 수: \(routeDataManager.coinCoordinates.count)")

        var coinCount = 0

        // CoinManager의 coins 배열 초기화
        coinManager.coins.removeAll()
        coinManager.collectedCoins = 0

        // 코인 배치용 좌표에만 코인 배치 (route_coords의 coords 배열)
        for (index, coordinate) in routeDataManager.coinCoordinates.enumerated() {
            // 지도에 코인 마커 추가
            let coinAnnotation = CoinAnnotation(
                coordinate: coordinate,
                title: "코인 \(coinCount + 1)",
                subtitle: index == 0 ? "출발지 코인" : "수집 가능한 코인",
                coinIndex: coinCount,
                isCollected: false
            )
            mapView.addAnnotation(coinAnnotation)
            
            // CoinManager의 coins 배열에도 코인 추가 (수집 기능을 위해)
            let coin = Coin(
                coordinate: coordinate,
                riskLevel: 1 // 기본 위험도
            )
            coinManager.coins.append(coin)
            
            coinCount += 1
            
            if index == 0 {
                print("   - 출발지 코인 추가: (\(coordinate.latitude), \(coordinate.longitude))")
            } else {
                print("   - 코인 \(coinCount)번째 마커 추가: (\(coordinate.latitude), \(coordinate.longitude))")
            }
        }
        
        // CoinManager의 totalCoins 업데이트
        coinManager.totalCoins = coinCount
        
        print("🪙 내비게이션 지도 코인 마커 추가 완료: \(coinCount)개 (모든 좌표에 배치)")
        print("🪙 CoinManager coins 배열 크기: \(coinManager.coins.count)개")
        print("🪙 CoinManager totalCoins: \(coinManager.totalCoins)개")
        print("🪙 현재 수집된 코인: \(coinManager.collectedCoins)개 / \(coinManager.totalCoins)개")
    }
    
    private func generateCoinsFromRouteData(on mapView: MKMapView, routeDataManager: RouteDataManager) {
        print("   - 코인 배치용 좌표 수: \(routeDataManager.coinCoordinates.count)")

        var coinCount = 0

        // CoinManager의 coins 배열 초기화
        coinManager.coins.removeAll()
        coinManager.collectedCoins = 0

        // 코인 배치용 좌표에만 코인 배치 (route_coords의 coords 배열)
        for (index, coordinate) in routeDataManager.coinCoordinates.enumerated() {
            // 지도에 코인 마커 추가
            let coinAnnotation = CoinAnnotation(
                coordinate: coordinate,
                title: "코인 \(coinCount + 1)",
                subtitle: index == 0 ? "출발지 코인" : "수집 가능한 코인",
                coinIndex: coinCount,
                isCollected: false
            )
            mapView.addAnnotation(coinAnnotation)
            
            // CoinManager의 coins 배열에도 코인 추가 (수집 기능을 위해)
            let coin = Coin(
                coordinate: coordinate,
                riskLevel: 1 // 기본 위험도
            )
            coinManager.coins.append(coin)
            
            coinCount += 1
            
            if index == 0 {
                print("   - 출발지 코인 추가: (\(coordinate.latitude), \(coordinate.longitude))")
            } else {
                print("   - 코인 \(coinCount)번째 마커 추가: (\(coordinate.latitude), \(coordinate.longitude))")
            }
        }
        
        // CoinManager의 totalCoins 업데이트
        coinManager.totalCoins = coinCount
        
        print("🪙 내비게이션 지도 코인 마커 추가 완료: \(coinCount)개 (모든 좌표에 배치)")
        print("🪙 CoinManager coins 배열 크기: \(coinManager.coins.count)개")
        print("🪙 CoinManager totalCoins: \(coinManager.totalCoins)개")
    }
    
    // MARK: - 코인 데이터 복원 함수
    private func restoreCoinDataFromRouteData(routeDataManager: RouteDataManager) {
        print("🪙 코인 데이터 복원 시작")
        print("🪙 복원 전 상태: \(coinManager.collectedCoins)개 / \(coinManager.totalCoins)개")
        
        // CoinManager의 coins 배열 초기화
        coinManager.coins.removeAll()
        coinManager.collectedCoins = 0
        
        // 모든 좌표에 코인 데이터 복원
        for (index, coordinate) in routeDataManager.routeCoordinates.enumerated() {
            let coin = Coin(
                coordinate: coordinate,
                riskLevel: 1 // 기본 위험도
            )
            coinManager.coins.append(coin)
        }
        
        // CoinManager의 totalCoins 업데이트
        coinManager.totalCoins = coinManager.coins.count
        
        print("🪙 코인 데이터 복원 완료: \(coinManager.coins.count)개")
        print("🪙 복원 후 상태: \(coinManager.collectedCoins)개 / \(coinManager.totalCoins)개")
    }
    
    private func addCoinsFromPathData(on mapView: MKMapView) {
        // 기존 샘플 경로 데이터를 기반으로 코인 마커 추가
        for (index, coin) in coinManager.coins.enumerated() {
            // PathDataManager의 경로 포인트에서 해당 인덱스의 좌표 가져오기
            guard index < pathDataManager.pathPoints.count else { continue }
            
            let pathPoint = pathDataManager.pathPoints[index]
            let coordinate = CLLocationCoordinate2D(
                latitude: pathPoint.latitude,
                longitude: pathPoint.longitude
            )
            
            let coinAnnotation = CoinAnnotation(
                coordinate: coordinate,
                title: "코인 \(index + 1)",
                subtitle: coin.isCollected ? "수집됨" : "대기",
                coinIndex: index,
                isCollected: coin.isCollected
            )
            
            mapView.addAnnotation(coinAnnotation)
        }
    }
}

// MARK: - 내비게이션 매니저
class NavigationManager: ObservableObject {
    private var currentRoute: MKRoute?
    private var currentUserLocation: CLLocation?
    private var currentStepIndex: Int = 0
    
    func startNavigation(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, completion: @escaping (MKRoute) -> Void) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 내비게이션 경로 계산 오류: \(error.localizedDescription)")
                    return
                }
                
                guard let route = response?.routes.first else {
                    print("❌ 내비게이션 경로를 찾을 수 없습니다")
                    return
                }
                
                self?.currentRoute = route
                self?.currentStepIndex = 0
                completion(route)
            }
        }
    }
    
    func updateUserLocation(_ location: CLLocation) {
        currentUserLocation = location
        
        // 현재 단계 업데이트 로직
        updateCurrentStep()
    }
    
    private func updateCurrentStep() {
        guard let route = currentRoute,
              let userLocation = currentUserLocation else { return }
        
        // 사용자 위치에서 가장 가까운 단계 찾기
        var closestStepIndex = 0
        var minDistance: CLLocationDistance = Double.greatestFiniteMagnitude
        
        for (index, step) in route.steps.enumerated() {
            let stepLocation = CLLocation(
                latitude: step.polyline.coordinate.latitude,
                longitude: step.polyline.coordinate.longitude
            )
            
            let distance = userLocation.distance(from: stepLocation)
            if distance < minDistance {
                minDistance = distance
                closestStepIndex = index
            }
        }
        
        currentStepIndex = closestStepIndex
    }
    
    func getCurrentStep() -> MKRoute.Step? {
        guard let route = currentRoute,
              currentStepIndex < route.steps.count else { return nil }
        
        return route.steps[currentStepIndex]
    }
    
    func getRemainingDistance() -> CLLocationDistance {
        guard let route = currentRoute else { return 0 }
        
        var remainingDistance: CLLocationDistance = 0
        
        // 현재 단계부터 마지막 단계까지의 거리 계산
        for i in currentStepIndex..<route.steps.count {
            remainingDistance += route.steps[i].distance
        }
        
        return remainingDistance
    }
}


// MARK: - 내비게이션 어노테이션
class NavigationAnnotation: NSObject, MKAnnotation {
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

// MARK: - 코인 어노테이션
class CoinAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var coinIndex: Int
    var isCollected: Bool
    
    init(coordinate: CLLocationCoordinate2D, title: String? = nil, subtitle: String? = nil, coinIndex: Int, isCollected: Bool = false) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.coinIndex = coinIndex
        self.isCollected = isCollected
    }
}

// MARK: - Double 확장 함수
extension Double {
    func toRadians() -> Double {
        return self * .pi / 180.0
    }
    
    func toDegrees() -> Double {
        return self * 180.0 / .pi
    }
}

#Preview {
    let routeDataManager = RouteDataManager()
    TurnByTurnNavigationView(
        locationManager: LocationManager(),
        destinationManager: DestinationManager(),
        routeDataManager: routeDataManager,
        pathDataManager: PathDataManager(routeDataManager: routeDataManager)
    )
}
