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
                VStack(spacing: RankdSpacing.lg) {
                    // Template suggestions (only for new lists without a pre-selected template)
                    if !isEditing && suggested == nil && name.isEmpty {
                        templateSuggestions
                    }
                    
                    // List Name
                    VStack(alignment: .leading, spacing: RankdSpacing.xs) {
                        Text("List Name")
                            .font(RankdTypography.labelMedium)
                            .foregroundStyle(RankdColors.textSecondary)
                        
                        TextField("e.g. Top Horror Movies", text: $name)
                            .font(RankdTypography.bodyLarge)
                            .foregroundStyle(RankdColors.textPrimary)
                            .padding(RankdSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: RankdRadius.md)
                                    .fill(RankdColors.surfacePrimary)
                            )
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: RankdSpacing.xs) {
                        Text("Description (Optional)")
                            .font(RankdTypography.labelMedium)
                            .foregroundStyle(RankdColors.textSecondary)
                        
                        TextField("What's this list about?", text: $listDescription, axis: .vertical)
                            .font(RankdTypography.bodyMedium)
                            .foregroundStyle(RankdColors.textPrimary)
                            .lineLimit(2...4)
                            .padding(RankdSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: RankdRadius.md)
                                    .fill(RankdColors.surfacePrimary)
                            )
                    }
                    
                    // Icon
                    VStack(alignment: .leading, spacing: RankdSpacing.xs) {
                        Text("Icon")
                            .font(RankdTypography.labelMedium)
                            .foregroundStyle(RankdColors.textSecondary)
                        
                        emojiPicker
                    }
                }
                .padding(RankdSpacing.md)
            }
            .background(RankdColors.background)
            .navigationTitle(isEditing ? "Edit List" : "New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(RankdColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveList()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? RankdColors.brand : RankdColors.textTertiary)
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
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            Text("Start from a template")
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textTertiary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RankdSpacing.sm) {
                    ForEach(SuggestedList.allSuggestions) { suggestion in
                        Button {
                            withAnimation(RankdMotion.normal) {
                                name = suggestion.name
                                listDescription = suggestion.description
                                selectedEmoji = suggestion.emoji
                            }
                        } label: {
                            VStack(spacing: RankdSpacing.xs) {
                                Text(suggestion.emoji)
                                    .font(.system(size: 28))
                                Text(suggestion.name)
                                    .font(RankdTypography.labelMedium)
                                    .foregroundStyle(RankdColors.textPrimary)
                                    .lineLimit(1)
                            }
                            .frame(width: 100)
                            .padding(.vertical, RankdSpacing.sm)
                            .padding(.horizontal, RankdSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: RankdRadius.md)
                                    .fill(RankdColors.surfacePrimary)
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
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: RankdSpacing.xs) {
                ForEach(commonEmojis, id: \.self) { emoji in
                    Button {
                        selectedEmoji = emoji
                    } label: {
                        Text(emoji)
                            .font(RankdTypography.headingLarge)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(selectedEmoji == emoji ? RankdColors.brand.opacity(0.3) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(RankdSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: RankdRadius.md)
                    .fill(RankdColors.surfacePrimary)
            )
            
            HStack {
                Text("Selected:")
                    .font(RankdTypography.bodySmall)
                    .foregroundStyle(RankdColors.textSecondary)
                Text(selectedEmoji)
                    .font(RankdTypography.headingLarge)
                
                Spacer()
                
                Button("Custom") {
                    showCustomEmoji.toggle()
                }
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.brand)
            }
            
            if showCustomEmoji {
                HStack {
                    TextField("Type an emoji", text: $customEmojiText)
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.textPrimary)
                        .padding(RankdSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: RankdRadius.md)
                                .fill(RankdColors.surfacePrimary)
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
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    CreateListView(suggested: nil)
        .modelContainer(for: [CustomList.self, CustomListItem.self], inMemory: true)
}
