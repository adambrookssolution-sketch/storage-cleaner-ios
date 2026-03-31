import SwiftUI

/// Full-screen view showing all duplicate groups with batch action bar.
struct DuplicatesListView: View {
    @StateObject private var viewModel: DuplicatesViewModel
    @Environment(\.dismiss) private var dismiss

    // Pagination for groups
    private static let groupPageSize = 20
    @State private var displayedGroupCount: Int = 20

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

    private var displayedGroups: [DuplicateGroup] {
        Array(viewModel.groups.prefix(displayedGroupCount))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: AppConstants.UI.cardSpacing) {
                        headerView

                        ForEach(displayedGroups) { group in
                            DuplicateGroupCardView(
                                group: group,
                                selectedIds: viewModel.selectedIds,
                                thumbnailStore: viewModel.thumbnails,
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
                    onDelete: { viewModel.confirmDeletion() }
                )
            }

            // Limit message overlay
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(NSLocalizedString("duplicates.title", comment: ""))
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
                        Text(String(format: NSLocalizedString("duplicates.deleting", comment: ""), viewModel.totalSelectedCount))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Text(NSLocalizedString("duplicates.confirmationNotice", comment: ""))
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

    private func loadMoreGroupsIfNeeded(current group: DuplicateGroup) {
        guard displayedGroupCount < viewModel.groups.count else { return }
        let threshold = max(0, displayedGroupCount - 5)
        if let index = viewModel.groups.firstIndex(where: { $0.id == group.id }),
           index >= threshold {
            displayedGroupCount = min(displayedGroupCount + Self.groupPageSize, viewModel.groups.count)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: NSLocalizedString("duplicates.groupsFound", comment: ""), viewModel.totalGroupCount))
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.secondaryText)
            Text(String(format: NSLocalizedString("duplicates.photosCount", comment: ""), viewModel.totalDuplicateCount))
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
            Text(NSLocalizedString("duplicates.emptyTitle", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)
            Text(NSLocalizedString("duplicates.emptyMessage", comment: ""))
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
            Spacer()
        }
    }
}
