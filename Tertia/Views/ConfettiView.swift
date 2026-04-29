//
//  ConfettiView.swift
//  Tertia
//
//  Created by Mark Martin on 4/29/26.
//

import SwiftUI

struct ConfettiView: View {
    @State private var particles: [Particle] = []
    @State private var startDate: Date = .now
    @State private var isAnimating: Bool = true

    private static let particleCount = 50
    private static let duration: TimeInterval = 2.8
    private static let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink
    ]

    var body: some View {
        Group {
            if isAnimating {
                TimelineView(.animation) { context in
                    Canvas { canvas, size in
                        let elapsed = context.date.timeIntervalSince(startDate)
                        for particle in particles {
                            draw(particle, elapsed: elapsed, in: canvas, size: size)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            particles = (0..<Self.particleCount).map { _ in
                Particle.random(colors: Self.colors)
            }
            startDate = .now
        }
        .task {
            try? await Task.sleep(for: .seconds(Self.duration + 0.3))
            isAnimating = false
        }
    }

    private func draw(_ p: Particle, elapsed: TimeInterval, in ctx: GraphicsContext, size: CGSize) {
        let t = elapsed - p.delay
        guard t > 0 else { return }
        let progress = t / Self.duration
        guard progress < 1 else { return }

        let startX = p.xOffset * size.width
        let x = startX + p.xDrift * size.width * CGFloat(t)
        let y = -20 + (size.height + 40) * CGFloat(progress * p.fallSpeed)

        let fadeStart = 0.7
        let opacity: Double = progress > fadeStart
            ? max(0, 1 - (progress - fadeStart) / (1 - fadeStart))
            : 1.0
        let rotation = Angle.degrees(p.rotationDegrees + p.rotationSpeed * t * 360)

        ctx.drawLayer { layer in
            layer.translateBy(x: x, y: y)
            layer.rotate(by: rotation)
            layer.opacity = opacity
            let rect = CGRect(
                x: -p.size / 2,
                y: -p.size / 4,
                width: p.size,
                height: p.size / 2
            )
            layer.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(p.color))
        }
    }
}

private struct Particle {
    let xOffset: CGFloat
    let xDrift: CGFloat
    let fallSpeed: CGFloat
    let rotationDegrees: Double
    let rotationSpeed: Double
    let color: Color
    let delay: TimeInterval
    let size: CGFloat

    static func random(colors: [Color]) -> Particle {
        Particle(
            xOffset: .random(in: 0...1),
            xDrift: .random(in: -0.15...0.15),
            fallSpeed: .random(in: 0.7...1.2),
            rotationDegrees: .random(in: 0...360),
            rotationSpeed: .random(in: -1.5...1.5),
            color: colors.randomElement() ?? .red,
            delay: .random(in: 0...0.4),
            size: .random(in: 7...11)
        )
    }
}

#Preview {
    ConfettiView()
        .background(Color.black.opacity(0.85))
}
