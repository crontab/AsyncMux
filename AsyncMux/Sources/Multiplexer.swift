//
//  Multiplexer.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 26/01/2023.
//

import Foundation


public typealias MuxKey = LosslessStringConvertible & Hashable & Sendable


final class _MuxFetcher<K: MuxKey, T: Codable & Sendable> {

	var storedValue: T?
	var isDirty: Bool = false
	var refreshFlag: Bool = false

	private var task: Task<T, Error>?
	private var completionTime: TimeInterval = 0

	func request(ttl: TimeInterval, cacher: MuxCacher<T>.Type, domain: String, key: K, onFetch: @Sendable @escaping () async throws -> T) async throws -> T {
		if !refreshFlag, !isExpired(ttl: ttl) {
			if let storedValue {
				return storedValue
			}
			else if let cachedValue = cacher.load(domain: domain, key: String(key)) {
				storedValue = cachedValue
				return cachedValue
			}
		}

		refreshFlag = false

		if task == nil {
			let storedValue = storedValue // silence the sendability warning
			task = Task {
				do {
					return try await onFetch()
				}
				catch {
					if error.isSilencable, let cachedValue = storedValue ?? cacher.load(domain: domain, key: String(key)) {
						return cachedValue
					}
					throw error
				}
			}
		}

		do {
			let result = try await task!.value
			task = nil
			storedValue = result
			completionTime = Date().timeIntervalSinceReferenceDate
			isDirty = true
			return result
		}
		catch {
			task = nil
			storedValue = nil
			completionTime = 0
			throw error
		}
	}

	func isExpired(ttl: TimeInterval) -> Bool {
		Date().timeIntervalSinceReferenceDate > completionTime + ttl
	}

	func clearMemory() {
		completionTime = 0
		storedValue = nil
	}
}


public actor MultiplexerMap<K: MuxKey, T: Codable & Sendable>: MuxRepositoryProtocol {

	public var timeToLive: TimeInterval = 30 * 60
	public let cacheKey: String

	private let cacher: MuxCacher<T>.Type
	private let onKeyFetch: @Sendable (K) async throws -> T
	private var fetcherMap: [K: _MuxFetcher<K, T>] = [:]

	public init(cacheKey: String? = nil, onKeyFetch: @Sendable @escaping (K) async throws -> T) {
		self.cacheKey = cacheKey ?? String(describing: T.self)
		self.cacher = MuxCacher<T>.self
		self.onKeyFetch = onKeyFetch
	}

	public func request(key: K) async throws -> T {
		let fetcher = fetcherForKey(key)
		return try await fetcher.request(ttl: timeToLive, cacher: cacher, domain: cacheKey, key: key) { [self] in
			try await onKeyFetch(key)
		}
	}

	@discardableResult
	public func refresh(_ flag: Bool = true, key: K) -> Self {
		if flag {
			fetcherMap[key]?.refreshFlag = true
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

	public func save() {
		fetcherMap.forEach { key, fetcher in
			if fetcher.isDirty, let storedValue = fetcher.storedValue {
				cacher.save(storedValue, domain: cacheKey, key: String(key))
				fetcher.isDirty = false
			}
		}
	}

	public func clearMemory(key: K) {
		fetcherMap.removeValue(forKey: key)
	}

	public func clearMemory() {
		fetcherMap = [:]
	}

	public func clear(key: K) {
		cacher.delete(domain: cacheKey, key: String(key))
		clearMemory(key: key)
	}

	public func clear() {
		cacher.deleteDomain(cacheKey)
		clearMemory()
	}

	private func fetcherForKey(_ key: K) -> _MuxFetcher<K, T> {
		var fetcher = fetcherMap[key]
		if fetcher == nil {
			fetcher = _MuxFetcher()
			fetcherMap[key] = fetcher
		}
		return fetcher!
	}
}


private let muxRootDomain = "_Root"


public actor Multiplexer<T: Codable & Sendable>: MuxRepositoryProtocol {

	public var timeToLive: TimeInterval = 30 * 60
	public let cacheKey: String

	private let cacher = MuxCacher<T>.self
	private let onKeyFetch: @Sendable () async throws -> T
	private var fetcher = _MuxFetcher<String, T>()

	public init(cacheKey: String? = nil, onKeyFetch: @Sendable @escaping () async throws -> T) {
		self.cacheKey = cacheKey ?? String(describing: T.self)
		self.onKeyFetch = onKeyFetch
	}

	public func request() async throws -> T {
		return try await fetcher.request(ttl: timeToLive, cacher: cacher, domain: muxRootDomain, key: cacheKey) { [self] in
			try await onKeyFetch()
		}
	}

	@discardableResult
	public func refresh(_ flag: Bool = true) -> Self {
		if flag {
			fetcher.refreshFlag = true
		}
		return self
	}

	public func save() {
		if fetcher.isDirty, let storedValue = fetcher.storedValue {
			cacher.save(storedValue, domain: muxRootDomain, key: cacheKey)
			fetcher.isDirty = false
		}
	}

	public func clearMemory() {
		fetcher.clearMemory()
	}

	public func clear() {
		cacher.delete(domain: muxRootDomain, key: cacheKey)
		clearMemory()
	}
}
