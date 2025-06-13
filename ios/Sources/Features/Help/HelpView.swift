import SwiftUI
import ComposableArchitecture

struct HelpView: View {
    let store: StoreOf<HelpFeature>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(
                    text: .init(
                        get: { store.searchText },
                        set: { store.send(.updateSearchText($0)) }
                    )
                )
                .padding()
                
                if let selectedTopic = store.selectedTopic {
                    // Topic Detail View
                    HelpTopicDetailView(
                        topic: selectedTopic,
                        onBack: { store.send(.clearSelection) }
                    )
                } else {
                    // Topic List View
                    HelpTopicListView(store: store)
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        store.send(.dismissHelp)
                    }
                }
            }
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search help topics...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .foregroundColor(.botanicalGreen)
            }
        }
    }
}

// MARK: - Help Topic List View
struct HelpTopicListView: View {
    let store: StoreOf<HelpFeature>
    
    private var topicsByCategory: [HelpTopic.Category: [HelpTopic]] {
        Dictionary(grouping: store.filteredTopics, by: \.category)
    }
    
    var body: some View {
        if store.filteredTopics.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("No help topics found")
                    .botanicalStyle(BotanicalTextStyle.headline)
                
                Text("Try different search terms")
                    .botanicalStyle(BotanicalTextStyle.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(HelpTopic.Category.allCases, id: \.self) { category in
                    if let topics = topicsByCategory[category], !topics.isEmpty {
                        Section(header: CategoryHeaderView(category: category)) {
                            ForEach(topics) { topic in
                                HelpTopicRowView(topic: topic) {
                                    store.send(.selectTopic(topic))
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
}

// MARK: - Category Header View
struct CategoryHeaderView: View {
    let category: HelpTopic.Category
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundColor(.botanicalGreen)
            
            Text(category.rawValue)
                .botanicalStyle(BotanicalTextStyle.headline)
        }
    }
}

// MARK: - Help Topic Row View
struct HelpTopicRowView: View {
    let topic: HelpTopic
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .botanicalStyle(BotanicalTextStyle.subheadline)
                        .foregroundColor(.primary)
                    
                    Text(topic.content.prefix(100) + "...")
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Help Topic Detail View
struct HelpTopicDetailView: View {
    let topic: HelpTopic
    let onBack: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.botanicalGreen)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    HStack {
                        Image(systemName: topic.category.icon)
                            .foregroundColor(.botanicalGreen)
                            .font(.title2)
                        
                        Text(topic.title)
                            .botanicalStyle(BotanicalTextStyle.largeTitle)
                    }
                    
                    // Content with Markdown-like formatting
                    MarkdownText(content: topic.content)
                }
                .padding()
            }
        }
    }
}

// MARK: - Markdown Text View
struct MarkdownText: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseContent(), id: \.id) { element in
                switch element.type {
                case .heading:
                    Text(element.text)
                        .botanicalStyle(BotanicalTextStyle.headline)
                        .padding(.top, 8)
                
                case .bold:
                    Text(element.text)
                        .botanicalStyle(BotanicalTextStyle.body)
                        .fontWeight(.semibold)
                
                case .bulletPoint:
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .botanicalStyle(BotanicalTextStyle.body)
                            .foregroundColor(.botanicalGreen)
                        
                        Text(element.text)
                            .botanicalStyle(BotanicalTextStyle.body)
                    }
                
                case .paragraph:
                    Text(element.text)
                        .botanicalStyle(BotanicalTextStyle.body)
                }
            }
        }
    }
    
    private func parseContent() -> [ContentElement] {
        let lines = content.components(separatedBy: .newlines)
        var elements: [ContentElement] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                continue
            } else if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") {
                // Bold heading
                let text = String(trimmed.dropFirst(2).dropLast(2))
                elements.append(ContentElement(type: .heading, text: text))
            } else if trimmed.hasPrefix("•") {
                // Bullet point
                let text = String(trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces))
                elements.append(ContentElement(type: .bulletPoint, text: text))
            } else if trimmed.contains("**") {
                // Bold text within paragraph
                elements.append(ContentElement(type: .bold, text: trimmed.replacingOccurrences(of: "**", with: "")))
            } else {
                // Regular paragraph
                elements.append(ContentElement(type: .paragraph, text: trimmed))
            }
        }
        
        return elements
    }
    
    private struct ContentElement {
        let id = UUID()
        let type: ElementType
        let text: String
        
        enum ElementType {
            case heading
            case bold
            case bulletPoint
            case paragraph
        }
    }
}

#Preview {
    HelpView(
        store: Store(
            initialState: HelpFeature.State(),
            reducer: { HelpFeature() }
        )
    )
}