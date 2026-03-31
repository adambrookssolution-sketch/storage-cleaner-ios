import SwiftUI
import Photos

/// Full-screen grid view showing all screenshots sorted by date with batch deletion.
struct ScreenshotsListView: View {
    @StateObject private var viewModel: ScreenshotsViewModel
    @Environment(\.dismiss) private var dismiss
    let scanProgress: ScanProgress

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    init(
        assets: [PHAsset],
        fileSizeCache: [String: Int64],
        thumbnailService: ThumbnailCacheService,
        deletionService: PhotoDeletionService,
        scanProgress: ScanProgress = .idle
    ) {
        _viewModel = StateObject(wrappedValue: ScreenshotsViewModel(
            assets: assets,
            fileSizeCache: fileSizeCache,
            thumbnailService: thumbnailService,
            deletionService: deletionService
        ))
        self.scanProgress = scanProgress
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.assets.isEmpty && !scanProgress.isScanning {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: AppConstants.UI.cardSpacing) {
                        // Scan progress banner while scan is still running
                        if scanProgress.isScanning {
                            ScanProgressView(progress: scanProgress)
                                .padding(.horizontal, AppConstants.UI.horizontalPadding)
                                .transition(.opacity)
                        }

                        headerView

                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(viewModel.displayedAssets, id: \.localIdentifier) { asset in
                                screenshotCell(asset)
                                    .onAppear {
                                        viewModel.loadThumbnails(for: [asset])
                                        viewModel.loadNextPageIfNeeded(currentAsset: asset)
                                    }
                            }
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, AppConstants.UI.horizontalPadding)
                }

                BatchActionBarView(
                    selectedCount: viewModel.totalSelectedCount,
                    potentialSavings: viewModel.totalPotentialSavings,
                    accentColor: Color.purple,
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
                        .foregroundColor(Color.purple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .padding(12)
                    .background(Color.purple.cornerRadius(10))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 90)
                }
            }
        }
        .navigationTitle(NSLocalizedString("screenshots.title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(NSLocalizedString("general.selectAll", comment: "")) { viewModel.selectAll() }
                    Button(NSLocalizedString("general.deselectAll", comment: "")) { viewModel.deselectAll() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onDisappear {
            // Evict thumbnails when leaving this screen to free cache for other screens
            viewModel.evictThumbnails(for: viewModel.assets.map(\.localIdentifier))
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $viewModel.showDeleteConfirmation) {
            DeletionConfirmationView(
                selectedCount: viewModel.totalSelectedCount,
                savedBytes: viewModel.totalPotentialSavings,
                itemLabel: NSLocalizedString("screenshots.itemLabel", comment: ""),
                destination: .photoLibrary,
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
                DeletionSuccessView(result: result, itemLabel: NSLocalizedString("screenshots.itemLabel", comment: ""), destination: .photoLibrary) {
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
                        Text(String(format: NSLocalizedString("screenshots.deleting", comment: ""), viewModel.totalSelectedCount))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Text(NSLocalizedString("screenshots.confirmationNotice", comment: ""))
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

    // MARK: - Screenshot Grid Cell

    private func screenshotCell(_ asset: PHAsset) -> some View {
        let id = asset.localIdentifier
        let isSelected = viewModel.selectedIds.contains(id)

        return ZStack(alignment: .topTrailing) {
            // Thumbnail
            Group {
                if let image = viewModel.thumbnails[id] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 20))
                                .foregroundColor(Color(.systemGray3))
                        )
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Selection checkbox
            ZStack {
                Circle()
                    .fill(isSelected ? Color.purple : Color.white.opacity(0.8))
                    .frame(width: 24, height: 24)
                    .shadow(radius: 2)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(6)

            // File size badge — from cache, no disk read
            VStack {
                Spacer()
                HStack {
                    Text(viewModel.fileSize(for: asset).formattedSize)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                    Spacer()
                }
                .padding(4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            viewModel.toggleSelection(assetId: id)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: NSLocalizedString("screenshots.count", comment: ""), viewModel.totalScreenshotCount))
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.secondaryText)
            Text(String(format: NSLocalizedString("screenshots.totalSize", comment: ""), viewModel.totalSize.formattedSize))
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.secondaryText)

            if viewModel.totalSelectedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.successGreen)
                    Text(String(format: NSLocalizedString("screenshots.savingsMessage", comment: ""), viewModel.totalPotentialSavings.formattedSize, viewModel.totalSelectedCount))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorTokens.successGreen)
                }
                .padding(.top, 2)
            }

            if viewModel.totalSelectedCount == viewModel.totalScreenshotCount && viewModel.totalScreenshotCount > 0 {
                Text(NSLocalizedString("screenshots.preselectedMessage", comment: ""))
                    .font(.system(size: 12))
                    .foregroundColor(ColorTokens.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.successGreen)
            Text(NSLocalizedString("screenshots.emptyTitle", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)
            Text(NSLocalizedString("screenshots.emptyMessage", comment: ""))
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
            Spacer()
        }
    }
}
