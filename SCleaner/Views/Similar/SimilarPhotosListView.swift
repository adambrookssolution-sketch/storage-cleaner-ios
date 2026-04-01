import SwiftUI

/// Full-screen view showing all similar photo groups with batch action bar.
struct SimilarPhotosListView: View {
    @StateObject private var viewModel: SimilarPhotosViewModel
    @Environment(\.dismiss) private var dismiss
    let scanProgress: ScanProgress

    // Pagination for groups
    private static let groupPageSize = 20
    @State private var displayedGroupCount: Int = 20

    init(
        groups: [SimilarGroup],
        thumbnailService: ThumbnailCacheService,
        deletionService: PhotoDeletionService,
        scanProgress: ScanProgress = .idle
    ) {
        _viewModel = StateObject(wrappedValue: SimilarPhotosViewModel(
            groups: groups,
            thumbnailService: thumbnailService,
            deletionService: deletionService
        ))
        self.scanProgress = scanProgress
    }

    private var displayedGroups: [SimilarGroup] {
        Array(viewModel.groups.prefix(displayedGroupCount))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.groups.isEmpty && !scanProgress.isScanning {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: AppConstants.UI.cardSpacing) {
                        if scanProgress.isScanning {
                            ScanProgressView(progress: scanProgress)
                                .padding(.horizontal, AppConstants.UI.horizontalPadding)
                                .transition(.opacity)
                        }

                        headerView

                        ForEach(displayedGroups) { group in
                            similarGroupCard(group)
                                .onAppear {
                                    viewModel.loadThumbnails(for: group)
                                    loadMoreGroupsIfNeeded(current: group)
                                }
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, AppConstants.UI.horizontalPadding)
                }

                BatchActionBarView(
                    selectedCount: viewModel.totalSelectedCount,
                    potentialSavings: viewModel.totalPotentialSavings,
                    accentColor: ColorTokens.warningOrange,
                    onDelete: { viewModel.confirmDeletion() }
                )
            }

            if let msg = viewModel.limitMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        Button(NSLocalizedString("general.becomePro", comment: "")) {
                            viewModel.showPaywall = true
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(ColorTokens.warningOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .padding(12)
                    .background(ColorTokens.warningOrange.cornerRadius(10))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 90)
                }
            }
        }
        .navigationTitle(NSLocalizedString("similar.title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .onDisappear {
            let allIds = viewModel.groups.flatMap { $0.photos.map(\.id) }
            viewModel.evictThumbnails(for: allIds)
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $viewModel.showDeleteConfirmation) {
            DeletionConfirmationView(
                selectedCount: viewModel.totalSelectedCount,
                savedBytes: viewModel.totalPotentialSavings,
                onConfirm: {
                    viewModel.showDeleteConfirmation = false
                    Task { await viewModel.executeDelete() }
                },
                onCancel: {
                    viewModel.showDeleteConfirmation = false
                }
            )
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $viewModel.showDeleteSuccess) {
            if let result = viewModel.deleteResult {
                DeletionSuccessView(result: result) {
                    viewModel.showDeleteSuccess = false
                }
            }
        }
        .overlay {
            if viewModel.isDeleting {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text(String(format: NSLocalizedString("similar.deleting", comment: ""), viewModel.totalSelectedCount))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Text(NSLocalizedString("similar.confirmationNotice", comment: ""))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }

    // MARK: - Pagination

    private func loadMoreGroupsIfNeeded(current group: SimilarGroup) {
        guard displayedGroupCount < viewModel.groups.count else { return }
        let threshold = max(0, displayedGroupCount - 5)
        if let index = viewModel.groups.firstIndex(where: { $0.id == group.id }),
           index >= threshold {
            displayedGroupCount = min(displayedGroupCount + Self.groupPageSize, viewModel.groups.count)
        }
    }

    // MARK: - Similar Group Card

    private func similarGroupCard(_ group: SimilarGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: NSLocalizedString("similar.groupCount", comment: ""), group.count))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ColorTokens.primaryText)
                Spacer()
                Text(group.totalSize.formattedSize)
                    .font(.system(size: 13))
                    .foregroundColor(ColorTokens.secondaryText)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(group.photos.enumerated()), id: \.element.id) { index, photo in
                        SelectablePhotoView(
                            assetId: photo.id,
                            isSelected: viewModel.selectedIds.contains(photo.id),
                            isBestResult: index == group.bestResultIndex,
                            thumbnail: viewModel.thumbnails[photo.id],
                            fileSize: photo.fileSize,
                            onToggle: { viewModel.toggleSelection(assetId: photo.id) }
                        )
                        .frame(width: 110)
                    }
                }
            }

            HStack(spacing: 12) {
                Button(NSLocalizedString("similar.keepAll", comment: "")) {
                    viewModel.deselectAllInGroup(group)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorTokens.primaryBlue)

                Button(NSLocalizedString("similar.selectSimilar", comment: "")) {
                    viewModel.selectAllInGroup(group)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorTokens.warningOrange)

                Spacer()
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: NSLocalizedString("similar.groupsFound", comment: ""), viewModel.totalGroupCount))
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.secondaryText)
            Text(String(format: NSLocalizedString("similar.photosCount", comment: ""), viewModel.totalSimilarCount))
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.successGreen)
            Text(NSLocalizedString("similar.emptyTitle", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)
            Text(NSLocalizedString("similar.emptyMessage", comment: ""))
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
            Spacer()
        }
    }
}
