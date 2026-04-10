//
//  ProcessingSpinner.swift
//  ClaudeIsland
//
//  Animated yarn ball spinner with rotation and bounce
//

import SwiftUI
import Combine

// MARK: - Yarn Ball Spinner
/// A yarn ball spinner that can be toggled on/off
/// When isAnimating is true, the yarn ball rotates and bounces
/// When isAnimating is false, the yarn ball remains static
struct ProcessingSpinner: View {
    @StateObject private var animator = SpinnerAnimator()

    var isAnimating: Bool = true

    var body: some View {
        YarnBallShape(phase: animator.phase)
            .frame(width: 14, height: 16)
            .onAppear {
                animator.isAnimating = isAnimating
                animator.updateAnimation()
            }
            .onChange(of: isAnimating) { _, newValue in
                animator.isAnimating = newValue
                animator.updateAnimation()
            }
            .onDisappear {
                animator.stop()
            }
    }
}

// MARK: - Spinner Animator
/// Manages the animation state - must be class for Timer closure to see updated values
private class SpinnerAnimator: ObservableObject {
    @Published var phase: Double = 0
    var isAnimating: Bool = true

    private var timer: Timer?

    func updateAnimation() {
        if isAnimating {
            start()
        } else {
            stop()
        }
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isAnimating {
                self.phase += 1.0 / 30.0
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Yarn Ball Shape
struct YarnBallShape: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius = min(size.width, size.height) / 2 - 2

            // Bounce offset (up and down)
            let bounceOffset = sin(phase * 8) * 2

            // Rotation
            let rotation = Angle.degrees(phase * 180)

            context.translateBy(x: center.x, y: center.y + bounceOffset)
            context.rotate(by: rotation)
            context.translateBy(x: -center.x, y: -center.y)

            let radius = baseRadius

            // Draw yarn ball base (pink)
            let ballRect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(Path(roundedRect: ballRect, cornerRadius: radius), with: .color(Color(hex: "ffb6c1")))

            // Draw yarn wrap lines (darker pink) - X pattern
            let lineColor = Color(hex: "e89aa0")

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: center.x - radius, y: center.y - radius * 0.3))
                    path.addLine(to: CGPoint(x: center.x + radius, y: center.y + radius * 0.3))
                },
                with: .color(lineColor),
                lineWidth: 1.5
            )

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: center.x + radius, y: center.y - radius * 0.3))
                    path.addLine(to: CGPoint(x: center.x - radius, y: center.y + radius * 0.3))
                },
                with: .color(lineColor),
                lineWidth: 1.5
            )

            // Center circle
            context.stroke(
                Path { path in
                    path.addEllipse(in: CGRect(
                        x: center.x - radius * 0.5,
                        y: center.y - radius * 0.5,
                        width: radius,
                        height: radius
                    ))
                },
                with: .color(lineColor),
                lineWidth: 1.5
            )

            // Draw yarn tail
            let tailPath = Path { path in
                path.move(to: CGPoint(x: center.x + radius * 0.6, y: center.y + radius * 0.6))
                path.addQuadCurve(
                    to: CGPoint(x: center.x + radius + 3, y: center.y + radius * 1.3),
                    control: CGPoint(x: center.x + radius + 5, y: center.y + radius * 0.8)
                )
            }
            context.stroke(tailPath, with: .color(Color(hex: "ffb6c1")), lineWidth: 2)
        }
    }
}

#Preview {
    ProcessingSpinner(isAnimating: true)
        .frame(width: 40, height: 48)
        .background(.black)
}
