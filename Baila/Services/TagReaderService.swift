//
//  TagReaderService.swift
//  Baila
//
//  Created by Karl on 04.05.26.
//
import CryptoKit
import CoreImage
import CoreImage.CIFilterBuiltins
import DominantColors
import Foundation
import OSLog
import SwiftData
import SwiftTagLib
import UIKit

typealias FileCache = [URL: FileCacheEntry]
typealias FileList = [URL: Int64]
typealias TaggedFile = (URL, Int64, SwiftTagLib.AudioFile.Metadata, SwiftTagLib.AudioFile.Properties)
typealias TaggedArtists = [(artist: Artist, files: [TaggedFile])]
typealias TaggedAlbums = [(album: Album, files: [TaggedFile])]
typealias TaggedCDs = [(cd: CD, files: [TaggedFile])]

let targetExtensions = ["mp3", "m4a", "flac", "ogg"]

enum IndexingJob: String {
    case creatingDatabase = "Updating database"
    case preparingAssets = "Preparing assets"

    var systemImage: String {
        switch self {
        case .creatingDatabase:
            "square.3.layers.3d.down.right"
        case .preparingAssets:
            "photo.on.rectangle.angled"
        }
    }
}

extension FileList {
    mutating func removeCached(cache: FileCache) {
        for (path, entry) in cache {
            if self[path] != nil && self[path] == entry.fileId {
                removeValue(forKey: path)
            }
        }
    }
}

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let tagReader = Logger(subsystem: subsystem, category: "TagReader")
}

private extension UIColor {
    nonisolated convenience init?(hex: String) {
        let trimmedHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmedHex.count == 6,
              let value = Int(trimmedHex, radix: 16) else {
            return nil
        }

        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexString: String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        let redComponent = Int(round(red * 255))
        let greenComponent = Int(round(green * 255))
        let blueComponent = Int(round(blue * 255))

        return String(format: "#%02X%02X%02X", redComponent, greenComponent, blueComponent)
    }
}

private extension UIImage {
    func blurred(radius: Double) -> UIImage? {
        guard let inputImage = ciImage ?? CIImage(image: self) else { return nil }

        let clampFilter = CIFilter.affineClamp()
        clampFilter.inputImage = inputImage
        clampFilter.transform = .identity

        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = clampFilter.outputImage
        blurFilter.radius = Float(radius)

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard
            let outputImage = blurFilter.outputImage?.cropped(to: inputImage.extent),
            let cgImage = context.createCGImage(outputImage, from: inputImage.extent)
        else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }

    func drawAspectFill(in rect: CGRect) {
        let widthRatio = rect.width / size.width
        let heightRatio = rect.height / size.height
        let scale = max(widthRatio, heightRatio)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let drawOrigin = CGPoint(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2
        )

        draw(in: CGRect(origin: drawOrigin, size: drawSize))
    }
}

@Observable
class TagReaderService {
    static let shared = TagReaderService()
    private static let fileEnumerationConcurrencyLimit = 8
    private static let tagReadConcurrencyLimit = 4
    private static let albumBackgroundStyleVersion = 1
    
    @MainActor public var jobRunning = false
    @MainActor public private(set) var progressCompleted = 0
    @MainActor public private(set) var progressTotal = 0
    @MainActor public private(set) var currentJob: IndexingJob = .creatingDatabase

