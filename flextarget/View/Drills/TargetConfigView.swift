import Foundation
import SwiftUI
import PhotosUI
import UIKit

// Import the DrillTargetsConfig data model
// (Assumes DrillTargetsConfig is defined in Model/DrillTargetsConfig.swift)

struct TargetConfigView: View {
    @Environment(\.dismiss) private var dismiss
    // Placeholder for DrillTargetsConfig usage

    var targetConfig: DrillTargetsConfig? = nil
    var deviceList: [NetworkDevice] = []

    @State private var availableDevices: [NetworkDevice] = []
    @State private var selectedDevice: NetworkDevice? = nil
    @State private var availableIcons: [String] = []
    @State private var selectedIcon: String? = nil

    var body: some View {
        GeometryReader { geometry in
            let frameWidth = geometry.size.width * 0.4
            let frameHeight = geometry.size.height * 0.35

            // Initialize availableDevices only once
            let _ = Self._printChanges()
            VStack(spacing: 0) {
                // Top Bar with back icon and title
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Target A")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer to center the title
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .opacity(0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .frame(height: 60)
                
                // Middle part: Rectangle frame
                VStack {
                    Rectangle()
                        .stroke(Color.white, lineWidth: 10)
                        .frame(width: frameWidth, height: frameHeight)
                        .overlay(alignment: .center) {
                            if let icon = selectedIcon {
                                Image(systemName: icon)
                                    .font(.system(size: 60))
                                    .foregroundColor(.white)
                            }
                        }
                        .overlay(alignment: .topLeading) {
                            Text(selectedDevice?.name ?? "No 1")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(8)
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Label above horizontal scroller
                HStack {
                    Text("Please select a available target")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    Spacer()
                }
                
                // Bottom part: Horizontal scroller of icons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(availableDevices) { device in
                            Button(action: {
                                if selectedDevice == nil {
                                    selectedDevice = device
                                    availableDevices.removeAll { $0.id == device.id }
                                } else {
                                    let temp = selectedDevice!
                                    selectedDevice = device
                                    if let index = availableDevices.firstIndex(where: { $0.id == device.id }) {
                                        availableDevices[index] = temp
                                    }
                                }
                            }) {
                                VStack {
                                    Image(systemName: "rectangle.ratio.9.to.16")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(Color.gray.opacity(0.3))
                                        .cornerRadius(8)
                                    Text(device.name)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .frame(height: 100)

                                // Label above horizontal scroller
                HStack {
                    Text("Please select target type")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    Spacer()
                }
                // New horizontal scroller with sample icons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(availableIcons.indices, id: \.self) { index in
                            let icon = availableIcons[index]
                            Button(action: {
                                if selectedIcon == nil {
                                    selectedIcon = icon
                                    availableIcons.remove(at: index)
                                } else {
                                    let temp = selectedIcon!
                                    selectedIcon = icon
                                    availableIcons[index] = temp
                                }
                            }) {
                                VStack {
                                    Image(systemName: icon)
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(Color.gray.opacity(0.3))
                                        .cornerRadius(8)
                                    Text("Sample \(availableIcons.firstIndex(of: icon)! + 1)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .frame(height: 100)
                
                // Two buttons below the horizontal scroller
                HStack(spacing: 20) {
                    Button(action: {
                        // Add Next button action
                    }) {
                        Text("Add Next")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // Complete button action
                    }) {
                        Text("Complete")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            initializeDevices()
        }
    }
    
    // Sample icon names for the horizontal scroller
    private let iconNames = [
        "star.fill",
        "heart.fill",
        "bell.fill",
        "camera.fill",
        "gear",
        "folder.fill",
        "calendar",
        "book.fill",
        "music.note",
        "gamecontroller.fill"
    ]

    // Initialize availableDevices from deviceList on appear
    private func initializeDevices() {
        if availableDevices.isEmpty && !deviceList.isEmpty {
            availableDevices = deviceList
        }
        if availableIcons.isEmpty {
            availableIcons = iconNames
        }
    }
}

#Preview {
    TargetConfigView()
}
