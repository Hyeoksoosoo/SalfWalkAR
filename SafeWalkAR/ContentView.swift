import SwiftUI
import CoreLocation

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var coinManager = CoinManager()
    @StateObject private var destinationManager = DestinationManager()
    @StateObject private var routeDataManager = RouteDataManager()
    @StateObject private var pathDataManager: PathDataManager
    @State private var showingPermissionAlert = false
    @State private var currentView: AppView = .go
    @State private var selectedTab: BottomTab = .go

    init() {
        let routeDataManager = RouteDataManager()
        _routeDataManager = StateObject(wrappedValue: routeDataManager)
        _pathDataManager = StateObject(wrappedValue: PathDataManager(routeDataManager: routeDataManager))
    }

    var body: some View {
        NavigationView {
            ZStack {
                // 깔끔한 흰색 배경
                Color.white
                    .ignoresSafeArea()

                // 메인 콘텐츠
                switch currentView {
                case .home:
                    HomeScreenView(selectedTab: $selectedTab)
                case .go:
                    GoView(
                        locationManager: locationManager,
                        coinManager: coinManager,
                        pathDataManager: pathDataManager,
                        destinationManager: destinationManager,
                        routeDataManager: routeDataManager,
                        currentView: $currentView,
                        selectedTab: $selectedTab
                    )
                case .profile:
                    MeView(selectedTab: $selectedTab)
                case .splitNavigation:
                    SplitNavigationView(destinationManager: destinationManager, routeDataManager: routeDataManager, pathDataManager: pathDataManager, currentView: $currentView)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // 앱 시작 시 RouteData.json 미리 로드
            print("🚀 ContentView onAppear - RouteData.json 로드 시작")
            routeDataManager.loadRouteData()
        }
        .alert("위치 권한이 필요합니다", isPresented: $showingPermissionAlert) {
            Button("설정으로 이동") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("다시 시도") {
                locationManager.requestLocationPermission()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("AR 길찾기와 안전한 경로 안내를 위해 현재 위치가 필요합니다.\n\n설정에서 위치 권한을 허용해주세요.")
        }
        .onChange(of: selectedTab) { _, newTab in
            // 탭 변경 시 currentView 업데이트
            switch newTab {
            case .home:
                currentView = .home
            case .go:
                currentView = .go
            case .profile:
                currentView = .profile
            }
        }
    }
}

enum AppView {
    case home
    case go
    case profile
    case splitNavigation
}

enum BottomTab {
    case home
    case go
    case profile
}

struct GoView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var coinManager: CoinManager
    @ObservedObject var pathDataManager: PathDataManager
    @ObservedObject var destinationManager: DestinationManager
    @ObservedObject var routeDataManager: RouteDataManager
    @Binding var currentView: AppView
    @Binding var selectedTab: BottomTab
    
    @State private var showingDestinationPicker = false
    @State private var selectedDestination: Destination?
    @State private var showingLocationInputForm = false
    
    // 출발지/목적지 입력 상태
    @State private var departureText: String = ""
    @State private var destinationText: String = ""
    
    // UX 개선을 위한 상태 관리
    @State private var isRouteLoading: Bool = false
    @State private var isRouteReady: Bool = false
    @State private var showRoutePreview: Bool = false
    @State private var loadingProgress: Double = 0.0
    @State private var loadingMessage: String = "안전이가 등교 준비를 하고 있습니다."
    @State private var isExistingRoute: Bool = false
    
    // 에러 처리 상태
    @State private var showErrorAlert: Bool = false
    @State private var showErrorToast: Bool = false
    @State private var currentError: NetworkError?
    @State private var errorMessage: String = ""

    // 날짜 및 시간 상태
    @State private var currentDate: String = ""
    @State private var currentTime: String = ""

    // 타이머
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 전체 배경 그라데이션 (Home 페이지와 동일)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.37, green: 0.87, blue: 0.90), // #5FDDE5 (상단 - Primary)
                        Color(red: 0.32, green: 0.79, blue: 0.82), // 중간 상단
                        Color(red: 0.85, green: 0.95, blue: 0.96), // 중간 하단 (밝은 톤)
                        Color.white                                  // 하단 (순백)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 상단 헤더 영역 (20%) - Primary Color
                    VStack(alignment: .leading, spacing: 0) {
                        // 상단: SafeWalk AR 타이틀 + 프로필 아이콘
                        HStack {
                            Text("SafeWalkAR")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Spacer()

                            // 프로필 아이콘
                            Button(action: {
                                print("프로필 버튼 클릭")
                            }) {
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 26))
                                            .foregroundColor(.white)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Spacer()

                        // 중앙: 시간 및 날짜 (가운데 정렬)
                        VStack(alignment: .center, spacing: 4) {
                            Text(currentTime)
                                .font(.system(size: 32, weight: .heavy, design: .default))
                                .foregroundColor(.white)

                            Text(currentDate)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(height: geometry.size.height * 0.2)

                    // 바디 영역 (72%)
                    ZStack {
                        // 투명 배경 (전체 그라데이션 표시)
                        Color.clear

                        VStack {
                            Spacer()
                                .frame(maxHeight: 40)

                            // 바디 정중앙에 콘텐츠 배치
                            Group {
                                // 출발지/목적지 입력 폼
                                if !isRouteLoading && !showRoutePreview {
                                    LocationInputForm(
                                        departureText: $departureText,
                                        destinationText: $destinationText,
                                        onSearch: {
                                            handleSearch()
                                        },
                                        onUseCurrentLocation: {
                                            handleUseCurrentLocation()
                                        }
                                    )
                                    .transition(.opacity)
                                }

                                // 경로 로딩 상태 표시
                                if isRouteLoading {
                                    RouteLoadingView(
                                        progress: loadingProgress,
                                        message: loadingMessage
                                    )
                                    .transition(.opacity)
                                }

                                // 경로 미리보기
                                if showRoutePreview && isRouteReady {
                                    RoutePreviewCard(
                                        destinationManager: destinationManager,
                                        locationManager: locationManager,
                                        routeDataManager: routeDataManager,
                                        isExistingRoute: isExistingRoute,
                                        onStartNavigation: {
                                            destinationManager.startNavigation()
                                            currentView = .splitNavigation
                                        },
                                        onSearchAgain: {
                                            startNewRouteInput()
                                        },
                                        onRefreshRoute: {
                                            refreshExistingRoute()
                                        }
                                    )
                                    .transition(.opacity)
                                }
                            }
                            .frame(height: 385)
                            .padding(.horizontal, 24)

                            Spacer()
                        }
                    }
                    .frame(height: geometry.size.height * 0.72)

                    // 하단 메뉴바 (8%)
                    BottomMenuBar(selectedTab: $selectedTab)
                        .frame(height: geometry.size.height * 0.08)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .animation(.easeInOut(duration: 0.3), value: isRouteLoading)
        .animation(.easeInOut(duration: 0.3), value: showRoutePreview)
        .preferredColorScheme(.dark)
        .overlay(
            // 에러 알림 오버레이
            Group {
                if showErrorAlert, let error = currentError {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                dismissErrorAlert()
                            }
                        
                        ErrorAlertView(
                            error: error,
                            onRetry: {
                                retryLastAction()
                            },
                            onDismiss: {
                                dismissErrorAlert()
                            }
                        )
                        .padding(.horizontal, 40)
                    }
                }
            }
        )
        .overlay(
            // 에러 토스트 오버레이
            VStack {
                if showErrorToast {
                    ErrorToastView(
                        message: errorMessage,
                        onDismiss: {
                            dismissErrorToast()
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                }
                Spacer()
            }
        )
        .onAppear {
            setupInitialData()
            updateDateTime()
        }
        .onReceive(timer) { _ in
            updateDateTime()
        }
        .onChange(of: locationManager.status) { _, newStatus in
            // 위치 상태 변경 시 자동 업데이트 삭제
            // 사용자가 "현재 위치 사용" 버튼을 명시적으로 눌러야만 업데이트
        }
        .sheet(isPresented: $showingDestinationPicker) {
            DestinationPickerView(
                destinations: destinationManager.predefinedDestinations,
                selectedDestination: $selectedDestination
            )
        }
    }
    
    private func setupInitialData() {
        // UI 업데이트 완료 후 상태 변경을 위해 비동기로 처리
        DispatchQueue.main.async {
            // 샘플 경로 데이터 로드
            pathDataManager.loadSamplePath()
            
            // 위치 권한 요청 및 위치 서비스 시작
            locationManager.requestLocationPermission()
            
            // 앱 실행 시 자동으로 출발지 설정 및 입력 폼 표시
            setupInitialUserFlow()
        }
    }
    
    private func setupInitialUserFlow() {
        // 출발지와 목적지는 빈 상태로 시작 (자동 입력 삭제)
        departureText = ""
        destinationText = ""

        // 기본 목적지 설정
        if let defaultDestination = destinationManager.predefinedDestinations.first {
            destinationManager.setDestination(defaultDestination)
        }

        // 기존 경로 데이터가 있으면 자동으로 경로 미리보기 표시
        if routeDataManager.isDataLoaded && !routeDataManager.routeCoordinates.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showRoutePreview = true
                    isRouteReady = true
                    isExistingRoute = true // 기존 경로임을 표시
                }
            }
        }
        // 입력 폼은 항상 표시됨 (로딩이나 미리보기가 없을 때)
    }
    
    // MARK: - 출발지/목적지 입력 폼 핸들러
    private func handleSearch() {
        print("🔍 경로 검색 요청:")
        print("   출발지: \(departureText)")
        print("   목적지: \(destinationText)")
        
        // 입력값이 있으면 경로 로딩 시작
        if !destinationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 기존 경로 미리보기가 있으면 먼저 숨기기
            if showRoutePreview {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRoutePreview = false
                    isRouteReady = false
                }
            }
            
            // 새로운 경로 로딩 시작
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                startRouteLoading()
            }
        }
    }
    
    private func startRouteLoading() {
        // 로딩 상태 시작
        withAnimation(.easeInOut(duration: 0.3)) {
            isRouteLoading = true
            loadingProgress = 0.0
            loadingMessage = "안전이가 등교 준비를 하고 있습니다."
        }
        
        // 실제 API 호출
        fetchRouteFromAPI()
    }
    
    // MARK: - API 연동 메서드들

    /// API를 통한 경로 데이터 요청 (주소 기반)
    private func fetchRouteFromAPI() {
        // 입력값 검증
        let startLocation = departureText.trimmingCharacters(in: .whitespacesAndNewlines)
        let endLocation = destinationText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !startLocation.isEmpty && !endLocation.isEmpty else {
            handleAPIError("출발지와 목적지를 입력해주세요.")
            return
        }

        // "현 내 위치 (자동)"인 경우 도로명 주소로 변환 후 API 호출
        if startLocation == "현 내 위치 (자동)" || startLocation == "위치 확인 중..." {
            print("🌐 현재 위치를 도로명 주소로 변환 중...")

            // 진행률 업데이트
            withAnimation(.linear(duration: 0.5)) {
                loadingProgress = 0.2
                loadingMessage = "안전이가 등교 준비를 하고 있습니다."
            }

            // 현재 위치를 도로명 주소로 변환
            locationManager.getCurrentLocationAddress { address in
                DispatchQueue.main.async {
                    if let address = address {
                        print("✅ 현재 위치 주소 변환 성공: \(address)")
                        print("📍 목적지 텍스트: \(endLocation)")

                        // 주소 모드로 API 요청
                        self.sendRouteRequest(from: address, to: endLocation)
                    } else {
                        print("❌ 현재 위치 주소 변환 실패")
                        self.handleAPIError("현재 위치를 주소로 변환할 수 없습니다.")
                    }
                }
            }
        } else {
            // 일반 텍스트 입력인 경우 바로 API 요청
            sendRouteRequest(from: startLocation, to: endLocation)
        }
    }

    /// 혼합 모드 API 요청 (출발지: 좌표, 목적지: 텍스트)
    private func sendMixedModeRequest(startCoordinate: CLLocationCoordinate2D, endLocation: String) {
        // 목적지를 predefinedDestinations에서 찾기
        let matchedDestination = destinationManager.predefinedDestinations.first { destination in
            destination.name.contains(endLocation) || endLocation.contains(destination.name)
        }

        if let destination = matchedDestination {
            // 목적지 좌표를 찾았으면 좌표 모드로 API 호출
            print("✅ 목적지 매칭: \(destination.name) (\(destination.coordinate.latitude), \(destination.coordinate.longitude))")

            routeDataManager.fetchRouteFromAPI(from: startCoordinate, to: destination.coordinate) { success in
                DispatchQueue.main.async {
                    if success {
                        self.handleAPISuccess()
                    } else {
                        if let error = self.routeDataManager.lastError {
                            self.handleNetworkError(error)
                        } else {
                            self.handleAPIError("경로를 찾을 수 없습니다. 다시 시도해주세요.")
                        }
                    }
                }
            }
        } else {
            // 목적지를 찾을 수 없으면 에러
            handleAPIError("'\(endLocation)'을(를) 찾을 수 없습니다. 미리 정의된 목적지를 선택하거나 직접 출발지를 입력해주세요.")
        }
    }

    /// 실제 API 요청 전송
    private func sendRouteRequest(from startLocation: String, to endLocation: String) {
        print("🌐 API 경로 요청 시작 (주소 모드)")
        print("   출발지: \(startLocation)")
        print("   목적지: \(endLocation)")

        // 진행률 업데이트 (각 단계를 최소 1초 이상 보장)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.linear(duration: 0.3)) {
                self.loadingProgress = 0.3
                self.loadingMessage = "안전이가 안전한 길을 찾고 있습니다."
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.linear(duration: 0.3)) {
                self.loadingProgress = 0.5
                self.loadingMessage = "안전이가 경로에 코인을 놓고 있습니다."
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.linear(duration: 0.3)) {
                self.loadingProgress = 0.7
                self.loadingMessage = "안전이가 위험 지역을 피해 가는 중이에요."
            }
        }

        // API 호출 (텍스트 그대로 전달)
        routeDataManager.overwriteRouteData(from: startLocation, to: endLocation) { success in
            DispatchQueue.main.async {
                if success {
                    self.handleAPISuccess()
                } else {
                    // RouteDataManager의 에러 정보 확인
                    if let error = self.routeDataManager.lastError {
                        self.handleNetworkError(error)
                    } else {
                        self.handleAPIError("경로를 찾을 수 없습니다. 다시 시도해주세요.")
                    }
                }
            }
        }
    }
    
    /// 날짜 및 시간 업데이트
    private func updateDateTime() {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")

        // 날짜 포맷: "2025년 1월 26일"
        dateFormatter.dateFormat = "yyyy년 M월 d일"
        currentDate = dateFormatter.string(from: now)

        // 시간 포맷: "오후 3:45"
        dateFormatter.dateFormat = "a h:mm"
        currentTime = dateFormatter.string(from: now)
    }

    /// 출발지 좌표 가져오기
    private func getStartCoordinate() -> CLLocationCoordinate2D? {
        // 현재 위치 사용
        if departureText == "현 내 위치 (자동)" || departureText == "위치 확인 중..." {
            return locationManager.currentLocation?.coordinate
        }

        // 사용자가 입력한 출발지 텍스트를 기반으로 미리 정의된 목적지 검색
        if !departureText.isEmpty {
            // 입력된 텍스트와 일치하는 목적지 찾기
            if let matchedDestination = destinationManager.predefinedDestinations.first(where: { destination in
                destination.name.contains(departureText) || departureText.contains(destination.name)
            }) {
                print("📍 입력된 출발지 '\(departureText)'와 매칭: \(matchedDestination.name)")
                return matchedDestination.coordinate
            }
        }

        // TODO: 카카오 로컬 API 등을 사용한 실시간 주소→좌표 변환 기능 추가
        // Fallback: 서울시청 (서버가 지원하는 서울 시내 중심)
        print("⚠️ 출발지를 찾을 수 없어 기본 출발지(서울시청)를 사용합니다")
        return CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780) // 서울시청
    }
    
    /// 목적지 좌표 가져오기
    private func getEndCoordinate() -> CLLocationCoordinate2D? {
        // 기본 목적지 사용
        if let destination = destinationManager.currentDestination {
            return destination.coordinate
        }

        // 사용자가 입력한 목적지 텍스트를 기반으로 미리 정의된 목적지 검색
        if !destinationText.isEmpty {
            // 입력된 텍스트와 일치하는 목적지 찾기
            if let matchedDestination = destinationManager.predefinedDestinations.first(where: { destination in
                destination.name.contains(destinationText) || destinationText.contains(destination.name)
            }) {
                print("📍 입력된 목적지 '\(destinationText)'와 매칭: \(matchedDestination.name)")
                return matchedDestination.coordinate
            }
        }

        // TODO: 카카오 로컬 API 등을 사용한 실시간 주소→좌표 변환 기능 추가
        // Fallback: 서울시청 (서버가 지원하는 서울 시내 중심)
        print("⚠️ 목적지를 찾을 수 없어 기본 목적지(서울시청)를 사용합니다")
        return CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780) // 서울시청
    }
    
    /// API 성공 처리
    private func handleAPISuccess() {
        print("✅ API 경로 요청 성공")

        // 목적지 이름 저장 (사용자가 입력한 텍스트)
        if !destinationText.isEmpty {
            destinationManager.destinationName = destinationText
            print("📍 목적지 이름 저장: \(destinationText)")

            // predefinedDestinations에서 매칭되면 좌표도 설정
            if let matchedDestination = destinationManager.predefinedDestinations.first(where: { destination in
                destination.name.contains(destinationText) || destinationText.contains(destination.name)
            }) {
                print("📍 목적지 좌표 설정: \(matchedDestination.name)")
                destinationManager.setDestination(matchedDestination)
            }
        }

        withAnimation(.linear(duration: 0.3)) {
            loadingProgress = 1.0
            loadingMessage = "조금만 기다려 주세요! 거의 다 왔어요 🚶‍♀️"
        }

        // 완료 처리 (마지막 단계도 최소 1초 이상 보장)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.completeRouteLoading()
        }
    }
    
    /// API 에러 처리
    private func handleAPIError(_ message: String) {
        print("❌ API 경로 요청 실패: \(message)")
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isRouteLoading = false
            loadingProgress = 0.0
            loadingMessage = message
        }
        
        // 에러 토스트 표시
        showErrorToast(message: message)
        
        // 에러 메시지 표시 후 초기화
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isRouteLoading = false
                self.loadingProgress = 0.0
                self.loadingMessage = "안전이가 등교 준비를 하고 있습니다."
            }
        }
    }
    
    /// 네트워크 에러 처리
    private func handleNetworkError(_ error: NetworkError) {
        print("❌ 네트워크 에러: \(error.localizedDescription)")
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isRouteLoading = false
            loadingProgress = 0.0
        }
        
        // 에러 알림 표시
        showErrorAlert(error: error)
    }
    
    // MARK: - 에러 처리 메서드들
    
    /// 에러 알림 표시
    private func showErrorAlert(error: NetworkError) {
        currentError = error
        showErrorAlert = true
    }
    
    /// 에러 알림 닫기
    private func dismissErrorAlert() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showErrorAlert = false
            currentError = nil
        }
    }
    
    /// 에러 토스트 표시
    private func showErrorToast(message: String) {
        errorMessage = message
        showErrorToast = true
    }
    
    /// 에러 토스트 닫기
    private func dismissErrorToast() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showErrorToast = false
            errorMessage = ""
        }
    }
    
    /// 마지막 액션 재시도
    private func retryLastAction() {
        print("🔄 마지막 액션 재시도")
        
        // 에러 알림 닫기
        dismissErrorAlert()
        
        // 경로 요청 재시도
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.startRouteLoading()
        }
    }
    
    private func simulateRouteAPI() {
        // 진행률 애니메이션
        withAnimation(.linear(duration: 1.0)) {
            loadingProgress = 0.3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.linear(duration: 1.0)) {
                loadingProgress = 0.7
                loadingMessage = "안전이가 경로에 코인을 놓고 있습니다."
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.linear(duration: 0.5)) {
                loadingProgress = 1.0
                loadingMessage = "조금만 기다려 주세요! 거의 다 왔어요 🚶‍♀️"
            }
        }
        
        // 로딩 완료 후 경로 미리보기 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            // 새로운 경로 데이터 로드 (실제로는 API 호출)
            loadNewRouteData()
            completeRouteLoading()
        }
    }
    
    private func loadNewRouteData() {
        // 실제로는 여기서 새로운 출발지/목적지에 대한 API 호출
        // 현재는 기존 데이터를 다시 로드하여 시뮬레이션
        print("🔄 새로운 경로 데이터 로드 중...")
        print("   출발지: \(departureText)")
        print("   목적지: \(destinationText)")
        
        // 기존 경로 데이터를 다시 로드 (실제로는 새로운 API 응답)
        routeDataManager.loadRouteData()
        
        // 새로운 목적지 설정
        if let defaultDestination = destinationManager.predefinedDestinations.first {
            destinationManager.setDestination(defaultDestination)
        }
    }
    
    private func completeRouteLoading() {
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // 로딩 완료 애니메이션
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isRouteLoading = false
            isRouteReady = true
            showRoutePreview = true
            isExistingRoute = false // 새로운 경로임을 표시
        }

        // 목적지 설정
        if let defaultDestination = destinationManager.predefinedDestinations.first {
            destinationManager.setDestination(defaultDestination)
        }
    }
    
    private func resetToSearchMode() {
        // 경로 미리보기 숨기기
        withAnimation(.easeInOut(duration: 0.3)) {
            showRoutePreview = false
            isRouteReady = false
            isRouteLoading = false
        }
        // 입력 폼은 항상 표시되어 있음 (미리보기가 숨겨지면 자동으로 나타남)
    }
    
    private func refreshExistingRoute() {
        print("🔄 기존 경로 갱신 시작")
        print("   출발지: \(departureText)")
        print("   목적지: \(destinationText)")
        
        // 기존 경로 미리보기 숨기기
        withAnimation(.easeInOut(duration: 0.2)) {
            showRoutePreview = false
            isRouteReady = false
        }
        
        // 출발지/목적지는 유지하고 경로만 갱신
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            startRouteLoading()
        }
    }
    
    /// 새로운 경로 입력 (기존 경로 덮어쓰기)
    private func startNewRouteInput() {
        print("🆕 새로운 경로 입력 시작")

        // 기존 경로 미리보기 숨기기
        withAnimation(.easeInOut(duration: 0.2)) {
            showRoutePreview = false
            isRouteReady = false
        }
        // 입력 폼은 항상 표시되어 있음 (미리보기가 숨겨지면 자동으로 나타남)
    }
    
    private func handleUseCurrentLocation() {
        print("📍 현재 위치로 출발지 설정")
        
        // 먼저 로딩 상태 표시
        departureText = "위치 확인 중..."
        
        // 위치 상태에 따른 처리
        switch locationManager.status {
        case .authorized, .locationFound:
            if let currentLocation = locationManager.currentLocation {
                // 현재 위치를 출발지로 설정 (자동 모드)
                departureText = "현 내 위치 (자동)"
                
                // 좌표 정보도 로그에 출력 (추후 API 연동 시 사용)
                print("   ✅ 현재 위치 좌표: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)")
            } else {
                departureText = "위치 정보 없음"
                print("   ⚠️ 현재 위치 정보를 가져올 수 없습니다")
            }
            
        case .denied:
            departureText = "위치 권한 필요"
            print("   ❌ 위치 권한이 거부되었습니다")
            
        case .notDetermined:
            departureText = "위치 권한 요청 중..."
            print("   🔄 위치 권한을 요청합니다")
            // 위치 권한 재요청
            locationManager.requestLocationPermission()
            
        default:
            departureText = "위치 확인 실패"
            print("   ❌ 위치 확인에 실패했습니다")
        }
    }
    
    private func updateDepartureTextBasedOnLocationStatus() {
        switch locationManager.status {
        case .authorized, .locationFound:
            if locationManager.currentLocation != nil {
                departureText = "현 내 위치 (자동)"
            } else {
                departureText = "위치 정보 없음"
            }
        case .denied:
            departureText = "위치 권한 필요"
        case .notDetermined:
            departureText = "위치 권한 요청 중..."
        default:
            departureText = "위치 확인 실패"
        }
    }
    
    private func startNavigationWithCustomDestination() {
        // 입력된 목적지로 내비게이션 시작
        if let defaultDestination = destinationManager.predefinedDestinations.first {
            destinationManager.setDestination(defaultDestination)
            destinationManager.startNavigation()
            currentView = .splitNavigation
        }
    }
    
    private var locationStatusIcon: String {
        switch locationManager.status {
        case .authorized, .locationFound:
            return "location.fill"
        case .denied:
            return "location.slash"
        case .notDetermined:
            return "location"
        default:
            return "exclamationmark.triangle"
        }
    }
    
    private var locationStatusColor: Color {
        switch locationManager.status {
        case .authorized, .locationFound:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - 경로 정보 카드와 게임 통계 카드 제거 (어린이용 간단한 UI)

// MARK: - 액션 버튼
struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(textColor)
                    .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(textColor)
                    
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textColor.opacity(0.9))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 20))
                    .foregroundColor(textColor.opacity(0.7))
            }
            .padding(25)
            .background(color)
            .cornerRadius(25)
            .shadow(color: .gray.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 목적지 선택 뷰
struct DestinationPickerView: View {
    let destinations: [Destination]
    @Binding var selectedDestination: Destination?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 헤더
                VStack(spacing: 16) {
                    Text("목적지 선택")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text("안전한 등하교 길찾기를 위한 목적지를 선택해주세요")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(Color.gray.opacity(0.1))
                
                // 목적지 리스트
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(destinations) { destination in
                            DestinationRow(
                                destination: destination,
                                isSelected: selectedDestination?.id == destination.id
                            ) {
                                selectedDestination = destination
                            }
                        }
                    }
                    .padding()
                }
                
                // 선택 완료 버튼
                if selectedDestination != nil {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("선택 완료")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("취소") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// MARK: - 목적지 행
struct DestinationRow: View {
    let destination: Destination
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 아이콘
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .blue : .gray)
                
                // 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text(destination.address)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 선택 표시
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Home 화면
struct HomeScreenView: View {
    @Binding var selectedTab: BottomTab

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 전체 배경 그라데이션 (위에서 아래로)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.37, green: 0.87, blue: 0.90), // #5FDDE5 (상단 - Primary)
                        Color(red: 0.32, green: 0.79, blue: 0.82), // 중간 상단
                        Color(red: 0.85, green: 0.95, blue: 0.96), // 중간 하단 (밝은 톤)
                        Color.white                                  // 하단 (순백)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 상단 헤더 영역 (15%) - 타이틀만
                    VStack(alignment: .leading, spacing: 0) {
                        Text("SafeWalkAR")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("안전한 등하교 기록")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .frame(height: geometry.size.height * 0.15)

                    // 대시보드 영역 (77%)
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // 오늘의 날씨 카드 (목업) - 맨 위로 이동
                            TodayWeatherCard()
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                            // 통계 카드 (코인 & 거리)
                            HStack(spacing: 12) {
                                // 총 획득 코인 카드
                                TotalCoinsCard()

                                // 총 이동 거리 카드
                                TotalDistanceCard()
                            }
                            .padding(.horizontal, 20)

                            // 최근 이동 기록
                            RecentTripsList()
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                        }
                    }
                    .frame(height: geometry.size.height * 0.77)

                    // 하단 메뉴바 (8%)
                    BottomMenuBar(selectedTab: $selectedTab)
                        .frame(height: geometry.size.height * 0.08)
                }
            }
        }
    }
}

