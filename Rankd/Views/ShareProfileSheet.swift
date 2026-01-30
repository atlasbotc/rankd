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
                    .padding(.top, RankdSpacing.sm)
                    .padding(.bottom, RankdSpacing.md)
                
                ScrollView {
                    cardPreview
                        .padding(.horizontal, RankdSpacing.md)
                }
                
                actionButtons
                    .padding(.horizontal, RankdSpacing.md)
                    .padding(.vertical, RankdSpacing.md)
                    .background(RankdColors.surfacePrimary)
            }
            .background(RankdColors.background)
            .navigationTitle("Share Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(RankdColors.textSecondary)
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
        [.top10Movies, .top10Shows]
    ]
    
    private var formatPicker: some View {
        VStack(spacing: RankdSpacing.xs) {
            ForEach(Self.profileFormats, id: \.first) { row in
                HStack(spacing: RankdSpacing.xs) {
                    ForEach(row) { format in
                        formatButton(format)
                    }
                }
            }
        }
        .padding(.horizontal, RankdSpacing.md)
    }
    
    private func formatButton(_ format: ShareCardFormat) -> some View {
        let isSelected = selectedFormat == format
        return Button {
            withAnimation(RankdMotion.normal) {
                selectedFormat = format
            }
        } label: {
            Text(format.rawValue)
                .font(RankdTypography.labelMedium)
                .foregroundStyle(isSelected ? RankdColors.textPrimary : RankdColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: RankdRadius.sm)
                        .fill(isSelected ? RankdColors.surfaceSecondary : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RankdRadius.sm)
                        .strokeBorder(isSelected ? RankdColors.brand : RankdColors.divider, lineWidth: isSelected ? 2 : 1)
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
                    .clipShape(RoundedRectangle(cornerRadius: RankdRadius.lg))
                    .shadow(color: RankdShadow.elevated, radius: RankdShadow.elevatedRadius, y: RankdShadow.elevatedY)
                    .padding(.vertical, RankdSpacing.xs)
            } else if let error = generator.errorMessage {
                errorState(message: error)
            } else {
                loadingState
            }
        }
    }
    
    private var loadingState: some View {
        VStack(spacing: RankdSpacing.md) {
            let aspectRatio: CGFloat = selectedFormat.isTop4 ? 1080.0 / 1920.0 : 1.0
            
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay {
                    VStack(spacing: RankdSpacing.sm) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(RankdColors.textTertiary)
                        Text("Generating card...")
                            .font(RankdTypography.bodyMedium)
                            .foregroundStyle(RankdColors.textSecondary)
                    }
                }
        }
    }
    
    private func errorState(message: String) -> some View {
        VStack(spacing: RankdSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(RankdTypography.displayMedium)
                .foregroundStyle(RankdColors.textTertiary)
            Text(message)
                .font(RankdTypography.bodyMedium)
                .foregroundStyle(RankdColors.textSecondary)
            Button("Retry") {
                Task { await generateCard() }
            }
            .font(RankdTypography.labelMedium)
            .foregroundStyle(RankdColors.brand)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RankdSpacing.xxxl)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: RankdSpacing.sm) {
            Button {
                generator.saveToPhotos()
                HapticManager.notification(.success)
                withAnimation(RankdMotion.normal) {
                    savedToPhotos = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(RankdMotion.normal) { savedToPhotos = false }
                }
            } label: {
                HStack(spacing: RankdSpacing.xs) {
                    Image(systemName: savedToPhotos ? "checkmark" : "arrow.down.to.line")
                        .font(RankdTypography.headingSmall)
                    Text(savedToPhotos ? "Saved!" : "Save")
                        .font(RankdTypography.headingSmall)
                }
                .foregroundStyle(RankdColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: RankdRadius.md)
                        .fill(RankdColors.surfaceSecondary)
                )
            }
            .buttonStyle(.plain)
            .disabled(generator.generatedImage == nil || generator.isLoading)
            
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: RankdSpacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(RankdTypography.headingSmall)
                    Text("Share")
                        .font(RankdTypography.headingSmall)
                }
                .foregroundStyle(RankdColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: RankdRadius.md)
                        .fill(RankdColors.brand)
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
