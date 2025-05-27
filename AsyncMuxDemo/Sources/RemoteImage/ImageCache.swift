//
//  ImageCache.swift
//
//  Created by Hovik Melikyan on 28.06.24.
//

import Foundation
import UIKit.UIImage
import AsyncMux


private let CacheCapacity = 20


final class ImageCache {

    static func request(_ url: URL) async throws -> UIImage {
        if let image = loadFromMemory(url) {
            return image
        }
        let image = try await requestRemote(url)
        storeToMemory(url: url, image: image)
        return image
    }


    static func loadFromMemory(_ url: URL) -> UIImage? {
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

    private static func storeToMemory(url: URL, image: UIImage) {
        semaphore.wait()
        defer { semaphore.signal() }
        memCache.set(image, forKey: url)
    }


    @AsyncMediaActor
    private static func requestRemote(_ url: URL) async throws -> UIImage {
        let localURL = try await AsyncMedia.request(url: url)
        guard let image = UIImage(contentsOfFile: localURL.path) else {
            try? FileManager.default.removeItem(at: localURL) // remove the damaged file
            throw AppError.cachedFileDamaged
        }
        return image
    }


    nonisolated(unsafe)
    private static var memCache = LRUCache<URL, UIImage>(capacity: CacheCapacity)

    private static let semaphore = DispatchSemaphore(value: 1)
}
