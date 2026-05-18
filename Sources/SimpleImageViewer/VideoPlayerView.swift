import AVKit
import SwiftUI

struct VideoPlayerView: NSViewRepresentable {
    let url: URL
    let startTime: Double
    let playbackCommandID: Int
    let onPositionChange: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPositionChange: onPositionChange)
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .floating
        playerView.videoGravity = .resizeAspect
        playerView.allowsMagnification = false
        context.coordinator.configure(playerView, url: url, startTime: startTime, playbackCommandID: playbackCommandID)
        return playerView
    }

    func updateNSView(_ playerView: AVPlayerView, context: Context) {
        context.coordinator.onPositionChange = onPositionChange
        context.coordinator.configure(playerView, url: url, startTime: startTime, playbackCommandID: playbackCommandID)
    }

    static func dismantleNSView(_ playerView: AVPlayerView, coordinator: Coordinator) {
        coordinator.savePosition()
        coordinator.stopObserving()
        playerView.player?.pause()
        playerView.player = nil
    }

    final class Coordinator {
        var onPositionChange: (Double) -> Void

        private var player: AVPlayer?
        private var currentURL: URL?
        private var lastPlaybackCommandID = 0
        private var timeObserver: Any?

        init(onPositionChange: @escaping (Double) -> Void) {
            self.onPositionChange = onPositionChange
        }

        func configure(_ playerView: AVPlayerView, url: URL, startTime: Double, playbackCommandID: Int) {
            if currentURL?.standardizedFileURL != url.standardizedFileURL {
                savePosition()
                stopObserving()
                player?.pause()
                currentURL = url

                let player = AVPlayer(url: url)
                self.player = player
                playerView.player = player
                if startTime > 0 {
                    player.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
                }
                addObserver(to: player)
            }

            if playbackCommandID != lastPlaybackCommandID {
                lastPlaybackCommandID = playbackCommandID
                togglePlayback()
            }
        }

        func savePosition() {
            guard let player else { return }
            onPositionChange(player.currentTime().seconds)
        }

        func stopObserving() {
            if let timeObserver, let player {
                player.removeTimeObserver(timeObserver)
            }
            timeObserver = nil
        }

        private func addObserver(to player: AVPlayer) {
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 1, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                self?.onPositionChange(time.seconds)
            }
        }

        private func togglePlayback() {
            guard let player else { return }
            if player.rate == 0 {
                let currentSeconds = player.currentTime().seconds
                let durationSeconds = player.currentItem?.duration.seconds ?? 0
                if currentSeconds.isFinite,
                   durationSeconds.isFinite,
                   durationSeconds > 0,
                   currentSeconds >= durationSeconds - 0.1 {
                    player.seek(to: .zero)
                }
                player.play()
            } else {
                player.pause()
            }
        }
    }
}
