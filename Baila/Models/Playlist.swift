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
    var tracks: [Track]

    init(singletonID: String = Playlist.defaultSingletonID, tracks: [Track] = []) {
        self.singletonID = singletonID
        self.tracks = tracks
    }

    static let defaultSingletonID = "main"
}
