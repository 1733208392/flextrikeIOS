import SwiftUI
import UIKit
import CoreData
import AVFoundation

enum DrillFormMode {
    case add
    case edit(DrillSetup)
    
    var saveButtonText: String {
        switch self {
        case .add: return NSLocalizedString("save_drill", comment: "Save drill button")
        case .edit: return NSLocalizedString("save_changes", comment: "Save changes button")
        }
    }
    
    var isEditMode: Bool {
        if case .edit = self {
            return true
        }
        return false
    }
}

struct DrillFormView: View {
    let bleManager: BLEManager
    let mode: DrillFormMode
    
    @State private var drillName: String = ""
    @State private var description: String = ""
    @State private var demoVideoURL: URL? = nil
    @State private var showFilePicker: Bool = false
    @State private var demoVideoThumbnail: UIImage? = nil
    @State private var thumbnailFileURL: URL? = nil
    @State private var showVideoPlayer: Bool = false
    // delayType removed; only random mode is supported now
    // Default to be 2-5s non configurable
    @State private var repeatsValue: Int = 1
    @State private var pauseValue: Int = 5
    @State private var drillDuration: Double = 5
    @State private var targets: [DrillTargetsConfigData] = []
    @State private var isTargetListReceived: Bool = false
    @State private var targetConfigs: [DrillTargetsConfigData] = []
    @State private var navigateToDrillSummary: Bool = false
    @State private var drillRepeatSummaries: [DrillRepeatSummary] = []
    // expected devices are derived from drill targetConfigs (by targetName)
    @State private var expectedDevices: [String] = []
    @State private var executionManager: DrillExecutionManager? = nil
    @State private var showAckTimeoutAlert: Bool = false
    @State private var isDrillInProgress: Bool = false
    @State private var dotCount: Int = 0
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var environmentContext

    private var viewContext: NSManagedObjectContext {
        if let coordinator =  environmentContext.persistentStoreCoordinator,
           coordinator.persistentStores.isEmpty == false {
            return environmentContext
        }
        return PersistenceController.shared.container.viewContext
    }

    private var currentDrillSetup: DrillSetup? {
        if case .edit(let setup) = mode {
            return setup
        }
        return nil
    }

    private var progressText: String {
        let base = NSLocalizedString("drill_in_progress", comment: "Drill in progress")
        return base + String(repeating: ".", count: dotCount)
    }
    
