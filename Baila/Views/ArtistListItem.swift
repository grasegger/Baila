//
//  Artist.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//

import SwiftData
import SwiftUI

struct ArtistListItem: View {
    let artist: Artist
    let onSelectAlbum: (Album) -> Void

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        VStack {
            Text(artist.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.all)
                .font(.largeTitle)
                .lineLimit(1)
                .truncationMode(.tail)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(
                    artist.albums.sorted {$0.releaseDate > $1.releaseDate },
                    id: \.self
                ) { album in
                    AlbumListItem(
                        album: album,
                        onTap: onSelectAlbum
                    )
                }
            }
            .padding(.all)
        }
    }
}

#Preview {
    let image = UIImage(named: "albumArt")
    let data = image?.pngData()
    let artist = Artist(name: "Artist",
                        albums: [
                            Album(
                                name: "Album",
                                releaseDate: Date(),
                                albumArt: data!,
                                CDs: [],
                                artist: Artist(name: "Artist", albums: [])
                            ),
                            Album(
                                name: "Album2",
                                releaseDate: Date(timeIntervalSinceNow: -60 * 60 * 24 * 365 * 5),
                                albumArt: data!,
                                CDs: [],
                                artist: Artist(name: "Artist", albums: [])
                            ),
                        ]
    )

    ArtistListItem(artist: artist) { _ in }
}
