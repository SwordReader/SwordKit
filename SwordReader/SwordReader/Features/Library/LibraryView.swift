import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var isImporting = false

    var body: some View {
        List {
            Section("Installed Bibles") {
                if model.modules.isEmpty {
                    Text("No Bibles installed").foregroundStyle(.secondary)
                }
                ForEach(model.modules) { module in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(module.title)
                            Text([module.id, module.language].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if module.id == model.selectedModuleID {
                            Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityLabel("Selected")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { model.selectedModuleID = module.id }
                }
            }

            if let catalog = model.catalog {
                Section("Available in \(catalog.directory.lastPathComponent)") {
                    ForEach(catalog.modules.filter(\.isBible)) { module in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(module.title)
                                Text(module.id).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Install") { Task { await model.install(module) } }
                                .disabled(model.isInstalling)
                        }
                    }
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Import Local Catalog", systemImage: "folder.badge.plus") { isImporting = true }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                Task { await model.inspectCatalog(at: url) }
            } else if case .failure(let error) = result {
                model.presentedError = PresentedError(error)
            }
        }
        .overlay { if model.isInstalling { ProgressView("Installing…").padding().background(.regularMaterial, in: .rect(cornerRadius: 12)) } }
    }
}