// MARK: - Profile 화면
struct ProfileScreenView: View {
    @Binding var selectedTab: BottomTab

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 상단 헤더 영역 (20%) - 비어있음
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(height: geometry.size.height * 0.2)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.37, green: 0.87, blue: 0.90), // #5FDDE5
                            Color(red: 0.30, green: 0.75, blue: 0.78)  // 조금 더 진한 Primary
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                // 바디 영역 (70%)
                ZStack {
                    Color.white

                    VStack {
                        Spacer()

                        Text("Me 화면")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31))

                        Text("프로필 화면 콘텐츠를 여기에 추가하세요")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54))
                            .padding(.top, 8)

                        Spacer()
                    }
                }
                .frame(height: geometry.size.height * 0.72)

                // 하단 메뉴바 (8%)
                BottomMenuBar(selectedTab: $selectedTab)
                    .frame(height: geometry.size.height * 0.08)
            }
        }
    }
}

// MARK: - 공통 하단 메뉴바 (중앙 강조형)
struct BottomMenuBar: View {
    @Binding var selectedTab: BottomTab

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 커스텀 배경 (중앙 곡선)
                CurvedTabBarShape()
                    .fill(Color.clear)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -3)
                    .edgesIgnoringSafeArea(.bottom)

                HStack(spacing: 0) {
                    // Home
                    Button(action: {
                        selectedTab = .home
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: selectedTab == .home ? "house.fill" : "house")
                                .font(.system(size: 28, weight: .medium))
                            Text("Home")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(selectedTab == .home ? Color(red: 0.37, green: 0.87, blue: 0.90) : Color(white: 0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Go (중앙 강조 버튼)
                    Button(action: {
                        selectedTab = .go
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.37, green: 0.87, blue: 0.90), // #5FDDE5
                                            Color(red: 0.30, green: 0.75, blue: 0.78)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 70, height: 70)
                                .shadow(color: Color(red: 0.37, green: 0.87, blue: 0.90).opacity(0.4), radius: 10, x: 0, y: 5)

                            Image(systemName: "location.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(y: -40) // 아이콘을 위로 올림 (곡선 깊이 50에 맞춤)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity)

                    // Me
                    Button(action: {
                        selectedTab = .profile
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: selectedTab == .profile ? "person.crop.circle.fill" : "person.crop.circle")
                                .font(.system(size: 28, weight: .medium))
                            Text("Me")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(selectedTab == .profile ? Color(red: 0.37, green: 0.87, blue: 0.90) : Color(white: 0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 8)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom : 8)
            }
        }
    }
}

// MARK: - 커스텀 탭바 곡선 Shape (아이콘 아래 여백을 두고 휘어진 형태)
struct CurvedTabBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        // 곡선의 최저점 (중앙 아이콘 하단까지 여유있게)
        let curveDepth: CGFloat = 50

        // 시작점 (왼쪽 상단)
        path.move(to: CGPoint(x: 0, y: 0))

        // 왼쪽에서 중앙 곡선 시작점까지 직선
        path.addLine(to: CGPoint(x: width * 0.30, y: 0))

        // 중앙 곡선 (아래로 부드럽게 휘어진 형태 - 왼쪽 커브)
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: curveDepth),
            control1: CGPoint(x: width * 0.33, y: 0),
            control2: CGPoint(x: width * 0.42, y: curveDepth)
        )

        // 중앙 곡선 (아래로 부드럽게 휘어진 형태 - 오른쪽 커브)
        path.addCurve(
            to: CGPoint(x: width * 0.70, y: 0),
            control1: CGPoint(x: width * 0.58, y: curveDepth),
            control2: CGPoint(x: width * 0.67, y: 0)
        )

        // 중앙에서 오른쪽까지 직선
        path.addLine(to: CGPoint(x: width, y: 0))

        // 오른쪽 하단
        path.addLine(to: CGPoint(x: width, y: height))

        // 하단 왼쪽
        path.addLine(to: CGPoint(x: 0, y: height))

        // 닫기
        path.closeSubpath()

        return path
    }
}

