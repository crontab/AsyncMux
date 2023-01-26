//
//  Multiplexer.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 26/01/2023.
//

import Foundation


final class _MuxFetcher<T: Codable & Sendable> {

	var storedValue: T?
	var isDirty: Bool = false
	var refreshFlag: Bool = false

	private var task: Task<T, Error>?
	private var completionTime: TimeInterval = 0

	func request<K: MuxKey>(ttl: TimeInterval, cacher: some MuxCacher<T>, key: K, onFetch: @Sendable @escaping () async throws -> T) async throws -> T {
		if !refreshFlag, !isExpired(ttl: ttl) {
			if let storedValue {
				return storedValue
			}
			else if let cachedValue = cacher.load(key: String(key)) {
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
					if error.isSilencable, let cachedValue = storedValue ?? cacher.load(key: String(key)) {
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
}


public typealias MuxKey = LosslessStringConvertible & Hashable & Sendable


public actor MultiplexerMap<K: MuxKey, T: Codable & Sendable>: MuxRepositoryProtocol {

	public var timeToLive: TimeInterval = 30 * 60
	public let cacheKey: String

	private let cacher: any MuxCacher<T>
	private let onKeyFetch: @Sendable (K) async throws -> T
	private var fetcherMap: [K: _MuxFetcher<T>] = [:]

	public init(cacheKey: String? = nil, cacher: some MuxCacher<T>, onKeyFetch: @Sendable @escaping (K) async throws -> T) {
		self.cacheKey = cacheKey ?? String(describing: T.self)
		self.cacher = cacher
		self.onKeyFetch = onKeyFetch
	}

	public func request(key: K) async throws -> T {
		let fetcher = fetcherForKey(key)
		return try await fetcher.request(ttl: timeToLive, cacher: cacher, key: key) { [self] in
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
				cacher.save(storedValue, key: String(key))
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
		cacher.delete(key: String(key))
		clearMemory(key: key)
	}

	public func clear() {
		cacher.deleteDomain()
		clearMemory()
	}

	private func fetcherForKey(_ key: K) -> _MuxFetcher<T> {
		var fetcher = fetcherMap[key]
		if fetcher == nil {
			fetcher = _MuxFetcher<T>()
			fetcherMap[key] = fetcher
		}
		return fetcher!
	}
}
