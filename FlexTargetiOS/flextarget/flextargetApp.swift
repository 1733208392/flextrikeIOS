//
//  opencvtestminimalApp.swift
//  opencvtestminimal
//
//  Created by Kai Yang on 2025/6/22.
//

import SwiftUI
import CoreData

@main
struct flextargetApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // Force dark mode globally
        UIApplication.shared.connectedScenes.forEach { scene in
            if let windowScene = scene as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .dark
                }
            }
        }
        
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.black
        appearance.titleTextAttributes = [.foregroundColor: UIColor(red: 222/255, green: 56/255, blue: 35/255, alpha: 1)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(red: 222/255, green: 56/255, blue: 35/255, alpha: 1)]
        UINavigationBar.appearance().tintColor = UIColor(red: 222/255, green: 56/255, blue: 35/255, alpha: 1)
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance for dark theme
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.black
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        
        #if DEBUG
        // NOTE: seeding runs from onAppear to avoid capturing `self` in init
        #endif
    }

    @State private var showLaunchScreen = true
    @StateObject var bleManager = BLEManager.shared
    @StateObject var deviceAuthManager = DeviceAuthManager.shared
    @State private var showAutoConnect = false
    @State private var showRemoteControl = false

    var body: some Scene {
        WindowGroup {
            Group {
            if showLaunchScreen {
                LaunchScreen()
                    .onAppear {
                        // Hide launch screen after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showLaunchScreen = false
                            }
                        }
                    }
            } else {
                TabNavigationView()
                    .environmentObject(BLEManager.shared)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .sheet(isPresented: $showAutoConnect) {
                        ConnectSmartTargetView(bleManager: bleManager, navigateToMain: .constant(false), onConnected: { 
                            showAutoConnect = false
                            showRemoteControl = true
                        })
                    }
                    .sheet(isPresented: $showRemoteControl) {
                        RemoteControlView()
                            .environmentObject(BLEManager.shared)
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    }
                    .onAppear {
                        if !bleManager.isConnected && bleManager.isBluetoothPoweredOn {
                            bleManager.autoDetectMode = true
                            bleManager.startScan()
                            showAutoConnect = true
                        }
                        
                        // Listen for the specific BLE message to show remote control
                        NotificationCenter.default.addObserver(forName: .bleNetlinkForwardReceived, object: nil, queue: .main) { notification in
                            if let userInfo = notification.userInfo,
                               let json = userInfo["json"] as? [String: Any],
                               let action = json["action"] as? String, action == "forward",
                               let content = json["content"] as? [String: Any],
                               let provisionStep = content["provision_step"] as? String, provisionStep == "verify_targetlink_status" {
                                print("Received verify_targetlink_status message, showing remote control")
                                showRemoteControl = true
                            }
                        }
                    }
            }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            // Run UITest seeder after the app UI appears (debug only)
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-UITestPopulate") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let bg = PersistenceController.shared.container.newBackgroundContext()
                        UITestDataSeeder.seedSampleData(into: bg)
                    }
                }
                #endif
            }
        }
    }
}
