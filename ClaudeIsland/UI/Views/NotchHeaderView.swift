//
//  NotchHeaderView.swift
//  ClaudeIsland
//
//  Header bar for the dynamic island
//

import Combine
import SwiftUI

struct ClaudeCrabIcon: View {
    let size: CGFloat
    let color: Color
    var animateLegs: Bool = false

    @State private var legPhase: Int = 0

    // Timer for leg animation
    private let legTimer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    init(size: CGFloat = 16, color: Color = Color(red: 0.85, green: 0.47, blue: 0.34), animateLegs: Bool = false) {
        self.size = size
        self.color = color
        self.animateLegs = animateLegs
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 52.0  // Original viewBox height is 52
            let xOffset = (canvasSize.width - 66 * scale) / 2

            // Left antenna
            let leftAntenna = Path { p in
                p.addRect(CGRect(x: 0, y: 13, width: 6, height: 13))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(leftAntenna, with: .color(color))

            // Right antenna
            let rightAntenna = Path { p in
                p.addRect(CGRect(x: 60, y: 13, width: 6, height: 13))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(rightAntenna, with: .color(color))

            // Animated legs - alternating up/down pattern for walking effect
            // Legs stay attached to body (y=39), only height changes
            let baseLegPositions: [CGFloat] = [6, 18, 42, 54]
            let baseLegHeight: CGFloat = 13

            // Height offsets: positive = longer leg (down), negative = shorter leg (up)
            let legHeightOffsets: [[CGFloat]] = [
                [3, -3, 3, -3],   // Phase 0: alternating
                [0, 0, 0, 0],     // Phase 1: neutral
                [-3, 3, -3, 3],   // Phase 2: alternating (opposite)
                [0, 0, 0, 0],     // Phase 3: neutral
            ]

            let currentHeightOffsets = animateLegs ? legHeightOffsets[legPhase % 4] : [CGFloat](repeating: 0, count: 4)

            for (index, xPos) in baseLegPositions.enumerated() {
                let heightOffset = currentHeightOffsets[index]
                let legHeight = baseLegHeight + heightOffset
                let leg = Path { p in
                    p.addRect(CGRect(x: xPos, y: 39, width: 6, height: legHeight))
                }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
                context.fill(leg, with: .color(color))
            }

            // Main body
            let body = Path { p in
                p.addRect(CGRect(x: 6, y: 0, width: 54, height: 39))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(body, with: .color(color))

            // Left eye
            let leftEye = Path { p in
                p.addRect(CGRect(x: 12, y: 13, width: 6, height: 6.5))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(leftEye, with: .color(.black))

            // Right eye
            let rightEye = Path { p in
                p.addRect(CGRect(x: 48, y: 13, width: 6, height: 6.5))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(rightEye, with: .color(.black))
        }
        .frame(width: size * (66.0 / 52.0), height: size)
        .onReceive(legTimer) { _ in
            if animateLegs {
                legPhase = (legPhase + 1) % 4
            }
        }
    }
}

// MARK: - Large Menu Bar Cat Icon (for notch header)
struct MenuBarCatIcon: View {
    let phase: SessionPhase
    let size: CGFloat

    init(phase: SessionPhase, size: CGFloat = 28) {
        self.phase = phase
        self.size = size
    }

    var body: some View {
        switch phase {
        case .waitingForInput:
            LargeWaitingCatIcon(size: size)
        case .waitingForApproval:
            LargeApprovalCatIcon(size: size)
        case .processing, .compacting:
            LargeRunningCatIcon(size: size)
        case .idle, .ended:
            LargeIdleCatIcon(size: size)
        }
    }
}

// MARK: - Large Idle Cat (sleeping)
struct LargeIdleCatIcon: View {
    let size: CGFloat
    @State private var breathOffset: CGFloat = 0

    var body: some View {
        Canvas { context, _ in
            let scale = size / 32
            context.scaleBy(x: scale, y: scale)

            func p(_ x: Int, _ y: Int, _ c: Color) {
                let rect = CGRect(x: CGFloat(x), y: CGFloat(y + Int(breathOffset)), width: 1, height: 1)
                context.fill(Path(rect), with: .color(c))
            }

            // body loaf (simplified)
            for x in 2..<8 { p(x, 4, PixelColor.gray) }
            for x in 1..<9 { p(x, 5, PixelColor.gray); p(x, 6, PixelColor.gray) }
            for x in 2..<8 { p(x, 7, PixelColor.white) }
            // head
            p(3, 2, PixelColor.gray); p(4, 2, PixelColor.gray)
            p(5, 2, PixelColor.gray); p(6, 2, PixelColor.gray)
            p(2, 3, PixelColor.black); p(3, 3, PixelColor.black)
            p(6, 3, PixelColor.black); p(7, 3, PixelColor.black)
            // closed eyes
            for x in 3..<7 { p(x, 3, PixelColor.black) }
            // nose
            p(4, 4, PixelColor.pink); p(5, 4, PixelColor.pink)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                breathOffset = 1
            }
        }
    }
}

// MARK: - Large Waiting Cat (sitting)
struct LargeWaitingCatIcon: View {
    let size: CGFloat
    @State private var tailWag: CGFloat = 0

    var body: some View {
        Canvas { context, _ in
            let scale = size / 32
            context.scaleBy(x: scale, y: scale)

            func p(_ x: Int, _ y: Int, _ c: Color) {
                let rect = CGRect(x: CGFloat(x), y: CGFloat(y + Int(tailWag)), width: 1, height: 1)
                context.fill(Path(rect), with: .color(c))
            }

            // tail
            p(1, 10, PixelColor.black); p(1, 11, PixelColor.black)
            p(2, 11, PixelColor.black); p(1, 12, PixelColor.black)

            // body sitting
            for x in 2..<8 { p(x, 5, PixelColor.gray) }
            for x in 1..<9 { p(x, 6, PixelColor.gray); p(x, 7, PixelColor.gray) }
            for x in 3..<7 { p(x, 7, PixelColor.white) }

            // head
            for x in 2..<8 { p(x, 2, PixelColor.gray) }
            for x in 1..<9 { p(x, 3, PixelColor.black) }

            // ears
            p(2, 1, PixelColor.black); p(7, 1, PixelColor.black)

            // eyes
            p(3, 3, PixelColor.black); p(4, 3, PixelColor.white)
            p(5, 3, PixelColor.black)
            p(6, 3, PixelColor.white); p(7, 3, PixelColor.black)

            // nose
            p(4, 4, PixelColor.pink); p(5, 4, PixelColor.pink)

            // paws
            p(2, 8, PixelColor.white); p(3, 8, PixelColor.white)
            p(6, 8, PixelColor.white); p(7, 8, PixelColor.white)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                tailWag = tailWag == 0 ? 1 : 0
            }
        }
    }
}

// MARK: - Large Running Cat (running right) - v6 design
struct LargeRunningCatIcon: View {
    let size: CGFloat
    @State private var frame: Int = 0
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        Canvas { context, _ in
            // Use 32x24 grid, 5px per pixel
            let scale = size / 32
            context.scaleBy(x: scale, y: scale)

            func px(_ x: Int, _ y: Int, _ c: Color) {
                let rect = CGRect(x: CGFloat(x) * 1, y: CGFloat(y) * 1, width: 1, height: 1)
                context.fill(Path(rect), with: .color(c))
            }

            let G = PixelColor.gray
            let B = PixelColor.black
            let W = PixelColor.white
            let P = PixelColor.pink
            let D = PixelColor.lightGray  // stripes

            // Cat faces RIGHT
            // Head on RIGHT (x=17-24), Body (x=9-17), Tail on LEFT (x=4-8)
            // White triangle face, pink square nose

            switch frame {
            case 0:
                // Frame 0: front legs forward, back legs back
                // HEAD - gray outer (rectangle)
                for x in 18..<24 { px(x, 6, G); px(x, 11, G) }
                for x in 17..<25 { px(x, 7, G); px(x, 8, G); px(x, 9, G); px(x, 10, G) }

                // White triangle face (inverted triangle: wide top, point bottom)
                px(20, 8, W); px(21, 8, W)
                px(19, 9, W); px(20, 9, W); px(21, 9, W); px(22, 9, W)
                px(18, 10, W); px(19, 10, W); px(20, 10, W); px(21, 10, W); px(22, 10, W); px(23, 10, W)
                px(18, 11, W); px(19, 11, W); px(20, 11, W); px(21, 11, W); px(22, 11, W); px(23, 11, W)

                // Pink square nose in center of triangle
                px(20, 9, P); px(21, 9, P)
                px(20, 10, P); px(21, 10, P)

                // Eyes (above triangle)
                px(18, 7, B); px(23, 7, B)

                // Ears
                px(17, 5, B); px(18, 5, B)
                px(16, 4, B); px(17, 4, B); px(18, 4, B)
                px(24, 5, B); px(25, 5, B)
                px(24, 4, B); px(25, 4, B); px(26, 4, B)

                // BODY
                for x in 10..<18 { px(x, 11, G); px(x, 12, G); px(x, 13, G) }
                // chest white
                px(14, 12, W); px(15, 12, W); px(16, 12, W)
                px(14, 13, W); px(15, 13, W); px(16, 13, W)
                // stripes
                px(11, 11, D); px(15, 11, D)

                // TAIL
                px(8, 10, B); px(7, 9, B); px(6, 8, B); px(5, 7, B); px(4, 6, B)

                // FRONT LEGS FORWARD (right side)
                px(18, 14, W); px(19, 14, W)
                px(19, 15, W); px(20, 15, W)
                px(18, 16, W); px(19, 16, W)

                // BACK LEGS BACK (left side)
                px(10, 16, W); px(11, 16, W)
                px(9, 17, W); px(10, 17, W)
                px(8, 18, W); px(9, 18, W)

            case 1:
                // Frame 1: legs passing mid
                // HEAD
                for x in 18..<24 { px(x, 6, G); px(x, 11, G) }
                for x in 17..<25 { px(x, 7, G); px(x, 8, G); px(x, 9, G); px(x, 10, G) }

                px(20, 8, W); px(21, 8, W)
                px(19, 9, W); px(20, 9, W); px(21, 9, W); px(22, 9, W)
                px(18, 10, W); px(19, 10, W); px(20, 10, W); px(21, 10, W); px(22, 10, W); px(23, 10, W)
                px(18, 11, W); px(19, 11, W); px(20, 11, W); px(21, 11, W); px(22, 11, W); px(23, 11, W)

                px(20, 9, P); px(21, 9, P)
                px(20, 10, P); px(21, 10, P)

                px(18, 7, B); px(23, 7, B)

                px(17, 5, B); px(18, 5, B)
                px(16, 4, B); px(17, 4, B); px(18, 4, B)
                px(24, 5, B); px(25, 5, B)
                px(24, 4, B); px(25, 4, B); px(26, 4, B)

                // BODY
                for x in 10..<18 { px(x, 11, G); px(x, 12, G); px(x, 13, G) }
                px(14, 12, W); px(15, 12, W); px(16, 12, W)
                px(14, 13, W); px(15, 13, W); px(16, 13, W)
                px(11, 11, D); px(15, 11, D)

                // TAIL
                px(8, 10, B); px(7, 9, B); px(6, 8, B); px(5, 7, B); px(4, 6, B)

                // legs mid
                px(18, 15, W); px(19, 15, W)
                px(19, 16, W); px(20, 16, W)
                px(18, 17, W); px(19, 17, W)

                px(10, 15, W); px(11, 15, W)
                px(9, 16, W); px(10, 16, W)
                px(8, 17, W); px(9, 17, W)

            case 2:
                // Frame 2: front legs back, back legs forward
                // HEAD
                for x in 18..<24 { px(x, 6, G); px(x, 11, G) }
                for x in 17..<25 { px(x, 7, G); px(x, 8, G); px(x, 9, G); px(x, 10, G) }

                px(20, 8, W); px(21, 8, W)
                px(19, 9, W); px(20, 9, W); px(21, 9, W); px(22, 9, W)
                px(18, 10, W); px(19, 10, W); px(20, 10, W); px(21, 10, W); px(22, 10, W); px(23, 10, W)
                px(18, 11, W); px(19, 11, W); px(20, 11, W); px(21, 11, W); px(22, 11, W); px(23, 11, W)

                px(20, 9, P); px(21, 9, P)
                px(20, 10, P); px(21, 10, P)

                px(18, 7, B); px(23, 7, B)

                px(17, 5, B); px(18, 5, B)
                px(16, 4, B); px(17, 4, B); px(18, 4, B)
                px(24, 5, B); px(25, 5, B)
                px(24, 4, B); px(25, 4, B); px(26, 4, B)

                // BODY
                for x in 10..<18 { px(x, 11, G); px(x, 12, G); px(x, 13, G) }
                px(14, 12, W); px(15, 12, W); px(16, 12, W)
                px(14, 13, W); px(15, 13, W); px(16, 13, W)
                px(11, 11, D); px(15, 11, D)

                // TAIL
                px(8, 10, B); px(7, 9, B); px(6, 8, B); px(5, 7, B); px(4, 6, B)

                // FRONT LEGS BACK
                px(16, 16, W); px(17, 16, W)
                px(15, 17, W); px(16, 17, W)
                px(14, 18, W); px(15, 18, W)

                // BACK LEGS FORWARD
                px(12, 14, W); px(13, 14, W)
                px(13, 15, W); px(14, 15, W)
                px(12, 16, W); px(13, 16, W)

            default:
                // Frame 3: legs passing opposite
                // HEAD
                for x in 18..<24 { px(x, 6, G); px(x, 11, G) }
                for x in 17..<25 { px(x, 7, G); px(x, 8, G); px(x, 9, G); px(x, 10, G) }

                px(20, 8, W); px(21, 8, W)
                px(19, 9, W); px(20, 9, W); px(21, 9, W); px(22, 9, W)
                px(18, 10, W); px(19, 10, W); px(20, 10, W); px(21, 10, W); px(22, 10, W); px(23, 10, W)
                px(18, 11, W); px(19, 11, W); px(20, 11, W); px(21, 11, W); px(22, 11, W); px(23, 11, W)

                px(20, 9, P); px(21, 9, P)
                px(20, 10, P); px(21, 10, P)

                px(18, 7, B); px(23, 7, B)

                px(17, 5, B); px(18, 5, B)
                px(16, 4, B); px(17, 4, B); px(18, 4, B)
                px(24, 5, B); px(25, 5, B)
                px(24, 4, B); px(25, 4, B); px(26, 4, B)

                // BODY
                for x in 10..<18 { px(x, 11, G); px(x, 12, G); px(x, 13, G) }
                px(14, 12, W); px(15, 12, W); px(16, 12, W)
                px(14, 13, W); px(15, 13, W); px(16, 13, W)
                px(11, 11, D); px(15, 11, D)

                // TAIL
                px(8, 10, B); px(7, 9, B); px(6, 8, B); px(5, 7, B); px(4, 6, B)

                // all legs mid
                px(17, 15, W); px(18, 15, W)
                px(18, 16, W); px(19, 16, W)
                px(17, 17, W); px(18, 17, W)

                px(11, 15, W); px(12, 15, W)
                px(10, 16, W); px(11, 16, W)
                px(9, 17, W); px(10, 17, W)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            timerCancellable = Timer.publish(every: 0.12, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    frame = (frame + 1) % 4
                }
        }
        .onDisappear {
            timerCancellable?.cancel()
        }
    }
}

// MARK: - Large Approval Cat (paw raised)
struct LargeApprovalCatIcon: View {
    let size: CGFloat
    @State private var pawBob: CGFloat = 0

    var body: some View {
        Canvas { context, _ in
            let scale = size / 32
            context.scaleBy(x: scale, y: scale)

            func p(_ x: Int, _ y: Int, _ c: Color) {
                let rect = CGRect(x: CGFloat(x), y: CGFloat(y + Int(pawBob)), width: 1, height: 1)
                context.fill(Path(rect), with: .color(c))
            }

            // body
            for x in 2..<8 { p(x, 6, PixelColor.gray) }
            for x in 1..<9 { p(x, 7, PixelColor.gray); p(x, 8, PixelColor.gray) }
            for x in 3..<7 { p(x, 8, PixelColor.white) }

            // head
            for x in 2..<8 { p(x, 2, PixelColor.gray) }
            for x in 1..<9 { p(x, 3, PixelColor.black) }
            p(2, 1, PixelColor.black); p(7, 1, PixelColor.black)

            // eyes
            p(3, 3, PixelColor.black); p(4, 3, PixelColor.white)
            p(5, 3, PixelColor.black)
            p(6, 3, PixelColor.black)

            // nose
            p(4, 4, PixelColor.pink); p(5, 4, PixelColor.pink)

            // raised paw
            p(8, 2, PixelColor.white); p(9, 2, PixelColor.white)
            p(9, 1, PixelColor.white)

            // paws
            p(2, 9, PixelColor.white); p(3, 9, PixelColor.white)
            p(6, 9, PixelColor.white); p(7, 9, PixelColor.white)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pawBob = pawBob == 0 ? -1 : 0
            }
        }
    }
}

// Pixel color enum for reuse
private enum PixelColor {
    static let black = Color(hex: "1a1a1a")
    static let gray = Color(hex: "5a5a5a")
    static let lightGray = Color(hex: "9a9a9a")
    static let white = Color(hex: "ffffff")
    static let pink = Color(hex: "ffb6c1")
    static let lightPink = Color(hex: "ffd4d8")
}

// Pixel art permission indicator icon
struct PermissionIndicatorIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 14, color: Color = Color(red: 0.11, green: 0.12, blue: 0.13)) {
        self.size = size
        self.color = color
    }

    // Visible pixel positions from the SVG (at 30x30 scale)
    private let pixels: [(CGFloat, CGFloat)] = [
        (7, 7), (7, 11),           // Left column
        (11, 3),                    // Top left
        (15, 3), (15, 19), (15, 27), // Center column
        (19, 3), (19, 15),          // Right of center
        (23, 7), (23, 11)           // Right column
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let pixelSize: CGFloat = 4 * scale

            for (x, y) in pixels {
                let rect = CGRect(
                    x: x * scale - pixelSize / 2,
                    y: y * scale - pixelSize / 2,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

// Pixel art "ready for input" indicator icon (checkmark/done shape)
struct ReadyForInputIndicatorIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 14, color: Color = TerminalColors.green) {
        self.size = size
        self.color = color
    }

    // Checkmark shape pixel positions (at 30x30 scale)
    private let pixels: [(CGFloat, CGFloat)] = [
        (5, 15),                    // Start of checkmark
        (9, 19),                    // Down stroke
        (13, 23),                   // Bottom of checkmark
        (17, 19),                   // Up stroke begins
        (21, 15),                   // Up stroke
        (25, 11),                   // Up stroke
        (29, 7)                     // End of checkmark
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let pixelSize: CGFloat = 4 * scale

            for (x, y) in pixels {
                let rect = CGRect(
                    x: x * scale - pixelSize / 2,
                    y: y * scale - pixelSize / 2,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