    init(bleManager: BLEManager, mode: DrillFormMode) {
        self.bleManager = bleManager
        self.mode = mode
        
        // Pre-populate fields if editing
        if case .edit(let drillSetup) = mode {
            _drillName = State(initialValue: drillSetup.name ?? "")
            _description = State(initialValue: drillSetup.desc ?? "")
            _demoVideoURL = State(initialValue: drillSetup.demoVideoURL)
            _thumbnailFileURL = State(initialValue: drillSetup.thumbnailURL)
//            _delayValue = State(initialValue: drillSetup.delay)
            _repeatsValue = State(initialValue: Int(drillSetup.repeats))
            _pauseValue = State(initialValue: Int(drillSetup.pause))
            _drillDuration = State(initialValue: drillSetup.drillDuration)
            
            let coreDataTargets = (drillSetup.targets as? Set<DrillTargetsConfig>) ?? []
            let targetsArray = coreDataTargets.sorted(by: { $0.seqNo < $1.seqNo }).map { $0.toStruct() }
            _targets = State(initialValue: targetsArray)
            _targetConfigs = State(initialValue: targetsArray)
        }
        
        // Note: Cannot call viewContext.rollback() here because viewContext is not initialized yet
        // Will handle cleanup in onAppear
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    Color.black.ignoresSafeArea()
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    
                    VStack(spacing: 20) {
                        // History Record Button - only show in edit mode
                        if let drillSetup = currentDrillSetup {
                            NavigationLink(destination: DrillRecordView(drillSetup: drillSetup)
                                .environment(\.managedObjectContext, viewContext)) {
                                HStack {
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.red, lineWidth: 1)
                                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.clear))
                                        .frame(height: 36)
                                        .overlay(
                                            HStack(spacing: 8) {
                                                Image(systemName: "clock.arrow.circlepath")
                                                    .foregroundColor(.red)
                                                    .font(.title3)
                                                Text("History Record")
                                                    .foregroundColor(.white)
                                                    .font(.footnote)
                                            }
                                        )
                                        .padding(.horizontal)
                                        .padding(.top)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        ScrollView {
                            // Grouped Section: Drill Name, Description, Add Video
                            VStack(spacing: 20) {
                                DrillNameSectionView(drillName: $drillName)
                                
                                DescriptionVideoSectionView(
                                    description: $description,
                                    demoVideoURL: $demoVideoURL,
                                    demoVideoThumbnail: $demoVideoThumbnail,
                                    thumbnailFileURL: $thumbnailFileURL,
                                    showVideoPlayer: $showVideoPlayer
                                )
                                .sheet(isPresented: $showVideoPlayer) {
                                    if let url = demoVideoURL {
                                        VideoPlayerView(url: url)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(20)
                            .padding(.horizontal)
                            
                            // Delay of Set Starting
                            RepeatsConfigView(
                                repeatsValue: $repeatsValue
                            )
                            .padding(.horizontal)
                            
                            // Drill Duration
                            DrillDurationConfigurationView(
                                drillDuration: $drillDuration
                            )
                            .padding(.horizontal)
                            
                            // Drill Setup Field
                            TargetsSectionView(
                                isTargetListReceived: $isTargetListReceived,
                                bleManager: bleManager,
                                targetConfigs: $targetConfigs,
                                onTargetConfigDone: { targets = targetConfigs }
                            )
                            .padding(.horizontal)
                            
                            Spacer()
                            
                            // Bottom Buttons
                            actionButtons
                        }
                        .onAppear {
                            // Clean up any leftover inserted objects from previous attempts
                            if viewContext.hasChanges {
                                print("⚠️ ViewContext has unsaved changes on appear, rolling back...")
                                print("  Inserted: \(viewContext.insertedObjects.count)")
                                print("  Updated: \(viewContext.updatedObjects.count)")
                                print("  Deleted: \(viewContext.deletedObjects.count)")
                                viewContext.rollback()
                            }
                            
                            queryDeviceList()
                            loadThumbnailIfNeeded()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .bleDeviceListUpdated)) { notification in
                            handleDeviceListUpdate(notification)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .bleNetlinkForwardReceived)) { notification in
                            handleNetlinkForward(notification)
                        }
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                    }
                }
            }
            .environment(\.managedObjectContext, viewContext)
            
