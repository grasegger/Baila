//
//  ContentView.swift
//  Baile
//
//  Created by Karl on 30.04.26.
//

import OSLog
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var artists: [Artist]

    @State private var groupByArtist = true
    @State private var runServer = false
    @State private var runScan = false

    //private let appBackground = Color(white: 0.12)

    private var albumCount: Int {
        artists.reduce(0) { partialResult, artist in
            partialResult + artist.albums.count
        }
    }

    private var sortedArtists: [Artist] {
        artists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var artistSections: [(title: String, artists: [Artist])] {
        let groupedArtists = Dictionary(grouping: sortedArtists, by: artistSectionTitle(for:))

        return groupedArtists
            .map { key, value in
                (title: key, artists: value)
            }
            .sorted { lhs, rhs in
                lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(artistSections, id: \.title) { section in
                        Section {
                            ForEach(section.artists) { artist in
                                ArtistListItem(artist: artist, onSelectAlbum: playAlbum)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        } header: {
                            EmptyView()
                        }
                        .sectionIndexLabel(section.title)
                    }
                }
                .listSectionIndexVisibility(.visible)
            }
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("\(albumCount) Albums")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation {
                            runScan.toggle()
                        }
                    } label: {
                        Image(
                            systemName: runScan ? "document.viewfinder.fill" : "document.viewfinder"
                        )
                    }
                    .disabled(runScan)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation {
                            runServer.toggle()
                        }
                    } label: {
                        Image(
                            systemName: runServer ? "icloud.fill" : "icloud.dashed"
                        )
                    }
                }
                ToolbarItem {
                    Button(action: {}) {
                        Label("Shuffle all songs", systemImage: "shuffle")
                    }
                }
                ToolbarItem {
                    Button {
                        withAnimation {
                            groupByArtist.toggle()
                        }
                    } label: {
                        Image(systemName: groupByArtist ? "person.circle.fill" : "person.circle")
                    }
                }
            }
        }
    }

    private func playAlbum(_ album: Album) {
        guard let playlist = playlist() else {
            return
        }

        let sortedTracks = album.CDs
            .sorted { lhs, rhs in
                lhs.number < rhs.number
            }
            .flatMap { cd in
                cd.tracks.sorted { lhs, rhs in
                    lhs.number < rhs.number
                }
            }

        playlist.replaceQueue(with: sortedTracks)

        do {
            try modelContext.save()
        } catch {
            Logger.ui.error("Failed to save playlist changes: \(error.localizedDescription)")
        }

        guard let firstTrack = playlist.currentTrack else {
            return
        }

        PlaybackController.shared.play(track: firstTrack)
    }

    private func playlist() -> Playlist? {
        let singletonID = Playlist.defaultSingletonID
        let descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.singletonID == singletonID }
        )

        do {
            if let existingPlaylist = try modelContext.fetch(descriptor).first {
                return existingPlaylist
            }

            let newPlaylist = Playlist()
            modelContext.insert(newPlaylist)
            try modelContext.save()
            return newPlaylist
        } catch {
            Logger.ui.error("Failed to fetch playlist: \(error.localizedDescription)")
            return nil
        }
    }

    private func artistSectionTitle(for artist: Artist) -> String {
        guard let firstCharacter = artist.name.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "#"
        }

        let title = String(firstCharacter).uppercased()
        return title.rangeOfCharacter(from: .letters) == nil ? "#" : title
    }
}

#Preview {
    let container = Utils.previewContainer

    ContentView().modelContainer(container)
}
