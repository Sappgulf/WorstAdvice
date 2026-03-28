import SwiftUI

actor ImageCache {
    static let shared = ImageCache()
    
    private var cache: [URL: Data] = [:]
    private var inProgress: [URL: Task<Data?, Never>] = [:]
    
    func data(for url: URL) -> Data? {
        cache[url]
    }
    
    func setData(_ data: Data, for url: URL) {
        cache[url] = data
    }
    
    func loadData(from url: URL) async -> Data? {
        if let cached = cache[url] {
            return cached
        }
        
        if let existingTask = inProgress[url] {
            return await existingTask.value
        }
        
        let task = Task<Data?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else {
                return nil
            }
            guard !Task.isCancelled else { return nil }
            cache[url] = data
            return data
        }
        
        inProgress[url] = task
        let result = await task.value
        inProgress[url] = nil
        return result
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var imageData: Data?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        if let cached = await ImageCache.shared.data(for: url) {
            self.imageData = cached
            return
        }
        
        if let loaded = await ImageCache.shared.loadData(from: url) {
            self.imageData = loaded
        }
    }
}

#if canImport(UIKit)
import UIKit
#endif