    private var modelContainer: ModelContainer?

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func run(clearCache: Bool = false) async {
        guard let modelContainer else {
            Logger.tagReader.error("No model container")
            return
        }
        
        await MainActor.run {
            jobRunning = true
        }
        
        let context = ModelContext(modelContainer)

        // drop everything if the cache should be cleared
        if clearCache {
            emptyDatabase(context: context)
        }

        // read files + checksums from the filesystem
        guard var fileList = await loadFileList() else {
            Logger.tagReader.error("Error loading files.")
            await MainActor.run {
                jobRunning = false
            }
            return
        }

        // if there are no files anymore clear the database and stop processing
        guard !fileList.isEmpty else {
            emptyDatabase(context: context)
            await MainActor.run {
                jobRunning = false
            }
            return
        }

        // read existing cache
        let fileCache = loadFileCache(context: context) ?? [:]

        // remove files from the database that got deleted or have a checksum missmatch
        cleanupOldFiles(files: fileList, cache: fileCache, context: context)

        // remove files from fileList that don't need to be parsed again
        fileList.removeCached(cache: fileCache)

        // gather tags of files
        do {
            let tags = try await getTags(
                files: fileList,
                context: context
            )
            
            // insert new tags
            do {
                try insertTags(tags: tags, context: context)
            } catch {
                Logger.tagReader
                    .error("Failed to insert tags: \(error.localizedDescription)")
                await MainActor.run {
                    jobRunning = false
                }
                return
            }
        } catch {
            Logger.tagReader.error("Failed to get tags: \(error.localizedDescription)")
            await MainActor.run {
                jobRunning = false
            }
            return
        }

        do {
            await beginJob(.preparingAssets)
            try await rebuildAlbumArtworkAssets(context: context)
        } catch {
            Logger.tagReader.error("Failed to rebuild album artwork assets: \(error.localizedDescription)")
        }

        // ensure no leftovers
        do {
            try clearLeftovers(context: context)
        } catch {
            Logger.tagReader.error("Failed to clear leftovers: \(error.localizedDescription)")
            await MainActor.run {
                jobRunning = false
            }
        }
        
        await MainActor.run {
            progressCompleted = progressTotal
            jobRunning = false
        }
    }

