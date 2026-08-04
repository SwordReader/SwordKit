#if os(macOS)
import SwiftUI

struct SwordReaderCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu("Navigate") {
            Button("Previous Chapter") { model.moveChapter(by: -1) }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
            Button("Next Chapter") { model.moveChapter(by: 1) }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
            Divider()
            ForEach(AppSection.allCases) { section in
                Button(section.title) { model.section = section }
            }
        }
    }
}
#endif

