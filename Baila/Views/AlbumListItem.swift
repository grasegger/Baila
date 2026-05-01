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
                Text(album.releaseDate, format: .dateTime.year())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(Font.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var albumArtwork: some View {
        if let albumArt = UIImage(data: album.albumArt) {
            Image(uiImage: albumArt)
                .resizable()
                .scaledToFit()
                .clipped()
                .frame(width: 120, height: 120)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.tertiary)
                .overlay {
                    Image(systemName: "music.note.list")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 120, height: 120)
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
