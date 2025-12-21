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
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.red]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.red]
        UINavigationBar.appearance().tintColor = .red
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        #if DEBUG
        // NOTE: seeding runs from onAppear to avoid capturing `self` in init
        #endif
    }

    @State private var showLaunchScreen = true
    @StateObject var bleManager = BLEManager.shared

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
//                OrientationView() // Replace with your main view
//                    .environmentObject(bleManager)
                NavigationView {
                    DrillMainPageView()
                        .environmentObject(BLEManager.shared)
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                }
                .navigationViewStyle(.stack)
                .background(Color.black)
//                NavigationStack {
//                    DrillListView(bleManager: BLEManager.shared)
//                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                }
//                .environmentObject(bleManager)
                .tint(.red)
            }
            }
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
