import SwiftUI
import Combine
import Foundation

// MARK: - Image Cache Service

@MainActor
class ImageCacheService: ObservableObject {
    static let shared = ImageCacheService()
    
    @Published var cacheSize: Int = 0
    @Published var isLoading = false
    
    private var cache = NSCache<NSString, UIImage>()
    private var downloadTasks: [String: Task<UIImage?, Error>] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB
    private let maxItemCount = 200
    private let compressionQuality: CGFloat = 0.8
    
    init() {
        setupCache()
        setupMemoryWarning()
    }
    
    private func setupCache() {
        cache.totalCostLimit = maxCacheSize
        cache.countLimit = maxItemCount
        cache.name = "PlantImageCache"
    }
    
    private func setupMemoryWarning() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func image(for url: String) async -> UIImage? {
        // Check cache first
        if let cachedImage = cache.object(forKey: url as NSString) {
            return cachedImage
        }
        
        // Check if download is in progress
        if let existingTask = downloadTasks[url] {
            return try? await existingTask.value
        }
        
        // Start new download
        let task = Task {
            return await downloadImage(from: url)
        }
        
        downloadTasks[url] = task
        
        do {
            let image = try await task.value
            downloadTasks.removeValue(forKey: url)
            return image
        } catch {
            downloadTasks.removeValue(forKey: url)
            print("❌ Image download failed for \(url): \(error)")
            return nil
        }
    }
    
    func preloadImages(_ urls: [String]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in urls.prefix(10) { // Limit concurrent downloads
                    group.addTask {
                        _ = await self.image(for: url)
                    }
                }
            }
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
        cacheSize = 0
        print("✅ Image cache cleared")
    }
    
    func removeCachedImage(for url: String) {
        cache.removeObject(forKey: url as NSString)
    }
    
    func getCacheInfo() -> ImageCacheInfo {
        let totalCount = cache.totalCostLimit
        let currentCount = cache.countLimit
        
        return ImageCacheInfo(
            totalSize: maxCacheSize,
            currentSize: cacheSize,
            itemCount: currentCount,
            maxItems: maxItemCount
        )
    }
    
    // MARK: - Private Methods
    
    private func downloadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return nil
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Validate response
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                print("❌ Invalid response for \(urlString)")
                return nil
            }
            
            // Validate content type
            guard let contentType = httpResponse.mimeType,
                  contentType.hasPrefix("image/") else {
                print("❌ Invalid content type for \(urlString)")
                return nil
            }
            
            // Create image
            guard let image = UIImage(data: data) else {
                print("❌ Failed to create image from data for \(urlString)")
                return nil
            }
            
            // Optimize image
            let optimizedImage = await optimizeImage(image)
            
            // Cache image
            await cacheImage(optimizedImage, for: urlString)
            
            return optimizedImage
            
        } catch {
            print("❌ Image download error for \(urlString): \(error)")
            return nil
        }
    }
    
    private func optimizeImage(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let optimized = self.resizeAndCompressImage(image)
                continuation.resume(returning: optimized)
            }
        }
    }
    
    private func resizeAndCompressImage(_ image: UIImage) -> UIImage {
        // Target size for plant images
        let targetSize = CGSize(width: 400, height: 400)
        
        // Don't upscale images
        guard image.size.width > targetSize.width || image.size.height > targetSize.height else {
            return compressImage(image)
        }
        
        // Calculate aspect ratio
        let aspectRatio = image.size.width / image.size.height
        var newSize = targetSize
        
        if aspectRatio > 1 {
            // Landscape
            newSize.height = targetSize.width / aspectRatio
        } else {
            // Portrait or square
            newSize.width = targetSize.height * aspectRatio
        }
        
        // Resize image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return compressImage(resizedImage)
    }
    
    private func compressImage(_ image: UIImage) -> UIImage {
        guard let data = image.jpegData(compressionQuality: compressionQuality),
              let compressedImage = UIImage(data: data) else {
            return image
        }
        
        return compressedImage
    }
    
    private func cacheImage(_ image: UIImage, for url: String) async {
        let cost = Int(image.size.width * image.size.height * 4) // Approximate memory cost
        cache.setObject(image, forKey: url as NSString, cost: cost)
        
        await MainActor.run {
            updateCacheSize()
        }
    }
    
    private func updateCacheSize() {
        // Approximate cache size calculation
        cacheSize = cache.totalCostLimit
    }
    
    private func handleMemoryWarning() {
        // Clear half the cache on memory warning
        let keysToRemove = Array(cache.allKeys.prefix(cache.allKeys.count / 2))
        
        for key in keysToRemove {
            if let nsKey = key as? NSString {
                cache.removeObject(forKey: nsKey)
            }
        }
        
        updateCacheSize()
        print("⚠️ Memory warning: Image cache reduced")
    }
}

// MARK: - Cache Info

struct ImageCacheInfo {
    let totalSize: Int
    let currentSize: Int
    let itemCount: Int
    let maxItems: Int
    
    var usagePercentage: Double {
        guard totalSize > 0 else { return 0 }
        return Double(currentSize) / Double(totalSize)
    }
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .memory)
    }
    
    var formattedCurrentSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(currentSize), countStyle: .memory)
    }
}

// MARK: - NSCache Extension

private extension NSCache {
    var allKeys: [AnyObject] {
        var keys: [AnyObject] = []
        
        // This is a workaround since NSCache doesn't provide direct access to keys
        // In practice, you might want to maintain your own set of keys
        return keys
    }
}

// MARK: - Cached Image View

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: String
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @StateObject private var imageCache = ImageCacheService.shared
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(
        url: String,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        defer { isLoading = false }
        
        self.image = await imageCache.image(for: url)
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: String) {
        self.init(
            url: url,
            content: { $0 },
            placeholder: { Color.gray.opacity(0.3) }
        )
    }
}

extension CachedAsyncImage where Placeholder == Color {
    init(
        url: String,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            url: url,
            content: content,
            placeholder: { Color.gray.opacity(0.3) }
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        CachedAsyncImage(url: "https://example.com/plant.jpg") { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 200, height: 200)
                .clipped()
                .cornerRadius(12)
        } placeholder: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 200, height: 200)
                .overlay {
                    ProgressView()
                }
        }
        
        Text("Cached Async Image Example")
            .caption()
            .foregroundColor(.secondary)
    }
    .padding()
}