import Foundation
import WebKit

class VideoExtractor: NSObject {
    private let webView: WKWebView
    private var completionHandlers: [UUID: ([VideoItem]) -> Void] = [:]
    
    init(webView: WKWebView) {
        self.webView = webView
        super.init()
        setupUserContentController()
    }
    
    private func setupUserContentController() {
        webView.configuration.userContentController.add(self, name: "videoExtractor")
    }
    
    func extractVideos(completion: @escaping ([VideoItem]) -> Void) {
        let requestId = UUID()
        completionHandlers[requestId] = completion
        
        let script = """
        (function() {
            var videos = [];
            
            var videoTags = document.getElementsByTagName('video');
            for (var i = 0; i < videoTags.length; i++) {
                var video = videoTags[i];
                var src = video.src || '';
                var title = video.title || video.getAttribute('data-title') || '';
                var poster = video.poster || '';
                
                if (src) {
                    videos.push({
                        url: src,
                        title: title,
                        thumbnail: poster
                    });
                }
                
                var sources = video.getElementsByTagName('source');
                for (var j = 0; j < sources.length; j++) {
                    var sourceSrc = sources[j].src || '';
                    if (sourceSrc && !videos.some(function(v) { return v.url === sourceSrc; })) {
                        videos.push({
                            url: sourceSrc,
                            title: title || 'Video ' + (videos.length + 1),
                            thumbnail: poster
                        });
                    }
                }
            }
            
            var mediaElements = document.querySelectorAll('source[type*=\"video\"]');
            for (var k = 0; k < mediaElements.length; k++) {
                var mediaSrc = mediaElements[k].src || '';
                var parentTitle = mediaElements[k].parentElement?.title || '';
                if (mediaSrc && !videos.some(function(v) { return v.url === mediaSrc; })) {
                    videos.push({
                        url: mediaSrc,
                        title: parentTitle || 'Video ' + (videos.length + 1),
                        thumbnail: ''
                    });
                }
            }
            
            window.webkit.messageHandlers.videoExtractor.postMessage({
                requestId: '\(requestId.uuidString)',
                videos: videos
            });
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error = error {
                print("JavaScript execution error: \(error)")
                self?.completionHandlers[requestId]?([])
                self?.completionHandlers.removeValue(forKey: requestId)
            }
        }
    }
    
    func extractVideosWithDelay(delay: TimeInterval = 1.0, completion: @escaping ([VideoItem]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.extractVideos(completion: completion)
        }
    }
    
    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "videoExtractor")
    }
}

extension VideoExtractor: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let requestIdString = body["requestId"] as? String,
              let requestId = UUID(uuidString: requestIdString),
              let videosArray = body["videos"] as? [[String: String]] else {
            return
        }
        
        let videoItems: [VideoItem] = videosArray.compactMap { videoDict in
            guard let urlString = videoDict["url"], let url = URL(string: urlString) else {
                return nil
            }
            let title = videoDict["title"] ?? ""
            let thumbnailURL = videoDict["thumbnail"].flatMap { URL(string: $0) }
            return VideoItem(url: url, title: title, thumbnailURL: thumbnailURL)
        }
        
        completionHandlers[requestId]?(videoItems)
        completionHandlers.removeValue(forKey: requestId)
    }
}