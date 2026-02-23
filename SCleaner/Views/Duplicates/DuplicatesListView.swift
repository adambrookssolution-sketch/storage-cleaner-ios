import SwiftUI

/// Full-screen view showing all duplicate groups with batch action bar.
struct DuplicatesListView: View {
    @StateObject private var viewModel: DuplicatesViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        groups: [DuplicateGroup],
        thumbnailService: ThumbnailCacheService,
        deletionService: PhotoDeletionService
    ) {
        _viewModel = StateObject(wrappedValue: DuplicatesViewModel(
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
                            DuplicateGroupCardView(
                                group: group,
                                selectedIds: viewModel.selectedIds,
                                thumbnailCache: viewModel.thumbnailCache,
                                onToggleSelection: { id in
                                    viewModel.toggleSelection(assetId: id)
                                },
                                onSelectAll: {
                                    viewModel.selectAllInGroup(group)
                                },
                                onDeselectAll: {
                                    viewModel.deselectAllInGroup(group)
                                }
                            )
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
                    onDelete: { viewModel.showDeleteConfirmation = true }
                )
            }
        }
        .navigationTitle("Duplicatas")
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

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(viewModel.totalGroupCount) grupos encontrados")
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.secondaryText)
            Text("\(viewModel.totalDuplicateCount) fotos duplicadas")
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
            Text("Nenhuma duplicata encontrada!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)
            Text("Sua biblioteca está organizada.")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
            Spacer()
        }
    }
}
