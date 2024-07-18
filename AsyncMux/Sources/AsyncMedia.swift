//
//  AsyncMedia.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 14/01/2023.
//  Copyright © 2023 Hovik Melikyan. All rights reserved.
//

import Foundation


/// Asynchronous caching downloader for video, audio or other large media files. Call `AsyncMedia.shared.request(url:)` to retrieve the local file path of the cached object. The result is a file URL.
@globalActor
public actor AsyncMedia {

    public static let shared = AsyncMedia()

    /// Requests an immutable remote file. The file will be stored in the app's cache directory and the URL returned to the caller asynchronously. For each URL, multiple simultaneous network requests are merged into one request. For subsequent requests a local file URL will be returned immediately. Note that the cached files can be removed by the OS at any time to free disk space, but only when the app is not running.
    public func request(url: URL) async throws -> URL {
        if url.isFileURL {
            return url
        }

        let cachedURL = Self.cacheFileURLFor(url: url, createDir: true)

        if FileManager.default.fileExists(cachedURL) {
            return cachedURL
        }

        if taskMap[url] == nil {
            taskMap[url] = Task {
                DLOG("AsyncMedia: Downloading: \(url)")
                let (tempURL, response) = try await Self.sharedSession.download(from: url)
                let httpResponse = response as! HTTPURLResponse
                switch httpResponse.statusCode {
                    case 200..<300:
                        try FileManager.default.moveItem(at: tempURL, to: cachedURL)
                        DLOG("AsyncMedia: Completed: \(url)")
                    default:
                        throw HTTPError(status: httpResponse.statusCode)
                }
            }
        }

        do {
            try await taskMap[url]!.value
            taskMap.removeValue(forKey: url)
            return cachedURL
        }
        catch {
            taskMap.removeValue(forKey: url)
            throw error
        }
    }

    /// Returns a local file URL for a cached object, if it exists
    public static func cachedValue(url: URL) -> URL? {
        let cachedURL = cacheFileURLFor(url: url, createDir: false)
        if FileManager.default.fileExists(cachedURL) {
            return cachedURL
        }
        return nil
    }

    /// Clears all files cached via `AsyncMedia.shared.request(url:)`.
    public func clear() {
        try? FileManager.default.removeItem(at: Self.cacheDirURL(create: false))
    }

    private var taskMap: [URL: Task<Void, Error>] = [:]

    private static let sharedSession = URLSession(configuration: .ephemeral)

    private static func cacheFileURLFor(url: URL, createDir: Bool) -> URL {
        cacheDirURL(create: createDir).appendingPathComponent(url.toFileSystemSafeString())
    }

    private static func cacheDirURL(create: Bool) -> URL {
        FileManager.default.cachesDirectory(subDirectory: "AsyncMediaFiles", create: create)
    }

    private init() { }
}
