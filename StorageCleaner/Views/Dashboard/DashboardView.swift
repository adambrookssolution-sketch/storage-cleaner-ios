import SwiftUI

/// Main scrollable dashboard showing storage stats, scan progress, and category cards
struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false

    init(
        photoService: PhotoLibraryService,
        storageService: StorageAnalysisService,
        thumbnailService: ThumbnailCacheService,
        permissionService: PermissionService
    ) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(
            photoService: photoService,
            storageService: storageService,
            thumbnailService: thumbnailService,
            permissionService: permissionService
        ))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppConstants.UI.cardSpacing) {
                    // Header
                    DashboardHeaderView {
                        showSettings = true
                    }

                    // Storage bar
                    StorageBarView(
                        usedBytes: viewModel.storageInfo.usedBytes,
                        totalBytes: viewModel.storageInfo.totalBytes,
                        height: 10
                    )
                    .padding(.horizontal, AppConstants.UI.horizontalPadding)

                    // Stats line
                    StatsLineView(
                        fileCount: viewModel.totalFileCount,
                        totalSize: viewModel.totalSizeFormatted,
                        isLoaded: viewModel.scanProgress.isCompleted
                    )

                    // Scan progress (visible while scanning)
                    if viewModel.scanProgress.isScanning {
                        ScanProgressView(progress: viewModel.scanProgress)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Category cards
                    if viewModel.scanProgress.isCompleted {
                        LazyVStack(spacing: AppConstants.UI.cardSpacing) {
                            ForEach(viewModel.categoryData) { cardData in
                                CategoryCardView(
                                    cardData: cardData,
                                    thumbnailCache: viewModel.thumbnailCache
                                )
                            }
                        }
                        .padding(.horizontal, AppConstants.UI.horizontalPadding)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Scanning placeholder cards
                    if viewModel.scanProgress.isScanning {
                        scanningPlaceholder
                            .padding(.horizontal, AppConstants.UI.horizontalPadding)
                    }

                    // Idle state - prompt to scan
                    if case .idle = viewModel.scanProgress {
                        idlePrompt
                            .padding(.horizontal, AppConstants.UI.horizontalPadding)
                    }

                    // Error state
                    if case .failed(let message) = viewModel.scanProgress {
                        errorView(message: message)
                            .padding(.horizontal, AppConstants.UI.horizontalPadding)
                    }

                    Spacer().frame(height: 30)
                }
            }
            .background(ColorTokens.screenBackground.ignoresSafeArea())
            .animation(.easeInOut(duration: 0.4), value: viewModel.scanProgress.isScanning)
            .animation(.easeInOut(duration: 0.4), value: viewModel.scanProgress.isCompleted)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            viewModel.loadInitialData()
            viewModel.startScan()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Scanning Placeholder

    private var scanningPlaceholder: some View {
        VStack(spacing: AppConstants.UI.cardSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 18)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 140)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(width: 160, height: 32)
                }
                .padding(16)
                .cardStyle()
                .shimmer(isActive: true)
            }
        }
    }

    // MARK: - Idle Prompt

    private var idlePrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.primaryBlue.opacity(0.6))

            Text("Toque para escanear sua biblioteca de fotos")
                .font(.system(size: 16))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)

            Button("Iniciar Escaneamento") {
                viewModel.startScan()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
        .cardStyle()
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(ColorTokens.warningOrange)

            Text(message)
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)

            Button("Tentar novamente") {
                viewModel.startScan()
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 30)
        .cardStyle()
    }
}
