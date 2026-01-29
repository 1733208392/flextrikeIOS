//
//  OverlayView.swift
//  opencvtestminimal
//
//  Created by Kai Yang on 2025/6/24.
//


import SwiftUI

struct OverlayView: View {
    let fps: Int

    var body: some View {
        GeometryReader { geometry in
            VStack {
                HStack {
                    Text(String(format: NSLocalizedString("fps_display", comment: "FPS display"), fps))
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, geometry.safeAreaInsets.top + 40)
            .padding(.leading)
        }
        .ignoresSafeArea(edges: .all)
    }
}
