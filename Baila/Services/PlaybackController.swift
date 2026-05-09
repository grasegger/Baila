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
    private var currentItemObserver: NSKeyValueObservation?
    private var playerItemEndObserver: NSObjectProtocol?
    private var periodicTimeObserver: Any?
    private var queuedPositionsByItemID: [ObjectIdentifier: PlaylistPosition] = [:]
    private var currentAsset : AVPlayerItem? = nil
    
    var playing = false
    var loopMode = PlaylistLoopMode.off
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }
    
    var currentPosition: PlaylistPosition?
    
    var currentTrack: Track? {
        guard let currentPosition else { return nil }
        guard let track = currentPosition.track else { return nil }
        return track
    }
    
    var hasNextTrack: Bool {
        nextPosition() != nil
    }
    
    var hasPreviousTrack: Bool {
        previousPosition() != nil
    }
    
    var playable = false
    
    func setLoopMode(_ loopMode: PlaylistLoopMode) {
        guard self.loopMode != loopMode else { return }
        
        self.loopMode = loopMode
        updateLookaheadQueue()
    }
    
    init () {
        timeControlObserver = avp.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let controller = self
            
            Task { @MainActor in
                controller?.syncPlaybackState()
            }
        }
        
        currentItemObserver = avp.observe(\.currentItem, options: [.new]) { [weak self] player, _ in
            let controller = self
            let currentItem = player.currentItem
            
            Task { @MainActor in
                controller?.syncCurrentPosition(with: currentItem)
            }
        }
        
        playerItemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let controller = self
            
            Task { @MainActor in
                await Task.yield()
                controller?.syncCurrentPosition(with: controller?.avp.currentItem)
            }
        }
        
        periodicTimeObserver = avp.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            let controller = self
            
            Task { @MainActor in
                controller?.syncPlaybackTime()
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
    }
    
    func stop() {
        guard let modelContainer else {
            Logger.player.error("Playback controller is missing a model container")
            return
        }
        
        avp.pause()
        avp.removeAllItems()
        queuedPositionsByItemID = [:]
        currentAsset = nil
        currentPosition = nil
        playing = false
        playable = false
        currentTime = 0
        duration = 0
        
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
        guard let currentPosition,
              let next = nextPosition(after: currentPosition, for: .manual) else { return }
        
        if queuedPosition(for: next) != nil {
            avp.advanceToNextItem()
            syncCurrentPosition(with: avp.currentItem)
            avp.play()
            playing = true
        } else {
            play(next)
        }
    }
    
    func prev() {
        guard let prev = previousPosition() else { return }
        play(prev)
    }
    
    var hasCurrentTrack : Bool {
        currentTrack != nil
    }
    
    func playPause() {
        if playing {
            avp.pause()
            playing = false
        } else {
            avp.play()
            playing = true
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
        playing = false
    }
    
    private func play(_ position: PlaylistPosition) {
        guard prepareAudioSession() else { return }
        
        avp.removeAllItems()
        queuedPositionsByItemID = [:]
        
        guard let asset = makePlayerItem(for: position) else { return }
        
        avp.insert(asset, after: nil)
        currentPosition = position
        currentAsset = asset
        playable = true
        
        if let nextPosition = nextPosition(after: position, for: .automatic),
           let nextAsset = makePlayerItem(for: nextPosition) {
            avp.insert(nextAsset, after: nil)
        }
        
        avp.play()
        playing = true
    }
    
    private func nextPosition() -> PlaylistPosition? {
        guard let currentPosition else { return nil }
        return nextPosition(after: currentPosition, for: .manual)
    }
    
    private func previousPosition() -> PlaylistPosition? {
        guard let currentPosition else { return nil }
        
        if let previous = adjacentPosition(from: currentPosition, step: -1) {
            return previous
        }
        
        guard loopMode == .all else {
            return nil
        }
        
        return lastPlayablePosition()
    }
    
    private enum AdvanceReason {
        case manual
        case automatic
    }
    
    private func nextPosition(after position: PlaylistPosition, for reason: AdvanceReason) -> PlaylistPosition? {
        if loopMode == .one && reason == .automatic {
            return position
        }
        
        if let next = adjacentPosition(from: position, step: 1) {
            return next
        }
        
        guard loopMode == .all else {
            return nil
        }
        
        return firstPlayablePosition()
    }
    
    private func adjacentPosition(from position: PlaylistPosition, step: Int) -> PlaylistPosition? {
        guard step != 0 else { return nil }
        
        guard let currentIndex = playlist.firstIndex(where: { $0.id == position.id }) else {
            return nil
        }
        
        var nextIndex = currentIndex + step
        
        while playlist.indices.contains(nextIndex) {
            let position = playlist[nextIndex]
            
            if position.track?.file?.filePath != nil {
                return position
            }
            
            nextIndex += step
        }
        
        return nil
    }
    
    private func firstPlayablePosition() -> PlaylistPosition? {
        playlist.first { $0.track?.file?.filePath != nil }
    }
    
    private func lastPlayablePosition() -> PlaylistPosition? {
        playlist.last { $0.track?.file?.filePath != nil }
    }
    
    private func makePlayerItem(for position: PlaylistPosition) -> AVPlayerItem? {
        guard let url = position.track?.file?.filePath else {
            Logger.player.error("Cannot queue playlist position without a cached file")
            return nil
        }
        
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        queuedPositionsByItemID[ObjectIdentifier(item)] = position
        return item
    }
    
    private func queuedPosition(for position: PlaylistPosition) -> PlaylistPosition? {
        let currentItemID = avp.currentItem.map { ObjectIdentifier($0) }
        
        return avp.items()
            .filter { ObjectIdentifier($0) != currentItemID }
            .compactMap { queuedPositionsByItemID[ObjectIdentifier($0)] }
            .first { $0.id == position.id }
    }
    
    private func syncCurrentPosition(with item: AVPlayerItem?) {
        guard let item else {
            currentAsset = nil
            
            if avp.items().isEmpty {
                playing = false
                playable = false
            }
            
            return
        }
        
        currentAsset = item
        
        if let position = queuedPositionsByItemID[ObjectIdentifier(item)] {
            currentPosition = position
        }
        
        syncPlaybackTime()
        removeStaleQueuedPositions()
        queueNextItemIfNeeded()
        syncPlaybackState()
    }
    
    private func syncPlaybackTime() {
        let seconds = avp.currentTime().seconds
        
        if seconds.isFinite {
            currentTime = max(0, seconds)
        } else {
            currentTime = 0
        }
        
        if let durationSeconds = avp.currentItem?.duration.seconds,
           durationSeconds.isFinite,
           durationSeconds > 0 {
            duration = durationSeconds
        } else {
            duration = currentTrack?.runtime ?? 0
        }
    }
    
    private func syncPlaybackState() {
        playable = avp.currentItem != nil
        playing = avp.timeControlStatus != .paused && playable
    }
    
    private func removeStaleQueuedPositions() {
        let queuedItemIDs = Set(avp.items().map { ObjectIdentifier($0) })
        queuedPositionsByItemID = queuedPositionsByItemID.filter { queuedItemIDs.contains($0.key) }
    }
    
    private func queueNextItemIfNeeded() {
        guard let currentPosition,
              let next = nextPosition(after: currentPosition, for: .automatic),
              queuedPosition(for: next) == nil,
              let nextAsset = makePlayerItem(for: next) else {
            return
        }
        
        avp.insert(nextAsset, after: nil)
    }
    
    private func updateLookaheadQueue() {
        let currentItem = avp.currentItem
        
        for item in avp.items() where item !== currentItem {
            avp.remove(item)
            queuedPositionsByItemID[ObjectIdentifier(item)] = nil
        }
        
        if let currentItem,
           let currentPosition {
            queuedPositionsByItemID[ObjectIdentifier(currentItem)] = currentPosition
        }
        
        queueNextItemIfNeeded()
    }
    
}
