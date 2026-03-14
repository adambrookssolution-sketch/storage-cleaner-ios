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
                    onDelete: { viewModel.confirmDeletion() }
                )
            }

            // Limit message overlay
            if let msg = viewModel.limitMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(ColorTokens.warningOrange.cornerRadius(10))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 90)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Duplicatas")
        .navigationBarTitleDisplayMode(.large)
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
                        Text("Excluindo \(viewModel.totalSelectedCount) fotos...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Text("O iOS solicitará sua confirmação.")
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
