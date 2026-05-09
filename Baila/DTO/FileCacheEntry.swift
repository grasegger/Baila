//
//  FileCacheEntry.swift
//  Baila
//
//  Created by Karl on 03.05.26.
//

import Foundation
import SwiftData

struct FileCacheEntry: Sendable {
let persistentID: PersistentIdentifier
    let fileId: Int64
    let trackID: PersistentIdentifier?
    let cdID: PersistentIdentifier?
    let albumID: PersistentIdentifier?
    let artistID: PersistentIdentifier?
    let playlistID: PersistentIdentifier?
    
    init(file: CachedFile) {
        persistentID = file.persistentModelID
        trackID = file.track?.persistentModelID
        fileId = file.fileId
        cdID = file.track?.CD?.persistentModelID
        albumID = file.track?.CD?.album?.persistentModelID
        artistID = file.track?.CD?.album?.artist?.persistentModelID
        playlistID = file.track?.playlistPosition?.persistentModelID
    }
}
