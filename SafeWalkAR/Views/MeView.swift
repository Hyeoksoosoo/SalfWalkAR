import SwiftUI

// MARK: - Me 페이지 (프로필/설정)
struct MeView: View {
    @Binding var selectedTab: BottomTab

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 바디 영역 (92%)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 프로필 헤더
                        ProfileHeaderView()
                            .padding(.top, 20)
                            .padding(.horizontal, 20)

                        // 메인 메뉴 섹션
                        VStack(spacing: 0) {
                            MenuItemView(
                                icon: "person.fill",
                                title: "Account Details",
                                iconColor: Color(red: 0.37, green: 0.87, blue: 0.90) // Primary
                            )

                            Divider()
                                .padding(.leading, 60)

                            MenuItemView(
                                icon: "bell.fill",
                                title: "Notification",
                                iconColor: Color(red: 0.97, green: 0.53, blue: 0.38) // Secondary
                            )

                            Divider()
                                .padding(.leading, 60)

                            MenuItemView(
                                icon: "gearshape.fill",
                                title: "Settings",
                                iconColor: Color(red: 0.18, green: 0.33, blue: 0.31) // Dark
                            )

                            Divider()
                                .padding(.leading, 60)

                            MenuItemView(
                                icon: "globe",
                                title: "Language",
                                iconColor: Color(red: 0.40, green: 0.65, blue: 0.54) // Medium
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)

                        // 보조 메뉴 섹션
                        VStack(spacing: 0) {
                            MenuItemView(
                                icon: "paintpalette.fill",
                                title: "Theme",
                                iconColor: Color(red: 0.37, green: 0.87, blue: 0.90) // Primary
                            )

                            Divider()
                                .padding(.leading, 60)

                            MenuItemView(
                                icon: "shield.fill",
                                title: "Privacy Policy",
                                iconColor: Color(red: 0.40, green: 0.65, blue: 0.54) // Medium
                            )

                            Divider()
                                .padding(.leading, 60)

                            MenuItemView(
                                icon: "person.2.fill",
                                title: "연동하기",
                                subtitle: "부모님 계정과 연결",
                                iconColor: Color(red: 0.97, green: 0.53, blue: 0.38) // Secondary
                            )

                            Divider()
                                .padding(.leading, 60)

                            MenuItemView(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Logout",
                                iconColor: Color.red.opacity(0.8),
                                showChevron: false
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)

                        // 앱 버전 정보
                        Text("Version 1.0.0")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(Color.gray.opacity(0.6))
                            .padding(.bottom, 20)
                    }
                }
                .frame(height: geometry.size.height * 0.92)
                .background(Color(red: 0.95, green: 0.95, blue: 0.95))

                // 하단 메뉴바 (8%)
                BottomMenuBar(selectedTab: $selectedTab)
                    .frame(height: geometry.size.height * 0.08)
            }
        }
    }
}

// MARK: - 프로필 헤더
struct ProfileHeaderView: View {
    var body: some View {
        HStack(spacing: 16) {
            // 프로필 이미지
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.37, green: 0.87, blue: 0.90),
                                Color(red: 0.40, green: 0.65, blue: 0.54)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)

                Image(systemName: "person.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }

            // 프로필 정보
            VStack(alignment: .leading, spacing: 4) {
                Text("안전이")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31))

                Text("safewalkar@example.com")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54))
            }

            Spacer()
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 메뉴 아이템
struct MenuItemView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let iconColor: Color
    var showChevron: Bool = true

    var body: some View {
        Button(action: {
            print("Tapped: \(title)")
        }) {
            HStack(spacing: 16) {
                // 아이콘
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(iconColor)
                }

                // 텍스트
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31))

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54))
                    }
                }

                Spacer()

                // 화살표
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 미리보기
#Preview {
    MeView(selectedTab: .constant(.profile))
}
