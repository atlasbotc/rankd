import SwiftUI
import SwiftData

struct CreateListView: View {
    let suggested: SuggestedList?
    var existingList: CustomList?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String = ""
    @State private var listDescription: String = ""
    @State private var selectedEmoji: String = "📋"
    @State private var showCustomEmoji = false
    @State private var customEmojiText: String = ""
    
    private let commonEmojis = ["🎬", "🎭", "🏆", "⭐", "🔥", "💀", "😱", "😂", "❤️", "🎪", "🌙", "🎄", "📋", "🍿", "👻", "🎯"]
    
    private var isEditing: Bool { existingList != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MarquiSpacing.lg) {
                    // Template suggestions (only for new lists without a pre-selected template)
                    if !isEditing && suggested == nil && name.isEmpty {
                        templateSuggestions
                    }
                    
                    // List Name
                    VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
                        Text("List Name")
                            .font(MarquiTypography.labelMedium)
                            .foregroundStyle(MarquiColors.textSecondary)
                        
                        TextField("e.g. Top Horror Movies", text: $name)
                            .font(MarquiTypography.bodyLarge)
                            .foregroundStyle(MarquiColors.textPrimary)
                            .padding(MarquiSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: MarquiRadius.md)
                                    .fill(MarquiColors.surfacePrimary)
                            )
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
                        Text("Description (Optional)")
                            .font(MarquiTypography.labelMedium)
                            .foregroundStyle(MarquiColors.textSecondary)
                        
                        TextField("What's this list about?", text: $listDescription, axis: .vertical)
                            .font(MarquiTypography.bodyMedium)
                            .foregroundStyle(MarquiColors.textPrimary)
                            .lineLimit(2...4)
                            .padding(MarquiSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: MarquiRadius.md)
                                    .fill(MarquiColors.surfacePrimary)
                            )
                    }
                    
                    // Icon
                    VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
                        Text("Icon")
                            .font(MarquiTypography.labelMedium)
                            .foregroundStyle(MarquiColors.textSecondary)
                        
                        emojiPicker
                    }
                }
                .padding(MarquiSpacing.md)
            }
            .background(MarquiColors.background)
            .navigationTitle(isEditing ? "Edit List" : "New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(MarquiColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveList()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? MarquiColors.brand : MarquiColors.textTertiary)
                }
            }
            .onAppear {
                if let list = existingList {
                    name = list.name
                    listDescription = list.listDescription
                    selectedEmoji = list.emoji
                } else if let suggestion = suggested {
                    name = suggestion.name
                    listDescription = suggestion.description
                    selectedEmoji = suggestion.emoji
                }
            }
        }
    }
    
    // MARK: - Template Suggestions
    
    private var templateSuggestions: some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
            Text("Start from a template")
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.textTertiary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MarquiSpacing.sm) {
                    ForEach(SuggestedList.allSuggestions) { suggestion in
                        Button {
                            withAnimation(MarquiMotion.normal) {
                                name = suggestion.name
                                listDescription = suggestion.description
                                selectedEmoji = suggestion.emoji
                            }
                        } label: {
                            VStack(spacing: MarquiSpacing.xs) {
                                Text(suggestion.emoji)
                                    .font(.system(size: 28))
                                Text(suggestion.name)
                                    .font(MarquiTypography.labelMedium)
                                    .foregroundStyle(MarquiColors.textPrimary)
                                    .lineLimit(1)
                            }
                            .frame(width: 100)
                            .padding(.vertical, MarquiSpacing.sm)
                            .padding(.horizontal, MarquiSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: MarquiRadius.md)
                                    .fill(MarquiColors.surfacePrimary)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Emoji Picker
    
    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: MarquiSpacing.xs) {
                ForEach(commonEmojis, id: \.self) { emoji in
                    Button {
                        selectedEmoji = emoji
                    } label: {
                        Text(emoji)
                            .font(MarquiTypography.headingLarge)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(selectedEmoji == emoji ? MarquiColors.brand.opacity(0.3) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(MarquiSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: MarquiRadius.md)
                    .fill(MarquiColors.surfacePrimary)
            )
            
            HStack {
                Text("Selected:")
                    .font(MarquiTypography.bodySmall)
                    .foregroundStyle(MarquiColors.textSecondary)
                Text(selectedEmoji)
                    .font(MarquiTypography.headingLarge)
                
                Spacer()
                
                Button("Custom") {
                    showCustomEmoji.toggle()
                }
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.brand)
            }
            
            if showCustomEmoji {
                HStack {
                    TextField("Type an emoji", text: $customEmojiText)
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.textPrimary)
                        .padding(MarquiSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: MarquiRadius.md)
                                .fill(MarquiColors.surfacePrimary)
                        )
                        .onChange(of: customEmojiText) { _, newValue in
                            if let first = newValue.first, newValue.unicodeScalars.first?.properties.isEmoji == true {
                                selectedEmoji = String(first)
                                customEmojiText = ""
                                showCustomEmoji = false
                            }
                        }
                }
            }
        }
    }
    
    // MARK: - Save
    
    private func saveList() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        if let list = existingList {
            list.name = trimmedName
            list.listDescription = listDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            list.emoji = selectedEmoji
            list.dateModified = Date()
        } else {
            let newList = CustomList(
                name: trimmedName,
                listDescription: listDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                emoji: selectedEmoji
            )
            modelContext.insert(newList)
            ActivityLogger.logCreatedList(list: newList, context: modelContext)
        }
        
        modelContext.safeSave()
        dismiss()
    }
}

#Preview {
    CreateListView(suggested: nil)
        .modelContainer(for: [CustomList.self, CustomListItem.self], inMemory: true)
}
