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

            if state.selectedTab != .gallery, let message = state.importMessage {
                MessageToast(message: message) {
                    state.dismissImportMessage()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 92)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: state.importMessage)
        .onChange(of: state.importMessage) { _, message in
            guard let message else { return }
            Task {
                try? await Task.sleep(for: .seconds(2))
                if state.importMessage == message {
                    state.dismissImportMessage()
                }
            }
        }
    }
}
