import SwiftUI

@main
struct LutShopApp: App {
    @StateObject private var state = LutShopAppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var state: LutShopAppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            switch state.selectedTab {
            case .gallery:
                GalleryView()
            case .preview:
                PreviewView()
            case .luts:
                LutsView()
            case .export:
                ExportView()
            }

            VStack(spacing: 0) {
                if state.selectedTab == .gallery, let selected = state.selectedPhotos.first {
                    SelectionActionBar(photo: selected)
                }
                BottomTabBar()
            }
        }
        .preferredColorScheme(.dark)
    }
}
