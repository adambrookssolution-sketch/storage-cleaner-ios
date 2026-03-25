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
            }

            // Bottom action bar
            if !viewModel.displayedFiles.isEmpty {
                BatchActionBarView(
                    selectedCount: viewModel.totalSelectedCount,
                    potentialSavings: viewModel.totalPotentialSavings,
                    accentColor: ColorTokens.warningOrange,
                    onDelete: { viewModel.confirmDeletion() }
                )
            }
        }
        .navigationTitle(NSLocalizedString("downloads.title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(NSLocalizedString("general.back", comment: "")) { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { viewModel.selectAll() }) {
                        Label(NSLocalizedString("general.selectAll", comment: ""), systemImage: "checkmark.circle.fill")
                    }
                    Button(action: { viewModel.deselectAll() }) {
                        Label(NSLocalizedString("general.deselectAll", comment: ""), systemImage: "circle")
                    }
                    Divider()
                    Button(action: { viewModel.toggleFilter() }) {
                        Label(
                            viewModel.showFilterOnly ? NSLocalizedString("downloads.showAll", comment: "") : NSLocalizedString("downloads.filteredOnly", comment: ""),
                            systemImage: viewModel.showFilterOnly ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
                        )
                    }
                    if viewModel.hasFolder {
                        Divider()
                        Button(action: { viewModel.changeFolder() }) {
                            Label(NSLocalizedString("downloads.changeFolder", comment: ""), systemImage: "folder.badge.gear")
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
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $viewModel.showDeleteConfirmation) {
            DeletionConfirmationView(
                selectedCount: viewModel.totalSelectedCount,
                savedBytes: viewModel.totalPotentialSavings,
                itemLabel: NSLocalizedString("general.files", comment: ""),
                destination: .appTrashBin,
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
                DeletionSuccessView(result: result, itemLabel: NSLocalizedString("general.files", comment: ""), destination: .appTrashBin) {
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
                        Text(NSLocalizedString("downloads.movingToTrash", comment: ""))
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

            Text(NSLocalizedString("downloads.noFolderSelected", comment: ""))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)

            Text(NSLocalizedString("downloads.selectFolderPrompt", comment: ""))
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { viewModel.selectFolder() }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                    Text(NSLocalizedString("downloads.selectFolderButton", comment: ""))
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

            Text(NSLocalizedString("downloads.scanning", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTokens.primaryText)

            Text(String(format: NSLocalizedString("downloads.analyzingFolder", comment: ""), viewModel.folderName))
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
                Text(NSLocalizedString("downloads.noLargeOldFiles", comment: ""))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ColorTokens.primaryText)

                Text(NSLocalizedString("downloads.noLargeOldFilesDetail", comment: ""))
                    .font(.system(size: 15))
                    .foregroundColor(ColorTokens.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if !viewModel.allFiles.isEmpty {
                    Button(action: { viewModel.toggleFilter() }) {
                        Text(NSLocalizedString("downloads.showAllFiles", comment: ""))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ColorTokens.warningOrange)
                    }
                    .padding(.top, 8)
                }
            } else {
                Text(NSLocalizedString("downloads.noFilesFound", comment: ""))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ColorTokens.primaryText)

                Text(NSLocalizedString("downloads.folderEmpty", comment: ""))
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
                        Text(String(format: NSLocalizedString("downloads.largeOldFilesCount", comment: ""), viewModel.totalDisplayedCount))
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.secondaryText)
                    } else {
                        Text(String(format: NSLocalizedString("downloads.filesFoundCount", comment: ""), viewModel.totalDisplayedCount))
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.secondaryText)
                    }

                    Text(String(format: NSLocalizedString("downloads.totalSize", comment: ""), viewModel.totalDisplayedSize.formattedSize))
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
