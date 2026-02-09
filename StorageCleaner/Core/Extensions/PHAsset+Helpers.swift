import Photos

extension PHAsset {
    /// Fetches the file size of the asset's primary resource in bytes
    var estimatedFileSize: Int64 {
        let resources = PHAssetResource.assetResources(for: self)
        guard let resource = resources.first else { return 0 }
        if let size = resource.value(forKey: "fileSize") as? Int64 {
            return size
        }
        return 0
    }

    /// Whether this asset is a screenshot
    var isScreenshot: Bool {
        mediaSubtypes.contains(.photoScreenshot)
    }

    /// Whether this asset is a video
    var isVideo: Bool {
        mediaType == .video
    }

    /// Whether this asset is a photo (non-video)
    var isPhoto: Bool {
        mediaType == .image
    }

    /// Whether this is a Live Photo
    var isLivePhoto: Bool {
        mediaSubtypes.contains(.photoLive)
    }

    /// Creation date formatted for display
    var formattedDate: String {
        guard let date = creationDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: date)
    }

    /// Duration formatted for videos (e.g., "2:34")
    var formattedDuration: String {
        guard mediaType == .video else { return "" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
