import Foundation

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults: UserDefaults = UserDefaults.standard
    
    private enum Keys: String {
        case downloadPath = "com.downloadapp.downloadPath"
        case m3u8SegmentLimit = "com.downloadapp.m3u8SegmentLimit"
    }
    
    @Published var downloadPath: String {
        didSet {
            defaults.set(downloadPath, forKey: Keys.downloadPath.rawValue)
        }
    }
    
    @Published var m3u8SegmentLimit: Int {
        didSet {
            defaults.set(m3u8SegmentLimit, forKey: Keys.m3u8SegmentLimit.rawValue)
        }
    }
    
    private init() {
        self.downloadPath = defaults.string(forKey: Keys.downloadPath.rawValue) 
            ?? FileUtils.defaultDownloadDirectory.path
        self.m3u8SegmentLimit = defaults.integer(forKey: Keys.m3u8SegmentLimit.rawValue)
    }
    
    var downloadDirectoryURL: URL {
        URL(fileURLWithPath: downloadPath)
    }
    
    func resetToDefaults() {
        downloadPath = FileUtils.defaultDownloadDirectory.path
        m3u8SegmentLimit = 0
    }
}