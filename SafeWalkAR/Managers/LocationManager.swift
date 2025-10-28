import Foundation
import CoreLocation
import MapKit

enum LocationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
    case locationFound
    case error(String)
}

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var status: LocationStatus = .notDetermined
    @Published var isLocationServiceEnabled = false
    
    // 🎯 위치 이상치 필터링을 위한 변수들
    private var locationHistory: [CLLocation] = []
    private let maxHistorySize = 5 // 최근 5개 위치만 유지
    private let maxWalkingSpeed: Double = 5.0 // m/s (18km/h) - 도보 최대 속도
    private let maxJumpDistance: Double = 50.0 // m - 한 번에 이동할 수 있는 최대 거리
    
    // 🎯 칼만 필터 인스턴스
    // TODO: KalmanFilter 구현 필요
    // private let kalmanFilter = KalmanFilter()

    // 🎯 모션 센서 매니저
    // TODO: MotionSensorManager 구현 필요
    // private let motionSensorManager = MotionSensorManager()

    // 🎯 경로 스냅핑 매니저
    // TODO: PathSnappingManager 구현 필요
    // private let pathSnappingManager = PathSnappingManager()
    
    var authorizationStatus: CLAuthorizationStatus {
        return locationManager.authorizationStatus
    }
    
    var onLocationUpdate: ((CLLocation) -> Void)?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        
        // 🎯 GPS 정확도 최적화 설정
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // 최고 정확도
        locationManager.distanceFilter = 2 // 2m 간격으로 업데이트 (도보 환경 최적화)
        locationManager.pausesLocationUpdatesAutomatically = false // 자동 일시정지 비활성화
        
        // 🎯 백그라운드 위치 업데이트 활성화 (필요 시)
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = false // 기본적으로 비활성화
        }
        
        // 🎯 위치 업데이트 빈도 최적화
        if #available(iOS 14.0, *) {
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        }
        
        print("🎯 LocationManager 최적화 설정 완료:")
        print("   - 정확도: kCLLocationAccuracyBestForNavigation")
        print("   - 거리 필터: 2m")
        print("   - 자동 일시정지: 비활성화")

        // 🎯 모션 센서 업데이트 시작
        // TODO: MotionSensorManager 구현 후 활성화
        // motionSensorManager.startMotionUpdates()
    }
    
    func requestLocationPermission() {
        print("📍 위치 권한 요청 시작")
        
        // 백그라운드 스레드에서 권한 상태 확인
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let currentStatus = self.locationManager.authorizationStatus
            print("📍 현재 권한 상태: \(currentStatus.rawValue)")
            
            DispatchQueue.main.async {
                switch currentStatus {
                case .notDetermined:
                    print("📍 권한 미결정 - 권한 요청")
                    self.locationManager.requestWhenInUseAuthorization()
                case .denied, .restricted:
                    print("📍 권한 거부됨")
                    self.status = .denied
                case .authorizedWhenInUse, .authorizedAlways:
                    print("📍 권한 허용됨 - 위치 업데이트 시작")
                    self.status = .authorized
                    self.startLocationUpdates()
                @unknown default:
                    print("📍 알 수 없는 권한 상태")
                    self.status = .error("알 수 없는 권한 상태")
                }
            }
        }
    }
    
    func startLocationUpdates() {
        // 시뮬레이터에서도 실제 위치 서비스 사용
        // #if targetEnvironment(simulator)
        // // 시뮬레이터에서는 가짜 위치 데이터 주입
        // injectSimulatorLocation()
        // return
        // #endif
        
        // 백그라운드 스레드에서 위치 서비스 확인
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard CLLocationManager.locationServicesEnabled() else {
                DispatchQueue.main.async {
                    self.status = .error("위치 서비스가 비활성화되어 있습니다")
                }
                return
            }
            
            let currentAuthStatus = self.authorizationStatus
            
            DispatchQueue.main.async {
                if currentAuthStatus == .notDetermined {
                    self.locationManager.requestWhenInUseAuthorization()
                    return
                }
                
                guard currentAuthStatus == .authorizedWhenInUse || currentAuthStatus == .authorizedAlways else {
                    self.status = .denied
                    return
                }
                
                self.locationManager.startUpdatingLocation()
                self.isLocationServiceEnabled = true
                self.status = .authorized
            }
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLocationServiceEnabled = false
    }
    
    // MARK: - 경로 설정 메서드

    /// 내비게이션 경로 설정 (경로 스냅핑용)
    func setNavigationRoute(_ route: MKRoute) {
        // TODO: PathSnappingManager 구현 후 활성화
        // pathSnappingManager.setRoute(route)
        print("🎯 LocationManager에 내비게이션 경로 설정 완료")
    }

    /// 좌표 배열로 경로 설정 (경로 스냅핑용)
    func setNavigationRoute(from coordinates: [CLLocationCoordinate2D]) {
        // TODO: PathSnappingManager 구현 후 활성화
        // pathSnappingManager.setRoute(from: coordinates)
        print("🎯 LocationManager에 좌표 배열 경로 설정 완료: \(coordinates.count)개 좌표")
    }
    
    
    func getLocationStatusDescription() -> String {
        switch status {
        case .notDetermined:
            return "위치 권한을 요청해주세요"
        case .denied:
            return "위치 권한이 거부되었습니다"
        case .authorized:
            return "위치 권한이 허용되었습니다"
        case .locationFound:
            return "현재 위치를 찾았습니다"
        case .error(let message):
            return "오류: \(message)"
        }
    }

    // MARK: - Reverse Geocoding (좌표 → 주소 변환)

    /// 현재 위치의 좌표를 주소로 변환
    func getCurrentLocationAddress(completion: @escaping (String?) -> Void) {
        guard let location = currentLocation else {
            print("❌ 현재 위치를 찾을 수 없습니다")
            completion(nil)
            return
        }

        reverseGeocodeLocation(location, completion: completion)
    }

    /// 좌표를 주소로 변환 (Apple Geocoding 사용)
    func reverseGeocodeLocation(_ location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()

        print("📍 Reverse Geocoding 시작: (\(location.coordinate.latitude), \(location.coordinate.longitude))")

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("❌ Reverse Geocoding 실패: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let placemark = placemarks?.first else {
                print("❌ 주소를 찾을 수 없습니다")
                completion(nil)
                return
            }

            // 🎯 서버용 도로명 주소 형식: "고양대로 632번길"
            var addressComponents: [String] = []

            // 도로명 (thoroughfare)만 사용
            if let thoroughfare = placemark.thoroughfare {
                addressComponents.append(thoroughfare)
            }

            let address = addressComponents.joined(separator: " ")

            if !address.isEmpty {
                print("✅ Reverse Geocoding 성공 (도로명): \(address)")
                completion(address)
            } else {
                print("⚠️ 도로명 주소 없음 - 전체 주소로 대체")
                // 도로명이 없으면 전체 주소 사용
                var fallbackComponents: [String] = []

                if let subThoroughfare = placemark.subThoroughfare {
                    fallbackComponents.append(subThoroughfare)
                }
                if let thoroughfare = placemark.thoroughfare {
                    fallbackComponents.append(thoroughfare)
                }
                if let subLocality = placemark.subLocality {
                    fallbackComponents.append(subLocality)
                }
                if let locality = placemark.locality {
                    fallbackComponents.append(locality)
                }

                let fallbackAddress = fallbackComponents.reversed().joined(separator: " ")
                completion(fallbackAddress.isEmpty ? placemark.name : fallbackAddress)
            }
        }
    }

    // MARK: - 위치 이상치 필터링
    
    /// 위치 이상치를 필터링하고 유효한 위치만 반환
    private func filterLocationOutliers(_ newLocation: CLLocation) -> CLLocation? {
        // 1. 기본 정확도 체크
        guard newLocation.horizontalAccuracy <= 20 else {
            print("⚠️ 위치 정확도가 낮음: \(newLocation.horizontalAccuracy)m")
            return nil
        }
        
        // 2. 첫 번째 위치는 항상 허용
        guard let lastLocation = locationHistory.last else {
            locationHistory.append(newLocation)
            return newLocation
        }
        
        // 3. 시간 기반 속도 체크
        let timeInterval = newLocation.timestamp.timeIntervalSince(lastLocation.timestamp)
        let distance = newLocation.distance(from: lastLocation)
        
        if timeInterval > 0 {
            let speed = distance / timeInterval // m/s
            
            // 4. 비정상적인 속도 체크 (도보 범위 초과)
            if speed > maxWalkingSpeed {
                print("⚠️ 비정상적인 속도 감지: \(speed)m/s (최대: \(maxWalkingSpeed)m/s)")
                return nil
            }
            
            // 5. 비정상적인 점프 거리 체크
            if distance > maxJumpDistance {
                print("⚠️ 비정상적인 점프 거리 감지: \(distance)m (최대: \(maxJumpDistance)m)")
                return nil
            }
        }
        
        // 6. 위치 히스토리에 추가
        locationHistory.append(newLocation)
        
        // 7. 히스토리 크기 제한
        if locationHistory.count > maxHistorySize {
            locationHistory.removeFirst()
        }
        
        // 8. Moving Average 적용하여 위치 평활화
        return calculateMovingAverageLocation()
    }
    
    /// 최근 위치들의 평균을 계산하여 평활화된 위치 반환
    private func calculateMovingAverageLocation() -> CLLocation? {
        guard !locationHistory.isEmpty else { return nil }
        
        // 가중 평균 계산 (최근 위치일수록 높은 가중치)
        var totalLatitude: Double = 0
        var totalLongitude: Double = 0
        var totalWeight: Double = 0
        
        for (index, location) in locationHistory.enumerated() {
            let weight = Double(index + 1) // 최근 위치일수록 높은 가중치
            totalLatitude += location.coordinate.latitude * weight
            totalLongitude += location.coordinate.longitude * weight
            totalWeight += weight
        }
        
        let averageLatitude = totalLatitude / totalWeight
        let averageLongitude = totalLongitude / totalWeight
        
        // 평균 위치로 새로운 CLLocation 생성
        let averageCoordinate = CLLocationCoordinate2D(latitude: averageLatitude, longitude: averageLongitude)
        let averageLocation = CLLocation(
            coordinate: averageCoordinate,
            altitude: locationHistory.last?.altitude ?? 0,
            horizontalAccuracy: locationHistory.last?.horizontalAccuracy ?? 0,
            verticalAccuracy: locationHistory.last?.verticalAccuracy ?? 0,
            timestamp: Date()
        )
        
        print("🎯 위치 평활화 완료: (\(averageLatitude), \(averageLongitude))")
        return averageLocation
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let rawLocation = locations.last else { return }

        // 🎯 위치 이상치 필터링 적용
        guard let outlierFilteredLocation = filterLocationOutliers(rawLocation) else {
            print("⚠️ 위치 이상치로 인해 업데이트 무시됨")
            return
        }

        // 🎯 칼만 필터 적용
        // TODO: KalmanFilter 구현 후 활성화
        // guard let kalmanFilteredLocation = kalmanFilter.update(with: outlierFilteredLocation) else {
        //     print("⚠️ 칼만 필터 적용 실패")
        //     return
        // }
        let kalmanFilteredLocation = outlierFilteredLocation

        // 🎯 모션 센서 보정 적용
        // TODO: MotionSensorManager 구현 후 활성화
        // let motionCorrectedLocation = motionSensorManager.correctLocation(kalmanFilteredLocation) ?? kalmanFilteredLocation
        let motionCorrectedLocation = kalmanFilteredLocation

        // 🎯 경로 스냅핑 적용
        // TODO: PathSnappingManager 구현 후 활성화
        // let finalLocation = pathSnappingManager.snapToPath(motionCorrectedLocation) ?? motionCorrectedLocation
        let finalLocation = motionCorrectedLocation

        // 위치 업데이트를 메인 스레드에서 처리
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.currentLocation = finalLocation
            self.status = .locationFound
            self.onLocationUpdate?(finalLocation)

            // 위치 업데이트 로그 (디버그 모드에서만)
            #if DEBUG
            print("📍 위치 업데이트 (최종 보정됨): \(finalLocation.coordinate.latitude), \(finalLocation.coordinate.longitude) (정확도: \(finalLocation.horizontalAccuracy)m)")
            print("📍 이상치 필터링됨: \(outlierFilteredLocation.coordinate.latitude), \(outlierFilteredLocation.coordinate.longitude)")
            print("📍 원본 위치: \(rawLocation.coordinate.latitude), \(rawLocation.coordinate.longitude) (정확도: \(rawLocation.horizontalAccuracy)m)")
            // TODO: 센서 데이터 및 경로 스냅핑 요약 활성화
            // print("🎯 센서 데이터: \(self.motionSensorManager.getSensorSummary())")
            // print("🎯 경로 스냅핑: \(self.pathSnappingManager.getRouteSummary())")
            #endif
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 오류 처리를 메인 스레드에서 처리
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.status = .error(error.localizedDescription)
            #if DEBUG
            print("❌ 위치 오류: \(error.localizedDescription)")
            #endif
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 권한 상태 변경: \(status.rawValue)")
        
        // 권한 변경 시 메인 스레드에서 처리
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch status {
            case .notDetermined:
                print("📍 권한 미결정 상태")
                self.status = .notDetermined
            case .denied, .restricted:
                print("📍 권한 거부됨 - 위치 업데이트 중지")
                self.status = .denied
                self.stopLocationUpdates()
            case .authorizedWhenInUse, .authorizedAlways:
                print("📍 권한 허용됨 - 위치 업데이트 시작")
                self.status = .authorized
                self.startLocationUpdates()
            @unknown default:
                print("📍 알 수 없는 권한 상태")
                self.status = .error("알 수 없는 권한 상태")
            }
        }
    }
}