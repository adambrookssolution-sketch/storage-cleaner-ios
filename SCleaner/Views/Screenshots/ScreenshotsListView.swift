import SwiftUI
import Photos

/// Full-screen grid view showing all screenshots sorted by date with batch deletion.
struct ScreenshotsListView: View {
    @StateObject private var viewModel: ScreenshotsViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    init(
        assets: [PHAsset],
        thumbnailService: ThumbnailCacheService,
        deletionService: PhotoDeletionService
    ) {
        _viewModel = StateObject(wrappedValue: ScreenshotsViewModel(
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
                    VStack(spacing: AppConstants.UI.cardSpacing) {
                        headerView

                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(viewModel.assets, id: \.localIdentifier) { asset in
                                screenshotCell(asset)
                                    .onAppear {
                                        viewModel.loadThumbnails(for: [asset])
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
                    onDelete: { viewModel.showDeleteConfirmation = true }
                )
            }
        }
        .navigationTitle("Capturas de tela")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Selecionar todos") { viewModel.selectAll() }
                    Button("Desmarcar todos") { viewModel.deselectAll() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $viewModel.showDeleteConfirmation) {
            DeletionConfirmationView(
                selectedCount: viewModel.totalSelectedCount,
                savedBytes: viewModel.totalPotentialSavings,
                itemLabel: "capturas de tela",
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
                DeletionSuccessView(result: result, itemLabel: "capturas de tela", destination: .photoLibrary) {
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
                        Text("Excluindo \(viewModel.totalSelectedCount) capturas de tela...")
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

    // MARK: - Screenshot Grid Cell

    private func screenshotCell(_ asset: PHAsset) -> some View {
        let id = asset.localIdentifier
        let isSelected = viewModel.selectedIds.contains(id)

        return ZStack(alignment: .topTrailing) {
            // Thumbnail
            Group {
                if let image = viewModel.thumbnailCache[id] {
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

            // File size badge
            VStack {
                Spacer()
                HStack {
                    Text(asset.estimatedFileSize.formattedSize)
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
            Text("\(viewModel.totalScreenshotCount) capturas de tela")
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.secondaryText)
            Text("Tamanho total: \(viewModel.totalSize.formattedSize)")
                .font(.system(size: 14))
                .foregroundColor(ColorTokens.secondaryText)

            if viewModel.totalSelectedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.successGreen)
                    Text("Economize \(viewModel.totalPotentialSavings.formattedSize) excluindo \(viewModel.totalSelectedCount) captura(s)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorTokens.successGreen)
                }
                .padding(.top, 2)
            }

            if viewModel.totalSelectedCount == viewModel.totalScreenshotCount && viewModel.totalScreenshotCount > 0 {
                Text("Todas as capturas de tela foram pré-selecionadas.")
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
            Text("Nenhuma captura de tela encontrada!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)
            Text("Sua biblioteca não contém capturas de tela.")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
            Spacer()
        }
    }
}
