//
//  Tagreader.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//
import CryptoKit
import Foundation
import OSLog
import SwiftData
import SwiftTagLib

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let tagReader = Logger(subsystem: subsystem, category: "TagReader")
}

let audioExtensions = ["mp3", "m4a", "flac", "ogg"]

class TagReader {
    private static func getArtist(name: String, context: ModelContext) -> Artist {
        let predicate = #Predicate<Artist> { artist in
            artist.name == name
        }
        let descriptor = FetchDescriptor<Artist>(predicate: predicate)

        let existing = try? context.fetch(descriptor).first

        if let existing = existing {
            return existing
        } else {
            let newArtist = Artist(name: name, albums: [])
            return newArtist
        }
    }

    private static func getAlbum(artist: Artist, name: String, releaseDate: Date, albumArt: Data) -> Album {
        let existing = artist.albums.first { $0.name == name }

        if let existing = existing {
            return existing
        } else {
            return Album(
                name: name,
                releaseDate: releaseDate,
                albumArt: albumArt,
                CDs: [],
                artist: artist
            )
        }
    }

    private static func GetCD(album: Album, number: Int32) -> CD {
        let existing = album.CDs.first { $0.number == number }

        if let existing = existing {
            return existing
        } else {
            return CD(number: number, tracks: [], album: album)
        }
    }

    private static func GetTrack(
        cd: CD,
        name: String,
        artist: String,
        number: Int32,
        file: CachedFile
    ) -> Track {
        let existing = cd.tracks.first(where: { $0.name == name })
        if let existing = existing {
            return existing
        } else {
            return Track(
                name: name,
                artist: artist,
                number: number,
                CD: cd,
                file: file
            )
        }
    }

    private static func GetTrack(file: CachedFile, context: ModelContext) throws -> Track {
        // todo fallbacks to "Unknown"
        let sourceFile = try AudioFile(url: file.path)
        let tags = sourceFile.metadata

        let releasedate = try! Date(
            tags.releaseDate!,
            strategy: .iso8601.year().month().day()
        )

        let albumArtData = tags.attachedPictures.first!.data
        
        let artist = getArtist(name: tags.albumArtist!, context: context)

        let album = getAlbum(
            artist: artist,
            name: tags.albumTitle!,
            releaseDate: releasedate,
            albumArt: albumArtData
        )
        
        let cd = GetCD(album: album, number: tags.discNumber!)
        
        let track = GetTrack(
            cd: cd,
            name: tags.title!,
            artist: tags.artist!,
            number: tags.trackNumber!,
            file: file
        )
        
        return track
    }

    static func GetFileChecksum(fileManager: FileManager, filePath: String) -> SHA256.Digest {
        let fileURL = URL(fileURLWithPath: filePath)
        let attributes = try! fileManager.attributesOfItem(atPath: filePath)
        let fileSize = attributes[.size] as! Int64
        let moddate = attributes[.modificationDate] as! Date
        let checksumData = "\(fileURL.path)\(fileSize)\(moddate.timeIntervalSince1970)".data(
            using: .utf8
        )!
        return SHA256.hash(data: checksumData)
    }

    static func scanAndPersistMusicFilesStatic(modelContainer: ModelContainer) async throws {
        let context = modelContainer.mainContext
        let folder = AppFiles.documentsDirectory
        let fetch = FetchDescriptor<CachedFile>()

        // cleanup database from deleted items
        var existingFiles = try! context.fetch(fetch)
        for file in existingFiles {
            if !FileManager.default.fileExists(atPath: file.path.absoluteString) {
                context.delete(file)
                existingFiles.removeAll(where: { $0.id == file.id })
            }
        }

        // scan all files for audio files
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: folder,
                                                      includingPropertiesForKeys: [.isRegularFileKey]
                                                      , options: [.skipsHiddenFiles]) else { return }
        var allFiles = enumerator.allObjects as? [URL] ?? []
        allFiles = allFiles.filter { url in
            audioExtensions.contains(url.pathExtension.lowercased())
        }

        // create checksum and create/update file in database
        for fileURL in allFiles {
            let checksum = GetFileChecksum(fileManager: fileManager, filePath: fileURL.path)
            let checksumString = checksum.map { String(format: "%02x", $0) }.joined().uppercased()

            let descriptor = FetchDescriptor<CachedFile>(
                predicate: #Predicate { file in
                    file.path == fileURL.absoluteURL
                }
            )

            let exists = (try? context.fetchCount(descriptor)) ?? 0 > 0

            let file: CachedFile? = try! {
                if !exists {
                    let file = CachedFile(filePath: fileURL, hash: checksum, track: nil)
                    context.insert(file)
                    return file
                } else {
                    let existing = try context.fetch(descriptor)
                    if let foundFile = existing.first {
                        if foundFile.checksum != checksumString {
                            // lazy "update"
                            context.delete(foundFile)

                            let file = CachedFile(filePath: fileURL, hash: checksum, track: nil)
                            context.insert(file)
                            return file
                        }
                    }
                }
                return nil
            }()

            if file != nil {
                let track = try? TagReader.GetTrack(file: file!, context: context)
                if let track = track {
                    try? context.save()
                } else {
                    Logger.tagReader.error("Failed to read tags for \(fileURL.path)")
                }
            }
        }

    }
}
