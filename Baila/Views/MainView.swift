//
//  ContentView.swift
//  Baile
//
//  Created by Karl on 30.04.26.
//

import SwiftData
import SwiftUI
import UIKit
import AVFoundation

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var artists: [Artist]
    @Query private var albums: [Album]
    @Query private var tracks: [Track]
    
    @Bindable private var player = PlaybackController.shared
    
    @SceneStorage("Loopmode") private var loopMode = PlaylistLoopMode.off
    @SceneStorage("AlbumSortByReleaseDate") private var sortAlbumsByReleaseDate = true
    @SceneStorage("AlbumSortAscending") private var albumSortAscending = false
    
    @State private var albumSortDescriptors = Album.makeSortDescriptors(
        sortByReleaseDate: true,
        ascending: false
    )
    
    @State private var searchTerm = ""
    @State private var isSearchPresented = false
    @State private var didLongPressPlayerButton = false
    @State private var playerIslandExpanded = false
    @State private var isAlbumScrollActive = false
    @State private var visibleAblumId : PersistentIdentifier?
    
    @Namespace private var ns
    
    private var isPlayerIslandVisible: Bool {
        !isSearchPresented && player.playable
    }
    
    private var isPlayerIslandExpanded: Bool {
        isPlayerIslandVisible && playerIslandExpanded
    }
    
    private var currentTrackAlbumIsVisible: Bool {
        guard let visibleAblumId,
              let currentAlbumId = player.currentTrack?.CD?.album?.persistentModelID else {
            return false
        }
        
        return visibleAblumId == currentAlbumId
    }
    
    private var playerIslandExpandedBinding: Binding<Bool> {
        Binding {
            playerIslandExpanded
        } set: { newValue in
            playerIslandExpanded = newValue
        }
    }
    
    var playerControls: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            
            Button {
                player.stop()
            } label: {
                Image(systemName: "stop.fill")
            }
            .disabled(!player.playing)
            
            Button {
                player.prev()
            } label: {
                Image(systemName: "backward.fill")
            }
            .disabled(player.currentPosition?.prev() == nil)
            Button {
                player.playPause()
            } label: {
                Image(systemName: player.playing ? "pause.fill" : "play.fill")
            }
            
            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
            }
            .disabled(player.currentPosition?.next() == nil)
            
            Button {
                // todo loop mode
            } label: {
                Image(systemName: "repeat")
            }
        }
    }
    
    private var settingsMenu: some View {
        Menu {
            LibraryScanMenu()
        } label: {
            Image(systemName: "gearshape")
        }
    }
    
    private var shuffleMenu: some View {
        Menu {
            Button {
            } label: {
                Label("Shuffle \(tracks.count) Songs", systemImage: "music.quarternote.3")
            }
            Button {
            } label: {
                Label("Shuffle \(albums.count) Albums", systemImage: "music.note.square.stack.fill")
            }
            Button {
            } label: {
                Label("Shuffle \(artists.count) Artists", systemImage: "person.2.fill")
            }
        } label: {
            Label("Shuffle", systemImage: "shuffle")
        }
    }
    
    private func toolbar(albumScrollProxy: ScrollViewProxy) -> some ToolbarContent {
        Group {
            ToolbarItem(placement: .bottomBar) {
                settingsMenu
            }
            
            ToolbarItem(placement: .bottomBar) {
                Menu {
                    Button {
                        sortAlbumsByReleaseDate = true
                    } label: {
                        Label("Release Date", systemImage: "calendar")
                    }
                    
                    Button {
                        sortAlbumsByReleaseDate = false
                    } label: {
                        Label("Title", systemImage: "textformat")
                    }
                    
                    Divider()
                    
                    Button {
                        albumSortAscending = false
                    } label: {
                        Label("Descending", systemImage: "arrow.down")
                    }
                    Button {
                        albumSortAscending = true
                    } label: {
                        Label("Ascending", systemImage: "arrow.up")
                    }
                } label: {
                    Label("Sort By", systemImage: "line.3.horizontal.decrease")
                }
            }
            
            ToolbarSpacer(.flexible, placement: .bottomBar)
            
            ToolbarItem(placement: .bottomBar) {
                shuffleMenu
            }
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
        }
    }
    
    private var filteredAlbums: [Album] {
        let sortedAlbums = albums.sorted(using: albumSortDescriptors)
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedSearchTerm.isEmpty == false else {
            return sortedAlbums
        }
        
        return sortedAlbums.filter { album in
            album.name.localizedCaseInsensitiveContains(trimmedSearchTerm)
            || (album.artist?.name.localizedCaseInsensitiveContains(trimmedSearchTerm) ?? false)
        }
    }

    private func scrollToCurrentAlbum(using albumScrollProxy: ScrollViewProxy) {
        guard let albumID = player.currentTrack?.CD?.album?.id else { return }

        let scrollToAlbum = {
            withAnimation(.easeInOut(duration: 0.35)) {
                albumScrollProxy.scrollTo(albumID, anchor: .center)
            }
        }

        guard searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            scrollToAlbum()
            return
        }

        searchTerm = ""
        Task { @MainActor in
            await Task.yield()
            scrollToAlbum()
        }
    }
    
    private func expandPlayerIslandIfCurrentAlbumIsVisible() {
        guard isPlayerIslandVisible,
              isAlbumScrollActive == false,
              currentTrackAlbumIsVisible else {
            return
        }
        
        withAnimation(PlayerIsland.spring) {
            playerIslandExpanded = true
        }
    }

    var body: some View {
        ScrollViewReader { albumScrollProxy in
            ZStack(alignment: .bottom) {
                NavigationStack {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(filteredAlbums, id: \.id) { album in
                                AlbumPane(
                                    album: album,
                                    currentAlbumId: $visibleAblumId,
                                    onPaneTap: {
                                        withAnimation(PlayerIsland.spring) {
                                            playerIslandExpanded = false
                                        }
                                    },
                                ) { album in
                                    visibleAblumId = album.persistentModelID
                                    withAnimation(PlayerIsland.spring) {
                                        playerIslandExpanded = true
                                    }
                                    player.play(album)
                                }
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .containerRelativeFrame([.horizontal, .vertical])
                                    .id(album.id)
                            }
                        }
                        .scrollTargetLayout()
                        .background(Color.clear)
                    }
                    .scrollIndicators(.hidden)
                    .scrollContentBackground(.hidden)
                    .scrollEdgeEffectHidden(true, for: [.top, .bottom])
                    .scrollTargetBehavior(.paging)
                    .toolbar {
                        toolbar(albumScrollProxy: albumScrollProxy)
                    }
                    .searchable(
                        text: $searchTerm,
                        isPresented: $isSearchPresented,
                        placement: .toolbar,
                        prompt: "Search artists and albums"
                    )
                    .searchToolbarBehavior(.minimize)
                    .preferredColorScheme(.dark)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .libraryIndexing()
                    .preferredColorScheme(.dark)
                    .onChange(of: sortAlbumsByReleaseDate, initial: true) { _, newValue in
                        albumSortDescriptors = Album.makeSortDescriptors(
                            sortByReleaseDate: newValue,
                            ascending: albumSortAscending
                        )
                    }
                    .onChange(of: albumSortAscending, initial: true) { _, newValue in
                        albumSortDescriptors = Album.makeSortDescriptors(
                            sortByReleaseDate: sortAlbumsByReleaseDate,
                            ascending: newValue
                        )
                    }
                    .onScrollPhaseChange {oldPhase,newPhase in
                        if newPhase.isScrolling {
                            isAlbumScrollActive = true
                            playerIslandExpanded = false
                        } else if oldPhase.isScrolling {
                            isAlbumScrollActive = false
                            expandPlayerIslandIfCurrentAlbumIsVisible()
                        }
                    }
                    .ignoresSafeArea(edges: .all)
                    .preferredColorScheme(.dark)
                    // todo .onContinueUserActivity(MainView.productUser, perform: )
                }
    
                if isPlayerIslandVisible {
                    PlayerIsland(
                        isExpanded: playerIslandExpandedBinding,
                        visibleAlbumId: $visibleAblumId,
                        onArtworkTap: {
                            scrollToCurrentAlbum(using: albumScrollProxy)
                        }
                    )
                    .ignoresSafeArea(edges: .bottom)
                    .transition(
                        .move(edge: .bottom)
                            .combined(with: .opacity)
                    )
                }
            }
            .onChange(of: visibleAblumId) {
                expandPlayerIslandIfCurrentAlbumIsVisible()
            }
            .animation(PlayerIsland.spring, value: isPlayerIslandVisible)
        }
    }
}


#Preview {
    MainView().modelContainer(Utils.previewContainer)
}
