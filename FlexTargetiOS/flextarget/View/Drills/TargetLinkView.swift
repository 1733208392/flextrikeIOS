import SwiftUI
import Foundation
import AudioToolbox

struct TargetLinkView: View {
    let bleManager: BLEManager
    @Binding var targetConfigs: [DrillTargetsConfigData]
    let onDone: () -> Void
    @Binding var drillMode: String
    var hasResults: Bool = false
    var onSettings: (() -> Void)? = nil
    var onStartDrill: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedConfigIndex: Int? = nil
    @State private var navigateToConfig = false
    @State private var popperHitTargets: Set<String> = []
    @State private var navigateToDevice: String? = nil
    
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
                        if !hasResults {
                            drillMode = "ipsc"
                        }
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
                    .disabled(hasResults)
                    
                    // CQB Button
                    Button(action: {
                        if !hasResults {
                            drillMode = "cqb"
                        }
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
                    .disabled(hasResults)
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
                
                if let onStartDrill = onStartDrill {
                    Button(action: onStartDrill) {
                        Text(NSLocalizedString("start_drill", comment: "Start drill button"))
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text(NSLocalizedString("target_link", comment: "Target Link title"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if let onSettings = onSettings {
                    Button(action: onSettings) {
                        Image(systemName: "gear")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433))
                    }
                }
            }
        }
        .onAppear {
            print("TargetLinkView: onAppear called with deviceList.count = \(bleManager.networkDevices.count)")
            initializeTargetConfigs()
        }
        .onReceive(bleManager.$networkDevices) { devices in
            updateTargetNamesForConnectedDevices(devices)
        }
        .onReceive(NotificationCenter.default.publisher(for: .blePopperHitReceived)) { notification in
            guard let targetName = notification.userInfo?["targetName"] as? String else { return }
            let hasPopper = targetConfigs.first { $0.targetName == String(targetName.dropLast(3)) }?.hasPhysicalPopper ?? false
            guard hasPopper else { return }
            AudioServicesPlaySystemSound(1104)
            popperHitTargets.insert(targetName)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                popperHitTargets.remove(targetName)
            }
        }
    }
    
    private func togglePopper(for deviceName: String) {
        if let index = targetConfigs.firstIndex(where: { $0.targetName == deviceName }) {
            targetConfigs[index].hasPhysicalPopper.toggle()
        }
    }
    
    private func updateTargetNamesForConnectedDevices(_ devices: [NetworkDevice]) {
        guard !devices.isEmpty else { return }
        
        var updated = targetConfigs
        var modified = false
        
        for (index, device) in devices.enumerated() {
            if index < updated.count {
                if updated[index].targetName != device.name {
                    print("TargetLinkView: Updating target name from \(updated[index].targetName) to \(device.name) at index \(index)")
                    updated[index].targetName = device.name
                    modified = true
                }
            } else {
                // Add new config if we have more devices than configs
                let zigzagOrder = [0, 1, 2, 5, 4, 3, 6, 7, 8, 11, 10, 9]
                let seqNo = index < zigzagOrder.count ? zigzagOrder[index] + 1 : index + 1
                let newConfig = DrillTargetsConfigData(
                    seqNo: seqNo,
                    targetName: device.name,
                    targetType: defaultTargetType(),
                    timeout: 30.0,
                    countedShots: 5
                )
                updated.append(newConfig)
                modified = true
                print("TargetLinkView: Added config for new device \(device.name) at index \(index)")
            }
        }
        
        if modified {
            targetConfigs = updated
        }
    }
    
    @ViewBuilder
    private var gridContent: some View {
        LazyVGrid(columns: gridColumns, spacing: 40) {
            ForEach(Array(buildGridItems().enumerated()), id: \.offset) { (_, item) in
                gridCell(for: item)
            }
        }
        .padding(16)
    }
    
    private func drawConnectionLines(context: inout GraphicsContext, canvasSize: CGSize) {
        let gridWidth = 3
        let horizontalSpacing: CGFloat = 12  // matches GridItem(.flexible(), spacing: 12)
        let verticalSpacing: CGFloat = 40
        let paddingLeftRight: CGFloat = 16
        let paddingTop: CGFloat = 16
        let lineColor = Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)
        let dotRadius: CGFloat = 3
        let dotSpacing: CGFloat = 8

