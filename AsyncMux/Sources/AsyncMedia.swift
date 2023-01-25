//
//  AsyncMedia.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 14/01/2023.
//  Copyright © 2023 Hovik Melikyan. All rights reserved.
//

import Foundation


@globalActor
public actor AsyncMedia {

	public static let shared = AsyncMedia()

	private var taskMap: [URL: Task<Void, Error>] = [:]

	public func request(url: URL) async throws -> URL {
		let cachedURL = Self.cacheFileURLFor(url: url, createDir: true)

		if FileManager.default.fileExists(cachedURL) {
			return cachedURL
		}

		if taskMap[url] == nil {
			taskMap[url] = Task {
				DLOG("AsyncMedia: Downloading: \(url.absoluteString)")
				let (tempURL, response) = try await Self.sharedSession.download(from: url)
				let httpResponse = response as! HTTPURLResponse
				switch httpResponse.statusCode {
					case 200..<300:
						try FileManager.default.moveItem(at: tempURL, to: cachedURL)
						DLOG("AsyncMedia: Completed: \(url)")
					default:
						throw AsyncHTTPError(status: httpResponse.statusCode)
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

	public func clear() {
		try? FileManager.default.removeItem(at: Self.cacheDirURL(create: false))
	}

	private static let sharedSession = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: .main)

	private static func cacheFileURLFor(url: URL, createDir: Bool) -> URL {
		cacheDirURL(create: createDir).appendingPathComponent(url.toFileSystemSafeString())
	}

	private static func cacheDirURL(create: Bool) -> URL {
		FileManager.default.cachesDirectory(subDirectory: "AsyncMediaFiles", create: create)
	}
}
