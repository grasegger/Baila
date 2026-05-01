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
            VStack {
                albumArtwork
                Text(album.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.bottom, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var albumArtwork: some View {
        if let albumArt = UIImage(data: album.albumArt) {
            ZStack {
                Color.clear
                    .glassEffect(in: RoundedRectangle(cornerRadius: 0, style: .continuous))

                Image(uiImage: albumArt)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                    .padding(1)
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
            .clipped()
            .compositingGroup()
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
