//
//  AlbumPane.swift
//  Baila
//
//  Created by Karl on 09.05.26.
//

import SwiftData
import SwiftUI
import UIKit

struct AlbumPane: View {
    let album: Album
    @Binding var currentAlbumId : PersistentIdentifier?
    @Binding var partiallyVisibleAlbumId: PersistentIdentifier?
    
    let onPaneTap: () -> Void
    let onPlay: (Album) -> Void
    
    @State private var artworkImage: UIImage?
    @State private var backgroundImage: UIImage?
    
    init(
        album: Album,
        currentAlbumId: Binding<PersistentIdentifier?>,
        partiallyVisibleAlbumId: Binding<PersistentIdentifier?>,
        onPaneTap: @escaping () -> Void,
        onPlay: @escaping (Album) -> Void
    ) {
        self.album = album
        self._currentAlbumId = currentAlbumId
        self._partiallyVisibleAlbumId = partiallyVisibleAlbumId
        self.onPaneTap = onPaneTap
        self.onPlay = onPlay
        self._artworkImage = State(initialValue: nil)
        self._backgroundImage = State(initialValue: nil)
    }
    
    private func loadImagesIfNeeded() {
        if artworkImage == nil {
            artworkImage = album.artworkImage
        }
        
        if backgroundImage == nil {
            backgroundImage = album.backgroundImage
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let contentPadding: CGFloat = 16
            let verticalSpacing: CGFloat = 12
            let textHeight: CGFloat = 44
            let availableWidth = max(44, proxy.size.width - (2 * contentPadding))
            let availableHeight = max(44, proxy.size.height - (2 * contentPadding))
            let coverSize = max(44, min(availableWidth, availableHeight - (2 * (verticalSpacing + textHeight))))
            let fontSize = 16.0
            let cardShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

            VStack(alignment: .center, spacing: 0) {
                if let image = artworkImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: coverSize, height: coverSize)
                        .cornerRadius(12 - 5)
                        .clipped()
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onPlay(album)
                        }
                        .padding(5)
                        .shadow(color: Color.black.opacity(0.1), radius: 5)
                }

                HStack(alignment: .center) {
                    VStack(spacing: 4) {
                        HStack {
                            Text(album.name)
                                .lineLimit(1)
                                .font(.system(size: fontSize, weight: .bold))
                            Spacer()
                        }
                        HStack {
                            Text(album.artist?.name ?? "---")
                                .font(.system(size: fontSize))
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    Text(album.releaseYear)
                        .font(.system(size: fontSize * 3))
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .frame(width: coverSize)
            }
            .background(.thickMaterial)
            .clipShape(cardShape)
            .shadow(color: .black.opacity(0.2), radius: 16)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background {
                if let image = backgroundImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    Color("AppBackground")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onPaneTap()
            }
            .onScrollVisibilityChange(threshold: 0.9) { isVisible in
                if isVisible && currentAlbumId != album.persistentModelID {
                    currentAlbumId = album.persistentModelID
                }
            }
            .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                if isVisible && partiallyVisibleAlbumId != album.persistentModelID {
                    partiallyVisibleAlbumId = album.persistentModelID
                }
            }
            .onAppear {
                loadImagesIfNeeded()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let container = Utils.previewContainer
    let albums = try? container.mainContext.fetch(FetchDescriptor<Album>())
    

    if let album = albums?.first {
        AlbumPane(
            album: album,
            currentAlbumId: .constant(nil),
            partiallyVisibleAlbumId: .constant(nil),
            onPaneTap: {
            },
            onPlay: {_ in }
            )
            .modelContainer(container)
            .frame(width: 393, height: 852)
            .preferredColorScheme(.light)
    }
}
