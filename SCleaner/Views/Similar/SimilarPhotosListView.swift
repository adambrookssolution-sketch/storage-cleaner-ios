import SwiftUI

/// Full-screen view showing all similar photo groups with batch action bar.
/// Uses orange accent instead of red (lower urgency than duplicates).
struct SimilarPhotosListView: View {
    @StateObject private var viewModel: SimilarPhotosViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        groups: [SimilarGroup],
        thumbnailService: ThumbnailCacheService,
        deletionService: PhotoDeletionService
    ) {
        _viewModel = StateObject(wrappedValue: SimilarPhotosViewModel(
            groups: groups,
            thumbnailService: thumbnailService,
            deletionService: deletionService
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: AppConstants.UI.cardSpacing) {
                        headerView

                        ForEach(viewModel.groups) { group in
                            similarGroupCard(group)
                                .onAppear {
                                    viewModel.loadThumbnails(for: group)
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
                    onDelete: { viewModel.showDeleteConfirmation = true }
                )
            }
        }
        .navigationTitle("Similar")
        .navigationBarTitleDisplayMode(.large)
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
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("Excluindo...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                    )
            }
        }
    }

    // MARK: - Similar Group Card (inline since structure is similar to DuplicateGroupCardView)

    private func similarGroupCard(_ group: SimilarGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(group.count) fotos similares")
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
                            thumbnail: viewModel.thumbnailCache[photo.id],
                            onToggle: { viewModel.toggleSelection(assetId: photo.id) }
                        )
                        .frame(width: 110)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Manter todos") {
                    viewModel.deselectAllInGroup(group)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorTokens.primaryBlue)

                Button("Selecionar similares") {
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
            Text("\(viewModel.totalGroupCount) grupos encontrados")
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.secondaryText)
            Text("\(viewModel.totalSimilarCount) fotos similares")
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
            Text("Nenhuma foto similar encontrada!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)
            Text("Sua biblioteca está organizada.")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
            Spacer()
        }
    }
}
