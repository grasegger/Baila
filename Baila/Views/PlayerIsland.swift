//
//  PlayerIsland.swift
//  Baila
//
//  Created by Karl on 09.05.26.
//

import SwiftData
import SwiftUI
import UIKit
import MediaPlayer


struct VolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        // Zeigt nur den Slider, nicht den AirPlay-Button (da wir den separat haben)
        return volumeView
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

struct PlayerIsland: View {
    static let spring = Animation.interpolatingSpring(
        mass: 0.72,
        stiffness: 260,
        damping: 18,
        initialVelocity: 0.45
    )

    @Bindable var player = PlaybackController.shared
    
    @Binding var isExpanded: Bool
    @Binding var visibleAlbumId : PersistentIdentifier?
    let forceExpanded: Bool
    var onArtworkTap : () -> Void

    init(
        isExpanded: Binding<Bool>,
        visibleAlbumId: Binding<PersistentIdentifier?>,
        forceExpanded: Bool = false,
        onArtworkTap: @escaping () -> Void,
    ) {
        self._isExpanded = isExpanded
        self._visibleAlbumId = visibleAlbumId
        self.forceExpanded = forceExpanded
        self.onArtworkTap = onArtworkTap
    }

    private var showsDetails: Bool {
        forceExpanded || isExpanded
    }

    private var runtime: String {
        guard let runtime = player.currentTrack?.runtime else {
            return "--:--"
        }
        let totalSeconds = max(0, Int(runtime.rounded()))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    @ViewBuilder
    private func artworkImage(size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let image = player.currentTrack?.CD?.album?.artworkImage ?? UIImage(
            named: "missing_album_art"
        ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: cornerRadius,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: cornerRadius,
                            style: .continuous
                        )
                        .stroke(.separator, lineWidth: 1)
                    }
        }
    }
    
    var sameAlbum : Bool {
        if let visibleAlbumId = visibleAlbumId, let albumId = player.currentTrack?.CD?.album?.persistentModelID {
            return visibleAlbumId == albumId
        } else {
            return false
        }
    }

    var body: some View {
        VStack(spacing: showsDetails ? 12 : 0) {
            if showsDetails && (!sameAlbum && !forceExpanded) {
                    GeometryReader { proxy in
                        HStack {
                            artworkImage(size: 320, cornerRadius: 36)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 320)
                }
                

            HStack(spacing: showsDetails ? 10 : 0) {
                if !showsDetails {
                    Button {
                        player.playPause()
                    } label: {
                        artworkImage(size: 48, cornerRadius: 200)
                    }
                }
            }
            if showsDetails {
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrack?.name ?? "Not Playing")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .foregroundStyle(Color.white)
                    if !sameAlbum {
                        Text(
                            "\(player.currentTrack?.CD?.album?.name ?? "---")"
                        )
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(Color.white)
                        .opacity(0.7)
                        Text(
                            player.currentTrack?.artist ?? player.currentTrack?.CD?.album?.artist?.name ?? "---"
                        )
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(Color.white)
                        .opacity(0.6)
                    }
                }
                .padding(.top, (sameAlbum || forceExpanded) ? 8 : 0)
                .frame(width: 320, alignment: .leading)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                HStack(spacing: 18) {
                    // todo read time from media live
                    Text("1:23")
                    ProgressView(
                        value: 55,
                        total: 100
                    )
                    .progressViewStyle(.linear)
                    Text("\(runtime)")
                }
                .foregroundStyle(Color.white.opacity(0.8))

                HStack(spacing: 18) {
                    Button {
                        // todo
                    } label: {
                        Image(systemName: "repeat")
                            .frame(width: 32, height: 32)
                    }
                    Button {
                        player.prev()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .frame(width: 32, height: 32)
                    }
                    .disabled(player.currentPosition?.hasPrev ?? false)

                    Button {
                        player.playPause()
                    } label: {
                        Image(
                            systemName: player.playing ? "pause.fill" : "play.fill"
                        )
                            .frame(width: 32, height: 32)
                    }

                    Button {
                        player.next()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .frame(width: 32, height: 32)
                    }
                    .disabled(player.currentPosition?.hasNext ?? false)
                    
                    if sameAlbum {
                        Button {
                            player.stop()
                        } label: {
                            Image(systemName: "stop.fill")
                                .frame(width: 32, height: 32)
                        }
                    } else {
                        Button {
                            onArtworkTap()
                        } label: {
                            Image(systemName: "scope")
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .foregroundStyle(Color.white)
                
            }
        }
        .padding(.horizontal, showsDetails ? 14 : 0)
        .padding(.top, showsDetails ? 14 : 0)
        .padding(.bottom, showsDetails ? 24 : 0)
        .frame(maxWidth: showsDetails ? .infinity : 48, minHeight: showsDetails ? 76 : 48)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: showsDetails ? 46 : 28, style: .continuous))
        .padding(.horizontal, showsDetails ? 12 : 0)
        .padding(.vertical, 16)
        .offset(y: showsDetails ? 36 : 22)
        .zIndex(1)
        .shadow(
            color: Color.black.opacity(0.4),
            radius: 16
        )
        .contentShape(RoundedRectangle(cornerRadius: showsDetails ? 30 : 28, style: .continuous))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                guard forceExpanded == false else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(Self.spring) {
                    isExpanded.toggle()
                }
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 16).onEnded { value in
                guard forceExpanded == false else { return }
                guard isExpanded else { return }
                guard value.translation.height > 24,
                      abs(value.translation.height) > abs(value.translation.width) else { return }

                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(Self.spring) {
                    isExpanded = false
                }
            }
        )
        .animation(Self.spring, value: showsDetails)
    }
}

#Preview {
    let container = Utils.previewContainer

    VStack(spacing: 32) {
        PlayerIsland(
            isExpanded: .constant(false),
            visibleAlbumId: .constant(nil),
            onArtworkTap: {},
        )

        PlayerIsland(
            isExpanded: .constant(false),
            visibleAlbumId: .constant(nil),
            forceExpanded: true,
            onArtworkTap: {},
        )
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
    .modelContainer(container)
    .preferredColorScheme(.light)
}
