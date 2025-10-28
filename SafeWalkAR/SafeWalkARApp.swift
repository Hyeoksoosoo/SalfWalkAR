import SwiftUI

@main
struct SafeWalkARApp: App {
    // 동영상 재생 임시 비활성화 (디자인 작업용)
    // @State private var isVideoFinished = false

    var body: some Scene {
        WindowGroup {
            // 동영상 없이 바로 ContentView 시작
            ContentView()
                .preferredColorScheme(.dark) // 다크 모드 기본 설정

            // 동영상 재생 (임시 비활성화)
            // if isVideoFinished {
            //     ContentView()
            //         .preferredColorScheme(.dark)
            // } else {
            //     OnboardingVideoView(isVideoFinished: $isVideoFinished)
            //         .preferredColorScheme(.dark)
            // }
        }
    }
}
