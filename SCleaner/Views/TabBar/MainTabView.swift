import SwiftUI

/// Main tab bar with 4 tabs: Limpeza (active), Contatos, E-mails, Comprimir
struct MainTabView: View {
    @State private var selectedTab = 0

    // Shared service instances
    private let permissionService: PermissionService
    private let storageService: StorageAnalysisService
    private let photoService: PhotoLibraryService
    private let thumbnailService: ThumbnailCacheService

    init() {
        let permission = PermissionService()
        let storage = StorageAnalysisService()
        let thumbnail = ThumbnailCacheService()
        let photo = PhotoLibraryService(thumbnailService: thumbnail)

        self.permissionService = permission
        self.storageService = storage
        self.thumbnailService = thumbnail
        self.photoService = photo

        // Configure tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().standardAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Limpeza (Cleanup) — Main dashboard
            DashboardView(
                photoService: photoService,
                storageService: storageService,
                thumbnailService: thumbnailService,
                permissionService: permissionService
            )
            .tabItem {
                Label("Limpeza", systemImage: "sparkles")
            }
            .tag(0)

            // Tab 2: Contatos (placeholder)
            PlaceholderTabView(
                title: "Contatos",
                icon: "person.crop.circle"
            )
            .tabItem {
                Label("Contatos", systemImage: "person.crop.circle")
            }
            .tag(1)

            // Tab 3: E-mails (placeholder)
            PlaceholderTabView(
                title: "E-mails",
                icon: "envelope.fill"
            )
            .tabItem {
                Label("E-mails", systemImage: "envelope")
            }
            .tag(2)

            // Tab 4: Comprimir (placeholder)
            PlaceholderTabView(
                title: "Comprimir",
                icon: "arrow.down.right.and.arrow.up.left"
            )
            .tabItem {
                Label("Comprimir", systemImage: "arrow.down.right.and.arrow.up.left")
            }
            .tag(3)
        }
        .tint(ColorTokens.primaryBlue)
    }
}
