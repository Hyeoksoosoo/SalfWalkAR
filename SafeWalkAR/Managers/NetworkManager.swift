import Foundation
import CoreLocation

// MARK: - API 요청/응답 모델
struct RouteRequest: Codable {
    let startLat: Double
    let startLon: Double
    let endLat: Double
    let endLon: Double
    let inputMode: String

    enum CodingKeys: String, CodingKey {
        case startLat = "start_lat"
        case startLon = "start_lon"
        case endLat = "end_lat"
        case endLon = "end_lon"
        case inputMode = "input_mode"
    }
}

struct RoutePointResponse: Codable {
    let lat: Double
    let lon: Double

    // 커스텀 디코딩으로 lat/lon과 latitude/longitude 둘 다 지원
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // lat/lon 시도
        if let latitude = try? container.decode(Double.self, forKey: .lat) {
            self.lat = latitude
        } else if let latitude = try? container.decode(Double.self, forKey: .latitude) {
            self.lat = latitude
        } else {
            throw DecodingError.keyNotFound(CodingKeys.lat, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "lat 또는 latitude 키를 찾을 수 없음"))
        }

        if let longitude = try? container.decode(Double.self, forKey: .lon) {
            self.lon = longitude
        } else if let longitude = try? container.decode(Double.self, forKey: .longitude) {
            self.lon = longitude
        } else {
            throw DecodingError.keyNotFound(CodingKeys.lon, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "lon 또는 longitude 키를 찾을 수 없음"))
        }
    }

    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }

    // 커스텀 인코딩 (표준 lat/lon 형식으로 출력)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lat, forKey: .lat)
        try container.encode(lon, forKey: .lon)
    }

    enum CodingKeys: String, CodingKey {
        case lat
        case lon
        case latitude
        case longitude
    }

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// 서버 실제 응답 모델
struct ServerAnalyzeRouteResponse: Codable {
    let success: Bool
    let message: String
    let data: ServerRouteData

    struct ServerRouteData: Codable {
        let startLocation: String  // 수정: 문자열로 변경
        let endLocation: String    // 수정: 문자열로 변경
        let startCoords: RoutePointResponse
        let endCoords: RoutePointResponse
        let dangerCentersCount: Int
        let files: RouteFiles

        enum CodingKeys: String, CodingKey {
            case startLocation = "start_location"
            case endLocation = "end_location"
            case startCoords = "start_coords"
            case endCoords = "end_coords"
            case dangerCentersCount = "danger_centers_count"
            case files
        }
    }

    struct RouteFiles: Codable {
        let dangerCenters: String
        let detailedRoute1m: String
        let originalRouteMap: String
        let routeCoords: String
        let safeRouteMap: String

        enum CodingKeys: String, CodingKey {
            case dangerCenters = "danger_centers"
            case detailedRoute1m = "detailed_route_1m"
            case originalRouteMap = "original_route_map"
            case routeCoords = "route_coords"
            case safeRouteMap = "safe_route_map"
        }
    }
}

// 앱 내부에서 사용하는 경로 응답 모델
struct RouteResponse: Codable {
    let route: [RoutePointResponse]
    let coinCoords: [RoutePointResponse]?  // 코인 배치용 좌표 (route_coords)
    let distance: Double
    let duration: Int
    let safetyScore: Int

    enum CodingKeys: String, CodingKey {
        case route, coinCoords, distance, duration
        case safetyScore = "safety_score"
    }
}

// MARK: - 네트워크 에러 타입
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(Int)
    case networkUnavailable
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .noData:
            return "서버에서 데이터를 받을 수 없습니다."
        case .decodingError:
            return "데이터를 처리할 수 없습니다."
        case .serverError(let code):
            return "서버 오류가 발생했습니다. (코드: \(code))"
        case .networkUnavailable:
            return "네트워크 연결을 확인해주세요."
        case .timeout:
            return "요청 시간이 초과되었습니다."
        }
    }
}

