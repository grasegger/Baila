//
//  Playlist.swift
//  Baila
//
//  Created by Karl on 01.05.26.
//
import Foundation
import SwiftData

@Model
class Playlist {
    @Attribute(.unique) var singletonID: String
    @Relationship(deleteRule: .nullify) var tracks: [Track]
    @Relationship(deleteRule: .nullify) var currentTrack : Track?
    var currentTrackPositionMS: Int

    init(singletonID: String = Playlist.defaultSingletonID, tracks: [Track] = [], currentTrack: Track? = nil, currentTrackPositionMS: Int = 0) {
        self.singletonID = singletonID
        self.tracks = tracks
        self.currentTrack = currentTrack
        self.currentTrackPositionMS = currentTrackPositionMS
    }

    static let defaultSingletonID = "main"

    func flush() {
        tracks.removeAll()
        currentTrack = nil
        currentTrackPositionMS = 0
    }
}
