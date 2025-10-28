import SwiftUI

// MARK: - 에러 알림 뷰
struct ErrorAlertView: View {
    let error: NetworkError
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    @State private var isShowing = true
    
    var body: some View {
        VStack(spacing: 20) {
            // 에러 아이콘
            Image(systemName: getErrorIcon())
                .font(.system(size: 50, weight: .light))
                .foregroundColor(getErrorColor())
            
            // 에러 제목
            Text(getErrorTitle())
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
            
            // 에러 메시지
            Text(error.localizedDescription)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            
            // 버튼들
            HStack(spacing: 16) {
                // 닫기 버튼
                Button(action: {
                    onDismiss?()
                    isShowing = false
                }) {
                    Text("닫기")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                // 재시도 버튼 (있는 경우)
                if onRetry != nil {
                    Button(action: {
                        onRetry?()
                        isShowing = false
                    }) {
                        Text("다시 시도")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.2, green: 0.6, blue: 0.8),
                                        Color(red: 0.4, green: 0.7, blue: 0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(30)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .scaleEffect(isShowing ? 1.0 : 0.8)
        .opacity(isShowing ? 1.0 : 0.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isShowing)
    }
    
    // MARK: - Private Methods
    
    private func getErrorIcon() -> String {
        switch error {
        case .networkUnavailable:
            return "wifi.slash"
        case .timeout:
            return "clock.badge.xmark"
        case .serverError:
            return "server.rack"
        case .decodingError:
            return "exclamationmark.triangle"
        case .noData:
            return "questionmark.circle"
        case .invalidURL:
            return "link.badge.plus"
        }
    }
    
    private func getErrorColor() -> Color {
        switch error {
        case .networkUnavailable:
            return Color(red: 0.9, green: 0.6, blue: 0.2) // 주황색
        case .timeout:
            return Color(red: 0.8, green: 0.4, blue: 0.2) // 빨간색
        case .serverError:
            return Color(red: 0.8, green: 0.2, blue: 0.2) // 빨간색
        case .decodingError:
            return Color(red: 0.9, green: 0.7, blue: 0.2) // 노란색
        case .noData:
            return Color(red: 0.6, green: 0.6, blue: 0.6) // 회색
        case .invalidURL:
            return Color(red: 0.7, green: 0.4, blue: 0.8) // 보라색
        }
    }
    
    private func getErrorTitle() -> String {
        switch error {
        case .networkUnavailable:
            return "네트워크 연결 오류"
        case .timeout:
            return "요청 시간 초과"
        case .serverError:
            return "서버 오류"
        case .decodingError:
            return "데이터 처리 오류"
        case .noData:
            return "데이터 없음"
        case .invalidURL:
            return "잘못된 요청"
        }
    }
}

// MARK: - 에러 토스트 뷰
struct ErrorToastView: View {
    let message: String
    let onDismiss: (() -> Void)?
    
    @State private var isShowing = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            if onDismiss != nil {
                Button(action: {
                    onDismiss?()
                    isShowing = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.4, blue: 0.2),
                    Color(red: 0.8, green: 0.3, blue: 0.1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        .offset(y: isShowing ? 0 : -100)
        .opacity(isShowing ? 1.0 : 0.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isShowing)
        .onAppear {
            // 3초 후 자동으로 사라짐
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    isShowing = false
                }
            }
        }
    }
}

// MARK: - 미리보기
#Preview {
    VStack(spacing: 20) {
        ErrorAlertView(
            error: .networkUnavailable,
            onRetry: {
                print("재시도 버튼 클릭")
            },
            onDismiss: {
                print("닫기 버튼 클릭")
            }
        )
        
        ErrorToastView(
            message: "네트워크 연결을 확인해주세요.",
            onDismiss: {
                print("토스트 닫기")
            }
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
