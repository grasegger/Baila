//
//  ContentView.swift
//  Baile
//
//  Created by Karl on 30.04.26.
//

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
                    ArtistListItem(artist: artist)
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
}

#Preview {
    let container = Utils.previewContainer

    ContentView().modelContainer(container)
}
