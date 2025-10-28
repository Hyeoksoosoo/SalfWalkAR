import Foundation
import CoreLocation
import Combine

// MARK: - JSON 파싱용 모델
struct RouteDataResponse: Codable {
    let routeType: String
    let nodes: [String: NodeData]
    let coords: [[Double]]
    
    enum CodingKeys: String, CodingKey {
        case routeType = "route_type"
        case nodes
        case coords
    }
}

struct NodeData: Codable {
    let lat: Double
    let lon: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - 경로 데이터 매니저
class RouteDataManager: ObservableObject {
    @Published var routeType: String = ""
    @Published var routeNodes: [String: NodeData] = [:]
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var coinCoordinates: [CLLocationCoordinate2D] = []  // 코인 배치용 좌표 (route_coords)
    @Published var isDataLoaded = false

    // API 연동을 위한 새로운 프로퍼티들
    @Published var isLoading = false
    @Published var lastError: NetworkError?
    @Published var routeDistance: Double = 0.0
    @Published var routeDuration: Int = 0
    @Published var safetyScore: Int = 0
    
    // 네트워크 매니저
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 이전 경로 데이터 백업 (롤백용)
    private var previousRouteData: (type: String, nodes: [String: NodeData], coordinates: [CLLocationCoordinate2D])?
    
    func loadRouteData() {
        // 이미 로드된 경우 스킵
        if isDataLoaded {
            print("📂 RouteData.json 이미 로드됨 - 스킵")
            return
        }
        
        print("📂 RouteData.json 로딩 시작...")
        
        guard let url = Bundle.main.url(forResource: "RouteData", withExtension: "json") else {
            print("❌ RouteData.json 파일을 찾을 수 없습니다")
            return
        }
        
        print("📂 JSON 파일 경로: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            print("📂 JSON 파일 크기: \(data.count) bytes")
            
            let routeData = try JSONDecoder().decode(RouteDataResponse.self, from: data)
            
            DispatchQueue.main.async {
                self.routeType = routeData.routeType
                self.routeNodes = routeData.nodes
                
                // coords 배열을 사용해서 경로 좌표 생성
                self.routeCoordinates = self.generateRouteCoordinatesFromCoords(routeData.coords)
                self.isDataLoaded = true
                
                print("✅ 경로 데이터 로드 완료:")
                print("   - 경로 타입: \(self.routeType)")
                print("   - 노드 수: \(self.routeNodes.count)개")
                print("   - 좌표 수: \(self.routeCoordinates.count)개")
                print("   - 출발지: \(self.routeCoordinates.first?.latitude ?? 0), \(self.routeCoordinates.first?.longitude ?? 0)")
                print("   - 도착지: \(self.routeCoordinates.last?.latitude ?? 0), \(self.routeCoordinates.last?.longitude ?? 0)")
            }
        } catch {
            print("❌ JSON 파싱 오류: \(error)")
            print("❌ 오류 상세: \(error.localizedDescription)")
        }
    }
    
    // coords 배열로부터 경로 좌표 생성
    private func generateRouteCoordinatesFromCoords(_ coords: [[Double]]) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        
        for coord in coords {
            guard coord.count >= 2 else { continue }
            let coordinate = CLLocationCoordinate2D(latitude: coord[0], longitude: coord[1])
            coordinates.append(coordinate)
        }
        
        return coordinates
    }
    
    // nodes 데이터로부터 경로 좌표 생성 (fallback)
    private func generateRouteCoordinatesFromNodes() -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // 모든 노드를 정렬된 순서로 사용
        let sortedNodeIds = routeNodes.keys.sorted()
        
        for nodeId in sortedNodeIds {
            if let node = routeNodes[nodeId] {
                coordinates.append(node.coordinate)
            }
        }
        
