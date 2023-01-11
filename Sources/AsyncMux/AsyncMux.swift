//
//  AsyncMux.swift
//
//  Created by Hovik Melikyan on 08/01/2023.
//

import Foundation


@MainActor
open class AsyncMux<T: Codable>: _AsyncMuxFetcher<T>, MuxRepositoryProtocol {

	public var timeToLive: TimeInterval = MuxDefaultTTL
	public let cacheKey: String

	private let cacher: any AsyncMuxCacher<T>
	private let onFetch: () async throws -> T

	public convenience init(cacheKey: String? = nil, onFetch: @escaping () async throws -> T) {
		self.init(cacheKey: cacheKey, cacher: JSONDiskCacher<T>(domain: nil), onFetch: onFetch)
	}

	public init(cacheKey: String? = nil, cacher: some AsyncMuxCacher<T>, onFetch: @escaping () async throws -> T) {
		self.cacheKey = cacheKey ?? String(describing: T.self)
		self.cacher = cacher
		self.onFetch = onFetch
	}

	public func request() async throws -> T {
		return try await request(ttl: timeToLive, cacher: cacher, key: cacheKey, onFetch: onFetch)
	}

	@discardableResult
	public func refresh(_ flag: Bool = true) -> Self {
		refreshFlag = refreshFlag || flag
		return self
	}

	@discardableResult
	public func clear() -> Self {
		cacher.delete(key: cacheKey)
		return clearMemory()
	}

	@discardableResult
	public func save() -> Self {
		if isDirty, let storedValue = storedValue {
			cacher.save(storedValue, key: cacheKey)
			isDirty = false
		}
		return self
	}
}
