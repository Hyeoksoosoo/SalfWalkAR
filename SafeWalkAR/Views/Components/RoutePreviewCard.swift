import SwiftUI

// MARK: - 경로 미리보기 카드
struct RoutePreviewCard: View {
    @ObservedObject var destinationManager: DestinationManager
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var routeDataManager: RouteDataManager
    let isExistingRoute: Bool
    let onStartNavigation: () -> Void
    let onSearchAgain: () -> Void
    let onRefreshRoute: () -> Void
    
    // MARK: - 계산된 속성들
    private var totalCoinCount: Int {
        return routeDataManager.coinCoordinates.count
    }
    
    private var routeDistanceText: String {
        let totalDistance = calculateTotalRouteDistance()
        if totalDistance < 1000 {
            return "약 \(Int(totalDistance))m"
        } else {
            let km = totalDistance / 1000
            return "약 \(String(format: "%.1f", km))km"
        }
    }
    
    private var estimatedTimeText: String {
        let totalDistance = calculateTotalRouteDistance()
        let walkingSpeed: Double = 1.4 // m/s (평균 보행 속도)
        let estimatedSeconds = totalDistance / walkingSpeed
        let estimatedMinutes = Int(estimatedSeconds / 60)
        
        if estimatedMinutes < 60 {
            return "약 \(estimatedMinutes)분"
        } else {
            let hours = estimatedMinutes / 60
            let minutes = estimatedMinutes % 60
            return "약 \(hours)시간 \(minutes)분"
        }
    }
    
    private func calculateTotalRouteDistance() -> Double {
        // RouteDataManager의 calculateTotalDistance() 메서드 사용 (km 단위)
        return routeDataManager.calculateTotalDistance() * 1000 // m 단위로 변환
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 헤더
            HStack {
                Text("경로 미리보기")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31)) // #2D5550

                Spacer()

                // 버튼 (오른쪽 배치)
                if isExistingRoute {
                    // 기존 경로일 때: 새 경로 버튼 (하얀 배경, Primary 테두리+글자)
                    Button(action: onSearchAgain) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 14, weight: .bold))
                            Text("새 경로")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundColor(Color(red: 0.37, green: 0.87, blue: 0.90)) // Primary color
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(minWidth: 100)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(red: 0.37, green: 0.87, blue: 0.90), lineWidth: 2.5) // Primary border
                        )
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // 새로운 경로일 때: 다시 검색 버튼 (하얀 배경, Primary 테두리+글자)
                    Button(action: onSearchAgain) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .bold))
                            Text("다시 검색")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundColor(Color(red: 0.37, green: 0.87, blue: 0.90)) // Primary color
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(minWidth: 100)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(red: 0.37, green: 0.87, blue: 0.90), lineWidth: 2.5) // Primary border
                        )
                        .cornerRadius(18)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // 지도 미리보기
            VStack(alignment: .leading, spacing: 8) {
                ChildSafeMapView(
                    destinationManager: destinationManager,
                    locationManager: locationManager,
                    routeDataManager: routeDataManager
                )
                .frame(height: 200)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color(red: 0.37, green: 0.87, blue: 0.90), lineWidth: 2.5) // Primary color border
                )
            }
            
                // 경로 정보
                HStack(spacing: 20) {
                    // 거리 정보
                    VStack(alignment: .center, spacing: 4) {
                        Text("거리")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54)) // #65A78A

                        Text(routeDistanceText)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31)) // #2D5550
                    }

                    Spacer()

                    // 예상 시간
                    VStack(alignment: .center, spacing: 4) {
                        Text("예상 시간")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54)) // #65A78A

                        Text(estimatedTimeText)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31)) // #2D5550
                    }

                    Spacer()

                    // 코인 정보
                    VStack(alignment: .center, spacing: 4) {
                        Text("수집 가능")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54)) // #65A78A

                        Text("\(totalCoinCount)개")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31)) // #2D5550
                    }
                }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 0.95, green: 0.95, blue: 0.95))
            .cornerRadius(12)
            
            // 길찾기 시작 버튼 (Primary Color)
            Button(action: onStartNavigation) {
                HStack {
                    Text("길찾기 시작")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 18)
                .background(Color(red: 0.37, green: 0.87, blue: 0.90)) // #5FDDE5
                .cornerRadius(20)
                .shadow(color: Color(red: 0.37, green: 0.87, blue: 0.90).opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(red: 0.37, green: 0.87, blue: 0.90).opacity(0.9), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 미리보기
#Preview {
    RoutePreviewCard(
        destinationManager: DestinationManager(),
        locationManager: LocationManager(),
        routeDataManager: RouteDataManager(),
        isExistingRoute: true,
        onStartNavigation: {
            print("길찾기 시작!")
        },
        onSearchAgain: {
            print("새로운 경로 입력!")
        },
        onRefreshRoute: {
            print("경로 갱신!")
        }
    )
    .padding()
    .background(Color.gray.opacity(0.1))
}
