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
        appearance.titleTextAttributes = [.foregroundColor: UIColor.red]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.red]
        UINavigationBar.appearance().tintColor = .red
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
