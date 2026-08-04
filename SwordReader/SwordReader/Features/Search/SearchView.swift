import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    var body: some View {
        Group {
            if model.modules.isEmpty {
                ContentUnavailableView("No Bible to Search", systemImage: "magnifyingglass", description: Text("Install a Bible from the Library first."))
            } else if model.isSearching {
                ProgressView("Searching…")
            } else if query.isEmpty {
                ContentUnavailableView("Search Scripture", systemImage: "text.magnifyingglass", description: Text("Search the selected translation for a word or phrase."))
            } else if model.searchResults.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(model.searchResults) { result in
                    Button {
                        model.open(reference: result.reference)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(result.reference).font(.headline)
                            Text(result.text).font(.body).foregroundStyle(.primary).lineLimit(3)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Word or phrase")
        .onSubmit(of: .search) { model.search(query) }
        .onChange(of: query) { _, value in
            if value.isEmpty { model.search("") }
        }
    }
}

