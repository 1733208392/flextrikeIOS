import SwiftUI
import Foundation

struct TargetLinkView: View {
    let bleManager: BLEManager
    @Binding var targetConfigs: [DrillTargetsConfigData]
    let onDone: () -> Void
    @Binding var drillMode: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedConfigIndex: Int? = nil
    @State private var navigateToConfig = false
    
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    private let rectangleHeight: CGFloat = 150
    private var rectangleWidth: CGFloat { rectangleHeight * 9 / 16 } // 9x16 aspect ratio
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Drill Mode Segment Control
                HStack(spacing: 0) {
                    // IPSC Button
                    Button(action: {
                        drillMode = "ipsc"
                    }) {
                        HStack(spacing: 6) {
                            if drillMode == "ipsc" {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text("IPSC")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundColor(drillMode == "ipsc" ? .white : .gray)
                        .background(drillMode == "ipsc" ? Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433) : Color.gray.opacity(0.2))
                    }
                    
                    // CQB Button
                    Button(action: {
                        drillMode = "cqb"
                    }) {
                        HStack(spacing: 6) {
                            if drillMode == "cqb" {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text("CQB")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundColor(drillMode == "cqb" ? .white : .gray)
                        .background(drillMode == "cqb" ? Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433) : Color.gray.opacity(0.2))
                    }
                }
                .frame(maxWidth: 200)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .padding(.top, 10)
                .onChange(of: drillMode) { _ in
                    updateTargetConfigsForMode()
                }

                ScrollView {
                    Spacer()
                    gridContent
                }
                .frame(maxHeight: .infinity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(NSLocalizedString("target_link", comment: "Target Link title"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    onDone()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                }
            }
        }
        .onAppear {
            print("TargetLinkView: onAppear called with deviceList.count = \(bleManager.networkDevices.count)")
            initializeTargetConfigs()
        }
    }
    
    @ViewBuilder
    private var gridContent: some View {
        ZStack(alignment: .topLeading) {
            // Connection lines overlay
            Canvas { context, size in
                var mutableContext = context
                drawConnectionLines(context: &mutableContext, canvasSize: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Grid background (on top so it's tappable)
            LazyVGrid(columns: gridColumns, spacing: 40) {
                ForEach(0...11, id: \.self) { (index: Int) in
                    if index < bleManager.networkDevices.count {
                        let device = bleManager.networkDevices[index]
                        
                        NavigationLink(destination: TargetConfigListViewV2(
                            deviceList: bleManager.networkDevices,
                            targetConfigs: $targetConfigs,
                            onDone: onDone,
                            drillMode: $drillMode,
                            singleDeviceMode: true,
                            deviceNameFilter: device.name,
                            isFromTargetLink: true
                        )) {
                            let config = targetConfigs.first { $0.targetName == device.name }
                            TargetRectangleView(
                                deviceName: device.name,
                                config: config,
                                width: rectangleWidth,
                                height: rectangleHeight
                            )
                        }
                    } else {
                        // Empty slot
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                            .frame(width: rectangleWidth, height: rectangleHeight)
                    }
                }
            }
            .padding(16)
        }
    }
    
    private func drawConnectionLines(context: inout GraphicsContext, canvasSize: CGSize) {
        let gridWidth = 3
        let horizontalSpacing: CGFloat = 24
        let verticalSpacing: CGFloat = 40
        let paddingLeftRight: CGFloat = 16
        let paddingTop: CGFloat = 16
        let lineWidth: CGFloat = 4
        let lineColor = Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)
        
        // Calculate actual available width for grid
        let availableWidth = canvasSize.width - 2 * paddingLeftRight
        let totalHorizontalSpacing = CGFloat(gridWidth - 1) * horizontalSpacing
        let totalRectangleWidth = availableWidth - totalHorizontalSpacing
        let cellWidth = totalRectangleWidth / CGFloat(gridWidth)
        let cellHeight = rectangleHeight
        
        // Snake pattern for 3x4 grid: 0→1→2, 2↓5, 5→4→3, 3↓6, 6→7→8, 8↓11, 11→10→9
        let snakePattern: [(Int, Int)] = [
            (0, 1), (1, 2), // Row 0: 0→1→2 (left to right)
            (2, 5), // Transition: 2↓5 (down)
            (5, 4), (4, 3), // Row 1: 5→4→3 (right to left)
            (3, 6), // Transition: 3↓6 (down)
            (6, 7), (7, 8), // Row 2: 6→7→8 (left to right)
            (8, 11), // Transition: 8↓11 (down)
            (11, 10), (10, 9) // Row 3: 11→10→9 (right to left)
        ]
        
        for (fromIndex, toIndex) in snakePattern {
            guard fromIndex < bleManager.networkDevices.count && toIndex < bleManager.networkDevices.count else { continue }
            
            let fromPos = getGridPosition(index: fromIndex, gridWidth: gridWidth)
            let toPos = getGridPosition(index: toIndex, gridWidth: gridWidth)
            
            let fromRect = getRectangleBounds(row: fromPos.row, col: fromPos.col, paddingLeft: paddingLeftRight, paddingTop: paddingTop, cellWidth: cellWidth, cellHeight: cellHeight, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
            let toRect = getRectangleBounds(row: toPos.row, col: toPos.col, paddingLeft: paddingLeftRight, paddingTop: paddingTop, cellWidth: cellWidth, cellHeight: cellHeight, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
            
            let fromPoint = getExitPoint(rect: fromRect, to: toPos, from: fromPos)
            let toPoint = getEntryPoint(rect: toRect, from: fromPos, to: toPos)
            
            // Draw dots instead of lines
            let dotRadius: CGFloat = 3
            let dotSpacing: CGFloat = 8
            
            // Calculate distance and number of dots
            let dx = toPoint.x - fromPoint.x
            let dy = toPoint.y - fromPoint.y
            let distance = sqrt(dx * dx + dy * dy)
            let numberOfDots = Int(ceil(Double(distance) / Double(dotSpacing)))
            
            for i in 1...max(1, numberOfDots - 1) {
                let progress = CGFloat(i) / CGFloat(max(2, numberOfDots))
                let dotX = fromPoint.x + dx * progress
                let dotY = fromPoint.y + dy * progress
                let dotPoint = CGPoint(x: dotX, y: dotY)
                
                var circle = Path()
                circle.addEllipse(in: CGRect(x: dotPoint.x - dotRadius, y: dotPoint.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
                context.fill(circle, with: .color(lineColor))
            }
        }
    }
    
    private func getGridPosition(index: Int, gridWidth: Int) -> (row: Int, col: Int) {
        return (index / gridWidth, index % gridWidth)
    }
    
    private func getRectangleBounds(row: Int, col: Int, paddingLeft: CGFloat, paddingTop: CGFloat, cellWidth: CGFloat, cellHeight: CGFloat, horizontalSpacing: CGFloat, verticalSpacing: CGFloat) -> CGRect {
        let x = paddingLeft + CGFloat(col) * (cellWidth + horizontalSpacing)
        let y = paddingTop + CGFloat(row) * (cellHeight + verticalSpacing)
        return CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
    }
    
    private func getExitPoint(rect: CGRect, to toPos: (row: Int, col: Int), from fromPos: (row: Int, col: Int)) -> CGPoint {
        let verticalLineShorten: CGFloat = 15
        // Determine exit point based on direction to target
        if toPos.row > fromPos.row {
            // Moving down - shorten the line
            return CGPoint(x: rect.midX, y: rect.maxY + verticalLineShorten)
        } else if toPos.row < fromPos.row {
            // Moving up - shorten the line
            return CGPoint(x: rect.midX, y: rect.minY - verticalLineShorten)
        } else if toPos.col > fromPos.col {
            // Moving right
            return CGPoint(x: rect.maxX, y: rect.midY)
        } else {
            // Moving left
            return CGPoint(x: rect.minX, y: rect.midY)
        }
    }
    
    private func getEntryPoint(rect: CGRect, from fromPos: (row: Int, col: Int), to toPos: (row: Int, col: Int)) -> CGPoint {
        let verticalLineShorten: CGFloat = 15
        // Determine entry point based on direction from source
        if fromPos.row < toPos.row {
            // Coming from above - shorten the line
            return CGPoint(x: rect.midX, y: rect.minY - verticalLineShorten)
        } else if fromPos.row > toPos.row {
            // Coming from below - shorten the line
            return CGPoint(x: rect.midX, y: rect.maxY + verticalLineShorten)
        } else if fromPos.col < toPos.col {
            // Coming from left
            return CGPoint(x: rect.minX, y: rect.midY)
        } else {
            // Coming from right
            return CGPoint(x: rect.maxX, y: rect.midY)
        }
    }
    
    private func initializeTargetConfigs() {
        // Follow zig-zag pattern for seqNo assignment: 0,1,2,5,4,3,6,7,8,11,10,9
        let zigzagOrder = [0, 1, 2, 5, 4, 3, 6, 7, 8, 11, 10, 9]
        var updated = targetConfigs
        
        print("TargetLinkView: Initializing configs for \(bleManager.networkDevices.count) devices")
        print("TargetLinkView: Device names: \(bleManager.networkDevices.map { $0.name })")
        print("TargetLinkView: Current targetConfigs has \(targetConfigs.count) items")
        print("TargetLinkView: Existing target names: \(targetConfigs.map { $0.targetName })")
        
        // First, ensure all devices have configurations
        for (index, device) in bleManager.networkDevices.enumerated() {
            if !updated.contains(where: { $0.targetName == device.name }) {
                let seqNo = index < zigzagOrder.count ? zigzagOrder[index] + 1 : index + 1
                let newConfig = DrillTargetsConfigData(
                    seqNo: seqNo,
                    targetName: device.name,
                    targetType: defaultTargetType(),
                    timeout: 30.0,
                    countedShots: 5
                )
                updated.append(newConfig)
                print("TargetLinkView: Added config for device \(device.name) at index \(index)")
            } else {
                print("TargetLinkView: Config already exists for device \(device.name)")
            }
        }
        
        // Sort by seqNo to maintain order
        updated.sort { $0.seqNo < $1.seqNo }
        targetConfigs = updated
        print("TargetLinkView: Final targetConfigs has \(targetConfigs.count) items")
    }

    private func updateTargetConfigsForMode() {
        var updated = targetConfigs
        for i in 0..<updated.count {
            updated[i].targetType = defaultTargetType()
            // Reset to default action for mode if needed (mostly for CQB)
            if drillMode == "cqb" {
                updated[i].action = "flash"
            } else {
                updated[i].action = ""
            }
        }
        targetConfigs = updated
    }
    
    private func defaultTargetType() -> String {
        switch drillMode {
        case "ipsc":
            return "ipsc"
        case "idpa":
            return "idpa"
        case "cqb":
            return "cqb_front"
        default:
            return "ipsc"
        }
    }
}

struct TargetRectangleView: View {
    let deviceName: String
    let config: DrillTargetsConfigData?
    let width: CGFloat
    let height: CGFloat
    
    private let accentColor = Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)
    
    var body: some View {
        VStack(spacing: 8) {
            if let config = config, !config.targetType.isEmpty {
                Image(config.primaryTargetType())
                    .resizable()
                    .scaledToFit()
                    .frame(height: height * 0.6)
                    .padding(8)
            } else {
                // Default IPSC target image
                Image("ipsc")
                    .resizable()
                    .scaledToFit()
                    .frame(height: height * 0.6)
                    .padding(8)
            }
            
            Text(deviceName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(accentColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: width, height: height)
        .background(config != nil ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
        .border(config != nil ? accentColor : Color.gray.opacity(0.15), width: 6)
    }
}


