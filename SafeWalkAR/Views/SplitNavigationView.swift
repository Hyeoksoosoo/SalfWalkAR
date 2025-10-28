import SwiftUI
import MapKit

struct SplitNavigationView: View {
    @ObservedObject var destinationManager: DestinationManager
    @ObservedObject var routeDataManager: RouteDataManager
    @ObservedObject var pathDataManager: PathDataManager
    @Binding var currentView: AppView
    @StateObject private var locationManager = LocationManager()
    @StateObject private var coinManager = CoinManager()
    
    @State private var showingPermissionAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 2D 지도 기반 내비게이션
                TurnByTurnNavigationView(
                    locationManager: locationManager,
                    destinationManager: destinationManager,
                    routeDataManager: routeDataManager,
                    pathDataManager: pathDataManager
                )
                .onAppear {
                    print("🔄 SplitNavigationView: 2D 지도 내비게이션 시작")
                }
                
                // 상단 정보 패널
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        
                        // 목적지 정보 패널
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("목적지로 안전하게")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)

                                if !destinationManager.destinationName.isEmpty {
                                    Text("→ \(destinationManager.destinationName)")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.8))
                                } else if let destination = destinationManager.currentDestination {
                                    Text("→ \(destination.name)")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.8))
                                }
                            }
                            
                            // 종료 버튼
                            Button(action: {
                                currentView = .home
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color(red: 0.4, green: 0.7, blue: 0.9), lineWidth: 2)
                        )
                        .cornerRadius(15)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                
            }
        }
        .onAppear {
            setupNavigation()
        }
        .alert("위치 권한이 필요합니다", isPresented: $showingPermissionAlert) {
            Button("설정으로 이동") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("길찾기를 사용하려면 위치 권한이 필요합니다.")
        }
    }
    
    private func setupNavigation() {
        // 경로 로드 및 코인 생성
        pathDataManager.loadSamplePath()
        // coinManager.setupCoins(with: pathDataManager.pathPoints) // 임시로 주석 처리
    }
}


#Preview {
    let routeDataManager = RouteDataManager()
    SplitNavigationView(
        destinationManager: DestinationManager(),
        routeDataManager: routeDataManager,
        pathDataManager: PathDataManager(routeDataManager: routeDataManager),
        currentView: .constant(.splitNavigation)
    )
}