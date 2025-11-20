import SwiftUI
import PhotosUI

struct DrillMainPageView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var showDrillList = false
    @State private var showConnectView = false
    @State private var showInfo = false
    @State private var selectedDrillSetup: DrillSetup? = nil
    @State private var selectedDrillShots: [ShotData]? = nil
    @State private var selectedDrillSummaries: [DrillRepeatSummary]? = nil
    @State private var showError = false
    @State private var errorMessage = ""
    let persistenceController = PersistenceController.shared
    @State private var errorObserver: NSObjectProtocol?
    
    // Image Transfer States
    @State private var showPhotoPicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var isTransferring = false
    @State private var transferProgress = 0
    @State private var transferMessage = ""
    @State private var showTransferAlert = false
    
    // iOS 16+ PhotosPicker
    @State private var selectedPhotoItem: Any? = nil
    
    // Image Crop Navigation
    @State private var showImageCrop = false
    
    private let imageTransferManager = ImageTransferManager()
    
    var body: some View {
        if showDrillList {
            DrillListView(bleManager: bleManager, showDrillList: $showDrillList)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        } else {
            mainContent
                .sheet(isPresented: $showConnectView) {
                    ConnectSmartTargetWrapper(onDismiss: { showConnectView = false })
                }
                .sheet(isPresented: $showInfo) {
                    InformationPage()
                }
                .sheet(isPresented: $showPhotoPicker) {
                    ImagePickerView { image in
                        if let image = image {
                            selectedImage = image
                            startImageTransfer(image)
                        }
                        showPhotoPicker = false
                    }
                }
                .onAppear {
                    if !bleManager.isConnected {
                        showConnectView = true
                    }
                    errorObserver = NotificationCenter.default.addObserver(forName: .bleErrorOccurred, object: nil, queue: .main) { notification in
                        if let error = notification.userInfo?["error"] as? BLEError {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    }
                }
                .onChange(of: bleManager.isConnected) { newValue in
                    if !newValue {
                        showConnectView = true
                    }
                }
                .onChange(of: selectedDrillSetup) { newValue in
                    if newValue == nil {
                        selectedDrillShots = nil
                        selectedDrillSummaries = nil
                    }
                }
                .onDisappear {
                    if let observer = errorObserver {
                        NotificationCenter.default.removeObserver(observer)
                    }
                }
                .alert(isPresented: $showError) {
                    Alert(title: Text(NSLocalizedString("ble_error", comment: "BLE Error alert title")), message: Text(errorMessage), dismissButton: .default(Text(NSLocalizedString("ok", comment: "OK button"))))
                }
                .alert(isPresented: $showTransferAlert) {
                    Alert(
                        title: Text("Image Transfer"),
                        message: Text(transferMessage),
                        dismissButton: .default(Text("OK")) {
                            selectedImage = nil
                            transferMessage = ""
                        }
                    )
                }
                .navigationViewStyle(.stack)
        }
    }
    
    var mainContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Recent Training (moved to subview)
                RecentTrainingView(selectedDrillSetup: $selectedDrillSetup, selectedDrillShots: $selectedDrillShots, selectedDrillSummaries: $selectedDrillSummaries)
                    .padding(.horizontal)
                    .padding(.top, 16)
                // Menu Buttons
                VStack(spacing: 20) {
                    MainMenuButton(icon: "target", text: NSLocalizedString("drills", comment: "Drills menu button"), color: .red)
                        .onTapGesture {
                            showDrillList = true
                        }
                    // Image Transfer Button (Testing - uses testTarget from assets)
                    // MainMenuButton(icon: "photo", text: "Transfer Image", color: .blue)
                    //     .onTapGesture {
                    //         if let testImage = UIImage(named: "testTarget") {
                    //             startImageTransfer(testImage)
                    //         } else {
                    //             transferMessage = "Test image 'testTarget' not found in assets"
                    //             showTransferAlert = true
                    //         }
                    //     }
                    // // Disabled IPSC button (non-interactive, visually muted)
                    // MainMenuButton(icon: "scope", text: NSLocalizedString("ipsc_questionaries", comment: "IPSC Questionaries menu button"), color: .gray)
                    //     .allowsHitTesting(false)
                    //     .opacity(0.6)
                    // // Disabled IDPA button (non-interactive, visually muted)
                    // MainMenuButton(icon: "shield", text: NSLocalizedString("idpa_questionaries", comment: "IDPA Questionaries menu button"), color: .gray)
                    //     .allowsHitTesting(false)
                    //     .opacity(0.6)
                }
                .padding(.top, 24)
                Spacer()
                // Home Indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 120, height: 6)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            NavigationLink(isActive: .constant(selectedDrillSetup != nil)) {
                if let drillSetup = selectedDrillSetup {
                    if let summaries = selectedDrillSummaries {
                        // Navigate to summary view for recent drills (showing all repeats from session)
                        DrillSummaryView(drillSetup: drillSetup, summaries: summaries)
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    } else if let shots = selectedDrillShots {
                        // Navigate to result view for manual drilling
                        DrillResultView(drillSetup: drillSetup, shots: shots)
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    } else {
                        // Default to result view
                        DrillResultView(drillSetup: drillSetup)
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    }
                }
            } label: {
                EmptyView()
            }
        }
        .toolbar {
            // Leading: BLE Connection Status
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showConnectView = true
                }) {
                    HStack(spacing: 8) {
                        Image(bleManager.isConnected ? "BleConnect": "BleDisconnect")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                        
                        Text(bleManager.connectedPeripheral?.name ?? (bleManager.isConnected ? NSLocalizedString("target_connected", comment: "Status when target is connected") : NSLocalizedString("target_disconnected", comment: "Status when target is disconnected")))
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                }
            }
            
            // Trailing: Info Button - Hidden for now
            // ToolbarItem(placement: .navigationBarTrailing) {
            //     Button(action: { showInfo = true }) {
            //         Image(systemName: "info.circle")
            //             .foregroundColor(.white)
            //             .font(.title2)
            //     }
            // }
        }
    }
    
    struct MainMenuButton: View {
        let icon: String
        let text: String
        let color: Color
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 28))
                Text(text)
                    .foregroundColor(.white)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(color)
                    .font(.system(size: 20))
            }
            .padding()
            .background(Color.gray.opacity(0.3))
            .cornerRadius(24)
            .padding(.horizontal)
        }
    }
    
    struct ConnectSmartTargetWrapper: View {
        @EnvironmentObject var bleManager: BLEManager
        let onDismiss: () -> Void
        var body: some View {
            ConnectSmartTargetView(bleManager: bleManager, navigateToMain: .constant(false), onConnected: onDismiss)
        }
    }
    
    // MARK: - Image Transfer Methods
    
    private func startImageTransfer(_ image: UIImage) {
        guard bleManager.isConnected else {
            transferMessage = "BLE device not connected. Please connect first."
            showTransferAlert = true
            return
        }
        
        isTransferring = true
        showPhotoPicker = false
        transferMessage = "Compressing and transferring image..."
        showTransferAlert = true
        
        // Start transfer in background
        DispatchQueue.global(qos: .userInitiated).async {
            imageTransferManager.transferImage(
                image,
                named: "target_image_\(Date().timeIntervalSince1970)",
                compressionQuality: 0.05
            ) { success, message in
                DispatchQueue.main.async {
                    isTransferring = false
                    transferMessage = message
                    showTransferAlert = true
                }
            }
        }
    }
}

// MARK: - Image Picker View (iOS 14+ compatible)

struct ImagePickerView: UIViewControllerRepresentable {
    var onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImageSelected: (UIImage?) -> Void
        
        init(onImageSelected: @escaping (UIImage?) -> Void) {
            self.onImageSelected = onImageSelected
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onImageSelected(image)
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImageSelected(nil)
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    DrillMainPageView()
        .environmentObject(BLEManager.shared)
}
