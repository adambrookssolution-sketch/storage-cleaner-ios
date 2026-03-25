import SwiftUI
import Photos

/// Full-screen view showing all videos sorted by size with selection and batch deletion.
struct VideosListView: View {
    @StateObject private var viewModel: VideosViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        assets: [PHAsset],
        thumbnailService: ThumbnailCacheService,
        deletionService: PhotoDeletionService
    ) {
        _viewModel = StateObject(wrappedValue: VideosViewModel(
            assets: assets,
            thumbnailService: thumbnailService,
            deletionService: deletionService
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.assets.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: AppConstants.UI.cardSpacing) {
                        headerView

                        ForEach(viewModel.assets, id: \.localIdentifier) { asset in
                            videoItemCard(asset)
                                .onAppear {
                                    viewModel.loadThumbnails(for: [asset])
                                }
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, AppConstants.UI.horizontalPadding)
                }

                BatchActionBarView(
                    selectedCount: viewModel.totalSelectedCount,
                    potentialSavings: viewModel.totalPotentialSavings,
                    accentColor: ColorTokens.primaryBlue,
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
                        .foregroundColor(ColorTokens.primaryBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .padding(12)
                    .background(ColorTokens.primaryBlue.cornerRadius(10))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 90)
                }
            }
        }
        .navigationTitle(NSLocalizedString("videos.title", comment: ""))
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
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $viewModel.showDeleteConfirmation) {
            DeletionConfirmationView(
                selectedCount: viewModel.totalSelectedCount,
                savedBytes: viewModel.totalPotentialSavings,
                itemLabel: NSLocalizedString("videos.itemLabel", comment: ""),
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
                DeletionSuccessView(result: result, itemLabel: NSLocalizedString("videos.itemLabel", comment: ""), destination: .photoLibrary) {
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
                        Text(String(format: NSLocalizedString("videos.deleting", comment: ""), viewModel.totalSelectedCount))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Text(NSLocalizedString("videos.confirmationNotice", comment: ""))
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

    // MARK: - Video Item Card

    private func videoItemCard(_ asset: PHAsset) -> some View {
        let id = asset.localIdentifier
        let isSelected = viewModel.selectedIds.contains(id)

        return HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
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
                                Image(systemName: "video.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(.systemGray3))
                            )
                    }
                }
                .frame(width: 100, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Duration badge
                VStack {
                    Spacer()
                    HStack {
                        Text(asset.formattedDuration)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.7)))
                        Spacer()
                    }
                    .padding(4)
                }
                .frame(width: 100, height: 80)

                // Selection checkbox
                ZStack {
                    Circle()
                        .fill(isSelected ? ColorTokens.primaryBlue : Color.white.opacity(0.8))
                        .frame(width: 24, height: 24)
                        .shadow(radius: 2)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(4)
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.estimatedFileSize.formattedSize)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ColorTokens.primaryText)

                Text(asset.formattedDuration)
                    .font(.system(size: 13))
                    .foregroundColor(ColorTokens.secondaryText)

                Text(asset.formattedDate)
                    .font(.system(size: 13))
                    .foregroundColor(ColorTokens.tertiaryText)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(ColorTokens.primaryBlue)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.cardCornerRadius)
                .stroke(isSelected ? ColorTokens.primaryBlue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            viewModel.toggleSelection(assetId: id)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: NSLocalizedString("videos.countFound", comment: ""), viewModel.totalVideoCount))
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.secondaryText)
            Text(String(format: NSLocalizedString("videos.totalSize", comment: ""), viewModel.totalSize.formattedSize))
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.secondaryText)

            if viewModel.totalSelectedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.successGreen)
                    Text(String(format: NSLocalizedString("videos.savingsMessage", comment: ""), viewModel.totalPotentialSavings.formattedSize, viewModel.totalSelectedCount))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorTokens.successGreen)
                }
                .padding(.top, 2)
            }

            if !viewModel.assets.isEmpty && viewModel.selectedIds.count > 0 {
                Text(NSLocalizedString("videos.preselectedMessage", comment: ""))
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
            Text(NSLocalizedString("videos.emptyTitle", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)
            Text(NSLocalizedString("videos.emptyMessage", comment: ""))
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
            Spacer()
        }
    }
}