    private func beginJob(_ job: IndexingJob, total: Int = 1) async {
        await MainActor.run {
            currentJob = job
            progressCompleted = 0
            progressTotal = max(total, 1)
        }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 80_000_000)
    }

    private func updateCurrentJobTotal(_ total: Int) async {
        await MainActor.run {
            progressCompleted = 0
            progressTotal = max(total, 1)
        }
        await Task.yield()
    }

    private func completeCurrentJob() async {
        await MainActor.run {
            progressCompleted = progressTotal
        }
        await Task.yield()
    }

    private func advanceProgress() async {
        await MainActor.run {
            guard progressTotal > 0 else { return }
            progressCompleted = min(progressCompleted + 1, progressTotal)
        }
    }

    func clearLeftovers(context: ModelContext) throws {
        let artistFD = FetchDescriptor<Artist>(
            predicate: #Predicate { $0.albums.isEmpty
            })

        let artists = try context.fetch(artistFD)

        for artist in artists {
            context.delete(artist)
        }

        let albumFD = FetchDescriptor<Album>(predicate: #Predicate { $0.CDs.isEmpty })
        let albums = try context.fetch(albumFD)

        for album in albums {
            context.delete(album)
        }

        let CDFD = FetchDescriptor<CD>(predicate: #Predicate { $0.tracks.isEmpty })
        let CDs = try context.fetch(CDFD)

        for CD in CDs {
            context.delete(CD)
        }

        let trackFD = FetchDescriptor<Track>(predicate: #Predicate { $0.file == nil })
        let tracks = try context.fetch(trackFD)

        for track in tracks {
            context.delete(track)
        }

        let fileFD = FetchDescriptor<CachedFile>(predicate: #Predicate { $0.track == nil })
        let files = try context.fetch(fileFD)

        for file in files {
            context.delete(file)
        }

        let playlistPositionFD = FetchDescriptor<PlaylistPosition>(predicate: #Predicate { $0.track == nil })
        let playlistPositions = try context.fetch(playlistPositionFD)

        for playlistPosition in playlistPositions {
            context.delete(playlistPosition)
        }

        try context.save()
    }

    func insertTags(tags: [CachedFile], context: ModelContext) throws {
        var counter = 0

        guard tags.isEmpty == false else { return }
        
        for index in 1 ... tags.count {
            let cf = tags[index - 1]
            context.insert(cf)

            counter += 1
            if counter.isMultiple(of: 20) {
                try context.save()
            }
        }
        try context.save()
    }

    func groupTagsByArtist(tags: [TaggedFile], context: ModelContext) throws -> TaggedArtists {
        var group: TaggedArtists = []

        for artist in tags {
            let tag = artist.2
            let entity = try Artist.getOrCreate(
                name: tag.albumArtist,
                context: context
            )

            if let index = group.firstIndex(where: { $0.artist.persistentModelID == entity.persistentModelID }) {
                group[index].files.append(artist)
            } else {
                group.append((artist: entity, files: [artist]))
            }
        }

        return group
    }

    func groupTagsByAlbum(artist: Artist, tags: [TaggedFile], context: ModelContext) async throws -> TaggedAlbums {
        var group: TaggedAlbums = []

        for album in tags {
            let fileURL = album.0
            let tag = album.2
            let imageData = tag.attachedPictures.first?.data ?? coverImageData(nextTo: fileURL)
            let entity = try Album.getOrCreate(
                name: tag.albumTitle,
                by: artist,
                on: tag.releaseDate,
                image: imageData,
                context: context
            )

            if let index = group.firstIndex(where: { $0.album.persistentModelID == entity.persistentModelID }) {
                group[index].files.append(album)
            } else {
                group.append((album: entity, files: [album]))
            }
            await advanceProgress()
        }

        return group
    }

    func groupTagsByCD(album: Album, tags: [TaggedFile], context: ModelContext) throws -> TaggedCDs {
        var group: TaggedCDs = []

        for cd in tags {
            let tag = cd.2
            let entity = try CD.getOrCreate(
                number: tag.discNumber,
                album: album,
                context: context
            )

            if let index = group.firstIndex(where: { $0.cd.persistentModelID == entity.persistentModelID }) {
                group[index].files.append(cd)
            } else {
                group.append((cd: entity, files: [cd]))
            }
        }

        return group
    }

    func getTags(files: FileList, context: ModelContext) async throws -> [CachedFile] {
        var cached: [CachedFile] = []

        try await withThrowingTaskGroup(of: TaggedFile?.self) { group in
            let pendingFiles = Array(files)
            let limit = max(1, Self.tagReadConcurrencyLimit)
            var nextIndex = 0

            func enqueueNextTask() {
                guard nextIndex < pendingFiles.count else { return }
                let (path, checksum) = pendingFiles[nextIndex]
                nextIndex += 1

                group.addTask {
                    let sourceFile = try? AudioFile(url: path)
                    guard let sourceFile else {
                        return nil
                    }

                    return (path, checksum, sourceFile.metadata, sourceFile.properties)
                }
            }

            for _ in 0 ..< min(limit, pendingFiles.count) {
                enqueueNextTask()
            }

            var tagged = [TaggedFile]()
            while let result = try await group.next() {
                if let (path, checksum, meta, properties) = result {
                    tagged.append((path, checksum, meta, properties))
                }
                enqueueNextTask()
            }

            await beginJob(.creatingDatabase, total: tagged.count * 2)

            for artistGroup in try groupTagsByArtist(
                tags: tagged,
                context: context
            ) {
                for albumGroup in try await groupTagsByAlbum(
                    artist: artistGroup.artist,
                    tags: artistGroup.files,
                    context: context
                ) {
                    for cdGroup in try groupTagsByCD(
                        album: albumGroup.album,
                        tags: albumGroup.files,
                        context: context
                    ) {
                        
                        for track in cdGroup.files {
                            
                            let (path, fileId, tag, properties) = track
                            
                            let track = try Track.getOrCreate(
                                title: tag.title,
                                by: tag.artist,
                                number: tag.trackNumber,
                                runtime: properties.duration,
                                on: cdGroup.cd,
                                context: context
                            )
                            let getorCreateCacheFile = try CachedFile.getOrCreate(
                                filePath: path,
                                fileId: fileId,
                                track: track,
                                context: context
                            )
                            
                            cached.append(getorCreateCacheFile)
                            await advanceProgress()
                        }

                    }
                }
            }
            await completeCurrentJob()
        }

        return cached
    }

    private func dominantColorHexes(from imageData: Data?) -> [String] {
        guard
            let imageData,
            let image = UIImage(data: imageData),
            let colors = try? DominantColors.dominantColors(
                uiImage: image,
                maxCount: 6,
                options: [.excludeBlack, .excludeWhite]
            )
        else {
            return []
        }

        return colors.compactMap(\.hexString)
    }

    private func coverImageData(nextTo fileURL: URL) -> Data? {
        let coverURL = fileURL.deletingLastPathComponent().appendingPathComponent("cover.jpg")
        return try? Data(contentsOf: coverURL)
    }

    private func rebuildAlbumArtworkAssets(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Album>()
        let albums = try context.fetch(descriptor)
        await updateCurrentJobTotal(albums.count)
        var didChange = false

        for album in albums {
            let dominantColorHexes = dominantColorHexes(from: album.albumArt)
            let background = albumBackgroundData(
                artworkData: album.albumArt,
                dominantColorHexes: dominantColorHexes
            )
            if let background {
                album.dominantColorHex = dominantColorHexes.first
                album.dominantColorHexes = dominantColorHexes
                album.albumBackground = background
                album.albumBackgroundStyleVersion = Self.albumBackgroundStyleVersion
                didChange = true
            }
            await advanceProgress()
        }

        if didChange {
            try context.save()
        }
        await completeCurrentJob()
    }

    private func albumBackgroundData(artworkData: Data?, dominantColorHexes: [String]) -> Data? {
        let size = CGSize(width: 900, height: 1600)
        let palette = dominantColorHexes.compactMap(UIColor.init(hex:))
        let baseColors = palette.isEmpty ? [UIColor(named: "AppBackground") ?? .systemBackground] : palette
        let colors = baseColors.count == 1 ? [baseColors[0], baseColors[0]] : baseColors
        let artwork = artworkData.flatMap(UIImage.init(data:)) ?? UIImage(named: "missing_album_art")

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            let cgContext = context.cgContext

            // Same layer order as the old SwiftUI background:
            // gradient, blurred transparent cover, gradient, frosted glass shader.
            drawAlbumGradient(colors: colors, in: cgContext, size: size)

            if let blurredArtwork = blurredAlbumArtworkLayer(artwork: artwork, size: size) {
                cgContext.saveGState()
                cgContext.setAlpha(0.72)
                blurredArtwork.draw(in: CGRect(origin: .zero, size: size))
                cgContext.restoreGState()
            }

            cgContext.saveGState()
            cgContext.setBlendMode(.screen)
            cgContext.setAlpha(0.16)
            drawAlbumGradient(colors: colors, in: cgContext, size: size)
            cgContext.restoreGState()

            if let frostOverlay = roughFrostOverlay(size: size) {
                cgContext.saveGState()
                cgContext.setBlendMode(.softLight)
                cgContext.setAlpha(0.72)
                frostOverlay.draw(in: CGRect(origin: .zero, size: size))
                cgContext.restoreGState()
            }
        }

        return image.jpegData(compressionQuality: 0.84)
    }

    private func blurredAlbumArtworkLayer(artwork: UIImage?, size: CGSize) -> UIImage? {
        guard let artwork else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let layer = renderer.image { _ in
            let baseRect = CGRect(origin: .zero, size: size)
            let scaledRect = baseRect.insetBy(
                dx: -size.width * 0.225,
                dy: -size.height * 0.225
            )
            artwork.drawAspectFill(in: scaledRect)
        }

        return layer.blurred(radius: 50)
    }

    private func drawAlbumGradient(colors: [UIColor], in context: CGContext, size: CGSize) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let cgColors = colors.map(\.cgColor) as CFArray
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: nil) else {
            colors.first?.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            return
        }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    private func roughFrostOverlay(size: CGSize) -> UIImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let intensity: Float = 0.92
        let baseAlpha: Float = 0.16
        let alphaRange: Float = 0.12

        for y in 0 ..< height {
            for x in 0 ..< width {
                let frost = roughFrostValue(
                    x: Float(x),
                    y: Float(y),
                    intensity: intensity
                )
                let alpha = UInt8(max(0, min(255, Int(round((baseAlpha + frost * alphaRange) * 255)))))
                let offset = y * bytesPerRow + x * bytesPerPixel
                pixels[offset] = alpha
                pixels[offset + 1] = alpha
                pixels[offset + 2] = alpha
                pixels[offset + 3] = alpha
            }
        }

        guard
            let provider = CGDataProvider(data: Data(pixels) as CFData),
            let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func roughFrostValue(x: Float, y: Float, intensity: Float) -> Float {
        let coarseNoise = frostHash(
            x: floor(x / 3) * 0.1031,
            y: floor(y / 3) * 0.11369
        )
        let fineNoise = frostHash(
            x: floor(x / 1.35) * 0.1031,
            y: floor(y / 1.35) * 0.11369
        )
        let scratchHash = frostHash(
            x: y * 0.06 * 0.1031,
            y: floor(x / 28) * 0.11369
        )
        let scratches = smoothStep(edge0: 0.78, edge1: 1, value: scratchHash)

        return (coarseNoise * 0.62 + fineNoise * 0.28 + scratches * 0.22) * intensity
    }

    private func frostHash(x: Float, y: Float) -> Float {
        var px = fract(x)
        var py = fract(y)
        let dotValue = px * (py + 19.19) + py * (px + 19.19)
        px += dotValue
        py += dotValue
        return fract((px + py) * px)
    }

    private func smoothStep(edge0: Float, edge1: Float, value: Float) -> Float {
        let t = max(0, min(1, (value - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    func cleanupOldFiles(files: FileList, cache: FileCache, context: ModelContext) {
        var filesToPurge: [FileCacheEntry] = []
        for (path, entry) in cache {
            if files[path] == nil {
                filesToPurge.append(entry)
            } else if files[path] != entry.fileId {
                filesToPurge.append(entry)
            }
        }

        for entry in filesToPurge {
            let targetID = entry.persistentID
            let cachedFileDescriptor = FetchDescriptor<CachedFile>(
                predicate: #Predicate<CachedFile> { file in
                    file.persistentModelID == targetID
                })
            deleteObj(descriptor: cachedFileDescriptor, context: context)

            if let playlistPositionId = entry.playlistID {
                let playlistDescriptor = FetchDescriptor<PlaylistPosition>(
                    predicate: #Predicate { $0.persistentModelID == playlistPositionId })
                deleteObj(descriptor: playlistDescriptor, context: context)
            }

            if let cdID = entry.cdID {
                let cdDescriptor = FetchDescriptor<CD>(
                    predicate: #Predicate { $0.persistentModelID == cdID && $0.tracks.isEmpty })
                deleteObj(descriptor: cdDescriptor, context: context)
            }

            if let albumID = entry.albumID {
                let albumDescriptor = FetchDescriptor<Album>(
                    predicate: #Predicate { $0.persistentModelID == albumID && $0.CDs.isEmpty })
                deleteObj(descriptor: albumDescriptor, context: context)
                try? context.save()
            }

            if let artistID = entry.artistID {
                let artistDescriptor = FetchDescriptor<Artist>(
                    predicate: #Predicate { $0.persistentModelID == artistID && $0.albums.isEmpty })
                deleteObj(descriptor: artistDescriptor, context: context)
                try? context.save()
            }
        }
        try? context.save()
    }

    func deleteObj<T>(descriptor: FetchDescriptor<T>, context: ModelContext) {
        if let obj = try? context.fetch(descriptor).first {
            context.delete(obj)
        }
    }

    func loadFileList() async -> FileList? {
        let fileManager = FileManager.default

        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        guard
            let enumerator = fileManager.enumerator(
                at: documentsPath,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else { return nil }

        guard let objects = enumerator.allObjects as? [URL] else { return nil }

        let allURLs = objects.filter {
            targetExtensions.contains($0.pathExtension.lowercased())
        }

        let list = await withTaskGroup(of: (URL, Int64)?.self) { group in
            let limit = max(1, Self.fileEnumerationConcurrencyLimit)
            var nextIndex = 0

            func enqueueNextTask() {
                guard nextIndex < allURLs.count else { return }
                let url = allURLs[nextIndex]
                nextIndex += 1

                group.addTask {
                    let path = url.absoluteURL.path()

                    guard path != "" else { return nil }

                    guard let attributes = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .fileContentIdentifierKey]) else {
                        return nil
                    }

                    guard let fileId = attributes.fileContentIdentifier else {
                        await Logger.tagReader
                            .error("Missing file identifier for \(url.path)")
                        return nil
                    }
                    return (url, fileId)
                }
            }

            for _ in 0 ..< min(limit, allURLs.count) {
                enqueueNextTask()
            }

            var list: FileList = [:]
            while let result = await group.next() {
                if let (url, fileId) = result {
                    list[url] = fileId
                }
                enqueueNextTask()
            }
            return list
        }

        return list
    }

    func loadFileCache(context: ModelContext) -> FileCache? {
        let descriptor = FetchDescriptor<CachedFile>()

        let contextResult = try? context.fetch(descriptor)
        guard let contextResult else { return nil }

        var cache: FileCache = [:]

        for f in contextResult {
            cache[f.filePath] = FileCacheEntry(file: f)
        }

        return cache
    }

    func emptyDatabase(context: ModelContext) {
        cleanup(Artist.self, context: context)
        cleanup(Album.self, context: context)
        cleanup(CD.self, context: context)
        cleanup(Track.self, context: context)
        cleanup(CachedFile.self, context: context)
        cleanup(PlaylistPosition.self, context: context)
        try? context.save()
    }

    func cleanup<targetType: PersistentModel>(
        _ type: targetType.Type,
        context: ModelContext
    ) {
        let descriptor = FetchDescriptor<targetType>()

        let contextResult = try? context.fetch(descriptor)
        guard let contextResult else { return }

        for artist in contextResult {
            context.delete(artist)
        }
    }
}
