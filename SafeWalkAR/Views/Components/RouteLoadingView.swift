import SwiftUI

// MARK: - 커스텀 코인 아이콘 (RouteLoadingView용)
/// 원 안에 원, 그 안에 45도 회전된 네모가 있는 코인 모양 아이콘
struct CustomCoinIconForLoading: View {
    var size: CGFloat = 60

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

// MARK: - 경로 로딩 뷰
struct RouteLoadingView: View {
    let progress: Double
    let message: String

    @State private var isAnimating: Bool = false
    @State private var rotationAngle: Double = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var scaleEffect: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 30) {
            // 원형 진행 표시기 + 아이콘
            ZStack {
                // 원형 진행 표시기
                Circle()
                    .stroke(Color(red: 0.37, green: 0.87, blue: 0.90).opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(red: 0.37, green: 0.87, blue: 0.90),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)

                // 중앙 아이콘
                getIconViewForMessage()
                    .scaleEffect(scaleEffect)
                    .frame(height: 60)
                    .id(message)
                    .onAppear {
                        startBounceAnimation()
                    }
            }
            .padding(.top, 20)

            // 메시지
            Text(message)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31)) // #2D5550
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.3), value: message)
                .padding(.horizontal, 20)

            Spacer()

            // 대기 안내 버튼
            HStack(spacing: 12) {
                Image(systemName: "hourglass")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("잠시만 기다려주세요")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color(red: 0.37, green: 0.87, blue: 0.90)) // Primary color
            .cornerRadius(15)
            .shadow(color: Color(red: 0.37, green: 0.87, blue: 0.90).opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(red: 0.37, green: 0.87, blue: 0.90).opacity(0.9), radius: 8, x: 0, y: 4)
    }

    // MARK: - Helper Methods

    /// 메시지에 따라 적절한 아이콘 뷰 반환
    @ViewBuilder
    private func getIconViewForMessage() -> some View {
        if message.contains("등교 준비") {
            // 등교 준비 - 보라색/파란색 계열
            Image(systemName: "backpack.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(Color(red: 0.42, green: 0.55, blue: 0.95)) // 파란색
        } else if message.contains("안전한 길을 찾고") {
            // 안전한 길 찾기 - Primary 컬러 (청록색)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(Color(red: 0.37, green: 0.87, blue: 0.90))
        } else if message.contains("코인을 놓고") {
            // 코인 - 금색/노란색 커스텀 아이콘
            CustomCoinIconForLoading(size: 60)
        } else if message.contains("위험 지역을 피해") {
            // 위험 지역 - 빨간색/주황색 경고 색상
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.38)) // 빨간색
        } else if message.contains("거의 다 왔어요") {
            // 완료 - 초록색 성공 색상
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(Color(red: 0.30, green: 0.85, blue: 0.39)) // 초록색
        } else {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(Color(red: 0.37, green: 0.87, blue: 0.90))
        }
    }

    /// 통통 튀는 + 크기 변화 애니메이션
    private func startBounceAnimation() {
        // 위아래 통통 튀는 효과
        withAnimation(
            .easeInOut(duration: 0.6)
            .repeatForever(autoreverses: true)
        ) {
            bounceOffset = -10
        }

        // 커졌다 작아지는 효과
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            scaleEffect = 1.2
        }
    }
}

// MARK: - 미리보기
#Preview {
    VStack(spacing: 20) {
        RouteLoadingView(
            progress: 0.2,
            message: "안전이가 등교 준비를 하고 있습니다."
        )

        RouteLoadingView(
            progress: 0.5,
            message: "안전이가 안전한 길을 찾고 있습니다."
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
