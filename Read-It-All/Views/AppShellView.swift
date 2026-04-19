import SwiftUI

struct AppShellView: View {
    var body: some View {
        TabView {
            LibraryRootView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }

            LibrarySearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            NavigationStack {
                AppSettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
