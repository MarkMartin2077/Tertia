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
        // Always-on TimelineView/Canvas (no `if isAnimating { ... }` wrap)
        // keeps the view's frame stable for the whole lifetime — easier on
        // SwiftUI's layout pass and prevents collapse-to-zero inside
        // `.overlay` slots. When the run finishes we fade to opacity 0
        // rather than yanking the canvas out of the tree.
        TimelineView(.animation) { context in
            Canvas { canvas, size in
                let elapsed = context.date.timeIntervalSince(startDate)
                for particle in particles {
                    draw(particle, elapsed: elapsed, in: canvas, size: size)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isAnimating ? 1 : 0)
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

#Preview("Frozen mid-flight") {
    // Renders a single representative frame at t=1.2s using a static
    // Canvas, no TimelineView. The interactive `TimelineView(.animation)`
    // path crashes Xcode's preview host on iOS 26 (running 60fps Canvas
    // drawLayer calls in the preview sandbox blows the memory budget),
    // so the static snapshot is the recommended way to iterate on
    // particle color / density / draw math. The real animation runs
    // correctly on simulator / device.
    ConfettiSnapshot(elapsed: 1.2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
}

#Preview("Over a sheet — frozen") {
    // Same snapshot rendered above mock sheet content so you can verify
    // particle legibility against a real-world surface (title + score
    // numeral + accent button — what daily / versus game-over present).
    VStack(spacing: 24) {
        Text("You won!")
            .font(.largeTitle.bold())
        Text("84")
            .font(.system(size: 64, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.purple.gradient)
        Button("Done") {}
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
    .overlay {
        ConfettiSnapshot(elapsed: 1.2)
            .allowsHitTesting(false)
    }
}

/// Renders one frozen frame of the confetti animation. Test-only — uses
/// the same draw math as `ConfettiView` but reads `elapsed` directly
/// instead of from a TimelineView.
private struct ConfettiSnapshot: View {
    let elapsed: TimeInterval

    /// Deterministic seed so the preview frame is stable across reloads.
    private static let particles: [Particle] = (0..<50).map { i in
        var rng = SeededGenerator(seed: UInt64(i + 1))
        return Particle(
            xOffset: .random(in: 0...1, using: &rng),
            xDrift: .random(in: -0.15...0.15, using: &rng),
            fallSpeed: .random(in: 0.7...1.2, using: &rng),
            rotationDegrees: .random(in: 0...360, using: &rng),
            rotationSpeed: .random(in: -1.5...1.5, using: &rng),
            color: [.red, .orange, .yellow, .green, .blue, .purple, .pink].randomElement(using: &rng) ?? .red,
            delay: .random(in: 0...0.4, using: &rng),
            size: .random(in: 7...11, using: &rng)
        )
    }

    var body: some View {
        Canvas { context, size in
            for particle in Self.particles {
                let t = elapsed - particle.delay
                guard t > 0 else { continue }
                let progress = t / 2.8
                guard progress < 1 else { continue }

                let startX = particle.xOffset * size.width
                let x = startX + particle.xDrift * size.width * CGFloat(t)
                let y = -20 + (size.height + 40) * CGFloat(progress * particle.fallSpeed)
                let opacity: Double = progress > 0.7
                    ? max(0, 1 - (progress - 0.7) / 0.3)
                    : 1.0
                let rotation = Angle.degrees(particle.rotationDegrees + particle.rotationSpeed * t * 360)

                context.drawLayer { layer in
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: rotation)
                    layer.opacity = opacity
                    let rect = CGRect(
                        x: -particle.size / 2,
                        y: -particle.size / 4,
                        width: particle.size,
                        height: particle.size / 2
                    )
                    layer.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(particle.color))
                }
            }
        }
    }
}

