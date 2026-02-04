import SwiftUI
import UIKit

struct ShareProfileSheet: View {
    let cardData: ShareCardData
    
    @StateObject private var generator = ShareCardGenerator()
    @State private var selectedFormat: ShareCardFormat = .top4Movies
    @State private var showShareSheet = false
    @State private var savedToPhotos = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                formatPicker
                    .padding(.top, MarquiSpacing.sm)
                    .padding(.bottom, MarquiSpacing.md)
                
                ScrollView {
                    cardPreview
                        .padding(.horizontal, MarquiSpacing.md)
                }
                
                actionButtons
                    .padding(.horizontal, MarquiSpacing.md)
                    .padding(.vertical, MarquiSpacing.md)
                    .background(MarquiColors.surfacePrimary)
            }
            .background(MarquiColors.background)
            .navigationTitle("Share Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(MarquiColors.textSecondary)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = generator.generatedImage {
                    ActivityViewController(activityItems: [image])
                }
            }
            .task {
                await generateCard()
            }
            .onChange(of: selectedFormat) { _, _ in
                Task { await generateCard() }
            }
        }
    }
    
    // MARK: - Format Picker
    
    private static let profileFormats: [[ShareCardFormat]] = [
        [.top4Movies, .top4Shows],
        [.top10Movies, .top10Shows],
        [.favorites]
    ]
    
    private var formatPicker: some View {
        VStack(spacing: MarquiSpacing.xs) {
            ForEach(Self.profileFormats, id: \.first) { row in
                HStack(spacing: MarquiSpacing.xs) {
                    ForEach(row) { format in
                        formatButton(format)
                    }
                }
            }
        }
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    private func formatButton(_ format: ShareCardFormat) -> some View {
        let isSelected = selectedFormat == format
        return Button {
            withAnimation(MarquiMotion.normal) {
                selectedFormat = format
            }
        } label: {
            Text(format.rawValue)
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(isSelected ? MarquiColors.textPrimary : MarquiColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: MarquiRadius.sm)
                        .fill(isSelected ? MarquiColors.surfaceSecondary : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MarquiRadius.sm)
                        .strokeBorder(isSelected ? MarquiColors.brand : MarquiColors.divider, lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Card Preview
    
    private var cardPreview: some View {
        Group {
            if generator.isLoading {
                loadingState
            } else if let image = generator.generatedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.lg))
                    .shadow(color: MarquiShadow.elevated, radius: MarquiShadow.elevatedRadius, y: MarquiShadow.elevatedY)
                    .padding(.vertical, MarquiSpacing.xs)
            } else if let error = generator.errorMessage {
                errorState(message: error)
            } else {
                loadingState
            }
        }
    }
    
    private var loadingState: some View {
        VStack(spacing: MarquiSpacing.md) {
            let aspectRatio: CGFloat = selectedFormat.isTop4 ? (1080.0 / 1920.0) : 1.0
            
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay {
                    VStack(spacing: MarquiSpacing.sm) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(MarquiColors.textTertiary)
                        Text("Generating card...")
                            .font(MarquiTypography.bodyMedium)
                            .foregroundStyle(MarquiColors.textSecondary)
                    }
                }
        }
    }
    
    private func errorState(message: String) -> some View {
        VStack(spacing: MarquiSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(MarquiTypography.displayMedium)
                .foregroundStyle(MarquiColors.textTertiary)
            Text(message)
                .font(MarquiTypography.bodyMedium)
                .foregroundStyle(MarquiColors.textSecondary)
            Button("Retry") {
                Task { await generateCard() }
            }
            .font(MarquiTypography.labelMedium)
            .foregroundStyle(MarquiColors.brand)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MarquiSpacing.xxxl)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: MarquiSpacing.sm) {
            Button {
                generator.saveToPhotos()
                HapticManager.notification(.success)
                withAnimation(MarquiMotion.normal) {
                    savedToPhotos = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(MarquiMotion.normal) { savedToPhotos = false }
                }
            } label: {
                HStack(spacing: MarquiSpacing.xs) {
                    Image(systemName: savedToPhotos ? "checkmark" : "arrow.down.to.line")
                        .font(MarquiTypography.headingSmall)
                    Text(savedToPhotos ? "Saved!" : "Save")
                        .font(MarquiTypography.headingSmall)
                }
                .foregroundStyle(MarquiColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: MarquiRadius.md)
                        .fill(MarquiColors.surfaceSecondary)
                )
            }
            .buttonStyle(.plain)
            .disabled(generator.generatedImage == nil || generator.isLoading)
            
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: MarquiSpacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(MarquiTypography.headingSmall)
                    Text("Share")
                        .font(MarquiTypography.headingSmall)
                }
                .foregroundStyle(MarquiColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: MarquiRadius.md)
                        .fill(MarquiColors.brand)
                )
            }
            .buttonStyle(.plain)
            .disabled(generator.generatedImage == nil || generator.isLoading)
        }
    }
    
    // MARK: - Helpers
    
    private func generateCard() async {
        _ = await generator.generateCard(format: selectedFormat, data: cardData)
    }
}

// MARK: - UIActivityViewController Wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
