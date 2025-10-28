import SwiftUI
import CoreLocation

// MARK: - Placeholder Extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - 출발지/목적지 입력 폼
struct LocationInputForm: View {
    @Binding var departureText: String
    @Binding var destinationText: String
    let onSearch: () -> Void
    let onUseCurrentLocation: () -> Void
    
    @State private var isSearchEnabled: Bool = false
    @FocusState private var focusedField: Field?
    @State private var isAutoLocationMode: Bool = false
    
    enum Field {
        case departure, destination
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 출발지 입력 섹션
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("출발지")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31)) // #2D5550
                    
                    Spacer()
                    
                    // 현재 위치로 설정 버튼 (Primary Color)
                    Button(action: onUseCurrentLocation) {
                        HStack(spacing: 6) {
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("현재 위치")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.37, green: 0.87, blue: 0.90)) // #5FDDE5
                        .cornerRadius(20)
                        .shadow(color: Color(red: 0.37, green: 0.87, blue: 0.90).opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // 출발지 입력 필드 (전체 영역 클릭 가능)
                HStack(spacing: 12) {
                    Image(systemName: "location.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(red: 0.37, green: 0.87, blue: 0.90)) // Primary color icon
                        .frame(width: 24)

                    TextField("출발지를 입력하세요", text: $departureText)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(isAutoLocationMode ? Color(red: 0.40, green: 0.65, blue: 0.54) : Color(red: 0.18, green: 0.33, blue: 0.31)) // #65A78A : #2D5550
                        .placeholder(when: departureText.isEmpty && !isAutoLocationMode) {
                            Text("출발지를 입력하세요")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54)) // #65A78A
                        }
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($focusedField, equals: .departure)
                        .onChange(of: departureText) { _, newValue in
                            updateSearchButtonState()
                            // 사용자가 직접 입력하면 수동 모드로 전환
                            if newValue != "현 내 위치 (자동)" {
                                isAutoLocationMode = false
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18) // 터치 영역 확장 (44pt 이상)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color(red: 0.37, green: 0.87, blue: 0.90), lineWidth: 2.5)
                )
                .cornerRadius(15)
                .onTapGesture {
                    // 전체 영역 클릭 시 포커스
                    if isAutoLocationMode {
                        departureText = ""
                        isAutoLocationMode = false
                    }
                    focusedField = .departure
                }
            }
            
            // 목적지 입력 섹션
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("목적지")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31)) // #2D5550

                    Spacer()
                }

                // 목적지 입력 필드 (전체 영역 클릭 가능)
                HStack(spacing: 12) {
                    Image(systemName: "flag.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(red: 0.97, green: 0.53, blue: 0.38)) // Secondary color icon
                        .frame(width: 24)

                    TextField("목적지를 입력하세요", text: $destinationText)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.18, green: 0.33, blue: 0.31)) // #2D5550
                        .placeholder(when: destinationText.isEmpty) {
                            Text("목적지를 입력하세요")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(Color(red: 0.40, green: 0.65, blue: 0.54)) // #65A78A
                        }
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($focusedField, equals: .destination)
                        .onChange(of: destinationText) { _, _ in
                            updateSearchButtonState()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18) // 터치 영역 확장 (44pt 이상)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color(red: 0.37, green: 0.87, blue: 0.90), lineWidth: 2.5)
                )
                .cornerRadius(15)
                .onTapGesture {
                    // 전체 영역 클릭 시 포커스
                    focusedField = .destination
                }
            }
            
            // 검색 버튼 (Secondary Color)
            Button(action: {
                focusedField = nil // 키보드 숨기기
                onSearch()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("경로 확인")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(isSearchEnabled ? Color(red: 0.97, green: 0.53, blue: 0.38) : Color.gray.opacity(0.3)) // #F78860
                .cornerRadius(15)
                .shadow(
                    color: isSearchEnabled ? Color(red: 0.97, green: 0.53, blue: 0.38).opacity(0.4) : Color.clear,
                    radius: isSearchEnabled ? 8 : 0,
                    x: 0,
                    y: 4
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isSearchEnabled)
            .animation(.easeInOut(duration: 0.2), value: isSearchEnabled)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(red: 0.37, green: 0.87, blue: 0.90).opacity(0.9), radius: 8, x: 0, y: 4)
        .onAppear {
            updateSearchButtonState()
            // 자동 위치 모드 감지
            isAutoLocationMode = departureText == "현 내 위치 (자동)"
        }
        .onChange(of: departureText) { _, newValue in
            // 자동 위치 모드 상태 업데이트
            isAutoLocationMode = newValue == "현 내 위치 (자동)"
        }
    }
    
    // MARK: - 검색 버튼 상태 업데이트
    private func updateSearchButtonState() {
        isSearchEnabled = !departureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                         !destinationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - 미리보기
#Preview {
    LocationInputForm(
        departureText: .constant(""),
        destinationText: .constant(""),
        onSearch: {
            print("검색 버튼 클릭됨")
        },
        onUseCurrentLocation: {
            print("현재 위치 버튼 클릭됨")
        }
    )
    .padding()
    .background(Color.gray.opacity(0.1))
}
