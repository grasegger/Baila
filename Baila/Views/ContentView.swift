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

    var body: some View {
        NavigationStack {
            List {
                ForEach(
                    artists
                        .sorted { $0.name.lowercased() < $1.name.lowercased()
                    }) { artist in
                    ArtistListItem(artist: artist, onSelectAlbum: playAlbum)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("23564 Albums")
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
}

#Preview {
    let container = Utils.previewContainer

    ContentView().modelContainer(container)
}
