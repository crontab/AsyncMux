//
//  AsyncMuxMap.swift
//
//  Created by Hovik Melikyan on 09/01/2023.
//

import Foundation


public typealias MuxKey = LosslessStringConvertible & Hashable


@MainActor
open class AsyncMuxMap<K: MuxKey, T: Codable>: MuxRepositoryProtocol {

	public var timeToLive: TimeInterval = MuxDefaultTTL
	public let cacheKey: String

	private let cacher: AsyncMuxCacher<T>?
	private let onKeyFetch: (K) async throws -> T
	private var fetcherMap: [String: _AsyncMuxFetcher<T>] = [:]

	public convenience init(cacheKey: String? = nil, onKeyFetch: @escaping (K) async throws -> T) {
		let cacheKey = cacheKey ?? String(describing: T.self)
		self.init(cacheKey: cacheKey, cacher: JSONDiskCacher<T>(domain: cacheKey), onKeyFetch: onKeyFetch)
	}

	public init(cacheKey: String? = nil, cacher: AsyncMuxCacher<T>?, onKeyFetch: @escaping (K) async throws -> T) {
		self.cacheKey = cacheKey ?? String(describing: T.self)
		self.cacher = cacher
		self.onKeyFetch = onKeyFetch
	}

	public func request(key: K) async throws -> T {
		let fetcher = fetcherForKey(key)
		return try await fetcher.request(ttl: timeToLive, cacher: cacher, key: String(key)) { [self] in
			try await onKeyFetch(key)
		}
	}

	@discardableResult
	public func refresh(_ flag: Bool = true, key: K) -> Self {
		if flag {
			fetcherMap[String(key)]?.refreshFlag = true
		}
		return self
	}

	@discardableResult
	public func refresh(_ flag: Bool = true) -> Self {
		if flag {
			fetcherMap.values.forEach {
				$0.refreshFlag = true
			}
		}
		return self
	}

	@discardableResult
	public func clearMemory(key: K) -> Self {
		fetcherMap.removeValue(forKey: String(key))
		return self
	}

	@discardableResult
	public func clearMemory() -> Self {
		fetcherMap = [:]
		return self
	}

	@discardableResult
	public func clear(key: K) -> Self {
		cacher?.delete(key: String(key))
		return clearMemory(key: key)
	}

	@discardableResult
	public func clear() -> Self {
		cacher?.deleteDomain()
		return clearMemory()
	}

	@discardableResult
	public func save() -> Self {
		fetcherMap.forEach { key, fetcher in
			if fetcher.isDirty, let storedValue = fetcher.storedValue {
				cacher?.save(storedValue, key: String(key))
				fetcher.isDirty = false
			}
		}
		return self
	}

	private func fetcherForKey(_ key: K) -> _AsyncMuxFetcher<T> {
		var fetcher = fetcherMap[String(key)]
		if fetcher == nil {
			fetcher = _AsyncMuxFetcher<T>()
			fetcherMap[String(key)] = fetcher
		}
		return fetcher!
	}
}
