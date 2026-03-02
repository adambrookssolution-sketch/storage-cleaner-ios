import SwiftUI

/// Trash Bin management screen with restore and permanent delete.
struct TrashBinListView: View {
    @StateObject private var viewModel = TrashBinViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Content
            if viewModel.trashedFiles.isEmpty {
                emptyView
            } else {
                fileListView
            }

            // Bottom action bar (dual: restore + delete)
            if !viewModel.trashedFiles.isEmpty && viewModel.totalSelectedCount > 0 {
                trashActionBar
            }
        }
        .navigationTitle("Lixeira")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Voltar") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { viewModel.selectAll() }) {
                        Label("Selecionar todos", systemImage: "checkmark.circle.fill")
                    }
                    Button(action: { viewModel.deselectAll() }) {
                        Label("Desmarcar todos", systemImage: "circle")
                    }
                    if !viewModel.trashedFiles.isEmpty {
                        Divider()
                        Button(role: .destructive, action: { viewModel.showDeleteConfirmation = true; viewModel.selectAll() }) {
                            Label("Esvaziar Lixeira", systemImage: "trash.slash.fill")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                }
            }
        }
        .onAppear { viewModel.refresh() }
        .sheet(isPresented: $viewModel.showDeleteConfirmation) {
            DeletionConfirmationView(
                selectedCount: viewModel.totalSelectedCount,
                savedBytes: viewModel.totalPotentialSavings,
                itemLabel: "arquivos",
                onConfirm: {
                    viewModel.showDeleteConfirmation = false
                    Task { await viewModel.executePermanentDelete() }
                },
                onCancel: { viewModel.showDeleteConfirmation = false }
            )
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $viewModel.showDeleteSuccess) {
            if let result = viewModel.deleteResult {
                DeletionSuccessView(result: result, itemLabel: "arquivos") {
                    viewModel.showDeleteSuccess = false
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showRestoreSuccess) {
            RestoreSuccessView(
                restoredCount: viewModel.restoreResult?.success ?? 0,
                failedCount: viewModel.restoreResult?.failed ?? 0
            ) {
                viewModel.showRestoreSuccess = false
            }
        }
        .overlay {
            if viewModel.isProcessing {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Processando...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.successGreen)

            Text("Lixeira vazia!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)

            Text("Nenhum arquivo na lixeira.")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)

            Spacer()
        }
    }

    // MARK: - File List

    private var fileListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.totalCount) arquivos na lixeira")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.secondaryText)

                    Text("Tamanho total: \(viewModel.totalSize.formattedSize)")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.tertiaryText)

                    Text("Arquivos são excluídos automaticamente após 30 dias.")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTokens.warningOrange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppConstants.UI.horizontalPadding)
                .padding(.top, 8)

                // File list
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.trashedFiles) { file in
                        TrashItemCardView(
                            file: file,
                            isSelected: viewModel.selectedIds.contains(file.id),
                            onToggle: { viewModel.toggleSelection(fileId: file.id) }
                        )
                    }
                }
                .padding(.horizontal, AppConstants.UI.horizontalPadding)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Dual Action Bar

    private var trashActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.totalSelectedCount) selecionado(s)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ColorTokens.primaryText)

                    Text(viewModel.totalPotentialSavings.formattedSize)
                        .font(.system(size: 13))
                        .foregroundColor(ColorTokens.secondaryText)
                }

                Spacer()

                // Restore button
                Button(action: { Task { await viewModel.executeRestore() } }) {
                    Text("Restaurar")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(ColorTokens.successGreen))
                }

                // Delete button
                Button(action: { viewModel.showDeleteConfirmation = true }) {
                    Text("Excluir")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(ColorTokens.destructiveRed))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ColorTokens.cardBackground
                    .shadow(color: .black.opacity(0.08), radius: 8, y: -4)
            )
        }
    }
}
