import SwiftUI
import Combine
import Photos

/// Primary ViewModel for the main dashboard. Orchestrates scan, manages category data, and loads thumbnails.
@MainActor
final class DashboardViewModel: ObservableObject {
    // MARK: - Published State
    @Published var scanProgress: ScanProgress = .idle
    @Published var scanResult: ScanResult = .empty
    @Published var storageInfo: StorageInfo = .placeholder
    @Published var totalFileCount: Int = 0
    @Published var totalSizeFormatted: String = ""
    @Published var categoryData: [CategoryCardData] = []
    @Published var thumbnailCache: [String: UIImage] = [:]

    // MARK: - Dependencies
    private let photoService: PhotoLibraryService
    private let storageService: StorageAnalysisService
    private let thumbnailService: ThumbnailCacheService
    private let permissionService: PermissionService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Category Card Data Model

    struct CategoryCardData: Identifiable {
        let id: String
        let category: MediaCategory
        let title: String
        let count: Int
        let sizeBytes: Int64
        let sampleAssetIds: [String]

        var badgeText: String {
            guard count > 0 else { return "" }
            let countStr: String
            switch category {
            case .videos, .similarVideos:
                countStr = "\(count) vídeos"
            default:
                countStr = "\(count) fotos"
            }
            let sizeStr = "(\(sizeBytes.formattedSize))"
            return "\(countStr)\n\(sizeStr)"
        }

        var badgeTextSingleLine: String {
            guard count > 0 else { return "" }
            let countStr: String
            switch category {
            case .videos, .similarVideos:
                countStr = "\(count) vídeos"
            default:
                countStr = "\(count) fotos"
            }
            return "\(countStr) (\(sizeBytes.formattedSize))"
        }

        var isEmpty: Bool { count == 0 }
    }

    // MARK: - Init

    init(
        photoService: PhotoLibraryService,
        storageService: StorageAnalysisService,
        thumbnailService: ThumbnailCacheService,
        permissionService: PermissionService
    ) {
        self.photoService = photoService
        self.storageService = storageService
        self.thumbnailService = thumbnailService
        self.permissionService = permissionService
    }

    // MARK: - Actions

    func loadInitialData() {
        storageInfo = storageService.getDeviceStorageInfo()
    }

    func startScan() {
        guard !scanProgress.isScanning else { return }
        guard permissionService.status.hasAccess else { return }

        photoService.scanLibrary()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self else { return }
                self.scanProgress = progress

                switch progress {
                case .scanning(let processed, let total):
                    self.totalFileCount = total
                    if self.totalSizeFormatted.isEmpty {
                        self.totalSizeFormatted = "..."
                    }
                case .completed(let result):
                    self.scanResult = result
                    self.totalFileCount = result.totalAssets
                    self.totalSizeFormatted = result.formattedTotalSize
                    self.buildCategoryData(from: result)
                    self.loadSampleThumbnails()
                    // Update storage info with photo library size
                    self.storageInfo = self.storageService.getDeviceStorageInfoWithPhotos(
                        photoLibrarySize: result.photosSizeBytes + result.videosSizeBytes
                    )
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    func cancelScan() {
        photoService.cancelScan()
        scanProgress = .idle
    }

    // MARK: - Private

    private func buildCategoryData(from result: ScanResult) {
        let counts = result.categoryCounts

        categoryData = MediaCategory.dashboardOrder.compactMap { cat in
            let data = counts[cat] ?? (0, 0)
            let samples = photoService.sampleAssets[cat]?.map(\.localIdentifier) ?? []
            return CategoryCardData(
                id: cat.rawValue,
                category: cat,
                title: cat.localizedTitle,
                count: data.count,
                sizeBytes: data.sizeBytes,
                sampleAssetIds: Array(samples.prefix(4))
            )
        }
    }

    private func loadSampleThumbnails() {
        let targetSize = AppConstants.Storage.categoryCardThumbnailSize
        for cardData in categoryData {
            for assetId in cardData.sampleAssetIds {
                guard thumbnailCache[assetId] == nil else { continue }
                Task {
                    if let image = await thumbnailService.loadThumbnail(
                        assetId: assetId, targetSize: targetSize
                    ) {
                        thumbnailCache[assetId] = image
                    }
                }
            }
        }
    }
}
