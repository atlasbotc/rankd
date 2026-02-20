import SwiftUI

/// A drop-in replacement for AsyncImage that checks PosterCache first.
/// Shows a shimmer placeholder while loading, caches results for reuse.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var uiImage: UIImage?
    @State private var isLoading = true
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url else {
            isLoading = false
            return
        }
        
        // Sync cache check first
        if let cached = await PosterCache.shared.cachedImage(for: url) {
            uiImage = cached
            isLoading = false
            return
        }
        
        // Async load (network + cache store)
        let image = await PosterCache.shared.loadImage(for: url)
        uiImage = image
        isLoading = false
    }
}

/// Convenience: poster-sized CachedAsyncImage with standard shimmer placeholder.
struct CachedPosterImage: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = MarquiPoster.cornerRadius
    var placeholderIcon: String = "film"
    
    var body: some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(MarquiColors.surfaceSecondary)
                .overlay {
                    Image(systemName: placeholderIcon)
                        .font(MarquiTypography.headingLarge)
                        .foregroundStyle(MarquiColors.textTertiary)
                }
                .shimmer()
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Image Prefetcher

/// Prefetches images beyond the visible area for smoother scrolling.
struct ImagePrefetcher {
    /// Prefetch a batch of URLs (fire-and-forget).
    static func prefetch(urls: [URL?]) {
        let validURLs = urls.compactMap { $0 }
        guard !validURLs.isEmpty else { return }
        Task.detached(priority: .utility) {
            _ = await PosterCache.shared.preload(urls: validURLs)
        }
    }
}
