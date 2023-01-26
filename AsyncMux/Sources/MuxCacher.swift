//
//  MuxCacher.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 09/01/2023.
//  Copyright © 2023 Hovik Melikyan. All rights reserved.
//

import Foundation


public struct MuxCacher<Object: Codable>: Sendable {

	let domain: String

	public func load(key: String) -> Object? {
		return try? JSONDecoder().decode(Object.self, from: Data(contentsOf: cacheFileURL(key: key, create: false)))
	}

	public func save(_ result: Object, key: String) {
		try! JSONEncoder().encode(result).write(to: cacheFileURL(key: key, create: true), options: .atomic)
	}

	public func delete(key: String) {
		try? FileManager.default.removeItem(at: cacheFileURL(key: key, create: false))
	}

	public func deleteDomain() {
		try? FileManager.default.removeItem(at: cacheDirURL(create: false))
	}

	private func cacheFileURL(key: String, create: Bool) -> URL {
		return cacheDirURL(create: create).appendingPathComponent(key).appendingPathExtension("json")
	}

	private func cacheDirURL(create: Bool) -> URL {
		let dir = "AsyncMux/" + domain
		return FileManager.default.cachesDirectory(subDirectory: dir, create: create)
	}
}
