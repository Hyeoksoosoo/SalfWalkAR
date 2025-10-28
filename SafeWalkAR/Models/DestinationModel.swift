import Foundation
import CoreLocation

// MARK: - 목적지 모델
struct Destination: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    
    enum CodingKeys: String, CodingKey {
        case name, address
        case latitude, longitude
    }
    
    init(name: String, address: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.address = address
        self.coordinate = coordinate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
    
    // Equatable 구현
    static func == (lhs: Destination, rhs: Destination) -> Bool {
        return lhs.name == rhs.name &&
               lhs.address == rhs.address &&
               lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

// MARK: - 경로 안내 상태
enum NavigationState {
    case idle
    case searching
    case navigating
    case arrived
    case error(String)
}

// MARK: - 화면 분할 모드
enum SplitViewMode {
    case arCamera    // AR 카메라 + 2D 지도
    case arVirtual   // AR 가상 지도 + 2D 지도
    case kakaoMap    // AR 카메라 + 카카오맵
    case fullAR      // 전체 AR 화면
    case fullMap     // 전체 지도 화면
}

// MARK: - 목적지 매니저
class DestinationManager: ObservableObject {
    @Published var currentDestination: Destination?
    @Published var destinationName: String = "" // 사용자가 입력한 목적지 이름
    @Published var navigationState: NavigationState = .idle
    @Published var splitViewMode: SplitViewMode = .kakaoMap
    @Published var isNavigationActive = false
    @Published var collectedCoins: Int = 0
    @Published var totalCoins: Int = 10
    
    // 미리 정의된 목적지들 (서울 및 수도권 주요 지점)
    let predefinedDestinations: [Destination] = [
        Destination(
            name: "광화문역",
            address: "서울특별시 종로구 세종대로 지하 172",
            coordinate: CLLocationCoordinate2D(latitude: 37.5720164, longitude: 126.9769914)
        ),
        Destination(
            name: "종각역",
            address: "서울특별시 종로구 종로 지하 19",
            coordinate: CLLocationCoordinate2D(latitude: 37.5695292, longitude: 126.9833361)
        ),
        Destination(
            name: "서울시청",
            address: "서울특별시 중구 세종대로 110",
            coordinate: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        ),
        Destination(
            name: "명동역",
            address: "서울특별시 중구 명동길 지하 14",
            coordinate: CLLocationCoordinate2D(latitude: 37.5606893, longitude: 126.9858097)
        ),
        Destination(
            name: "서울역",
            address: "서울특별시 용산구 한강대로 405",
            coordinate: CLLocationCoordinate2D(latitude: 37.5546788, longitude: 126.9707299)
        ),
        Destination(
            name: "일산역",
            address: "경기도 고양시 일산동구 중앙로 1275",
            coordinate: CLLocationCoordinate2D(latitude: 37.6567, longitude: 126.7707)
        ),
        Destination(
            name: "풍산역",
            address: "경기도 고양시 일산동구 장백로 156",
            coordinate: CLLocationCoordinate2D(latitude: 37.6487, longitude: 126.7529)
        ),
        Destination(
            name: "대화역",
            address: "경기도 고양시 일산서구 대화동",
            coordinate: CLLocationCoordinate2D(latitude: 37.6581, longitude: 126.7475)
        ),
        Destination(
            name: "주엽역",
            address: "경기도 고양시 일산서구 주엽동",
            coordinate: CLLocationCoordinate2D(latitude: 37.6712, longitude: 126.7652)
        )
    ]
    
    func setDestination(_ destination: Destination) {
        currentDestination = destination
        navigationState = .searching
    }
    
    func startNavigation() {
        guard currentDestination != nil else { return }
        navigationState = .navigating
        isNavigationActive = true
    }
    
    func stopNavigation() {
        navigationState = .idle
        isNavigationActive = false
    }
    
    func setSplitViewMode(_ mode: SplitViewMode) {
        splitViewMode = mode
    }
}
