//
//  PlaybackController.swift
//  Baila
//
//  Created by Karl on 02.05.26.
//

import AVFoundation
import Foundation
import MediaPlayer
import OSLog
import SwiftData
import SwiftUI

extension Logger {
  private static var subsystem = Bundle.main.bundleIdentifier!
  static let player = Logger(subsystem: subsystem, category: "Player")
}

@MainActor
@Observable
final class PlaybackController  {
    
    static let shared = PlaybackController()
    
    private var modelContainer: ModelContainer?
    private var avp = AVQueuePlayer()
    private var playlist: [PlaylistPosition] = []
    private var timeControlObserver: NSKeyValueObservation?
    private var currentAsset : AVPlayerItem? = nil
    
    var playing = false
    
    var currentPosition: PlaylistPosition?
    
    var currentTrack: Track? {
        guard let currentPosition else { return nil }
        guard let track = currentPosition.track else { return nil }
        return track
    }
    
    var playable = false
    
    init () {
        timeControlObserver = avp.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor in
                let playable = player.currentItem?.status == .readyToPlay
            
                DispatchQueue.main.async {
                    self?.playable = playable
                }
                
                if playable {
                    let isPlaying = player.timeControlStatus == .playing
                    DispatchQueue.main.async {
                        self?.playing = isPlaying
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.playing = playable
                    }
                }
                
            }
        }
    }
    
    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.refreshPlaylist()
    }
    
    func refreshPlaylist () {
        Logger.player.debug("Refreshing playlist")
        
        let descriptor = FetchDescriptor<PlaylistPosition>(
            sortBy: [SortDescriptor(\.position)]
        )
        let playlistPositions = try? modelContainer?.mainContext.fetch(descriptor) ?? []
        
        if let playlistPositions {
            self.playlist = playlistPositions
        }
    }
    
    func play(_ album: Album) {
        replaceQueue(album.allTracksSorted)
    }
    
    // todo return bool if not working
    @MainActor
    func replaceQueue(_ tracks: [Track]) {
        Logger.player.debug("Got replace request")
        guard let modelContainer else {
            Logger.player.error("Playback controller is missing a model container")
            return
        }
        
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<PlaylistPosition>()
        
        guard let existing = try? context.fetch(descriptor) else { return }
        
        existing.forEach { context.delete($0) }
        
        var index = 0
        
        tracks.forEach(
            { track in
                let position = PlaylistPosition(position: index, track: track)
                context.insert(position)
                index += 1
            })
        
        do {
            try context.save()
        } catch {
            Logger.player.error("Error saving new playlist")
        }
        
        refreshPlaylist()
        
        if let firstPosition = playlist.first {
            play(firstPosition)
        }
        // todo add to player queue - maybe we dont even need to hold the state in the end? :) just wondering how we would sync the now playing
        
        /*
         player.stop(clearQueue: true)
         
         for track in tracks {
         if let  path = track.file?.filePath {
         player.queue(url: path)
         }
         }
         */
    }
    
    func stop() {
        guard let modelContainer else {
            Logger.player.error("Playback controller is missing a model container")
            return
        }
        
        avp.pause()
        avp.removeAllItems()
        currentAsset = nil
        currentPosition = nil
        playing = false
        
        for position in playlist {
            modelContainer.mainContext.delete(position)
        }
        
        do {
            try modelContainer.mainContext.save()
            playlist = []
        } catch
        {
            Logger.player
                .error(
                    "Error clearing out playist: \(error.localizedDescription)"
                )
        }
    }
    
    func next() {
        guard let next = currentPosition?.next() else { return }
        play(next)
    }
    
    func prev() {
        guard let prev = currentPosition?.prev() else { return }
        play(prev)
    }
    
    var hasCurrentTrack : Bool {
        if let _ = currentPosition {
            return true
        } else {
            return true
        }
    }
    
    func playPause() {
        if avp.timeControlStatus == .playing {
            avp.pause()
        } else {
            avp.play()
        }
    }
    
    private func prepareAudioSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            return true
        } catch {
            Logger.player.error("Failed to activate audio session: \(error.localizedDescription)")
            return false
        }
    }
    
    func pause() {
        avp.pause()
    }
    
    private func play(_ position: PlaylistPosition) {
        guard let url = position.track?.file?.filePath else {
            Logger.player.error("Cannot play playlist position without a cached file")
            return
        }
        
        guard prepareAudioSession() else { return }
        
        let asset = AVPlayerItem(asset: AVURLAsset(url: url))
        avp.removeAllItems()
        avp.insert(asset, after: nil)
        currentPosition = position
        currentAsset = asset
        avp.play()
    }
    
}
