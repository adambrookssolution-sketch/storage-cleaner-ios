import SwiftUI

/// Downloads folder scanning and file management screen.
struct DownloadsListView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Content
            if !viewModel.hasFolder && !viewModel.isScanning {
                noFolderView
            } else if viewModel.isScanning {
                scanningView
            } else if viewModel.displayedFiles.isEmpty {
                emptyResultView
            } else {
                fileListView
            }

            // Bottom action bar
            if !viewModel.displayedFiles.isEmpty {
                BatchActionBarView(
                    selectedCount: viewModel.totalSelectedCount,
                    potentialSavings: viewModel.totalPotentialSavings,
                    accentColor: ColorTokens.warningOrange,
                    onDelete: { viewModel.showDeleteConfirmation = true }
                )
            }
        }
        .navigationTitle("Downloads")
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
                    Divider()
                    Button(action: { viewModel.toggleFilter() }) {
                        Label(
                            viewModel.showFilterOnly ? "Mostrar todos" : "Apenas filtrados",
                            systemImage: viewModel.showFilterOnly ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
                        )
                    }
                    if viewModel.hasFolder {
                        Divider()
                        Button(action: { viewModel.changeFolder() }) {
                            Label("Alterar pasta", systemImage: "folder.badge.gear")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                }
            }
        }
        .onAppear {
            if viewModel.hasFolder {
                Task { await viewModel.scanFolder() }
            }
        }
        .sheet(isPresented: $viewModel.showFolderPicker) {
            DocumentPickerView(
                onFolderSelected: { url in
                    viewModel.onFolderSelected(url: url)
                },
                onCancel: {
                    viewModel.showFolderPicker = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showDeleteConfirmation) {
            DeletionConfirmationView(
                selectedCount: viewModel.totalSelectedCount,
                savedBytes: viewModel.totalPotentialSavings,
                itemLabel: "arquivos",
                onConfirm: {
                    viewModel.showDeleteConfirmation = false
                    Task { await viewModel.executeDelete() }
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
        .overlay {
            if viewModel.isDeleting {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Movendo para a Lixeira...")
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

    // MARK: - No Folder Selected

    private var noFolderView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 56))
                .foregroundColor(ColorTokens.warningOrange.opacity(0.6))

            Text("Nenhuma pasta selecionada")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)

            Text("Selecione a pasta de Downloads para escanear arquivos grandes e antigos.")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { viewModel.selectFolder() }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                    Text("Selecionar Pasta")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Capsule().fill(ColorTokens.warningOrange))
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(ColorTokens.warningOrange)

            Text("Escaneando...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)

            Text("Analisando arquivos na pasta \(viewModel.folderName)")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    // MARK: - Empty Result

    private var emptyResultView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.successGreen)

            if viewModel.showFilterOnly {
                Text("Nenhum arquivo grande e antigo!")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ColorTokens.primaryText)

                Text("Não foram encontrados arquivos maiores que 10 MB sem uso há 6+ meses.")
                    .font(.system(size: 15))
                    .foregroundColor(ColorTokens.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if !viewModel.allFiles.isEmpty {
                    Button(action: { viewModel.toggleFilter() }) {
                        Text("Mostrar todos os arquivos")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ColorTokens.warningOrange)
                    }
                    .padding(.top, 8)
                }
            } else {
                Text("Nenhum arquivo encontrado!")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ColorTokens.primaryText)

                Text("A pasta selecionada está vazia.")
                    .font(.system(size: 15))
                    .foregroundColor(ColorTokens.secondaryText)
            }

            Spacer()
        }
    }

    // MARK: - File List

    private var fileListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.showFilterOnly {
                        Text("\(viewModel.totalDisplayedCount) arquivos grandes (>10 MB) sem uso há 6+ meses")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.secondaryText)
                    } else {
                        Text("\(viewModel.totalDisplayedCount) arquivos encontrados")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.secondaryText)
                    }

                    Text("Tamanho total: \(viewModel.totalDisplayedSize.formattedSize)")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.tertiaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppConstants.UI.horizontalPadding)
                .padding(.top, 8)

                // File list
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.displayedFiles) { file in
                        FileItemCardView(
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
}
