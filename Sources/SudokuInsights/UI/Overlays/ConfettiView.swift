import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let x: CGFloat
    let speed: Double
    let delay: Double
    let rotation: Double
    let size: CGFloat
}

public struct ConfettiView: View {
    @State private var animate = false

    let pieces: [ConfettiPiece] = (0..<60).map { _ in
        ConfettiPiece(
            color: [Color.red, .blue, .green, .yellow, .orange, .purple, .pink, .mint, .cyan].randomElement()!,
            x: CGFloat.random(in: -200...200),
            speed: Double.random(in: 2...4),
            delay: Double.random(in: 0...1.5),
            rotation: Double.random(in: 0...360),
            size: CGFloat.random(in: 6...12)
        )
    }

    public init() {}

    public var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size * 1.4)
                    .rotationEffect(.degrees(animate ? piece.rotation + 360 : piece.rotation))
                    .offset(
                        x: piece.x,
                        y: animate ? 500 : -100
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeIn(duration: piece.speed)
                        .delay(piece.delay),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}