            NavigationLink(isActive: $navigateToDrillSummary) {
                if case .edit(let drillSetup) = mode {
                    DrillSummaryView(drillSetup: drillSetup, summaries: drillRepeatSummaries)
                        .environment(\.managedObjectContext, viewContext)
                }
            } label: {
                EmptyView()
            }
        }
        .alert(isPresented: $showAckTimeoutAlert) {
            Alert(title: Text(NSLocalizedString("ack_timeout_title", comment: "ACK timeout")), message: Text(NSLocalizedString("ack_timeout_message", comment: "Not all devices responded in time")), dismissButton: .default(Text("OK")))
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if isDrillInProgress {
                dotCount = (dotCount + 1) % 4
            } else {
                dotCount = 0
            }
        }
        .overlay(
            Group {
                if isDrillInProgress {
                    ZStack {
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                        Text(progressText)
                            .foregroundColor(.white)
                            .font(.largeTitle)
                            .bold()
                    }
                }
            }
        )
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Button(action: saveDrill) {
                Text(mode.saveButtonText)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(bleManager.isConnected ? Color.red : Color.gray)
                    .cornerRadius(8)
            }
            .disabled(!bleManager.isConnected)
            
            if case .edit = mode {
                Button(action: startDrill) {
                    Text(NSLocalizedString("start_drill", comment: "Start drill button"))
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(bleManager.isConnected ? Color.green : Color.gray)
                        .cornerRadius(8)
                }
                .disabled(!bleManager.isConnected)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    // MARK: - Save Logic
    
    private func saveDrill() {
        targets = targetConfigs
        
        do {
            // Ensure any picked temp files are moved into app Documents for persistence
            if let tempVideo = demoVideoURL, tempVideo.path.starts(with: FileManager.default.temporaryDirectory.path) {
                if let moved = moveFileToDocuments(from: tempVideo) {
                    demoVideoURL = moved
                } else {
                    print("Warning: Failed to move video from temp to Documents, keeping temp path")
                }
            }
            if let tempThumb = thumbnailFileURL, tempThumb.path.starts(with: FileManager.default.temporaryDirectory.path) {
                if let moved = moveFileToDocuments(from: tempThumb) {
                    thumbnailFileURL = moved
                } else {
                    print("Warning: Failed to move thumbnail from temp to Documents, keeping temp path")
                }
            }

            switch mode {
            case .add:
                createNewDrillSetup()
                
            case .edit(let drillSetup):
                updateExistingDrillSetup(drillSetup)
            }
            
            // Ensure save happens on main thread
            if viewContext.hasChanges {
                print("Context has changes, attempting to save...")
                
                // Check if context is valid
                print("ViewContext description: \(viewContext)")
                print("Persistent store coordinator: \(String(describing: viewContext.persistentStoreCoordinator))")
                print("Persistent stores: \(viewContext.persistentStoreCoordinator?.persistentStores.count ?? 0)")
                print("Inserted objects count: \(viewContext.insertedObjects.count)")
                print("Updated objects count: \(viewContext.updatedObjects.count)")
                print("Deleted objects count: \(viewContext.deletedObjects.count)")
                
                // Try to validate all inserted objects
                for object in viewContext.insertedObjects {
                    do {
                        try object.validateForInsert()
                        print("Validation passed for: \(object)")
                    } catch let validationError {
                        print("Validation failed for \(object): \(validationError)")
                        throw validationError
                    }
                }
                
                // Try to save - explicitly ensure we're on the right thread
                print("About to save - Thread check:")
                print("  Is main thread: \(Thread.isMainThread)")
                print("  Context concurrency type: \(viewContext.concurrencyType.rawValue)")
                
                // Check if persistent store is available
                guard let coordinator = viewContext.persistentStoreCoordinator else {
                    print("ERROR: No persistent store coordinator!")
                    throw NSError(domain: "DrillFormView", code: -1, userInfo: [NSLocalizedDescriptionKey: "No persistent store coordinator"])
                }
                
                if coordinator.persistentStores.isEmpty {
                    print("ERROR: No persistent stores loaded!")
                    throw NSError(domain: "DrillFormView", code: -2, userInfo: [NSLocalizedDescriptionKey: "No persistent stores loaded"])
                }
                
                print("Persistent stores loaded: \(coordinator.persistentStores.count)")
                for (index, store) in coordinator.persistentStores.enumerated() {
                    print("  Store \(index): \(store.type) at \(store.url?.path ?? "unknown")")
                }
                
                do {
                    // Force save on context's queue
                    try viewContext.save()
                    print("Save successful!")

                    // Notify listeners that the repository changed so UI can refresh
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .drillRepositoryDidChange, object: nil)
                    }
                } catch let saveError as NSError {
                    print("Save failed with NSError:")
                    print("  localizedDescription: \(saveError.localizedDescription)")
                    print("  code: \(saveError.code)")
                    print("  domain: \(saveError.domain)")
                    print("  userInfo keys: \(saveError.userInfo.keys)")
                    for (key, value) in saveError.userInfo {
                        print("    \(key): \(value)")
                    }
                    
                    // Try to get more details from the error
                    if let underlyingError = saveError.userInfo[NSUnderlyingErrorKey] as? NSError {
                        print("Underlying error found:")
                        print("  description: \(underlyingError)")
                        print("  domain: \(underlyingError.domain)")
                        print("  code: \(underlyingError.code)")
                        print("  userInfo: \(underlyingError.userInfo)")
                    }
                    
                    // Check for Core Data specific error keys
                    if let affectedObjects = saveError.userInfo[NSAffectedObjectsErrorKey] as? [NSManagedObject] {
                        print("Affected objects: \(affectedObjects)")
                    }
                    
                    if let validationKey = saveError.userInfo[NSValidationKeyErrorKey] {
                        print("Validation key: \(validationKey)")
                    }
                    
                    if let validationObject = saveError.userInfo[NSValidationObjectErrorKey] {
                        print("Validation object: \(validationObject)")
                    }
                    
                    throw saveError
                }
            } else {
                print("No changes to save")
            }
            presentationMode.wrappedValue.dismiss()
        } catch let error as NSError {
            print("Failed to save drill setup: \(error.localizedDescription)")
            print("Error code: \(error.code)")
            print("Error domain: \(error.domain)")
            print("Error userInfo: \(error.userInfo)")
            if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                for detailedError in detailedErrors {
                    print("Detailed error: \(detailedError.localizedDescription)")
                    print("Failed object: \(detailedError.userInfo)")
                }
            }
            
            // Rollback the failed changes to clean up the context
            print("Rolling back failed changes...")
            viewContext.rollback()
        } catch {
            print("Unknown error: \(error)")
            
            // Rollback on unknown error too
            print("Rolling back failed changes...")
            viewContext.rollback()
        }
    }
    
    private func startDrill() {
        guard case .edit(let drillSetup) = mode else { return }

        isDrillInProgress = true
        dotCount = 0

        drillRepeatSummaries.removeAll()
        navigateToDrillSummary = false
        
        // Save changes before starting
        targets = targetConfigs
        updateExistingDrillSetup(drillSetup)
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save drill setup before starting: \(error)")
        }
        
        // Use the current drill targetConfigs as the expected devices
        expectedDevices = targetConfigs.compactMap { $0.targetName }
        
        // Create and start drill execution manager
        let executionManager = DrillExecutionManager(
            bleManager: bleManager,
            drillSetup: drillSetup,
            expectedDevices: expectedDevices,
            onComplete: { summaries in
                DispatchQueue.main.async {
                    self.drillRepeatSummaries = summaries
                    self.saveDrillResultsFromSummaries(summaries, for: drillSetup)
                    self.navigateToDrillSummary = true
                    self.executionManager = nil
                    self.isDrillInProgress = false
                }
            },
            onFailure: {
                DispatchQueue.main.async {
                    self.showAckTimeoutAlert = true
                    self.executionManager = nil
                    self.isDrillInProgress = false
                }
            }
        )
        
        // Store reference to handle notifications
        self.executionManager = executionManager
        executionManager.startExecution()
    }

    private func handleNetlinkForward(_ notification: Notification) {
        executionManager?.handleNetlinkForward(notification)
    }
    
    // MARK: - CoreData Operations
    
    private func createNewDrillSetup() {
        let drillSetup = DrillSetup(context: viewContext)
        drillSetup.id = UUID()
        drillSetup.name = drillName
        drillSetup.desc = description
        
        // Set URLs - ensure they're valid file URLs
        if let videoURL = demoVideoURL {
            print("Setting demoVideoURL: \(videoURL.absoluteString)")
            print("  isFileURL: \(videoURL.isFileURL)")
            print("  path: \(videoURL.path)")
            
            // Try standardizing the URL to ensure it's properly formatted
            let standardizedURL = videoURL.standardized
            print("  standardized: \(standardizedURL.absoluteString)")
            drillSetup.demoVideoURL = standardizedURL
        }
        
        if let thumbURL = thumbnailFileURL {
            print("Setting thumbnailURL: \(thumbURL.absoluteString)")
            print("  isFileURL: \(thumbURL.isFileURL)")
            print("  path: \(thumbURL.path)")
            
            // Try standardizing the URL to ensure it's properly formatted
            let standardizedURL = thumbURL.standardized
            print("  standardized: \(standardizedURL.absoluteString)")
            drillSetup.thumbnailURL = standardizedURL
        }
        
        drillSetup.repeats = repeatsValue
        drillSetup.pause = pauseValue
        drillSetup.drillDuration = drillDuration
        
        print("Creating drill setup with:")
        print("  name: \(drillName)")
        print("  desc: \(description)")
        print("  repeats: \(repeatsValue)")
        print("  drillDuration: \(drillDuration)")
        print("  targetConfigs count: \(targetConfigs.count)")
        
        // Add targets - use the Core Data relationship method instead of direct assignment
        for (index, targetData) in targetConfigs.enumerated() {
            let target = DrillTargetsConfig(context: viewContext)
            target.id = targetData.id  // Ensure id is never nil
            target.seqNo = Int32(targetData.seqNo)
            target.targetName = targetData.targetName
            target.targetType = targetData.targetType
            target.timeout = targetData.timeout
            target.countedShots = Int32(targetData.countedShots)
            
            // Use the Core Data generated method to establish relationship
            drillSetup.addToTargets(target)
            
            print("  Added target \(index): \(targetData.targetName) with id: \(target.id?.uuidString ?? "nil")")
            print("    Relationship established: drillSetup.targets count = \((drillSetup.targets?.count ?? 0))")
        }
        
        // Try to validate before saving
        do {
            try drillSetup.validateForInsert()
            print("Drill setup validation passed")
        } catch {
            print("Drill setup validation failed: \(error)")
        }
        
        // Validate all targets too
        for target in viewContext.insertedObjects where target is DrillTargetsConfig {
            do {
                try (target as! DrillTargetsConfig).validateForInsert()
            } catch {
                print("Target validation failed: \(error)")
            }
        }
    }
    
    private func updateExistingDrillSetup(_ drillSetup: DrillSetup) {
        // Clean up old video file if we're replacing it with a new one
        if let oldVideoURL = drillSetup.demoVideoURL,
           let newVideoURL = demoVideoURL,
           oldVideoURL != newVideoURL {
            do {
                if FileManager.default.fileExists(atPath: oldVideoURL.path) {
                    try FileManager.default.removeItem(at: oldVideoURL)
                    print("Deleted old video file: \(oldVideoURL.lastPathComponent)")
                }
            } catch {
                print("Failed to delete old video file: \(error)")
            }
        }
        
        // Clean up old thumbnail file if we're replacing it with a new one
        if let oldThumbnailURL = drillSetup.thumbnailURL,
           let newThumbnailURL = thumbnailFileURL,
           oldThumbnailURL != newThumbnailURL {
            do {
                if FileManager.default.fileExists(atPath: oldThumbnailURL.path) {
                    try FileManager.default.removeItem(at: oldThumbnailURL)
                    print("Deleted old thumbnail file: \(oldThumbnailURL.lastPathComponent)")
                }
            } catch {
                print("Failed to delete old thumbnail file: \(error)")
            }
        }
        
        drillSetup.name = drillName
        drillSetup.desc = description
        drillSetup.demoVideoURL = demoVideoURL
        drillSetup.thumbnailURL = thumbnailFileURL
        drillSetup.repeats = repeatsValue
        drillSetup.pause = pauseValue
        drillSetup.drillDuration = drillDuration
        
        // Clear and update targets
        if let existingTargets = drillSetup.targets {
            drillSetup.removeFromTargets(existingTargets)
        }
        
        for targetData in targetConfigs {
            let target = DrillTargetsConfig(context: viewContext)
            target.id = targetData.id  // Ensure id is never nil
            target.seqNo = Int32(targetData.seqNo)
            target.targetName = targetData.targetName
            target.targetType = targetData.targetType
            target.timeout = targetData.timeout
            target.countedShots = Int32(targetData.countedShots)
            
            // Use the Core Data generated method to establish relationship
            drillSetup.addToTargets(target)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadThumbnailIfNeeded() {
        // If we have a thumbnail URL, try to load it and validate existence
        if let url = thumbnailFileURL {
            // Check if file exists before attempting to load
            if !FileManager.default.fileExists(atPath: url.path) {
                print("Thumbnail file does not exist at: \(url.path)")
                print("Clearing invalid thumbnail reference")
                thumbnailFileURL = nil
                demoVideoThumbnail = nil
            } else {
                do {
                    let data = try Data(contentsOf: url)
                    if let image = UIImage(data: data) {
                        demoVideoThumbnail = image
                        print("Successfully loaded thumbnail: \(url.lastPathComponent)")
                    } else {
                        print("Failed to create UIImage from thumbnail data")
                        thumbnailFileURL = nil
                        demoVideoThumbnail = nil
                    }
                } catch {
                    print("Failed to load thumbnail: \(error)")
                    print("Clearing invalid thumbnail reference")
                    thumbnailFileURL = nil
                    demoVideoThumbnail = nil
                }
            }
            return
        }

        // If there's no thumbnail file but we do have a saved demo video, try to regenerate the thumbnail
        if let videoURL = demoVideoURL, FileManager.default.fileExists(atPath: videoURL.path) {
            print("No thumbnail file found, attempting to regenerate from video: \(videoURL.lastPathComponent)")
            DispatchQueue.global(qos: .userInitiated).async {
                if let image = self.generateThumbnailSync(for: videoURL), let jpeg = image.jpegData(compressionQuality: 0.8) {
                    if let saved = self.saveThumbnailDataToDocuments(jpeg) {
                        DispatchQueue.main.async {
                            self.thumbnailFileURL = saved
                            self.demoVideoThumbnail = image
                            print("Regenerated and saved thumbnail: \(saved.lastPathComponent)")
                        }
                        return
                    } else {
                        print("Failed to save regenerated thumbnail to Documents")
                    }
                } else {
                    print("Failed to generate thumbnail from video: \(videoURL)")
                }
            }
        }
    }

    // Synchronous thumbnail generation helper (used from background thread)
    private func generateThumbnailSync(for url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            // Optionally crop or scale if needed; return as-is for now
            return uiImage
        } catch {
            print("generateThumbnailSync error: \(error)")
            return nil
        }
    }

    // Save JPEG data into Documents and return URL
    private func saveThumbnailDataToDocuments(_ data: Data) -> URL? {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try data.write(to: dest)
            return dest
        } catch {
            print("Failed to write thumbnail data to Documents: \(error)")
            return nil
        }
    }

    // Move a file from temp directory into app Documents and return new URL
    private func moveFileToDocuments(from url: URL) -> URL? {
        let fileManager = FileManager.default
        
        // Check if source file exists
        guard fileManager.fileExists(atPath: url.path) else {
            print("Source file does not exist at: \(url.path)")
            return nil
        }
        
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent(UUID().uuidString + "." + (url.pathExtension.isEmpty ? "dat" : url.pathExtension))
        do {
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try fileManager.copyItem(at: url, to: dest)
            print("Successfully moved file to Documents: \(dest.lastPathComponent)")
            // Try to remove the original temp file after successful copy
            do { try fileManager.removeItem(at: url) } catch { print("Could not remove temp file: \(error)") }
            return dest
        } catch {
            print("Failed to move file to Documents: \(error.localizedDescription)")
            print("Source: \(url.path)")
            print("Destination: \(dest.path)")
            return nil
        }
    }
    

    
    // MARK: - Device List Query
    
    private func queryDeviceList() {
        guard bleManager.isConnected else {
            print("BLE not connected, cannot query device list")
            return
        }
        
        let command = ["action": "netlink_query_device_list"]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: command, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Query message length: \(jsonData.count)")
                bleManager.writeJSON(jsonString)
                print("Sent netlink_query_device_list command: \(jsonString)")
            }
        } catch {
            print("Failed to serialize netlink_query_device_list command: \(error)")
        }
        
        #if targetEnvironment(simulator)
        // In simulator, immediately post the device list notification with mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: .bleDeviceListUpdated,
                object: nil,
                userInfo: ["device_list": self.bleManager.networkDevices]
            )
        }
        #endif
    }
    
    private func handleDeviceListUpdate(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deviceList = userInfo["device_list"] as? [NetworkDevice] {
            print("Device list received with \(deviceList.count) devices")
            DispatchQueue.main.async {
                self.isTargetListReceived = true
            }
        }
    }
    
    private func saveDrillResultsFromSummaries(_ summaries: [DrillRepeatSummary], for drillSetup: DrillSetup) {
        guard let drillId = drillSetup.id else {
            print("Failed to save drill results: drillSetup.id is nil")
            return
        }
        
        let context = drillSetup.managedObjectContext ?? viewContext
        
        // Generate a unique session ID for all results from this execution
        let sessionId = UUID()
        
        for summary in summaries {
            let drillResult = DrillResult(context: context)
            drillResult.drillId = drillId
            drillResult.sessionId = sessionId
            drillResult.date = Date()
            drillResult.drillSetup = drillSetup
            
            for shotData in summary.shots {
                let shot = Shot(context: context)
                do {
                    let jsonData = try JSONEncoder().encode(shotData)
                    shot.data = String(data: jsonData, encoding: .utf8)
                } catch {
                    print("Failed to encode shot data: \(error)")
                    shot.data = nil
                }
                shot.timestamp = Date()
                shot.drillResult = drillResult
            }
        }
        
        do {
            try context.save()
            print("Drill results saved successfully for \(summaries.count) repeats")
        } catch let error as NSError {
            print("Failed to save drill results: \(error)")
            print("Error domain: \(error.domain)")
            print("Error code: \(error.code)")
            print("Error userInfo: \(error.userInfo)")
            
            if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                for detailedError in detailedErrors {
                    print("Detailed error: \(detailedError)")
                }
            }
        }
    }
}

// MARK: - Preview
struct DrillFormView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        Group {
            DrillFormView(bleManager: BLEManager.shared, mode: .add)
                .environment(\.managedObjectContext, context)
                .environmentObject(BLEManager.shared)
                .previewDisplayName("Add Mode")
            
            DrillFormView(bleManager: BLEManager.shared, mode: .edit(mockDrillSetup(context: context)))
                .environment(\.managedObjectContext, context)
                .environmentObject(BLEManager.shared)
                .previewDisplayName("Edit Mode")
        }
    }
    
    static func mockDrillSetup(context: NSManagedObjectContext) -> DrillSetup {
        let drillSetup = DrillSetup(context: context)
        drillSetup.id = UUID()
        drillSetup.name = "Sample Drill"
        drillSetup.desc = "A sample drill for testing"
        drillSetup.delay = 5.0
        drillSetup.repeats = 1
        drillSetup.pause = 5
        drillSetup.drillDuration = 15.0
        
        let target = DrillTargetsConfig(context: context)
        target.id = UUID()
        target.seqNo = 1
        target.targetName = "Target 1"
        target.targetType = "Standard"
        target.timeout = 30
        target.countedShots = 5
        target.drillSetup = drillSetup
        
        return drillSetup
    }
}