        let availableWidth = canvasSize.width - 2 * paddingLeftRight
        let cellWidth = (availableWidth - CGFloat(gridWidth - 1) * horizontalSpacing) / CGFloat(gridWidth)
        let cellHeight = rectangleHeight
        // Fixed-width content is centred inside each flexible column
        let contentOffsetX = (cellWidth - rectangleWidth) / 2

        let deviceGridIndices = buildGridItems().enumerated().compactMap { (i, item) -> Int? in
            if case .device = item { return i } else { return nil }
        }

        for i in 0..<(deviceGridIndices.count - 1) {
            let fromIndex = deviceGridIndices[i]
            let toIndex = deviceGridIndices[i + 1]
            let fromPos = getGridPosition(index: fromIndex, gridWidth: gridWidth)
            let toPos = getGridPosition(index: toIndex, gridWidth: gridWidth)

            let rawFrom = getRectangleBounds(row: fromPos.row, col: fromPos.col, paddingLeft: paddingLeftRight, paddingTop: paddingTop, cellWidth: cellWidth, cellHeight: cellHeight, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
            let rawTo = getRectangleBounds(row: toPos.row, col: toPos.col, paddingLeft: paddingLeftRight, paddingTop: paddingTop, cellWidth: cellWidth, cellHeight: cellHeight, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
            let fromRect = CGRect(x: rawFrom.minX + contentOffsetX, y: rawFrom.minY, width: rectangleWidth, height: cellHeight)
            let toRect = CGRect(x: rawTo.minX + contentOffsetX, y: rawTo.minY, width: rectangleWidth, height: cellHeight)

            // Build waypoints: for same-row non-adjacent devices (popper in between),
            // route below the row to avoid drawing through the popper cell.
            var waypoints: [CGPoint]
            if fromPos.row == toPos.row && abs(toPos.col - fromPos.col) > 1 {
                let routeY = fromRect.maxY + verticalSpacing * 0.4
                let fromX = toPos.col > fromPos.col ? fromRect.maxX : fromRect.minX
                let toX   = toPos.col > fromPos.col ? toRect.minX  : toRect.maxX
                waypoints = [
                    CGPoint(x: fromX, y: fromRect.midY),
                    CGPoint(x: fromX, y: routeY),
                    CGPoint(x: toX,   y: routeY),
                    CGPoint(x: toX,   y: toRect.midY)
                ]
            } else {
                waypoints = [
                    getExitPoint(rect: fromRect, to: toPos, from: fromPos),
                    getEntryPoint(rect: toRect, from: fromPos, to: toPos)
                ]
            }

            // Draw dots along each segment of the path
            for s in 0..<(waypoints.count - 1) {
                let p0 = waypoints[s]
                let p1 = waypoints[s + 1]
                let dx = p1.x - p0.x
                let dy = p1.y - p0.y
                let distance = sqrt(dx * dx + dy * dy)
                guard distance > 0 else { continue }
                let numberOfDots = Int(ceil(Double(distance) / Double(dotSpacing)))
                for j in 1...max(1, numberOfDots - 1) {
                    let progress = CGFloat(j) / CGFloat(max(2, numberOfDots))
                    var circle = Path()
                    circle.addEllipse(in: CGRect(
                        x: p0.x + dx * progress - dotRadius,
                        y: p0.y + dy * progress - dotRadius,
                        width: dotRadius * 2, height: dotRadius * 2
                    ))
                    context.fill(circle, with: .color(lineColor))
                }
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

    private func sendGreeting(to deviceName: String) {
        let message: [String: Any] = [
            "action": "netlink_forward",
            "dest": deviceName,
            "content": ["command": "greeting"]
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            bleManager.writeJSON(jsonString)
            print("[TargetLinkView] Sent greeting to: \(deviceName)")
        }
    }

    private func buildGridItems() -> [TargetGridItem] {
        var items: [TargetGridItem] = []
        for device in bleManager.networkDevices {
            if items.count >= 12 { break }
            let config = targetConfigs.first { $0.targetName == device.name }
            items.append(.device(device: device, config: config))
            if config?.hasPhysicalPopper == true && items.count < 12 {
                items.append(.popper(parentDeviceName: device.name))
            }
        }
        while items.count < 12 { items.append(.empty) }
        return items
    }

    @ViewBuilder
    private func gridCell(for item: TargetGridItem) -> some View {
        switch item {
        case .device(let device, let config):
            // ZStack(alignment: .topTrailing) so the + button sits at the top-right corner.
            // The button is a ZStack sibling – placed after (on top of) the gestured
            // view – so SwiftUI's hit-testing picks the button first for its area
            // and never falls through to the navigation gesture below.
            ZStack(alignment: .topTrailing) {
                // Programmatic NavigationLink – activated by state, not by tap gesture directly
                NavigationLink(
                    destination: TargetConfigListViewV2(
                        deviceList: bleManager.networkDevices,
                        targetConfigs: $targetConfigs,
                        onDone: onDone,
                        drillMode: $drillMode,
                        singleDeviceMode: true,
                        deviceNameFilter: device.name,
                        isFromTargetLink: true,
                        hasResults: hasResults,
                        onSettings: onSettings,
                        onStartDrill: onStartDrill
                    ),
                    tag: device.name,
                    selection: $navigateToDevice
                ) { EmptyView() }
                .hidden()

                TargetRectangleView(
                    deviceName: device.name,
                    config: config,
                    width: rectangleWidth,
                    height: rectangleHeight,
                    onTogglePopper: nil  // button is lifted out to the ZStack below
                )
                .contentShape(Rectangle())
                .gesture(
                    // Double tap takes exclusive priority: if two taps arrive quickly,
                    // send a greeting. Otherwise the single-tap fallback triggers navigation.
                    TapGesture(count: 2)
                        .onEnded { sendGreeting(to: device.name) }
                        .exclusively(before:
                            TapGesture(count: 1)
                                .onEnded { navigateToDevice = device.name }
                        )
                )

                // + button is a ZStack sibling (frontmost layer) so it is hit-tested
                // before the gesture view and does not trigger navigation.
                if config?.hasPhysicalPopper != true {
                    Button(action: { togglePopper(for: device.name) }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .popper(let parentDeviceName):
            PopperRectangleView(
                parentDeviceName: parentDeviceName,
                width: rectangleWidth,
                height: rectangleHeight,
                popperHitAnimating: popperHitTargets.contains("\(parentDeviceName)-01"),
                onRemove: { togglePopper(for: parentDeviceName) }
            )
        case .empty:
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                .frame(width: rectangleWidth, height: rectangleHeight)
        }
    }
}

struct TargetRectangleView: View {
    let deviceName: String
    let config: DrillTargetsConfigData?
    let width: CGFloat
    let height: CGFloat
    var onTogglePopper: (() -> Void)? = nil

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
        .overlay(alignment: .topTrailing) {
            if let onTogglePopper = onTogglePopper {
                Button(action: onTogglePopper) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private enum TargetGridItem {
    case device(device: NetworkDevice, config: DrillTargetsConfigData?)
    case popper(parentDeviceName: String)
    case empty
}

struct PopperRectangleView: View {
    let parentDeviceName: String
    let width: CGFloat
    let height: CGFloat
    var popperHitAnimating: Bool = false
    var onRemove: (() -> Void)? = nil

    private let accentColor = Color(red: 0.8705882352941177, green: 0.2196078431372549, blue: 0.13725490196078433)

    var body: some View {
        VStack(spacing: 8) {
            Image("popper")
                .resizable()
                .scaledToFit()
                .frame(height: height * 0.6)
                .padding(8)
                .scaleEffect(popperHitAnimating ? 1.3 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: popperHitAnimating)

            Text(parentDeviceName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(accentColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: width, height: height)
        .background(Color.gray.opacity(0.2))
        .border(accentColor, width: 6)
        .overlay(alignment: .topTrailing) {
            Button(action: { onRemove?() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(accentColor)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
    }
}


