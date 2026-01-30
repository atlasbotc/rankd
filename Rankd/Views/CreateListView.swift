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
            Form {
                Section("List Name") {
                    TextField("e.g. Top Horror Movies", text: $name)
                }
                
                Section("Description (Optional)") {
                    TextField("What's this list about?", text: $listDescription, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Icon") {
                    emojiPicker
                }
            }
            .navigationTitle(isEditing ? "Edit List" : "New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveList()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let list = existingList {
                    name = list.name
                    listDescription = list.listDescription
                    selectedEmoji = list.emoji
                } else if let suggestion = suggested {
                    name = suggestion.name
                    selectedEmoji = suggestion.emoji
                }
            }
        }
    }
    
    // MARK: - Emoji Picker
    
    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                ForEach(commonEmojis, id: \.self) { emoji in
                    Button {
                        selectedEmoji = emoji
                    } label: {
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(selectedEmoji == emoji ? Color.orange.opacity(0.3) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack {
                Text("Selected:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(selectedEmoji)
                    .font(.title2)
                
                Spacer()
                
                Button("Custom") {
                    showCustomEmoji.toggle()
                }
                .font(.subheadline)
            }
            
            if showCustomEmoji {
                HStack {
                    TextField("Type an emoji", text: $customEmojiText)
                        .textFieldStyle(.roundedBorder)
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
        }
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    CreateListView(suggested: nil)
        .modelContainer(for: [CustomList.self, CustomListItem.self], inMemory: true)
}
