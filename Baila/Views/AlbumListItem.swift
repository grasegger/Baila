//
//  AlbumView.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//


import SwiftData
import SwiftUI

struct AlbumListItem: View {
    let album: Album
    let onTap: (Album) -> Void
    
    var body : some View {
        Button {
            onTap(album)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                albumArtwork
                Text(album.name)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.bottom, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var albumArtwork: some View {
        if let albumArt = UIImage(data: album.albumArt) {
            GeometryReader { proxy in
                ZStack {
                    Color.clear
                        .glassEffect(in: RoundedRectangle(cornerRadius: 0, style: .continuous))

                    Image(uiImage: albumArt)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width - 2, height: proxy.size.width - 2)
                        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Text(album.releaseDate, format: .dateTime.year())
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .glassEffect()
                                .padding(4)
                        }
                }
                .frame(width: proxy.size.width, height: proxy.size.width)
                .clipped()
                .compositingGroup()
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }
}

#Preview {
    let image = UIImage(named: "albumArt")
    let data = image?.pngData()
    let album = Album(
        name: "Album",
        releaseDate: Date(),
        albumArt: data!,
        CDs: [],
        artist: Artist(name: "Artist", albums: [])
    )
    AlbumListItem(album: album) { _ in }
}
