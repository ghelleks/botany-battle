import SwiftUI

struct ShopView: View {
    @StateObject private var shopFeature: ShopFeature
    @State private var showingFilters = false
    @State private var showOnlyAffordable = false
    
    init(userDefaultsService: UserDefaultsService) {
        self._shopFeature = StateObject(wrappedValue: ShopFeature(userDefaultsService: userDefaultsService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with trophies and stats
            ShopHeaderView(
                trophies: shopFeature.userDefaultsService.totalTrophies,
                statistics: shopFeature.shopStatistics
            )
            
            // Category Picker
            ShopCategoryPicker(selectedCategory: $shopFeature.selectedCategory)
                .padding(.horizontal)
            
            // Filter Bar
            ShopFilterBar(
                showOnlyAffordable: $showOnlyAffordable,
                onFilterTap: { showingFilters.toggle() }
            )
            .padding(.horizontal)
            
            // Items Grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ForEach(shopFeature.filteredItems(
                        category: shopFeature.selectedCategory,
                        showOnlyAffordable: showOnlyAffordable
                    )) { item in
                        ShopItemCard(
                            item: item,
                            shopFeature: shopFeature
                        )
                    }
                }
                .padding()
            }
            .refreshable {
                shopFeature.objectWillChange.send()
            }
        }
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if shopFeature.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
        .alert("Error", isPresented: .constant(shopFeature.errorMessage != nil)) {
            Button("OK") {
                shopFeature.errorMessage = nil
            }
        } message: {
            Text(shopFeature.errorMessage ?? "")
        }
        .sheet(isPresented: $showingFilters) {
            ShopFiltersView(
                showOnlyAffordable: $showOnlyAffordable,
                selectedCategory: $shopFeature.selectedCategory
            )
        }
    }
}

// MARK: - Shop Header

struct ShopHeaderView: View {
    let trophies: Int
    let statistics: ShopStatistics
    
    var body: some View {
        VStack(spacing: 12) {
            // Trophy Balance
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                Text("\(trophies)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Trophies")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(statistics.ownedItems)/\(statistics.totalItems)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text("Owned")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress Bar
            VStack(spacing: 4) {
                HStack {
                    Text("Collection Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(statistics.formattedCompletionPercentage)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                ProgressView(value: statistics.completionPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Category Picker

struct ShopCategoryPicker: View {
    @Binding var selectedCategory: ShopItemCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ShopItemCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct CategoryButton: View {
    let category: ShopItemCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .green)
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.green : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Filter Bar

struct ShopFilterBar: View {
    @Binding var showOnlyAffordable: Bool
    let onFilterTap: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onFilterTap) {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filters")
                        .font(.caption)
                }
                .foregroundColor(.green)
            }
            
            Spacer()
            
            Toggle("Affordable Only", isOn: $showOnlyAffordable)
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .scaleEffect(0.8)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Shop Item Card

struct ShopItemCard: View {
    let item: ShopItem
    @ObservedObject var shopFeature: ShopFeature
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: item.icon)
                .font(.system(size: 40))
                .foregroundColor(item.isOwned ? .green : .primary)
                .frame(height: 50)
            
            // Name
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Description
            Text(item.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 30)
            
            Spacer()
            
            // Price/Status Button
            if item.isOwned {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("OWNED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if shopFeature.purchaseInProgress.contains(item.id) {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(height: 28)
            } else {
                Button(action: {
                    Task {
                        await shopFeature.purchaseItem(item)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("\(item.price)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(shopFeature.canAfford(item) ? Color.green : Color(.systemGray4))
                    .foregroundColor(shopFeature.canAfford(item) ? .white : .secondary)
                    .cornerRadius(8)
                }
                .disabled(!shopFeature.canAfford(item))
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                }, perform: {})
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(item.isOwned ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Shop Filters View

struct ShopFiltersView: View {
    @Binding var showOnlyAffordable: Bool
    @Binding var selectedCategory: ShopItemCategory
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ShopItemCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Filters") {
                    Toggle("Show Only Affordable Items", isOn: $showOnlyAffordable)
                }
                
                Section("About Categories") {
                    ForEach(ShopItemCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.green)
                                .frame(width: 25)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(category.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Shop Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ShopView(userDefaultsService: MockUserDefaultsService())
    }
}

// MARK: - Mock for Preview

extension MockUserDefaultsService {
    convenience init(withTrophies trophies: Int) {
        self.init()
        self.totalTrophies = trophies
    }
}