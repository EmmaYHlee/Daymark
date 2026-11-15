import SwiftUI

struct Celebration: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.width * 0.38, y: rect.height))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        return p
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x = CGFloat.random(in: 0...1)
    let drift = CGFloat.random(in: -0.15...0.15)
    let endY = CGFloat.random(in: 0.6...1.1)
    let size = CGFloat.random(in: 6...11)
    let rotation = Double.random(in: 180...720)
    let delay = Double.random(in: 0...0.25)
    let duration = Double.random(in: 1.2...2.0)
    let color = [Color.pink, .orange, .yellow, .mint, .cyan, .purple, .red].randomElement() ?? .pink
}

struct ConfettiView: View {
    @State private var pieces = (0..<60).map { _ in ConfettiPiece() }
    @State private var go = false

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 1.6)
                    .rotationEffect(.degrees(go ? p.rotation : 0))
                    .position(x: geo.size.width * (p.x + (go ? p.drift : 0)),
                              y: go ? geo.size.height * p.endY : -20)
                    .opacity(go ? 0 : 1)
                    .animation(.easeIn(duration: p.duration).delay(p.delay), value: go)
            }
        }
        .allowsHitTesting(false)
        .onAppear { go = true }
    }
}

struct CelebrationOverlay: View {
    let celebration: Celebration
    let accent: Color
    var onDismiss: () -> Void

    @AppStorage("animationEnabled") private var animationEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var checkProgress: CGFloat = 0

    private var animate: Bool { animationEnabled && !reduceMotion }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea().onTapGesture(perform: onDismiss)
            if animate { ConfettiView().ignoresSafeArea() }

            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(accent).frame(width: 84, height: 84)
                    CheckmarkShape()
                        .trim(from: 0, to: checkProgress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        .frame(width: 36, height: 28)
                }
                Text("Checked in!").font(.title3.bold())
                Text(celebration.message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(40)
            .scaleEffect(shown || !animate ? 1 : 0.85)
            .opacity(shown ? 1 : 0)
        }
        .task {
            let pop: Animation? = animate ? .spring(duration: 0.4) : nil
            let draw: Animation? = animate ? .easeOut(duration: 0.5).delay(0.2) : nil
            withAnimation(pop) { shown = true }
            withAnimation(draw) { checkProgress = 1 }
            try? await Task.sleep(for: .seconds(2.4))
            onDismiss()
        }
    }
}
