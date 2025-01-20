//
//  ImageCache.swift
//
//  Created by Hovik Melikyan on 28.06.24.
//

import SwiftUI
import AsyncMux


private let CacheCapacity = 20


final class ImageCache {

    static func request(_ url: URL) async throws -> Image {
        if let image = loadFromMemory(url) {
            return image
        }
        let image = try await Self.requestRemote(url)
        storeToMemory(url: url, image: image)
        return image
    }


    static func loadFromMemory(_ url: URL) -> Image? {
        semaphore.wait()
        defer { semaphore.signal() }
        return memCache.touch(key: url)
    }


    static func clear() {
        semaphore.wait()
        defer { semaphore.signal() }
        memCache.removeAll()
    }


    // MARK: - Private part

    private static func storeToMemory(url: URL, image: Image) {
        semaphore.wait()
        defer { semaphore.signal() }
        memCache.set(image, forKey: url)
    }


    @AsyncMediaActor
    private static func requestRemote(_ url: URL) async throws -> Image {
        let localURL = try await AsyncMedia.request(url: url)
        guard let uiImage = UIImage(contentsOfFile: localURL.path) else {
            try? FileManager.default.removeItem(at: localURL) // reove the damaged file
            throw AppError(code: "cached_file_damaged", message: "Internal: cached file damaged")
        }
        return Image(uiImage: uiImage)
    }


    nonisolated(unsafe)
    private static var memCache = LRUCache<URL, Image>(capacity: CacheCapacity)

    private static let semaphore = DispatchSemaphore(value: 1)
}
