# SafeWalkAR

어린이를 위한 안전한 등하교 AR 내비게이션 앱

## 📱 프로젝트 소개

SafeWalkAR은 어린이들의 안전한 등하교를 돕기 위한 iOS AR 내비게이션 애플리케이션입니다. 증강현실(AR) 기술과 안전한 경로 안내를 결합하여 어린이들이 재미있고 안전하게 목적지까지 이동할 수 있도록 돕습니다.

## ✨ 주요 기능

### 🗺️ AR 기반 내비게이션
- **실시간 AR 경로 안내**: 카메라 화면에 경로를 직접 표시
- **3D 지도 뷰**: 자동차 내비게이션 스타일의 동적 카메라
- **다중 화면 모드**: AR 카메라, 2D 지도, 카카오맵 등 다양한 뷰 모드

### 🪙 게임화 요소
- **코인 수집 시스템**: 경로를 따라가며 코인 수집
- **진행률 추적**: 실시간 이동 거리 및 수집 현황 표시
- **통계 대시보드**: 총 획득 코인, 이동 거리 등 기록

### 🛡️ 안전 기능
- **안전한 경로 우선**: 위험 지역을 피한 경로 계산
- **실시간 위치 추적**: GPS 기반 정확한 위치 파악
- **위치 필터링**: 이상치 제거 및 평활화를 통한 정확도 향상

### 🎨 사용자 친화적 UI
- **어린이 친화적 디자인**: 밝고 직관적인 인터페이스
- **실시간 로딩 화면**: 단계별 진행 상황 표시
- **경로 미리보기**: 출발 전 경로 확인 가능

## 🏗️ 기술 스택

- **언어**: Swift
- **프레임워크**: SwiftUI
- **지도**: MapKit, ARKit
- **아키텍처**: MVVM
- **최소 지원 버전**: iOS 17.0+

## 📂 프로젝트 구조

```
SafeWalkAR/
├── Constants/
│   └── AppConstants.swift          # 앱 전역 상수 (색상, 폰트, UI)
├── Managers/
│   ├── LocationManager.swift       # 위치 서비스 관리
│   ├── CoinManager.swift          # 코인 수집 로직
│   ├── DestinationManager.swift   # 목적지 관리
│   ├── RouteDataManager.swift     # 경로 데이터 및 API
│   └── NetworkManager.swift       # 네트워크 통신
├── Models/
│   ├── DestinationModel.swift     # 목적지 데이터 모델
│   ├── RouteDataModel.swift       # 경로 데이터 모델
│   └── PathData.swift             # 경로 포인트 모델
├── Views/
│   ├── ContentView.swift          # 메인 탭 컨테이너
│   ├── TurnByTurnNavigationView.swift  # AR 내비게이션 뷰
│   ├── SplitNavigationView.swift  # 분할 화면 뷰
│   └── Components/               # 재사용 가능한 UI 컴포넌트
│       ├── LocationInputForm.swift
│       ├── RoutePreviewCard.swift
│       ├── RouteLoadingView.swift
│       └── MapViewComponents.swift
├── Utils/
│   └── RouteCalculationUtils.swift # 경로 계산 유틸리티
└── Styles/
    └── (스타일 컴포넌트 - 추후 추가 예정)
```

## 🚀 시작하기

### 요구사항
- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

### 설치 및 실행

1. 프로젝트 클론
```bash
git clone [repository-url]
cd SafeWalkAR
```

2. Xcode에서 프로젝트 열기
```bash
open SafeWalkAR.xcodeproj
```

3. 시뮬레이터 또는 실제 디바이스 선택

4. 빌드 및 실행 (⌘ + R)

### 위치 권한 설정
앱 실행 시 위치 권한을 허용해야 정상적으로 작동합니다.

## 🎮 사용 방법

1. **앱 실행**: SafeWalkAR 앱 실행
2. **위치 권한 허용**: 위치 서비스 권한 요청 시 허용
3. **목적지 입력**:
   - 출발지: "현 내 위치 사용" 버튼 클릭
   - 목적지: 목적지 주소 입력
4. **경로 확인**: 계산된 경로 미리보기
5. **내비게이션 시작**: "출발하기" 버튼 클릭
6. **코인 수집**: 경로를 따라 이동하며 코인 수집

## 🏛️ 아키텍처

### Manager 계층
```
ContentView (Root)
├── LocationManager (독립) - 위치 서비스
├── CoinManager (독립) - 코인 수집 로직
├── DestinationManager (독립) - 목적지 관리
├── RouteDataManager (독립) - 경로 데이터
└── PathDataManager (RouteDataManager 의존) - 경로 변환
```

### 주요 설계 원칙
- **단일 책임 원칙**: 각 Manager는 하나의 책임만 가짐
- **의존성 주입**: 명확한 의존성 관리
- **재사용성**: 공통 컴포넌트 및 유틸리티 함수 활용

## 📊 주요 상수

### 지도 설정
- 기본 고도: 60m (도보)
- 카메라 각도: 60° (건물 가림 방지)
- 카메라 중심: 사용자 앞 25m 지점

### 코인 설정
- 배치 간격: 경로의 모든 좌표
- 수집 반경: 20m
- 코인 가치: 10점

## 🔮 향후 개선 계획

- [ ] KalmanFilter 구현 (GPS 정확도 향상)
- [ ] MotionSensorManager 구현 (모션 센서 보정)
- [ ] PathSnappingManager 구현 (경로 스냅핑)
- [ ] Protocol 기반 의존성 주입
- [ ] 다국어 지원
- [ ] 접근성 개선

## 🐛 알려진 이슈

현재 프로젝트는 정상적으로 빌드되고 실행됩니다. 발견된 버그는 Issues에 등록해주세요.

## 📝 최근 업데이트

### v1.0.0 (2025-01-28)
- ✅ AppConstants 확장 (색상/폰트/UI 상수)
- ✅ Manager 계층 분석 및 정리
- ✅ LocationManager 버그 수정
- ✅ RouteCalculationUtils 유틸리티 추가
- ✅ TurnByTurnNavigationView 버그 수정
- ✅ 전체 프로젝트 빌드 성공

## 👥 기여

기여는 언제나 환영합니다! Pull Request를 보내주세요.

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 📧 연락처

프로젝트에 대한 문의사항은 Issues를 통해 남겨주세요.

---

**Made with ❤️ for children's safety**
