import SwiftUI

struct ReaderView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isReferenceFocused: Bool

    var body: some View {
        @Bindable var model = model
        Group {
            if model.modules.isEmpty {
                ContentUnavailableView {
                    Label("No Bibles Installed", systemImage: "book.closed")
                } description: {
                    Text("Import a local SWORD catalog from the Library to begin reading.")
                } actions: {
                    Button("Open Library") { model.section = .library }
                }
            } else if model.isLoading && model.chapter == nil {
                ProgressView("Loading chapter…")
            } else if let chapter = model.chapter {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(chapter.verses) { verse in
                            VerseView(verse: verse)
                        }
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 24)
                }
                .contentMargins(.bottom, 56, for: .scrollContent)
            } else {
                ContentUnavailableView("Choose a Chapter", systemImage: "text.book.closed")
            }
        }
        .navigationTitle(model.chapter?.reference ?? "Read")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Previous Chapter", systemImage: "chevron.left") { model.moveChapter(by: -1) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Button("Next Chapter", systemImage: "chevron.right") { model.moveChapter(by: 1) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
            }
            ToolbarItem(placement: .principal) {
                TextField("Book and chapter", text: $model.reference)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 130, idealWidth: 190, maxWidth: 240)
                    .focused($isReferenceFocused)
                    .submitLabel(.go)
                    .onSubmit { model.submitReference() }
            }
            ToolbarItem(placement: .secondaryAction) {
                Picker("Translation", selection: $model.selectedModuleID) {
                    ForEach(model.modules) { module in
                        Text(module.id).tag(Optional(module.id))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

private struct VerseView: View {
    let verse: BibleVerse

    var body: some View {
        Text(verse.number + " ")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        + Text(verse.text)
            .font(.body)
    }
}

