import SwiftUI
import CoreData

struct AdminTabView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    
    var body: some View {
        AdminContentView()
            .environment(\.managedObjectContext, managedObjectContext)
    }
}

struct AdminContentView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @State private var selectedAdminTab = 0
    @State private var showMainMenu = true
    @State private var showDeviceManagement = false
    @State private var showLoginFlow = false
    @State private var showInformation = false
    @State private var showUserProfile = false
    @State private var scannedPeripheralName: String? = nil
    @State private var showConnectView = false
    @ObservedObject var bleManager = BLEManager.shared
    @ObservedObject var authManager = AuthManager.shared
    
    let persistenceController = PersistenceController.shared
    
    var isDeviceConnected: Bool {
        bleManager.isConnected && bleManager.connectedPeripheral != nil
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showMainMenu {
                mainMenuView
            } else if showDeviceManagement {
                deviceManagementView
            } else if showLoginFlow {
                LoginView(onDismiss: {
                    showLoginFlow = false
                    showMainMenu = true
                })
            } else if showUserProfile {
                UserProfileView(onDismiss: {
                    showUserProfile = false
                    showMainMenu = true
                })
            } else if showInformation {
                InformationPage()
            }
        }
        .navigationTitle(NSLocalizedString("admin", comment: "Admin tab title"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: authManager.isAuthenticated) { newValue in
            if !newValue {
                // User was logged out (either manually or due to token expiration)
                showMainMenu = false
                showDeviceManagement = false
                showUserProfile = false
                showInformation = false
                showLoginFlow = true
            }
        }
        .sheet(isPresented: $showConnectView) {
            ConnectSmartTargetView(
                bleManager: bleManager,
                navigateToMain: .constant(false),
                targetPeripheralName: scannedPeripheralName,
                isAlreadyConnected: bleManager.isConnected,
                onConnected: { showConnectView = false }
            )
        }
    }
    
    private var mainMenuView: some View {
        VStack(spacing: 0) {
            
            // Menu List
            ScrollView {
                VStack(spacing: 12) {
                    // Device Management
                    adminMenuButton(
                        icon: "iphone.and.arrow.forward",
                        title: NSLocalizedString("device_management", comment: "Device Management"),
                        description: isDeviceConnected ?
                            NSLocalizedString("device_connected", comment: "Device is connected") :
                            NSLocalizedString("connect_device", comment: "Connect to a device"),
                        isActive: isDeviceConnected
                    ) {
                        showMainMenu = false
                        showDeviceManagement = true
                    }
                    
                    // User Management
                    if authManager.isAuthenticated {
                        // User Profile
                        adminMenuButton(
                            icon: "person.circle",
                            title: authManager.currentUser?.username ?? NSLocalizedString("user_profile", comment: "User Profile"),
                            description: NSLocalizedString("manage_profile", comment: "Manage user profile"),
                            isActive: false
                        ) {
                            showMainMenu = false
                            showUserProfile = true
                        }
                    } else {
                        // Login
                        adminMenuButton(
                            icon: "person.circle",
                            title: NSLocalizedString("login", comment: "Login"),
                            description: NSLocalizedString("user_login", comment: "User login"),
                            isActive: false
                        ) {
                            showMainMenu = false
                            showLoginFlow = true
                        }
                    }
                    
                    // Information
                    // adminMenuButton(
                    //     icon: "info.circle",
                    //     title: NSLocalizedString("information", comment: "Information"),
                    //     description: NSLocalizedString("app_info", comment: "App information"),
                    //     isActive: false
                    // ) {
                    //     showMainMenu = false
                    //     showInformation = true
                    // }
                }
                .padding(12)
            }
        }
    }
    
    private var deviceManagementView: some View {
        VStack {
            if isDeviceConnected {
                VStack(spacing: 16) {
                    // Connected Device Menu
                    NavigationLink(destination: ConnectSmartTargetView(
                        bleManager: bleManager,
                        navigateToMain: .constant(false),
                        isAlreadyConnected: true,
                        hideCloseButton: true
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.title2)
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("connected_device", comment: "Connected device"))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                if let peripheralName = bleManager.connectedPeripheral?.name {
                                    Text(peripheralName)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    Text(NSLocalizedString("manage_connection", comment: "Manage connection"))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.red)
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                
                Spacer()
            } else {
                VStack(spacing: 16) {
                    // QR Scan Option
                    NavigationLink(destination: QRScannerView(onQRScanned: { code in
                        // Save scanned peripheral name and present connect view
                        scannedPeripheralName = code
                        showDeviceManagement = false
                        showMainMenu = true
                        // Small delay to ensure state settles before presenting sheet
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showConnectView = true
                        }
                    }, hideBackButton: true)) {
                        HStack(spacing: 12) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("scan_qr_code", comment: "Scan QR Code"))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(NSLocalizedString("scan_device_qr", comment: "Scan device QR code"))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.red)
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding(12)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("device_management", comment: "Device Management"))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showDeviceManagement = false; showMainMenu = true }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private func adminMenuButton(
        icon: String,
        title: String,
        description: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private func logout() {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<AppAuth> = AppAuth.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            for auth in results {
                context.delete(auth)
            }
            try context.save()
        } catch {
            print("Error during logout: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        AdminTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
