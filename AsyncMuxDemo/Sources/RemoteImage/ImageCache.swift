//
//  ImageCache.swift
//
//  Created by Hovik Melikyan on 28.06.24.
//

import Foundation
import UIKit.UIImage
import AsyncMux


private let CacheCapacity = 20


@MainActor
final class ImageCache {

    static func request(_ url: URL) async throws -> UIImage {
        if let image = loadFromMemory(url) {
            return image
        }
        let image = try await requestRemote(url)
        memCache.set(image, forKey: url)
        return image
    }


    static func loadFromMemory(_ url: URL) -> UIImage? {
        memCache.touch(key: url)
    }


    static func clear() {
        memCache.removeAll()
    }

    
    // MARK: - Private part

    @AsyncMediaActor
    private static func requestRemote(_ url: URL) async throws -> UIImage {
        let localURL = try await AsyncMedia.request(url: url)
        guard let image = UIImage(contentsOfFile: localURL.path) else {
            try? FileManager.default.removeItem(at: localURL) // remove the damaged file
            throw AppError.cachedFileDamaged
        }
        return image
    }


    private static var memCache = LRUCache<URL, UIImage>(capacity: CacheCapacity)

    private init() { }
}