        return coordinates
    }
    
    // 특정 노드 ID로 좌표 가져오기
    func getCoordinate(for nodeId: String) -> CLLocationCoordinate2D? {
        return routeNodes[nodeId]?.coordinate
    }
    
    // 모든 노드 ID 목록 가져오기
    func getAllNodeIds() -> [String] {
        return Array(routeNodes.keys).sorted()
    }
    
    // 경로의 시작점과 끝점 가져오기
    func getStartAndEndPoints() -> (start: CLLocationCoordinate2D, end: CLLocationCoordinate2D)? {
        guard let start = routeCoordinates.first,
              let end = routeCoordinates.last else {
            return nil
        }
        return (start: start, end: end)
    }
    
    // 경로의 총 거리 계산
    func calculateTotalDistance() -> Double {
        guard routeCoordinates.count > 1 else { return 0.0 }
        
        var totalDistance: Double = 0.0
        for i in 0..<routeCoordinates.count - 1 {
            let start = CLLocation(latitude: routeCoordinates[i].latitude, longitude: routeCoordinates[i].longitude)
            let end = CLLocation(latitude: routeCoordinates[i + 1].latitude, longitude: routeCoordinates[i + 1].longitude)
            totalDistance += start.distance(from: end)
        }
        
        return totalDistance / 1000.0 // km로 변환
    }
    
    // MARK: - API 연동 메서드들

    /// API를 통한 새로운 경로 데이터 요청 (좌표 기반)
    /// - Parameters:
    ///   - start: 출발지 좌표
    ///   - end: 목적지 좌표
    ///   - completion: 완료 핸들러
    func fetchRouteFromAPI(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        completion: @escaping (Bool) -> Void
    ) {
        print("\n========================================")
        print("🌐 RouteDataModel.fetchRouteFromAPI() 호출됨")
        print("========================================")
        print("   출발지: \(start.latitude), \(start.longitude)")
        print("   목적지: \(end.latitude), \(end.longitude)")
        print("   networkManager: \(networkManager)")

        // 로딩 상태 시작
        DispatchQueue.main.async {
            self.isLoading = true
            self.lastError = nil
        }

        // 이전 데이터 백업 (롤백용)
        backupCurrentRouteData()

        print("🔄 NetworkManager.fetchRoute() 호출 직전...")

        // API 요청
        networkManager.fetchRoute(from: start, to: end) { [weak self] result in
            print("\n📨 NetworkManager.fetchRoute() 콜백 수신됨")

            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let routeResponse):
                    print("✅ API 성공 - handleSuccessfulRouteResponse 호출")
                    print("   경로 포인트 수: \(routeResponse.route.count)")
                    print("   거리: \(routeResponse.distance)km")
                    print("   소요시간: \(routeResponse.duration)분")
                    print("   안전도: \(routeResponse.safetyScore)")
                    self?.handleSuccessfulRouteResponse(routeResponse)
                    completion(true)

                case .failure(let error):
                    print("❌ API 실패 - handleRouteError 호출")
                    print("   에러: \(error)")
                    print("   에러 설명: \(error.localizedDescription)")
                    self?.handleRouteError(error)
                    completion(false)
                }
            }
        }

        print("✅ NetworkManager.fetchRoute() 호출 완료 (비동기 대기 중)")
        print("========================================\n")
    }
    
    /// 비동기 API를 통한 새로운 경로 데이터 요청
    /// - Parameters:
    ///   - start: 출발지 좌표
    ///   - end: 목적지 좌표
    /// - Returns: 성공 여부
    func fetchRouteFromAPIAsync(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) async -> Bool {
        print("🌐 비동기 API를 통한 경로 데이터 요청 시작")
        print("   출발지: \(start.latitude), \(start.longitude)")
        print("   목적지: \(end.latitude), \(end.longitude)")
        
        // 로딩 상태 시작
        await MainActor.run {
            self.isLoading = true
            self.lastError = nil
        }
        
        // 이전 데이터 백업 (롤백용)
        backupCurrentRouteData()
        
        do {
            let routeResponse = try await networkManager.fetchRouteAsync(from: start, to: end)
            await handleSuccessfulRouteResponse(routeResponse)
            return true
            
        } catch {
            await handleRouteError(error as? NetworkError ?? .networkUnavailable)
            return false
        }
    }
    
    /// API를 통한 새로운 경로 데이터 요청 (주소 기반)
    /// - Parameters:
    ///   - startLocation: 출발지 장소명
    ///   - endLocation: 목적지 장소명
    ///   - completion: 완료 핸들러
    func fetchRouteFromAPI(
        from startLocation: String,
        to endLocation: String,
        completion: @escaping (Bool) -> Void
    ) {
        print("\n========================================")
        print("🌐 RouteDataModel.fetchRouteFromAPI() 호출됨 (주소 모드)")
        print("========================================")
        print("   출발지: \(startLocation)")
        print("   목적지: \(endLocation)")
        print("   networkManager: \(networkManager)")

        // 로딩 상태 시작
        DispatchQueue.main.async {
            self.isLoading = true
            self.lastError = nil
        }

        // 이전 데이터 백업 (롤백용)
        backupCurrentRouteData()

        print("🔄 NetworkManager.fetchRoute() 호출 직전... (주소 모드)")

        // API 요청
        networkManager.fetchRoute(from: startLocation, to: endLocation) { [weak self] result in
            print("\n📨 NetworkManager.fetchRoute() 콜백 수신됨 (주소 모드)")

            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let routeResponse):
                    print("✅ API 성공 - handleSuccessfulRouteResponse 호출")
                    print("   경로 포인트 수: \(routeResponse.route.count)")
                    print("   거리: \(routeResponse.distance)km")
                    print("   소요시간: \(routeResponse.duration)분")
                    print("   안전도: \(routeResponse.safetyScore)")
                    self?.handleSuccessfulRouteResponse(routeResponse)
                    completion(true)

                case .failure(let error):
                    print("❌ API 실패 - handleRouteError 호출")
                    print("   에러: \(error)")
                    print("   에러 설명: \(error.localizedDescription)")
                    self?.handleRouteError(error)
                    completion(false)
                }
            }
        }

        print("✅ NetworkManager.fetchRoute() 호출 완료 (비동기 대기 중)")
        print("========================================\n")
    }

    /// 기존 경로 데이터를 새 데이터로 덮어쓰기 (좌표 기반)
    /// - Parameters:
    ///   - start: 출발지 좌표
    ///   - end: 목적지 좌표
    ///   - completion: 완료 핸들러
    func overwriteRouteData(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        completion: @escaping (Bool) -> Void
    ) {
        print("🔄 기존 경로 데이터 덮어쓰기 시작 (좌표 모드)")

        // 기존 데이터가 있는 경우에만 덮어쓰기
        guard isDataLoaded else {
            print("⚠️ 기존 경로 데이터가 없어서 새로 로드합니다")
            fetchRouteFromAPI(from: start, to: end, completion: completion)
            return
        }

        // 이전 데이터 백업
        backupCurrentRouteData()

        // 새 경로 요청
        fetchRouteFromAPI(from: start, to: end) { [weak self] success in
            if success {
                print("✅ 경로 데이터 덮어쓰기 완료")
            } else {
                print("❌ 경로 데이터 덮어쓰기 실패 - 이전 데이터로 복원")
                self?.restorePreviousRouteData()
            }
            completion(success)
        }
    }

    /// 기존 경로 데이터를 새 데이터로 덮어쓰기 (주소 기반)
    /// - Parameters:
    ///   - startLocation: 출발지 장소명
    ///   - endLocation: 목적지 장소명
    ///   - completion: 완료 핸들러
    func overwriteRouteData(
        from startLocation: String,
        to endLocation: String,
        completion: @escaping (Bool) -> Void
    ) {
        print("🔄 기존 경로 데이터 덮어쓰기 시작 (주소 모드)")

        // 기존 데이터가 있는 경우에만 덮어쓰기
        guard isDataLoaded else {
            print("⚠️ 기존 경로 데이터가 없어서 새로 로드합니다")
            fetchRouteFromAPI(from: startLocation, to: endLocation, completion: completion)
            return
        }

        // 이전 데이터 백업
        backupCurrentRouteData()

        // 새 경로 요청
        fetchRouteFromAPI(from: startLocation, to: endLocation) { [weak self] success in
            if success {
                print("✅ 경로 데이터 덮어쓰기 완료")
            } else {
                print("❌ 경로 데이터 덮어쓰기 실패 - 이전 데이터로 복원")
                self?.restorePreviousRouteData()
            }
            completion(success)
        }
    }
    
    /// 이전 경로 데이터로 롤백
    func rollbackToPreviousRoute() {
        print("🔄 이전 경로 데이터로 롤백")
        restorePreviousRouteData()
    }
    
    /// 캐시된 경로 데이터 정리
    func clearRouteCache() {
        print("🗑️ 경로 데이터 캐시 정리")
        
        DispatchQueue.main.async {
            self.routeType = ""
            self.routeNodes = [:]
            self.routeCoordinates = []
            self.isDataLoaded = false
            self.routeDistance = 0.0
            self.routeDuration = 0
            self.safetyScore = 0
            self.lastError = nil
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// 현재 경로 데이터 백업
    private func backupCurrentRouteData() {
        previousRouteData = (
            type: routeType,
            nodes: routeNodes,
            coordinates: routeCoordinates
        )
        print("💾 현재 경로 데이터 백업 완료")
    }
    
    /// 이전 경로 데이터 복원
    private func restorePreviousRouteData() {
        guard let previous = previousRouteData else {
            print("⚠️ 복원할 이전 데이터가 없습니다")
            return
        }
        
        DispatchQueue.main.async {
            self.routeType = previous.type
            self.routeNodes = previous.nodes
            self.routeCoordinates = previous.coordinates
            self.isDataLoaded = true
            self.lastError = nil
        }
        
        print("🔄 이전 경로 데이터 복원 완료")
    }
    
    /// 성공적인 경로 응답 처리
    private func handleSuccessfulRouteResponse(_ response: RouteResponse) {
        print("\n========================================")
        print("✅ API 경로 응답 처리 시작")
        print("========================================")
        print("📊 받은 데이터:")
        print("   - 경로 포인트 (노드) 개수: \(response.route.count)개")
        print("   - 거리: \(response.distance)km")
        print("   - 소요시간: \(response.duration)분")
        print("   - 안전도: \(response.safetyScore)점")

        if response.route.count > 0 {
            print("📍 첫 번째 노드: lat=\(response.route[0].lat), lon=\(response.route[0].lon)")
            print("📍 마지막 노드: lat=\(response.route.last!.lat), lon=\(response.route.last!.lon)")
        }

        // 경로 좌표 변환
        let coordinates = response.route.map { $0.clLocationCoordinate }

        // 코인 배치용 좌표 변환
        if let coinCoords = response.coinCoords {
            let coinCoordinatesArray = coinCoords.map { $0.clLocationCoordinate }
            coinCoordinates = coinCoordinatesArray
            print("🪙 코인 배치용 좌표: \(coinCoordinates.count)개")
        } else {
            // route_coords 다운로드 실패 시 경로 좌표 사용
            coinCoordinates = coordinates
            print("🪙 코인 배치용 좌표: 경로 좌표 사용 (\(coinCoordinates.count)개)")
        }

        // 데이터 업데이트
        routeType = "API_ROUTE"
        routeCoordinates = coordinates
        routeDistance = response.distance
        routeDuration = response.duration
        safetyScore = response.safetyScore
        isDataLoaded = true
        lastError = nil

        // 노드 데이터 생성 (기존 형식과 호환성을 위해)
        generateNodesFromCoordinates(coordinates)

        print("✅ API 경로 데이터 처리 완료")
        print("   - routeCoordinates 배열에 \(routeCoordinates.count)개 좌표 저장됨")
        print("   - coinCoordinates 배열에 \(coinCoordinates.count)개 좌표 저장됨")
        print("   - routeNodes 딕셔너리에 \(routeNodes.count)개 노드 저장됨")
        print("========================================\n")
    }
    
    /// 경로 에러 처리
    private func handleRouteError(_ error: NetworkError) {
        print("❌ API 경로 요청 실패: \(error.localizedDescription)")
        
        lastError = error
        isDataLoaded = false
        
        // 이전 데이터가 있으면 복원
        if previousRouteData != nil {
            print("🔄 이전 경로 데이터로 복원 시도")
            restorePreviousRouteData()
        }
    }
    
    /// 좌표 배열로부터 노드 데이터 생성
    private func generateNodesFromCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
        var nodes: [String: NodeData] = [:]
        
        for (index, coordinate) in coordinates.enumerated() {
            let nodeId = "node_\(index)"
            let nodeData = NodeData(lat: coordinate.latitude, lon: coordinate.longitude)
            nodes[nodeId] = nodeData
        }
        
        routeNodes = nodes
        print("📍 노드 데이터 생성 완료: \(nodes.count)개")
    }
}
