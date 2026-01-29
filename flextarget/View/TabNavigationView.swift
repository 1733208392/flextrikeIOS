import SwiftUI
import CoreData

struct TabNavigationView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.managedObjectContext) var managedObjectContext
    @State private var selectedTab: Int = 0
    @AppStorage("isCompetitionLoggedIn") private var isCompetitionLoggedIn = false
    
    // Sheet states for modals
    @State private var showConnectView = false
    @State private var showInfo = false
    @State private var showQRScanner = false
    @State private var scannedPeripheralName: String? = nil
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var errorObserver: NSObjectProtocol?
    
    let persistenceController = PersistenceController.shared
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Drills Tab
                NavigationView {
                    DrillsTabView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label(NSLocalizedString("drills", comment: "Drills tab"), systemImage: "target")
                }
                .tag(0)
                
                // History Tab
                NavigationView {
                    HistoryTabView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label(NSLocalizedString("history", comment: "History tab"), systemImage: "clock.fill")
                }
                .tag(1)
                
                // Competition Tab
                NavigationView {
                    CompetitionTabView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label(NSLocalizedString("competition", comment: "Competition tab"), systemImage: "trophy.fill")
                }
                .tag(2)
                
                // Admin Tab
                NavigationView {
                    AdminTabView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label(NSLocalizedString("admin", comment: "Admin tab"), systemImage: "person.badge.key")
                }
                .tag(3)
            }
            .tint(.red)
            .preferredColorScheme(.dark)
            .onAppear {
                errorObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name("bleErrorOccurred"), object: nil, queue: .main) { notification in
                    // Handle BLE errors if needed
                    if let userInfo = notification.userInfo {
                        print("BLE Error: \(userInfo)")
                    }
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
            .alert(isPresented: $bleManager.showErrorAlert) {
                Alert(title: Text("Error"), message: Text(bleManager.errorMessage ?? "Unknown error occurred"), dismissButton: .default(Text("OK")))
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    TabNavigationView()
        .environmentObject(BLEManager.shared)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
