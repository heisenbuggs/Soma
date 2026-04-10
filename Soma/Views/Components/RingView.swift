import SwiftUI

struct RingView: View {
    let progress: Double    // 0.0 – 1.0
    let color: Color
    let lineWidth: CGFloat

    init(progress: Double, color: Color, lineWidth: CGFloat = 8) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
    }
}

#Preview {
    RingView(progress: 0.78, color: .somaGreen)
        .frame(width: 80, height: 80)
        .background(Color.black)
}
