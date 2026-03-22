import SwiftUI

// MARK: - LineChartView (Moving Average Smooth Trend)

struct LineChartView: View {
    let dataPoints: [Double]
    let title: String
    let unit: String
    let color: Color
    var windowSize: Int = 5

    private var smoothed: [Double] {
        guard dataPoints.count >= 2 else { return dataPoints }
        let w = max(1, min(windowSize, dataPoints.count))
        return dataPoints.indices.map { i in
            let half = w / 2
            let start = max(0, i - half)
            let end = min(dataPoints.count - 1, i + half)
            let window = dataPoints[start...end]
            return window.reduce(0, +) / Double(window.count)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)

            if dataPoints.count < 2 {
                Text("Not enough data")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let s = smoothed
                    let minVal = s.min() ?? 0
                    let maxVal = s.max() ?? 1
                    let range = max(maxVal - minVal, 0.001)
                    let pts: [CGPoint] = s.indices.map { i in
                        CGPoint(
                            x: CGFloat(i) / CGFloat(s.count - 1) * w,
                            y: h - CGFloat((s[i] - minVal) / range) * h
                        )
                    }
                    ZStack {
                        gridLines(width: w, height: h)
                        areaPath(points: pts, height: h)
                            .fill(LinearGradient(
                                colors: [color.opacity(0.25), color.opacity(0.0)],
                                startPoint: .top, endPoint: .bottom
                            ))
                        smoothCurvePath(points: pts)
                            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        VStack {
                            Text(String(format: "%.2f\(unit)", maxVal))
                                .font(.system(size: 9))
                                .foregroundColor(.gray.opacity(0.5))
                            Spacer()
                            Text(String(format: "%.2f\(unit)", minVal))
                                .font(.system(size: 9))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(height: 90)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    // MARK: - Chart Helpers

    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            for i in 0...3 {
                let y = height * CGFloat(i) / 3.0
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
        }
        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
    }

    private func smoothCurvePath(points: [CGPoint]) -> Path {
        Path { path in
            guard points.count > 1 else { return }
            path.move(to: points[0])
            for i in 1..<points.count {
                let prev2 = points[max(0, i - 2)]
                let prev  = points[i - 1]
                let curr  = points[i]
                let next  = points[min(points.count - 1, i + 1)]
                let cp1 = CGPoint(x: prev.x + (curr.x - prev2.x) / 6,
                                  y: prev.y + (curr.y - prev2.y) / 6)
                let cp2 = CGPoint(x: curr.x - (next.x - prev.x) / 6,
                                  y: curr.y - (next.y - prev.y) / 6)
                path.addCurve(to: curr, control1: cp1, control2: cp2)
            }
        }
    }

    private func areaPath(points: [CGPoint], height: CGFloat) -> Path {
        Path { path in
            guard points.count > 1 else { return }
            path.move(to: CGPoint(x: points[0].x, y: height))
            path.addLine(to: points[0])
            for i in 1..<points.count {
                let prev2 = points[max(0, i - 2)]
                let prev  = points[i - 1]
                let curr  = points[i]
                let next  = points[min(points.count - 1, i + 1)]
                let cp1 = CGPoint(x: prev.x + (curr.x - prev2.x) / 6,
                                  y: prev.y + (curr.y - prev2.y) / 6)
                let cp2 = CGPoint(x: curr.x - (next.x - prev.x) / 6,
                                  y: curr.y - (next.y - prev.y) / 6)
                path.addCurve(to: curr, control1: cp1, control2: cp2)
            }
            path.addLine(to: CGPoint(x: points.last!.x, y: height))
            path.closeSubpath()
        }
    }
}

// MARK: - PerformanceTableView

struct PerformanceTableView: View {
    let dataPoints: [PerformanceDataPoint]
    
    private let accentRed = Color(red: 222/255, green: 56/255, blue: 35/255)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SESSION DATA")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            if dataPoints.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    // Header Row
                    HStack {
                        headerCell("DATE")
                            .frame(width: 100, alignment: .leading)
                        Spacer()
                        headerCell("REACTION")
                        Spacer()
                        headerCell("SPLIT")
                        Spacer()
                        headerCell("GROUP")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    
                    // Data Rows
                    VStack(spacing: 0) {
                        ForEach(dataPoints.reversed()) { point in
                            HStack {
                                Text(point.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                    .frame(width: 100, alignment: .leading)
                                
                                Spacer()
                                
                                dataCell(String(format: "%.3fs", point.reactionTime))
                                Spacer()
                                dataCell(String(format: "%.3fs", point.fastestSplit))
                                Spacer()
                                dataCell(String(format: "%.1f", point.grouping))
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
    
    private func headerCell(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.gray)
    }
    
    private func dataCell(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
