import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark ? [Color(hex: "1B1535"), Color(hex: "0E1A3A")]
                                        : [Color(hex: "E9DEFF"), Color(hex: "CFE4FF")],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(hex: scheme == .dark ? "B9A2FF" : "7A56D6"))
                Text("Daymark")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                Text("Small actions. Consistent progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(reduceMotion || appeared ? 1 : 0.92)
        }
        .task {
            let fade: Animation? = reduceMotion ? nil : .easeOut(duration: 0.7)
            withAnimation(fade) { appeared = true }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.8 : 1.5))
            onFinish()
        }
    }
}
