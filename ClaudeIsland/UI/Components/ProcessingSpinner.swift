//
//  ProcessingSpinner.swift
//  ClaudeIsland
//
//  Animated yarn ball spinner for processing state
//

import Combine
import SwiftUI

// MARK: - Yarn Ball Spinner
struct ProcessingSpinner: View {
    @State private var rotation: Double = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 2

            // Rotate the yarn ball pattern
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: .degrees(rotation))
            context.translateBy(x: -center.x, y: -center.y)

            // Draw yarn ball base (pink)
            let ballRect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(Path(roundedRect: ballRect, cornerRadius: radius), with: .color(Color(hex: "ffb6c1")))

            // Draw yarn wrap lines (darker pink) - 4 crossing lines
            let lineColor = Color(hex: "e89aa0")

            // Line 1
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: center.x - radius, y: center.y - radius * 0.3))
                    path.addLine(to: CGPoint(x: center.x + radius, y: center.y + radius * 0.3))
                },
                with: .color(lineColor),
                lineWidth: 1.5
            )

            // Line 2
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: center.x + radius, y: center.y - radius * 0.3))
                    path.addLine(to: CGPoint(x: center.x - radius, y: center.y + radius * 0.3))
                },
                with: .color(lineColor),
                lineWidth: 1.5
            )

            // Line 3 (horizontal-ish)
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: center.x - radius * 0.8, y: center.y))
                    path.addLine(to: CGPoint(x: center.x + radius * 0.8, y: center.y))
                },
                with: .color(lineColor),
                lineWidth: 1.5
            )

            // Line 4 (vertical-ish)
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: center.x, y: center.y - radius * 0.8))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + radius * 0.8))
                },
                with: .color(lineColor),
                lineWidth: 1.5
            )

            // Draw yarn tail
            let tailPath = Path { path in
                path.move(to: CGPoint(x: center.x + radius * 0.7, y: center.y + radius * 0.7))
                path.addQuadCurve(
                    to: CGPoint(x: center.x + radius + 4, y: center.y + radius * 1.5),
                    control: CGPoint(x: center.x + radius + 6, y: center.y + radius * 0.9)
                )
            }
            context.stroke(tailPath, with: .color(Color(hex: "ffb6c1")), lineWidth: 2)
        }
        .frame(width: 20, height: 20)
        .onAppear {
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

#Preview {
    ProcessingSpinner()
        .frame(width: 40, height: 40)
        .background(.black)
}
