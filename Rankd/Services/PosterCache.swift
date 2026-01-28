import UIKit

/// Downloads and caches poster UIImages for use with ImageRenderer.
/// AsyncImage doesn't work inside ImageRenderer, so we pre-fetch as UIImage.
actor PosterCache {
    static let shared = PosterCache()
    
    private var cache: [URL: UIImage] = [:]
    
    /// Load a single image from URL (cached).
    func loadImage(from url: URL) async -> UIImage? {
        if let cached = cache[url] {
            return cached
        }
        
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            return nil
        }
        
        cache[url] = image
        return image
    }
    
    /// Pre-load multiple poster images in parallel. Returns a dictionary of URL → UIImage.
    func preload(urls: [URL]) async -> [URL: UIImage] {
        await withTaskGroup(of: (URL, UIImage?).self) { group in
            for url in urls {
                group.addTask {
                    let image = await self.loadImage(from: url)
                    return (url, image)
                }
            }
            
            var results: [URL: UIImage] = [:]
            for await (url, image) in group {
                if let image {
                    results[url] = image
                }
            }
            return results
        }
    }
    
    /// Clear the cache (e.g. on memory warning).
    func clearCache() {
        cache.removeAll()
    }
}