// MARK: - 커스텀 코인 아이콘
/// 원 안에 원, 그 안에 45도 회전된 네모가 있는 코인 모양 아이콘
struct CustomCoinIcon: View {
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            // 가장 큰 원 (외곽) - #FFE386
            Circle()
                .fill(Color(red: 1.0, green: 0.89, blue: 0.53))
                .frame(width: size, height: size)

            // 중간 원 (내부) - #FFC040
            Circle()
                .fill(Color(red: 1.0, green: 0.75, blue: 0.25))
                .frame(width: size * 0.65, height: size * 0.65)

            // 가장 작은 네모 (중앙) - 45도 회전, #FFE386
            RoundedRectangle(cornerRadius: size * 0.08)
                .fill(Color(red: 1.0, green: 0.89, blue: 0.53))
                .frame(width: size * 0.25, height: size * 0.25)
                .rotationEffect(.degrees(45))
        }
    }
}

// MARK: - 홈 대시보드 카드 컴포넌트들

/// 총 획득 코인 카드
struct TotalCoinsCard: View {
    // 목업 데이터
    let totalCoins: Int = 1247

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 커스텀 코인 아이콘
            CustomCoinIcon(size: 32)

            Spacer()

            // 수치
            Text("\(totalCoins)")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31))

            // 라벨
            Text("총 획득 코인")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140) // 고정 높이
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
}

