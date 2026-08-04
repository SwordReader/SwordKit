import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                CompactRootView()
            } else {
                SplitRootView()
            }
        }
        .alert(item: Bindable(model).presentedError) { error in
            Alert(
                title: Text("Something Went Wrong"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

private struct CompactRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.section) {
            NavigationStack { ReaderView() }
                .tabItem { Label(AppSection.read.title, systemImage: AppSection.read.systemImage) }
                .tag(AppSection.read)
            NavigationStack { SearchView() }
                .tabItem { Label(AppSection.search.title, systemImage: AppSection.search.systemImage) }
                .tag(AppSection.search)
            NavigationStack { LibraryView() }
                .tabItem { Label(AppSection.library.title, systemImage: AppSection.library.systemImage) }
                .tag(AppSection.library)
        }
    }
}

private struct SplitRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases) { section in
                Button {
                    model.section = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(model.section == section ? Color.accentColor.opacity(0.14) : Color.clear)
            }
            .navigationTitle("SwordReader")
        } detail: {
            NavigationStack {
                switch model.section {
                case .read: ReaderView()
                case .search: SearchView()
                case .library: LibraryView()
                }
            }
        }
    }
}
