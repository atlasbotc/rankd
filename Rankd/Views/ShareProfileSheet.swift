import SwiftUI
import UIKit

struct ShareProfileSheet: View {
    let cardData: ShareCardData
    
    @StateObject private var generator = ShareCardGenerator()
    @State private var selectedFormat: ShareCardFormat = .top4
    @State private var showShareSheet = false
    @State private var savedToPhotos = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Format picker
                formatPicker
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                
                // Card preview
                ScrollView {
                    cardPreview
                        .padding(.horizontal)
                }
                
                // Action buttons
                actionButtons
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
            }
            .navigationTitle("Share Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
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
    
    private var formatPicker: some View {
        Picker("Format", selection: $selectedFormat) {
            ForEach(ShareCardFormat.allCases) { format in
                Text(format.rawValue).tag(format)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
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
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    .padding(.vertical, 8)
            } else if let error = generator.errorMessage {
                errorState(message: error)
            } else {
                loadingState
            }
        }
    }
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            let aspectRatio: CGFloat = selectedFormat == .top4 ? 1080.0 / 1920.0 : 1.0
            
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Generating card...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }
    
    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await generateCard() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Save to Photos
            Button {
                generator.saveToPhotos()
                withAnimation {
                    savedToPhotos = true
                }
                // Reset after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { savedToPhotos = false }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: savedToPhotos ? "checkmark" : "arrow.down.to.line")
                        .font(.body.weight(.semibold))
                    Text(savedToPhotos ? "Saved!" : "Save")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            .disabled(generator.generatedImage == nil || generator.isLoading)
            
            // Share
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                    Text("Share")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.orange)
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
