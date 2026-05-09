//
//  IndexView.swift
//  Baila
//
//  Created by Karl on 09.05.26.
//

import SwiftData
import SwiftUI

private enum LibraryScanner {
    static func start(clearCache: Bool = false) async {
        guard await shouldStart(clearCache: clearCache) else { return }
        await TagReaderService.shared.run(clearCache: clearCache)
    }

    private static func shouldStart(clearCache: Bool) async -> Bool {
        if clearCache {
            return true
        }

        return await MainActor.run {
            !TagReaderService.shared.jobRunning
        }
    }
}

struct LibraryScanMenu: View {
    @Bindable private var tagReader = TagReaderService.shared

    var body: some View {
        Button {
            Task {
                await LibraryScanner.start()
            }
        } label: {
            Label(
                "Rescan library",
                systemImage: "document.viewfinder"
            )
        }

        Button {
            Task {
                await LibraryScanner.start(clearCache: true)
            }
        } label: {
            Label(
                "Reset library",
                systemImage: "trash"
            )
        }
    }
}

private struct LibraryIndexingModifier: ViewModifier {
    @Bindable private var tagReader = TagReaderService.shared
    @Query private var tracks: [Track]
    @State private var didAttemptInitialScan = false

    private let isRunningPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    func body(content: Content) -> some View {
        content
            .fullScreenCover(
                isPresented: Binding(
                    get: { tagReader.jobRunning },
                    set: { _ in }
                )
            ) {
                IndexView()
            }
            .task(id: tracks.count) {
                guard isRunningPreview == false else { return }
                await runInitialLibraryScanIfNeeded()
            }
    }

    private func runInitialLibraryScanIfNeeded() async {
        guard didAttemptInitialScan == false else { return }
        guard tracks.isEmpty else { return }

        didAttemptInitialScan = true
        await LibraryScanner.start()
    }
}

extension View {
    func libraryIndexing() -> some View {
        modifier(LibraryIndexingModifier())
    }
}

struct IndexView: View {
    @Bindable private var tagReader = TagReaderService.shared
    private let progressWidth: CGFloat = 240
    private let previewProgressCompleted: Int?
    private let previewProgressTotal: Int?
    private let previewCurrentJob: IndexingJob?

    init(
        progressCompleted: Int? = nil,
        progressTotal: Int? = nil,
        currentJob: IndexingJob? = nil
    ) {
        self.previewProgressCompleted = progressCompleted
        self.previewProgressTotal = progressTotal
        self.previewCurrentJob = currentJob
    }

    private var progressCompleted: Int {
        previewProgressCompleted ?? tagReader.progressCompleted
    }

    private var progressTotal: Int {
        previewProgressTotal ?? tagReader.progressTotal
    }

    private var currentJob: IndexingJob {
        previewCurrentJob ?? tagReader.currentJob
    }

    private var steppedProgressCompleted: Double {
        let total = Double(max(progressTotal, 1))
        let completed = Double(progressCompleted)
        guard completed < total else { return total }

        let stepCount = floor((completed / total) / 0.02)
        return stepCount * 0.02 * total
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Scanning library")
            Text("Please wait while your music is indexed.")

            VStack(spacing: 8) {
                ProgressView(
                    value: steppedProgressCompleted,
                    total: Double(max(progressTotal, 1))
                )
                .progressViewStyle(.linear)
                .frame(width: progressWidth)
                .clipped()

                Label(currentJob.rawValue, systemImage: currentJob.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: progressWidth)
                    .clipped()
            }
            .frame(width: progressWidth)
            .clipped()
        }
        .interactiveDismissDisabled(true)
    }
}

#Preview {
    TimelineView(.animation) { timeline in
        let phase = timeline.date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 5)
        let progress = Int((phase / 5) * 100)
        let jobs: [IndexingJob] = [
            .creatingDatabase,
            .preparingAssets,
        ]
        let currentJob = jobs[min(Int(phase / 2.5), jobs.count - 1)]

        IndexView(
            progressCompleted: progress,
            progressTotal: 100,
            currentJob: currentJob
        )
    }
}
