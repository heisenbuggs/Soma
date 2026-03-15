import SwiftUI
import Charts

struct SparklineView: View {
    let values: [Double]
    let color: Color

    private var normalizedValues: [(Int, Double)] {
        guard !values.isEmpty else { return [] }
        return values.enumerated().map { ($0.offset, $0.element) }
    }

    var body: some View {
        if values.isEmpty {
            Rectangle()
                .fill(Color.clear)
        } else {
            Chart(normalizedValues, id: \.0) { index, value in
                LineMark(
                    x: .value("Day", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Day", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: (values.min() ?? 0)...(values.max() ?? 100))
        }
    }
}

#Preview {
    SparklineView(values: [72, 68, 75, 80, 65, 70, 78], color: Color(hex: "00C853"))
        .frame(height: 40)
        .background(Color(hex: "1C1C1E"))
}