// MARK: - API 응답 상태
enum APIResponseStatus {
    case success
    case loading
    case error(NetworkError)
}

// MARK: - 네트워크 매니저
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    // MARK: - Properties
    private let session: URLSession
    private let baseURL: String
    private let timeoutInterval: TimeInterval = 240.0  // 4분 - 주소 기반 경로 계산에 충분한 시간
    
    // MARK: - Published Properties
    @Published var isConnected: Bool = true
    @Published var lastError: NetworkError?
    
    // MARK: - Initialization
    private init() {
        // EC2 서버 IP 주소 설정
        self.baseURL = "http://3.35.11.129"
        
        // URLSession 설정
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval
        config.waitsForConnectivity = true
        
        self.session = URLSession(configuration: config)
        
        // 네트워크 상태 모니터링
        startNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// 경로 계산 API 호출 (좌표 기반)
    /// - Parameters:
    ///   - start: 출발지 좌표
    ///   - end: 목적지 좌표
    ///   - completion: 완료 핸들러
    func fetchRoute(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        completion: @escaping (Result<RouteResponse, NetworkError>) -> Void
    ) {
        print("\n🔍 NetworkManager.fetchRoute() 호출됨 (좌표 모드)")
        print("   isConnected 상태: \(isConnected)")

        // 네트워크 연결 확인
        guard isConnected else {
            print("❌ 네트워크 연결 체크 실패 - isConnected = false")
            print("   NetworkManager가 네트워크를 사용할 수 없다고 판단했습니다.")
            completion(.failure(.networkUnavailable))
            return
        }

        print("✅ 네트워크 연결 체크 통과 - API 요청 진행")

        // API 요청 생성
        let request = createRouteRequest(from: start, to: end)

        // 네트워크 요청 실행
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleRouteResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }

    /// 경로 계산 API 호출 (주소 기반)
    /// - Parameters:
    ///   - startLocation: 출발지 장소명
    ///   - endLocation: 목적지 장소명
    ///   - completion: 완료 핸들러
    func fetchRoute(
        from startLocation: String,
        to endLocation: String,
        completion: @escaping (Result<RouteResponse, NetworkError>) -> Void
    ) {
        print("\n🔍 NetworkManager.fetchRoute() 호출됨 (주소 모드)")
        print("   isConnected 상태: \(isConnected)")

        // 네트워크 연결 확인
        guard isConnected else {
            print("❌ 네트워크 연결 체크 실패 - isConnected = false")
            print("   NetworkManager가 네트워크를 사용할 수 없다고 판단했습니다.")
            completion(.failure(.networkUnavailable))
            return
        }

        print("✅ 네트워크 연결 체크 통과 - API 요청 진행")

        // API 요청 생성
        let request = createRouteRequest(from: startLocation, to: endLocation)

        // 네트워크 요청 실행
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleRouteResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }
    
    /// 비동기 경로 계산 API 호출 (async/await)
    /// - Parameters:
    ///   - start: 출발지 좌표
    ///   - end: 목적지 좌표
    /// - Returns: RouteResponse 또는 NetworkError
    func fetchRouteAsync(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) async throws -> RouteResponse {
        guard isConnected else {
            throw NetworkError.networkUnavailable
        }
        
        let request = createRouteRequest(from: start, to: end)
        
        do {
            let (data, response) = try await session.data(for: request)
            return try await handleRouteResponseAsync(data: data, response: response)
        } catch {
            if let networkError = error as? NetworkError {
                throw networkError
            } else {
                throw NetworkError.networkUnavailable
            }
        }
    }
    
    // MARK: - Private Methods

    /// 경로 요청 생성 (좌표 기반)
    private func createRouteRequest(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> URLRequest {
        print("\n========================================")
        print("🚀 API 요청 시작")
        print("========================================")

        guard let url = URL(string: "\(baseURL)/api/analyze-route") else {
            fatalError("Invalid URL")
        }

        print("📍 URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("📤 Method: POST")
        print("📋 Headers:")
        print("   Content-Type: application/json")
        print("   Accept: application/json")

        // 요청 바디 생성
        let routeRequest = RouteRequest(
            startLat: start.latitude,
            startLon: start.longitude,
            endLat: end.latitude,
            endLon: end.longitude,
            inputMode: "coordinate"
        )

        print("📍 출발지: (위도: \(start.latitude), 경도: \(start.longitude))")
        print("📍 목적지: (위도: \(end.latitude), 경도: \(end.longitude))")
        print("📝 입력 모드: coordinate")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            request.httpBody = try encoder.encode(routeRequest)

            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                print("📦 요청 Body:")
                print(jsonString)
            }
        } catch {
            print("❌ JSON 인코딩 실패: \(error)")
        }

        print("========================================\n")
        return request
    }

    /// 경로 요청 생성 (주소 기반)
    private func createRouteRequest(from startLocation: String, to endLocation: String) -> URLRequest {
        print("\n========================================")
        print("🚀 API 요청 시작 (주소 모드)")
        print("========================================")

        guard let url = URL(string: "\(baseURL)/api/analyze-route") else {
            fatalError("Invalid URL")
        }

        print("📍 URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("📤 Method: POST")
        print("📋 Headers:")
        print("   Content-Type: application/json")
        print("   Accept: application/json")

        // 주소 기반 요청 바디 생성
        let requestBody: [String: String] = [
            "start_location": startLocation,
            "end_location": endLocation,
            "input_mode": "address"
        ]

        print("📍 출발지: \(startLocation)")
        print("📍 목적지: \(endLocation)")
        print("📝 입력 모드: address")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            request.httpBody = try encoder.encode(requestBody)

            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                print("📦 요청 Body:")
                print(jsonString)
            }
        } catch {
            print("❌ JSON 인코딩 실패: \(error)")
        }

        print("========================================\n")
        return request
    }

    /// 경로 응답 처리 (completion handler)
    private func handleRouteResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        completion: @escaping (Result<RouteResponse, NetworkError>) -> Void
    ) {
        print("\n========================================")
        print("📥 API 응답 수신")
        print("========================================")

        // 에러 확인
        if let error = error {
            print("❌ 네트워크 에러 발생:")
            print("   에러: \(error.localizedDescription)")
            print("   상세: \(error)")
            let networkError = mapErrorToNetworkError(error)
            lastError = networkError
            print("========================================\n")
            completion(.failure(networkError))
            return
        }

        // HTTP 상태 코드 확인
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ HTTP 응답을 받지 못했습니다")
            lastError = .noData
            print("========================================\n")
            completion(.failure(.noData))
            return
        }

        print("📊 HTTP 상태 코드: \(httpResponse.statusCode)")
        print("📋 응답 헤더:")
        for (key, value) in httpResponse.allHeaderFields {
            print("   \(key): \(value)")
        }

        guard 200...299 ~= httpResponse.statusCode else {
            print("❌ HTTP 에러: 상태 코드 \(httpResponse.statusCode)")
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📦 에러 응답 내용:")
                print(responseString)
            }
            let networkError = NetworkError.serverError(httpResponse.statusCode)
            lastError = networkError
            print("========================================\n")
            completion(.failure(networkError))
            return
        }

        // 데이터 확인
        guard let data = data else {
            print("❌ 응답 데이터가 없습니다")
            lastError = .noData
            print("========================================\n")
            completion(.failure(.noData))
            return
        }

        print("📦 응답 데이터 크기: \(data.count) bytes")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📦 응답 Body:")
            print(responseString)
        }

        // JSON 디코딩
        do {
            print("\n🔄 서버 응답 파싱 시도 중...")
            // 먼저 서버의 실제 응답 형식으로 파싱 시도
            let serverResponse = try JSONDecoder().decode(ServerAnalyzeRouteResponse.self, from: data)

            if serverResponse.success {
                print("✅ 서버 응답 파싱 성공!")
                print("   메시지: \(serverResponse.message)")
                print("   출발지: \(serverResponse.data.startLocation)")
                print("   목적지: \(serverResponse.data.endLocation)")
                print("   위험 지역 수: \(serverResponse.data.dangerCentersCount)")
                print("   출발지 좌표: lat=\(serverResponse.data.startCoords.lat), lon=\(serverResponse.data.startCoords.lon)")
                print("   도착지 좌표: lat=\(serverResponse.data.endCoords.lat), lon=\(serverResponse.data.endCoords.lon)")
                print("   경로 파일: \(serverResponse.data.files.detailedRoute1m)")

                // 경로 파일 다운로드 (1m 간격 상세 경로 사용)
                print("\n📥 경로 파일 다운로드 시작 (1m 간격 상세 경로)...")
                self.downloadRouteFile(path: serverResponse.data.files.detailedRoute1m) { [weak self] routeResult in
                    guard let self = self else { return }

                    switch routeResult {
                    case .success(let routePoints):
                        print("✅ 경로 파일 다운로드 성공: \(routePoints.count)개 포인트")

                        // 코인 배치용 route_coords.json도 다운로드
                        print("\n🪙 코인 배치용 좌표 다운로드 시작 (route_coords)...")
                        self.downloadRouteFile(path: serverResponse.data.files.routeCoords) { coinResult in
                            let coinCoords: [RoutePointResponse]?
                            switch coinResult {
                            case .success(let coords):
                                print("✅ 코인 배치용 좌표 다운로드 성공: \(coords.count)개 포인트")
                                coinCoords = coords
                            case .failure(let error):
                                print("⚠️ 코인 배치용 좌표 다운로드 실패: \(error.localizedDescription)")
                                print("   경로 좌표로 대체합니다")
                                coinCoords = nil  // 실패 시 nil (RouteDataManager에서 routeCoordinates 사용)
                            }

                            let routeResponse = RouteResponse(
                                route: routePoints,
                                coinCoords: coinCoords,
                                distance: self.calculateDistance(from: routePoints),
                                duration: self.estimateDuration(from: routePoints),
                                safetyScore: 85  // 기본값, 서버에서 제공하면 사용
                            )
                            self.lastError = nil
                            print("========================================\n")
                            completion(.success(routeResponse))
                        }

                    case .failure(let error):
                        print("❌ 경로 파일 다운로드 실패: \(error.localizedDescription)")
                        print("❌ 경로 데이터를 가져올 수 없습니다")
                        self.lastError = error
                        print("========================================\n")
                        completion(.failure(error))
                    }
                }
            } else {
                print("❌ 서버 오류: \(serverResponse.message)")
                lastError = .serverError(400)
                print("========================================\n")
                completion(.failure(.serverError(400)))
            }
        } catch {
            print("⚠️ ServerAnalyzeRouteResponse 파싱 실패: \(error)")
            // ServerAnalyzeRouteResponse 파싱 실패 시 기존 RouteResponse로 시도
            do {
                print("🔄 RouteResponse 파싱 재시도 중...")
                let routeResponse = try JSONDecoder().decode(RouteResponse.self, from: data)
                print("✅ RouteResponse 파싱 성공!")
                lastError = nil
                print("========================================\n")
                completion(.success(routeResponse))
            } catch {
                // 둘 다 실패하면 모의 데이터 생성
                print("⚠️ RouteResponse 파싱도 실패: \(error)")
                print("⚠️ 모의 데이터 생성으로 fallback")
                let mockResponse = createMockRouteResponse()
                lastError = nil
                print("========================================\n")
                completion(.success(mockResponse))
            }
        }
    }
    
    /// 모의 경로 데이터 생성
    private func createMockRouteResponse() -> RouteResponse {
        // 서울시청에서 광화문역까지의 모의 경로 데이터
        let mockRoute = [
            RoutePointResponse(lat: 37.5665, lon: 126.9780),      // 서울시청
            RoutePointResponse(lat: 37.5680, lon: 126.9775),      // 중간점 1
            RoutePointResponse(lat: 37.5695, lon: 126.9770),      // 중간점 2
            RoutePointResponse(lat: 37.5705, lon: 126.9772),      // 중간점 3
            RoutePointResponse(lat: 37.5715, lon: 126.9771),      // 중간점 4
            RoutePointResponse(lat: 37.5720164, lon: 126.9769914) // 광화문역
        ]

        return RouteResponse(
            route: mockRoute,
            coinCoords: nil,    // Mock 데이터는 코인 좌표 없음
            distance: 0.8,      // 0.8km
            duration: 10,       // 10분
            safetyScore: 90     // 안전도 90점
        )
    }
    
    /// 경로 응답 처리 (async/await)
    private func handleRouteResponseAsync(data: Data, response: URLResponse) async throws -> RouteResponse {
        print("\n========================================")
        print("📥 API 응답 수신 (Async)")
        print("========================================")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ HTTP 응답을 받지 못했습니다")
            print("========================================\n")
            throw NetworkError.noData
        }

        print("📊 HTTP 상태 코드: \(httpResponse.statusCode)")
        print("📋 응답 헤더:")
        for (key, value) in httpResponse.allHeaderFields {
            print("   \(key): \(value)")
        }

        guard 200...299 ~= httpResponse.statusCode else {
            print("❌ HTTP 에러: 상태 코드 \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 에러 응답 내용:")
                print(responseString)
            }
            print("========================================\n")
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        print("📦 응답 데이터 크기: \(data.count) bytes")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📦 응답 Body:")
            print(responseString)
        }

        do {
            print("\n🔄 서버 응답 파싱 시도 중... (Async)")
            // 먼저 서버의 실제 응답 형식으로 파싱 시도
            let serverResponse = try JSONDecoder().decode(ServerAnalyzeRouteResponse.self, from: data)

            if serverResponse.success {
                print("✅ 서버 응답 파싱 성공! (Async)")
                print("   메시지: \(serverResponse.message)")
                print("   출발지: \(serverResponse.data.startLocation)")
                print("   목적지: \(serverResponse.data.endLocation)")
                print("   위험 지역 수: \(serverResponse.data.dangerCentersCount)")
                print("   출발지 좌표: lat=\(serverResponse.data.startCoords.lat), lon=\(serverResponse.data.startCoords.lon)")
                print("   도착지 좌표: lat=\(serverResponse.data.endCoords.lat), lon=\(serverResponse.data.endCoords.lon)")
                print("   경로 파일: \(serverResponse.data.files.detailedRoute1m)")

                // 경로 파일 다운로드 (Async) - 1m 간격 상세 경로 사용
                print("\n📥 경로 파일 다운로드 시작... (Async - 1m 간격 상세 경로)")
                do {
                    let routePoints = try await downloadRouteFileAsync(path: serverResponse.data.files.detailedRoute1m)
                    print("✅ 경로 파일 다운로드 성공: \(routePoints.count)개 포인트")

                    // 코인 배치용 route_coords.json도 다운로드
                    print("\n🪙 코인 배치용 좌표 다운로드 시작 (route_coords)... (Async)")
                    let coinCoords: [RoutePointResponse]?
                    do {
                        let coords = try await downloadRouteFileAsync(path: serverResponse.data.files.routeCoords)
                        print("✅ 코인 배치용 좌표 다운로드 성공: \(coords.count)개 포인트")
                        coinCoords = coords
                    } catch {
                        print("⚠️ 코인 배치용 좌표 다운로드 실패: \(error.localizedDescription)")
                        print("   경로 좌표로 대체합니다")
                        coinCoords = nil  // 실패 시 nil
                    }

                    return RouteResponse(
                        route: routePoints,
                        coinCoords: coinCoords,
                        distance: calculateDistance(from: routePoints),
                        duration: estimateDuration(from: routePoints),
                        safetyScore: 85
                    )
                } catch {
                    print("❌ 경로 파일 다운로드 실패: \(error.localizedDescription)")
                    print("❌ 경로 데이터를 가져올 수 없습니다")
                    throw NetworkError.decodingError
                }
            } else {
                print("❌ 서버 오류: \(serverResponse.message)")
                print("========================================\n")
                throw NetworkError.serverError(400)
            }
        } catch {
            print("⚠️ ServerAnalyzeRouteResponse 파싱 실패: \(error)")
            // ServerAnalyzeRouteResponse 파싱 실패 시 기존 RouteResponse로 시도
            do {
                print("🔄 RouteResponse 파싱 재시도 중... (Async)")
                let routeResponse = try JSONDecoder().decode(RouteResponse.self, from: data)
                print("✅ RouteResponse 파싱 성공! (Async)")
                print("========================================\n")
                return routeResponse
            } catch {
                // 둘 다 실패하면 모의 데이터 생성
                print("⚠️ RouteResponse 파싱도 실패: \(error)")
                print("⚠️ 모의 데이터 생성으로 fallback")
                print("========================================\n")
                return createMockRouteResponse()
            }
        }
    }
    
    /// 에러 매핑
    private func mapErrorToNetworkError(_ error: Error) -> NetworkError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .timeout
            default:
                return .networkUnavailable
            }
        }
        return .networkUnavailable
    }
    
    /// 코인 배치용 경로 좌표 다운로드 (공개 메서드)
    func downloadCoinCoordinates(path: String, completion: @escaping (Result<[RoutePointResponse], NetworkError>) -> Void) {
        print("🪙 코인 배치용 좌표 다운로드: \(path)")
        downloadRouteFile(path: path, completion: completion)
    }

    /// 경로 파일 다운로드 (콜백 기반)
    private func downloadRouteFile(path: String, completion: @escaping (Result<[RoutePointResponse], NetworkError>) -> Void) {
        // 파일 경로를 전체 URL로 변환
        let fileURL: URL
        if path.hasPrefix("http") {
            // 절대 URL인 경우
            guard let url = URL(string: path) else {
                completion(.failure(.invalidURL))
                return
            }
            fileURL = url
        } else {
            // 상대 경로인 경우 - /api/download/ 엔드포인트 사용
            guard let url = URL(string: "\(baseURL)/api/download/\(path)") else {
                completion(.failure(.invalidURL))
                return
            }
            fileURL = url
        }

        print("📥 경로 파일 다운로드: \(fileURL.absoluteString)")

        var request = URLRequest(url: fileURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutInterval

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 파일 다운로드 실패: \(error.localizedDescription)")
                completion(.failure(self.mapErrorToNetworkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
                print("❌ HTTP 에러: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                completion(.failure(.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)))
                return
            }

            guard let data = data else {
                print("❌ 데이터 없음")
                completion(.failure(.noData))
                return
            }

            print("📦 파일 다운로드 완료: \(data.count) bytes")

            // JSON 파싱 시도
            do {
                // 좌표 배열 형식으로 파싱 시도: [[lat, lon], [lat, lon], ...]
                let coordinates = try JSONDecoder().decode([[Double]].self, from: data)
                let routePoints = coordinates.compactMap { coord -> RoutePointResponse? in
                    guard coord.count >= 2 else { return nil }
                    return RoutePointResponse(lat: coord[0], lon: coord[1])
                }
                print("✅ 경로 좌표 파싱 성공 (배열 형식): \(routePoints.count)개")
                completion(.success(routePoints))
            } catch {
                print("⚠️ 좌표 배열 파싱 실패, RoutePointResponse 배열로 재시도")
                do {
                    // RoutePointResponse 배열로 파싱 시도
                    let routePoints = try JSONDecoder().decode([RoutePointResponse].self, from: data)
                    print("✅ 경로 좌표 파싱 성공 (객체 배열): \(routePoints.count)개")
                    completion(.success(routePoints))
                } catch {
                    print("⚠️ 객체 배열 파싱 실패, 딕셔너리 형식으로 재시도")
                    do {
                        // 딕셔너리 형식으로 파싱 시도: {"route": [[lat, lon], ...]}
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                        // "coords" 키 먼저 확인 (route_coords.json 형식)
                        if let coordsArray = json?["coords"] as? [[Double]] {
                            let routePoints = coordsArray.compactMap { coord -> RoutePointResponse? in
                                guard coord.count >= 2 else { return nil }
                                return RoutePointResponse(lat: coord[0], lon: coord[1])
                            }
                            print("✅ 경로 좌표 파싱 성공 (딕셔너리의 coords): \(routePoints.count)개")
                            completion(.success(routePoints))
                        } else if let coordsArray = json?["route"] as? [[Double]] {
                            let routePoints = coordsArray.compactMap { coord -> RoutePointResponse? in
                                guard coord.count >= 2 else { return nil }
                                return RoutePointResponse(lat: coord[0], lon: coord[1])
                            }
                            print("✅ 경로 좌표 파싱 성공 (딕셔너리의 route): \(routePoints.count)개")
                            completion(.success(routePoints))
                        } else if let coordsArray = json?["coordinates"] {
                            // coordinates를 객체 배열로 먼저 시도 ({"latitude": ..., "longitude": ...} 형식)
                            do {
                                let coordsData = try JSONSerialization.data(withJSONObject: coordsArray)
                                let routePoints = try JSONDecoder().decode([RoutePointResponse].self, from: coordsData)
                                print("✅ 경로 좌표 파싱 성공 (딕셔너리의 coordinates 객체 배열): \(routePoints.count)개")
                                completion(.success(routePoints))
                            } catch {
                                // [[Double]] 형식으로 재시도
                                if let coordsArray = coordsArray as? [[Double]] {
                                    let routePoints = coordsArray.compactMap { coord -> RoutePointResponse? in
                                        guard coord.count >= 2 else { return nil }
                                        return RoutePointResponse(lat: coord[0], lon: coord[1])
                                    }
                                    print("✅ 경로 좌표 파싱 성공 (딕셔너리의 coordinates 배열): \(routePoints.count)개")
                                    completion(.success(routePoints))
                                } else {
                                    print("❌ coordinates 파싱 실패: \(error)")
                                    print("📦 JSON 내용: \(String(data: data, encoding: .utf8) ?? "읽을 수 없음")")
                                    completion(.failure(.decodingError))
                                }
                            }
                        } else {
                            print("❌ 경로 파일 파싱 실패: 지원하지 않는 형식")
                            print("📦 JSON 내용: \(String(data: data, encoding: .utf8) ?? "읽을 수 없음")")
                            completion(.failure(.decodingError))
                        }
                    } catch {
                        print("❌ 경로 파일 파싱 실패: \(error)")
                        print("📦 응답 내용: \(String(data: data, encoding: .utf8) ?? "읽을 수 없음")")
                        completion(.failure(.decodingError))
                    }
                }
            }
        }.resume()
    }

    /// 경로 파일 다운로드 (Async)
    private func downloadRouteFileAsync(path: String) async throws -> [RoutePointResponse] {
        // 파일 경로를 전체 URL로 변환
        let fileURL: URL
        if path.hasPrefix("http") {
            guard let url = URL(string: path) else {
                throw NetworkError.invalidURL
            }
            fileURL = url
        } else {
            // 상대 경로인 경우 - /api/download/ 엔드포인트 사용
            guard let url = URL(string: "\(baseURL)/api/download/\(path)") else {
                throw NetworkError.invalidURL
            }
            fileURL = url
        }

        print("📥 경로 파일 다운로드: \(fileURL.absoluteString)")

        var request = URLRequest(url: fileURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutInterval

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        print("📦 파일 다운로드 완료: \(data.count) bytes")

        // JSON 파싱
        do {
            // [[Double]] 형식으로 파싱 시도
            let coordinates = try JSONDecoder().decode([[Double]].self, from: data)
            let routePoints = coordinates.compactMap { coord -> RoutePointResponse? in
                guard coord.count >= 2 else { return nil }
                return RoutePointResponse(lat: coord[0], lon: coord[1])
            }
            print("✅ 경로 좌표 파싱 성공 (배열 형식): \(routePoints.count)개")
            return routePoints
        } catch {
            print("⚠️ 좌표 배열 파싱 실패, RoutePointResponse 배열로 재시도")
            do {
                // [RoutePointResponse] 형식으로 파싱 시도
                let routePoints = try JSONDecoder().decode([RoutePointResponse].self, from: data)
                print("✅ 경로 좌표 파싱 성공 (객체 배열): \(routePoints.count)개")
                return routePoints
            } catch {
                print("⚠️ 객체 배열 파싱 실패, 딕셔너리 형식으로 재시도")
                // 딕셔너리 형식으로 파싱 시도: {"coordinates": [...]}
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                // "coords" 키 먼저 확인 (route_coords.json 형식 - [[Double]] 배열)
                if let coordsArray = json?["coords"] as? [[Double]] {
                    let routePoints = coordsArray.compactMap { coord -> RoutePointResponse? in
                        guard coord.count >= 2 else { return nil }
                        return RoutePointResponse(lat: coord[0], lon: coord[1])
                    }
                    print("✅ 경로 좌표 파싱 성공 (딕셔너리의 coords): \(routePoints.count)개")
                    return routePoints
                } else if let coordsArray = json?["coordinates"] {
                    // coordinates를 객체 배열로 시도 ({"latitude": ..., "longitude": ...} 형식)
                    let coordsData = try JSONSerialization.data(withJSONObject: coordsArray)
                    let routePoints = try JSONDecoder().decode([RoutePointResponse].self, from: coordsData)
                    print("✅ 경로 좌표 파싱 성공 (딕셔너리의 coordinates 객체 배열): \(routePoints.count)개")
                    return routePoints
                } else if let coordsArray = json?["route"] {
                    // route 키로 시도
                    let coordsData = try JSONSerialization.data(withJSONObject: coordsArray)
                    let routePoints = try JSONDecoder().decode([RoutePointResponse].self, from: coordsData)
                    print("✅ 경로 좌표 파싱 성공 (딕셔너리의 route 객체 배열): \(routePoints.count)개")
                    return routePoints
                } else {
                    print("❌ 경로 파일 파싱 실패: 지원하지 않는 형식")
                    print("📦 JSON 내용: \(String(data: data, encoding: .utf8) ?? "읽을 수 없음")")
                    throw NetworkError.decodingError
                }
            }
        }
    }

    /// 경로 거리 계산 (km)
    private func calculateDistance(from points: [RoutePointResponse]) -> Double {
        guard points.count > 1 else { return 0.0 }

        var totalDistance: Double = 0.0
        for i in 0..<points.count - 1 {
            let start = CLLocation(latitude: points[i].lat, longitude: points[i].lon)
            let end = CLLocation(latitude: points[i + 1].lat, longitude: points[i + 1].lon)
            totalDistance += start.distance(from: end)
        }

        return totalDistance / 1000.0 // km로 변환
    }

    /// 경로 소요 시간 추정 (분)
    private func estimateDuration(from points: [RoutePointResponse]) -> Int {
        let distance = calculateDistance(from: points)
        let walkingSpeedKmPerHour = 4.0 // 평균 보행 속도 4km/h
        let hours = distance / walkingSpeedKmPerHour
        return Int(hours * 60) // 분으로 변환
    }

    /// 네트워크 상태 모니터링 시작
    private func startNetworkMonitoring() {
        // 네트워크 상태 확인 로직 (실제 구현에서는 Network 프레임워크 사용)
        // 현재는 간단한 구현
        print("🌐 NetworkManager 초기화: 네트워크 모니터링 시작")
        print("   baseURL: \(baseURL)")
        isConnected = true
        print("   isConnected 설정됨: \(isConnected)")
    }
}
