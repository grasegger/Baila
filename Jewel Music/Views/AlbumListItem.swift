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
    
    var body : some View {
        let albumArt =  UIImage(data: album.albumArt)!
        VStack {
            Image (uiImage: albumArt)
                .resizable()
                .scaledToFit()
                .clipped()
                .frame(width: 120, height: 120)
            Text(album.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(album.releaseDate, format: .dateTime.year())
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(Font.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.bottom,16)
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
    AlbumListItem(album: album)
}
