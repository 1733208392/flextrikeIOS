//
//  VideoPlayerView.swift
//  opencvtestminimal
//
//  Created by Kai Yang on 2025/7/8.
//


import SwiftUI
import AVKit

struct VideoPlayerView: UIViewControllerRepresentable {
    let url: URL
    var onComplete: (() -> Void)?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    class Coordinator: NSObject {
        var onComplete: (() -> Void)?

        init(onComplete: (() -> Void)?) {
            self.onComplete = onComplete
        }

        @objc func playerDidFinishPlaying() {
            onComplete?()
        }
    }
}