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
    
    @State private var artworkImage: UIImage?
    @State private var suppressNextArtworkTap = false

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
        formattedTime(player.duration)
    }
    
    private var currentTime: String {
        formattedTime(player.currentTime)
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "0:00" }
        
        let totalSeconds = max(0, Int(time.rounded()))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    @ViewBuilder
    private func artworkImage(cornerRadius: CGFloat) -> some View {
        if let image = artworkImage ?? UIImage(named: "missing_album_art") {
            let shape = RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
            
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
                .clipShape(shape)
                .overlay {
                    shape
                        .stroke(.separator, lineWidth: 1)
                }
                .contentShape(shape)
                .onTapGesture {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(40))
                        
                        guard suppressNextArtworkTap == false else {
                            suppressNextArtworkTap = false
                            return
                        }
                        
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.playPause()
                    }
                }
        }
    }
    
    @ViewBuilder
    private var artwork: some View {
        if showsDetails && !sameAlbum {
            artworkImage(cornerRadius: 36)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .transition(
                    .opacity.combined(
                        with: .scale(scale: 0.96, anchor: .center)
                    )
                )
        } else if !showsDetails {
            artworkImage(cornerRadius: 36)
                .frame(width: 48, height: 48)
        }
    }
    
    private func refreshArtworkImage() {
        artworkImage = player.currentTrack?.CD?.album?.artworkImage
    }
    
    var sameAlbum : Bool {
        if let visibleAlbumId = visibleAlbumId, let albumId = player.currentTrack?.CD?.album?.persistentModelID {
            return visibleAlbumId == albumId
        } else {
            return false
        }
    }
    @State private var loopMode = PlaylistLoopMode.off
    
    private func advanceLoop() {
        switch loopMode {
        case .off:
            loopMode = PlaylistLoopMode.one
        case .one:
            loopMode = PlaylistLoopMode.all
        case .all:
            loopMode = PlaylistLoopMode.off
        }
        
        player.setLoopMode(loopMode)
    }
    
    @ViewBuilder
    var loopModeIcon : some View {
        switch loopMode {
        case .off:
            Image(systemName: "repeat")
                .frame(width: 32, height: 32)
                .foregroundStyle(.secondary)
        case .all:
            Image(systemName: "repeat").frame(width: 32, height: 32)
        case .one:
            Image(systemName: "repeat.1").frame(width: 32, height: 32)
        }
    }
    
    var body: some View {
        VStack(spacing: showsDetails ? 12 : 0) {
            artwork
                .animation(Self.spring, value: showsDetails)
                .animation(Self.spring, value: sameAlbum)
            
            if showsDetails {
                HStack {
                    if sameAlbum {
                        Spacer()
                    }
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
                    Spacer()
                }
                .padding(.top, (sameAlbum || forceExpanded) ? 16 : 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                
                HStack(spacing: 18) {
                    Text(currentTime)
                        .monospacedDigit()
                    ProgressView(
                        value: player.progress,
                        total: 1
                    )
                    .progressViewStyle(.linear)
                    Text(runtime)
                        .monospacedDigit()
                }
                .foregroundStyle(Color.white.opacity(0.4))
                
                HStack(spacing: 18) {
                    Button {
                        advanceLoop()
                    } label: {
                        loopModeIcon
                    }
                    Button {
                        player.prev()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!player.hasPreviousTrack)
                    
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
                    .disabled(!player.hasNextTrack)
                    
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
                .tint(.white)
                
            }
        }
        .padding(.horizontal, showsDetails ? 14 : 0)
        .padding(.top, showsDetails ? 14 : 0)
        .padding(.bottom, showsDetails ? 24 : 0)
        .frame(maxWidth: showsDetails ? .infinity : 48, minHeight: 48)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: showsDetails ? 46 : 28, style: .continuous))
        .padding(.horizontal, showsDetails ? 10 : 0)
        .padding(.vertical, 10)
        .offset(y: showsDetails ? 36 : 16)
        .zIndex(1)
        .shadow(
            color: Color.black.opacity(0.4),
            radius: 16
        )
        .contentShape(RoundedRectangle(cornerRadius: showsDetails ? 30 : 28, style: .continuous))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                guard forceExpanded == false else { return }
                suppressNextArtworkTap = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(Self.spring) {
                    isExpanded.toggle()
                }
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .onChanged { _ in
                    suppressNextArtworkTap = true
                }
                .onEnded { value in
                guard forceExpanded == false else { return }
                guard isExpanded else { return }
                guard value.translation.height > 24 else { return }
                
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(Self.spring) {
                    isExpanded = false
                }
                }
        )
        .animation(Self.spring, value: showsDetails)
        .animation(Self.spring, value: sameAlbum)
        .onAppear {
            refreshArtworkImage()
        }
        .onChange(of: player.currentTrack?.id) {
            refreshArtworkImage()
        }
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
