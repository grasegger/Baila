//
//  Utils.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//
import Foundation
import AVFoundation
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
                let albumArtData = previewAlbumArtData(index: i * 2)
                let album2ArtData = previewAlbumArtData(index: i * 2 + 1)
                let artist = Artist(name: "Artist\(i)", albums: [
                    Album(
                        name: "Album",
                        releaseDate: Date(),
                        albumArt: albumArtData,
                        CDs: [],
                        artist: nil
                    ),
                    Album(
                        name: "Album2",
                        releaseDate: Date(timeIntervalSinceNow: -60 * 60 * 24 * 365 * 5),
                        albumArt: album2ArtData,
                        CDs: [],
                        artist: nil
                    )
                ])
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

    private let player = AVPlayer()

    private init() {}

    func play(track: Track) {
        guard let url = track.file?.path else {
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.ui.error("Failed to configure audio session: \(error.localizedDescription)")
        }

        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
    }
}
