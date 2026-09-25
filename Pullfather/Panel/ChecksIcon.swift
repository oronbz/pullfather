import SwiftUI

struct ChecksIcon: View {
    let checks: Checks

    var body: some View {
        Group {
            if checks == .running {
                SpinningRing()
            } else {
                Canvas { context, size in
                    context.scaleBy(x: size.width / 16, y: size.height / 16)
                    let disc = Path(ellipseIn: CGRect(x: 1, y: 1, width: 14, height: 14))
                    let markStyle = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    switch checks {
                    case .passing:
                        context.fill(disc, with: .color(Palette.checksPassing))
                        context.stroke(Path { path in
                            path.move(to: CGPoint(x: 4.8, y: 8.2))
                            path.addLine(to: CGPoint(x: 7, y: 10.4))
                            path.addLine(to: CGPoint(x: 11.2, y: 5.9))
                        }, with: .color(.white), style: markStyle)
                    case .failing:
                        context.fill(disc, with: .color(Palette.checksFailing))
                        context.stroke(Path { path in
                            path.move(to: CGPoint(x: 5.6, y: 5.6))
                            path.addLine(to: CGPoint(x: 10.4, y: 10.4))
                            path.move(to: CGPoint(x: 10.4, y: 5.6))
                            path.addLine(to: CGPoint(x: 5.6, y: 10.4))
                        }, with: .color(.white), style: markStyle)
                    case .running:
                        break
                    }
                }
            }
        }
        .frame(width: 14, height: 14)
        .accessibilityElement()
        .accessibilityLabel(label)
    }

    private var label: String {
        switch checks {
        case .passing: "Checks passing"
        case .running: "Checks running"
        case .failing: "Checks failing"
        }
    }
}

private struct SpinningRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let secondsPerTurn = 1.5

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                context.scaleBy(x: size.width / 16, y: size.height / 16)
                context.fill(Path(ellipseIn: CGRect(x: 5.6, y: 5.6, width: 4.8, height: 4.8)),
                             with: .color(Palette.checksRunning))
                guard !reduceMotion else {
                    context.stroke(Path(ellipseIn: CGRect(x: 1.8, y: 1.8, width: 12.4, height: 12.4)),
                                   with: .color(Palette.checksRunning), lineWidth: 1.8)
                    return
                }
                let turn = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: secondsPerTurn) / secondsPerTurn
                context.translateBy(x: 8, y: 8)
                context.rotate(by: .degrees(turn * 360))
                context.stroke(Path { path in
                    path.addArc(center: .zero, radius: 6.2, startAngle: .zero, endAngle: .degrees(270), clockwise: false)
                }, with: .color(Palette.checksRunning), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }
    }
}

#if DEBUG
#Preview("Checks") {
    BothAppearances {
        HStack(spacing: 12) {
            ChecksIcon(checks: .passing)
            ChecksIcon(checks: .running)
            ChecksIcon(checks: .failing)
        }
        .padding(12)
        .background(Palette.surface)
    }
}
#endif
