//
//  AsyncMuxCacher.swift
//
//  Created by Hovik Melikyan on 09/01/2023.
//

import Foundation


public class AsyncMuxCacher<T: Codable> {
	func load(key: String) -> T? { preconditionFailure() }
	func save(_ result: T, key: String) { preconditionFailure() }
	func delete(key: String) { preconditionFailure() }
	func deleteDomain() { preconditionFailure() }
}


public final class JSONDiskCacher<T: Codable>: AsyncMuxCacher<T> {

	private let domain: String?

	public required init(domain: String?) {
		self.domain = domain
	}

	public override func load(key: String) -> T? {
		return try? JSONDecoder().decode(T.self, from: Data(contentsOf: cacheFileURL(key: key, create: false)))
	}

	public override func save(_ result: T, key: String) {
		try! JSONEncoder().encode(result).write(to: cacheFileURL(key: key, create: true), options: .atomic)
	}

	public override func delete(key: String) {
		try? FileManager.default.removeItem(at: cacheFileURL(key: key, create: false))
	}

	public override func deleteDomain() {
		precondition(domain != nil)
		try? FileManager.default.removeItem(at: cacheDirURL(create: false))
	}

	private func cacheFileURL(key: String, create: Bool) -> URL {
		return cacheDirURL(create: create).appendingPathComponent(key).appendingPathExtension("json")
	}

	private func cacheDirURL(create: Bool) -> URL {
		let dir = "AsyncMux/" + (domain ?? "")
		return FileManager.cachesDirectory(subDirectory: dir, create: create)
	}
}
