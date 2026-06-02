import SwiftUI

struct FileItemRow: View {
    let file: FileItem
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: file.type == .folder ? "folder" : "doc")
                .foregroundColor(file.type == .folder ? .blue : .gray)
            Text(file.name)
            Spacer()
            if file.type == .folder {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
}
