//
//  AlbumPane.swift
//  Baila
//
//  Created by Karl on 09.05.26.
//

import SwiftData
import SwiftUI
import Glur
import UIKit

struct AlbumPane: View {
    let album: Album
    @Binding var currentAlbumId : PersistentIdentifier?
    @Binding var partiallyVisibleAlbumId: PersistentIdentifier?
    @Environment(\.displayScale) private var displayScale
    
    let onPaneTap: () -> Void
    let onPlay: (Album) -> Void
#if DEBUG
    var forceBlur: Bool = false
#endif
    
    @State private var artworkImage: UIImage?
    @State private var backgroundImage: UIImage?
    
    private var fontColor: Color
    private var shadowColor: Color
    
    init(
        album: Album,
        currentAlbumId: Binding<PersistentIdentifier?>,
        partiallyVisibleAlbumId: Binding<PersistentIdentifier?>,
        onPaneTap: @escaping () -> Void,
        onPlay: @escaping (Album) -> Void,
        forceBlur: Bool = false
    ) {
        self.album = album
        self._currentAlbumId = currentAlbumId
        self._partiallyVisibleAlbumId = partiallyVisibleAlbumId
        self.onPaneTap = onPaneTap
        self.onPlay = onPlay
        self._artworkImage = State(initialValue: nil)
        self._backgroundImage = State(initialValue: nil)
        self.fontColor = album.isDark ? Color.white : Color.black
        self.shadowColor = album.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.2)
#if DEBUG
        self.forceBlur = forceBlur
#endif
    }
    
    private func loadImagesIfNeeded() {
        if artworkImage == nil {
            artworkImage = album.artworkImage
        }
        
        if backgroundImage == nil {
            backgroundImage = album.backgroundImage
        }
    }
    
    @ViewBuilder
    var details: some View {
        HStack(alignment: .center) {
            VStack(spacing: 4) {
                HStack {
                    Text(album.name)
                        .lineLimit(1)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black)
                    Spacer()
                }
                HStack {
                    Text(album.artist?.name ?? "---")
                        .font(.system(size: 16))
                        .lineLimit(1)
                        .foregroundStyle(Color.black)
                        .opacity(0.7)
                    Spacer()
                }
            }
            Text(album.releaseYear)
                .font(.system(size: 16 * 3))
                .foregroundStyle(Color.black)
                .opacity(0.3)
        }
        .padding(.all)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 36))
        .shadow(color: shadowColor, radius: 16)
        .padding(.bottom, 16)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentPadding: CGFloat = 16
            let contentWidth = max(0, proxy.size.width - (contentPadding * 2))
            let contentHeight = max(0, proxy.size.height - (contentPadding * 2))
            let artworkSize = contentWidth

            ZStack(alignment: .center) {
                details
                if let image = artworkImage {
                    Color.clear
                        .frame(width: artworkSize, height: artworkSize)
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onPlay(album)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(album.primaryColor, lineWidth: 1)
                        )
                        .shadow(color: shadowColor, radius: 16)
                    
                }
                
            }
            .frame(width: contentWidth, height: contentHeight)
            .padding(.all, contentPadding)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background {
                if let image = backgroundImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
#if DEBUG
                        .scaleEffect(1.5)
#endif
                        .glur(offset: 0.5,direction: .up)
                } else {
                    Color("AppBackground")
                }
            }
            .contentShape(Rectangle())
            .clipped()
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
    let container = PreviewContainer.previewContainer
    let albums = try? container.mainContext.fetch(FetchDescriptor<Album>())
    
    
    if let album = albums?.first {
        AlbumPane(
            album: album,
            currentAlbumId: .constant(nil),
            partiallyVisibleAlbumId: .constant(nil),
            onPaneTap: {
            },
            onPlay: {_ in },
            forceBlur:  true
        )
        .modelContainer(container)
        .frame(width: 393, height: 852)
        .preferredColorScheme(.light)
    }
}