/// 총 이동 거리 카드
struct TotalDistanceCard: View {
    // 목업 데이터
    let totalDistance: Double = 42.5 // km

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 아이콘
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color(red: 0.37, green: 0.87, blue: 0.90))

            Spacer()

            // 수치
            Text(String(format: "%.1f km", totalDistance))
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31))

            // 라벨
            Text("총 이동 거리")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140) // 고정 높이
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
}

/// 오늘의 날씨 카드 (목업)
struct TodayWeatherCard: View {
    // 목업 데이터
    let temperature: String = "18°"
    let condition: String = "맑음"
    let weatherIcon: String = "sun.max.fill"

    var body: some View {
        HStack(spacing: 20) {
            // 날씨 아이콘
            Image(systemName: weatherIcon)
                .font(.system(size: 56, weight: .medium))
                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0)) // 태양색
                .frame(width: 70, height: 70)

            // 날씨 정보
            VStack(alignment: .leading, spacing: 8) {
                Text("오늘의 날씨")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(temperature)
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31))

                    Text(condition)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31))
                }
            }

            Spacer()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
}

/// 최근 이동 기록 리스트
struct RecentTripsList: View {
    // 목업 데이터
    let recentTrips: [TripRecord] = [
        TripRecord(date: "2025년 1월 27일", destination: "서울초등학교", distance: 1.2, coins: 45, time: "오전 8:15"),
        TripRecord(date: "2025년 1월 26일", destination: "서울초등학교", distance: 1.2, coins: 42, time: "오전 8:20"),
        TripRecord(date: "2025년 1월 25일", destination: "서울초등학교", distance: 1.3, coins: 48, time: "오전 8:10"),
        TripRecord(date: "2025년 1월 24일", destination: "동네 도서관", distance: 0.8, coins: 30, time: "오후 3:30"),
        TripRecord(date: "2025년 1월 23일", destination: "서울초등학교", distance: 1.2, coins: 44, time: "오전 8:18")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 섹션 타이틀
            Text("최근 이동 기록")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31))
                .padding(.horizontal, 4)

            // 기록 리스트
            VStack(spacing: 12) {
                ForEach(recentTrips) { trip in
                    TripRecordRow(trip: trip)
                }
            }
        }
    }
}

/// 이동 기록 데이터 모델
struct TripRecord: Identifiable {
    let id = UUID()
    let date: String
    let destination: String
    let distance: Double
    let coins: Int
    let time: String
}

/// 이동 기록 행
struct TripRecordRow: View {
    let trip: TripRecord

    var body: some View {
        HStack(spacing: 16) {
            // 날짜 및 시간
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.time)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31))

                Text(trip.date)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54))
            }

            Spacer()

            // 목적지 & 거리
            VStack(alignment: .trailing, spacing: 4) {
                Text(trip.destination)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31))

                Text(String(format: "%.1f km", trip.distance))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54))
            }

            // 코인
            HStack(spacing: 4) {
                CustomCoinIcon(size: 16)

                Text("\(trip.coins)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }
}

#Preview {
    ContentView()
}
