import Foundation

struct VideoItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let title: String
    let thumbnailURL: URL?
    
    init(url: URL, title: String, thumbnailURL: URL? = nil) {
        self.url = url
        self.title = title.isEmpty ? url.lastPathComponent : title
        self.thumbnailURL = thumbnailURL
    }
    
    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool {
        lhs.url == rhs.url
    }
}