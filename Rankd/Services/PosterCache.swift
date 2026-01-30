import UIKit

/// Downloads and caches poster UIImages with memory (NSCache) and disk persistence.
/// AsyncImage doesn't work inside ImageRenderer, so we pre-fetch as UIImage.
actor PosterCache {
    static let shared = PosterCache()
    
    // MARK: - Memory Cache (NSCache)
    
    private let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 100 * 1024 * 1024  // 100 MB
        cache.countLimit = 200
        return cache
    }()
    
    // MARK: - Disk Cache
    
    private let diskCacheURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("PosterCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    private let diskMaxAge: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    
    private var hasCleanedDisk = false
    
    // MARK: - Public API
    
    /// Synchronous check — returns cached image from memory or disk, nil on miss.
    func cachedImage(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        
        // Memory hit
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }
        
        // Disk hit
        if let image = loadFromDisk(key: key) {
            let cost = image.jpegData(compressionQuality: 1.0)?.count ?? 0
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)
            return image
        }
        
        return nil
    }
    
    /// Async load — checks caches first, then fetches from network.
    func loadImage(for url: URL) async -> UIImage? {
        // Check caches
        if let cached = cachedImage(for: url) {
            return cached
        }
        
        // Network fetch
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            return nil
        }
        
        let key = cacheKey(for: url)
        let cost = data.count
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
        saveToDisk(data: data, key: key)
        
        return image
    }
    
    /// Legacy compatibility — load from URL directly.
    func loadImage(from url: URL) async -> UIImage? {
        await loadImage(for: url)
    }
    
    /// Pre-load multiple poster images in parallel. Returns a dictionary of URL → UIImage.
    func preload(urls: [URL]) async -> [URL: UIImage] {
        await withTaskGroup(of: (URL, UIImage?).self) { group in
            for url in urls {
                group.addTask {
                    let image = await self.loadImage(for: url)
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
    
    /// Clear memory cache (e.g. on memory warning).
    func clearCache() {
        memoryCache.removeAllObjects()
    }
    
    /// Remove expired disk cache entries (older than 7 days).
    func cleanDiskCacheIfNeeded() {
        guard !hasCleanedDisk else { return }
        hasCleanedDisk = true
        
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }
        
        let cutoff = Date().addingTimeInterval(-diskMaxAge)
        
        for fileURL in files {
            guard let attrs = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = attrs.contentModificationDate,
                  modified < cutoff else { continue }
            try? fm.removeItem(at: fileURL)
        }
    }
    
    // MARK: - Private Helpers
    
    private func cacheKey(for url: URL) -> String {
        // Use last two path components as key (e.g. "w500/abcdef.jpg")
        let path = url.path
        return path
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
    
    private func diskPath(for key: String) -> URL {
        diskCacheURL.appendingPathComponent(key)
    }
    
    private func loadFromDisk(key: String) -> UIImage? {
        let path = diskPath(for: key)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        
        // Check expiry
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
           let modified = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) > diskMaxAge {
            try? FileManager.default.removeItem(at: path)
            return nil
        }
        
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }
    
    private func saveToDisk(data: Data, key: String) {
        let path = diskPath(for: key)
        try? data.write(to: path, options: .atomic)
    }
}
