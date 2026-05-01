//
//  Utils.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//
import Foundation
import AVFoundation
import MediaPlayer
import OSLog
import SwiftData
import SwiftUI

class Utils {
    static let previewContainer: ModelContainer = {
        do {
            print("Creating container")
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: Artist.self,
                Album.self,
                CD.self,
                Track.self,
                CachedFile.self,
                Playlist.self,
                configurations: config
            )

            container.mainContext.insert(Playlist())

            for i in 0...26  {
                let albumCount = Int.random(in: 1...8)
                let albums = (0..<albumCount).map { albumIndex in
                    Album(
                        name: "Album \(albumIndex + 1)",
                        releaseDate: Date(timeIntervalSinceNow: -Double(albumIndex) * 60 * 60 * 24 * 365),
                        albumArt: previewAlbumArtData(index: i * 8 + albumIndex),
                        CDs: [],
                        artist: nil
                    )
                }
                let artist = Artist(name: "Artist\(i)", albums: albums)
                container.mainContext.insert(artist)
            }

            try container.mainContext.save()

            return container
        } catch {
            fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
        }
    }()

    private static func previewAlbumArtData(index: Int) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120))
        let image = renderer.image { context in
            let hue = CGFloat(index % 24) / 24
            UIColor(hue: hue, saturation: 0.55, brightness: 0.9, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))

            let text = "\(index + 1)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: UIColor.white,
            ]
            let size = text.size(withAttributes: attributes)
            let origin = CGPoint(x: (120 - size.width) / 2, y: (120 - size.height) / 2)
            text.draw(at: origin, withAttributes: attributes)
        }

        return image.pngData() ?? Data()
    }
}

@MainActor
final class PlaybackController {
    static let shared = PlaybackController()

    private var player: AVAudioPlayer?

    private init() {
        configureRemoteCommands()
    }

    func play(track: Track) {
        guard let url = track.file?.path else {
            Logger.ui.error("Track has no file URL: \(track.name)")
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.ui.error("Track file does not exist at path: \(url.path)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            self.player = player
            updateNowPlayingInfo(for: track, duration: player.duration)
        } catch {
            Logger.ui.error("Failed to start playback for \(url.path): \(error.localizedDescription)")
        }
    }

    private func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, let player = self.player else {
                return .commandFailed
            }

            player.play()
            self.updatePlaybackState()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self, let player = self.player else {
                return .commandFailed
            }

            player.pause()
            self.updatePlaybackState()
            return .success
        }
    }

    private func updateNowPlayingInfo(for track: Track, duration: TimeInterval) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: track.name,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPNowPlayingInfoPropertyPlaybackRate: 1,
        ]

        if let album = track.CD?.album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album.name

            if let artworkImage = UIImage(data: album.albumArt) {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                    boundsSize: artworkImage.size
                ) { _ in
                    artworkImage
                }
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        updatePlaybackState()
    }

    private func updatePlaybackState() {
        guard let player else {
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            return
        }

        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? 1 : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        MPNowPlayingInfoCenter.default().playbackState = player.isPlaying ? .playing : .paused
    }
}
