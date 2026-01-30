import SwiftUI
import UIKit

/// Generates high-resolution shareable card images from SwiftUI views.
@MainActor
final class ShareCardGenerator: ObservableObject {
    
    @Published var isLoading = false
    @Published var generatedImage: UIImage?
    @Published var errorMessage: String?
    
    /// Generate a card image for the given format and data.
    func generateCard(format: ShareCardFormat, data: ShareCardData) async -> UIImage? {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Pre-load all poster images needed for the format
        let items: [RankedItem]
        switch format {
        case .top4Movies, .top4Shows:
            items = data.filteredItems(for: format)
        case .top10Movies, .top10Shows:
            items = data.filteredItems(for: format)
        case .list:
            // List cards are generated separately via ListShareSheet
            return nil
        }
        
        let urls = items.compactMap { $0.posterURL }
        let posterImages = await PosterCache.shared.preload(urls: urls)
        
        // Create updated data with loaded poster images
        let enrichedData = ShareCardData(
            items: data.items,
            posterImages: posterImages,
            movieCount: data.movieCount,
            tvCount: data.tvCount,
            tastePersonality: data.tastePersonality
        )
        
        // Render the card to a UIImage
        let image: UIImage?
        switch format {
        case .top4Movies, .top4Shows:
            let cardView = Top4CardView(data: enrichedData, format: format)
            let renderer = ImageRenderer(content: cardView)
            renderer.scale = 3.0
            renderer.proposedSize = .init(width: 1080, height: 1920)
            image = renderer.uiImage
            
        case .top10Movies, .top10Shows:
            let cardView = Top10CardView(data: enrichedData, format: format)
            let renderer = ImageRenderer(content: cardView)
            renderer.scale = 3.0
            renderer.proposedSize = .init(width: 1080, height: 1080)
            image = renderer.uiImage
            
        case .list:
            image = nil
        }
        
        if let image {
            generatedImage = image
        } else {
            errorMessage = "Failed to render card image."
        }
        
        return image
    }
    
    /// Save the generated image to the photo library.
    func saveToPhotos() {
        guard let image = generatedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
