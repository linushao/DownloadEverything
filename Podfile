platform :ios, '15.0'

target 'DownloadManager' do
  use_frameworks! :linkage => :static, :disable_swift_sandboxing => true
  pod 'Alamofire', '~> 5.9'
  pod 'Kingfisher', '~> 8.0'

  target 'DownloadManagerTests' do
    inherit! :search_paths
    pod 'Alamofire', '~> 5.9'
  end
end

target 'DownloadManagerMac' do
  platform :macos, '15.0'
  use_frameworks! :linkage => :static
  pod 'Alamofire', '~> 5.9'
  pod 'Kingfisher', '~> 8.0'
end
