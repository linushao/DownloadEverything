import XCTest
@testable import DownloadAppShared

class UserAgentTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testUserAgentPlatformCases() {
        let platforms = UserAgentPlatform.allCases
        XCTAssertEqual(platforms.count, 4)
        XCTAssertTrue(platforms.contains(.iphone))
        XCTAssertTrue(platforms.contains(.android))
        XCTAssertTrue(platforms.contains(.desktop))
        XCTAssertTrue(platforms.contains(.default))
    }
    
    func testUserAgentPlatformDisplayName() {
        XCTAssertEqual(UserAgentPlatform.iphone.displayName, "iPhone")
        XCTAssertEqual(UserAgentPlatform.android.displayName, "Android")
        XCTAssertEqual(UserAgentPlatform.desktop.displayName, "桌面端")
        XCTAssertEqual(UserAgentPlatform.default.displayName, "系统默认")
    }
    
    func testUserAgentManagerOptionsCount() {
        let manager = UserAgentManager.shared
        
        XCTAssertEqual(manager.iphoneOptions.count, 4)
        XCTAssertEqual(manager.androidOptions.count, 4)
        XCTAssertEqual(manager.desktopOptions.count, 5)
        XCTAssertEqual(manager.allOptions.count, 14)
    }
    
    func testUserAgentOptionById() {
        let manager = UserAgentManager.shared
        
        if let option = manager.option(forId: "iphone-15-pro") {
            XCTAssertEqual(option.name, "iPhone 15 Pro (Safari)")
            XCTAssertEqual(option.platform, .iphone)
            XCTAssertTrue(option.userAgentString.contains("iPhone"))
        } else {
            XCTFail("Failed to find option with id 'iphone-15-pro'")
        }
        
        if let option = manager.option(forId: "macos-safari") {
            XCTAssertEqual(option.name, "macOS Safari")
            XCTAssertEqual(option.platform, .desktop)
            XCTAssertTrue(option.userAgentString.contains("Macintosh"))
        } else {
            XCTFail("Failed to find option with id 'macos-safari'")
        }
        
        XCTAssertNil(manager.option(forId: "nonexistent-id"))
    }
    
    func testDefaultOption() {
        let manager = UserAgentManager.shared
        
        XCTAssertEqual(manager.defaultOption.id, "default")
        XCTAssertEqual(manager.defaultOption.name, "系统默认")
        XCTAssertEqual(manager.defaultOption.platform, .default)
        XCTAssertEqual(manager.defaultOption.userAgentString, "")
    }
    
    func testSettingsManagerUserAgentDefault() {
        let settingsManager = SettingsManager.shared
        XCTAssertEqual(settingsManager.userAgentId, "default")
        XCTAssertEqual(settingsManager.currentUserAgent, "")
    }
    
    func testSettingsManagerUserAgentChange() {
        let settingsManager = SettingsManager.shared
        let originalId = settingsManager.userAgentId
        
        settingsManager.userAgentId = "iphone-15-pro"
        
        let expectedUA = UserAgentManager.shared.option(forId: "iphone-15-pro")?.userAgentString
        XCTAssertEqual(settingsManager.currentUserAgent, expectedUA)
        XCTAssertTrue(settingsManager.currentUserAgent.contains("iPhone"))
        
        settingsManager.userAgentId = originalId
    }
    
    func testSettingsManagerResetToDefaults() {
        let settingsManager = SettingsManager.shared
        settingsManager.userAgentId = "macos-chrome"
        
        settingsManager.resetToDefaults()
        
        XCTAssertEqual(settingsManager.userAgentId, "default")
        XCTAssertEqual(settingsManager.currentUserAgent, "")
    }
    
    func testUserAgentOptionsByPlatform() {
        let manager = UserAgentManager.shared
        
        let iphoneOptions = manager.options(for: .iphone)
        XCTAssertEqual(iphoneOptions.count, 4)
        iphoneOptions.forEach { option in
            XCTAssertEqual(option.platform, .iphone)
        }
        
        let androidOptions = manager.options(for: .android)
        XCTAssertEqual(androidOptions.count, 4)
        androidOptions.forEach { option in
            XCTAssertEqual(option.platform, .android)
        }
        
        let desktopOptions = manager.options(for: .desktop)
        XCTAssertEqual(desktopOptions.count, 5)
        desktopOptions.forEach { option in
            XCTAssertEqual(option.platform, .desktop)
        }
        
        let defaultOptions = manager.options(for: .default)
        XCTAssertEqual(defaultOptions.count, 1)
        XCTAssertEqual(defaultOptions.first?.platform, .default)
    }
}
