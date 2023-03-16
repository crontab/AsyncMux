//
//  Multiplexer.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 26/01/2023.
//

import Foundation


public typealias MuxKey = LosslessStringConvertible & Hashable & Sendable

private let defaultTTL: TimeInterval = 30 * 60
private let muxRootDomain = "_Root"


///
/// `Multiplexer<T>` is an asynchronous, callback-based caching facility for client apps. Each multiplxer instance can manage retrieval and caching of one object of type `T: Codable & Sendable`, therefore it is best to define each multiplexer instance in your app as a singleton.
/// For each multiplexer singleton you define a block that implements asynchronous retrieval of the object, which in your app will likely be a network request, e.g. to your backend system.
/// See README.md for a more detailed discussion.
///
public actor Multiplexer<T: Codable & Sendable>: MuxRepositoryProtocol {

	public typealias OnFetch = @Sendable () async throws -> T

	public var timeToLive: TimeInterval = defaultTTL
	public let cacheKey: String

	///
	/// Instantiates a `Multiplexer<T>` object with a given `onFetch` block.
	/// - parameter cacheKey (optional): a string to be used as a file name for the disk cache. If omitted, an automatic name is generated based on `T`'s description. NOTE: if you have several  multiplexers whose `T` is the same, you *should* define unique non-conflicting `cacheKey` parameters for each.
	/// - parameter onFetch: an async throwing block that should retrieve an object presumably in an asynchronous manner.
	///
	public init(cacheKey: String? = nil, onFetch: @escaping OnFetch) {
		self.cacheKey = cacheKey ?? String(describing: T.self)
		self.onFetch = onFetch
	}

	///
	/// Performs a request either by calling the `onFetch` block supplied in the multiplexer's constructor, or by returning the previously cached object, if available. Multiple simultaneous calls to `request()` are handled by the Multiplexer so that only one `onFetch` operation can be invoked at a time, but all callers of `request()` will eventually receive the result.
	///
	public func request() async throws -> T {
		return try await fetcher.request(ttl: timeToLive, cacher: cacher, domain: muxRootDomain, key: cacheKey) { [self] in
			try await onFetch()
		}
	}

	/// "Soft" refresh: the next call to `request()` will attempt to retrieve the object again, without discarding the caches in case of a failure. `refresh()` does not have an immediate effect on any ongoing asynchronous requests. Can be chained with the subsequent `request()`.
	@discardableResult
	public func refresh(_ flag: Bool = true) -> Self {
		if flag {
			fetcher.refreshFlag = true
		}
		return self
	}

	/// Writes the previously cached object to disk.
	public func save() {
		if fetcher.isDirty, let storedValue = fetcher.storedValue {
			cacher.save(storedValue, domain: muxRootDomain, key: cacheKey)
			fetcher.isDirty = false
		}
	}

	public func clearMemory() {
		fetcher.clearMemory()
	}

	/// Clears the memory and disk caches. Will trigger a full fetch on the next `request()` call.
	public func clear() {
		cacher.delete(domain: muxRootDomain, key: cacheKey)
		clearMemory()
	}

	private let cacher = MuxCacher<T>.self
	private let onFetch: OnFetch
	private var fetcher = _MuxFetcher<String, T>()
}


///
/// `MultiplexerMap<K, T>` is similar to `Multiplexer<T>` in many ways except it maintains a dictionary of objects of the same type. One example would be e.g. user profile objects in your social app.
/// The `K` generic paramter should conform to  `LosslessStringConvertible & Hashable & Sendable`. The string convertibility requirement is because it simplifies the disk cacher's job of storing objects on disk or a database.
/// See README.md for a more detailed discussion.
///
public actor MultiplexerMap<K: MuxKey, T: Codable & Sendable>: MuxRepositoryProtocol {

	public typealias OnKeyFetch = @Sendable (K) async throws -> T

	public var timeToLive: TimeInterval = defaultTTL
	public let cacheKey: String

	///
	/// Instantiates a `MultiplexerMap<T>` object with a given `onKeyFetch` block.
	/// - parameter cacheKey (optional): a string to be used as a file name for the disk cache. If omitted, an automatic name is generated based on `T`'s description. NOTE: if you have several  multiplexers whose `T` is the same, you *should* define unique non-conflicting `cacheKey` parameters for each.
	/// - parameter onKeyFetch: an async throwing block that should retrieve an object by a given key presumably in an asynchronous manner.
	///
	public init(cacheKey: String? = nil, onKeyFetch: @escaping OnKeyFetch) {
		self.cacheKey = cacheKey ?? String(describing: T.self)
		self.onKeyFetch = onKeyFetch
	}

	///
	/// Performs a request either by calling the `onKeyFetch` block supplied in the multiplexer's constructor, or by returning the previously cached object, if available. Multiple simultaneous calls to `request(key:)` are handled by the MultiplexerMap so that only one `onKeyFetch` operation can be invoked at a time for any given `key`, but all callers of `request(key:)` will eventually receive the result.
	///
	public func request(key: K) async throws -> T {
		let fetcher = fetcherForKey(key)
		return try await fetcher.request(ttl: timeToLive, cacher: cacher, domain: cacheKey, key: key) { [self] in
			try await onKeyFetch(key)
		}
	}

	/// "Soft" refresh: the next call to `request(key:)` will attempt to retrieve the object again, without discarding the caches in case of a failure. `refresh(key:)` does not have an immediate effect on any ongoing asynchronous requests. Can be chained with the subsequent `request(key:)`.
	@discardableResult
	public func refresh(_ flag: Bool = true, key: K) -> Self {
		if flag {
			fetcherMap[key]?.refreshFlag = true
		}
		return self
	}

	/// "Soft" refresh for all objects stored in this `MultiplexerMap`: the next call to `request(key:)` with any key will attempt to retrieve the object again, without discarding the caches in case of a failure. `refresh()` does not have an immediate effect on any ongoing asynchronous requests. Can be chained with the subsequent `request(key:)`.
	@discardableResult
	public func refresh(_ flag: Bool = true) -> Self {
		if flag {
			fetcherMap.values.forEach {
				$0.refreshFlag = true
			}
		}
		return self
	}

	/// Writes all previously cached objects in this `MultiplexerMap` to disk.
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

	/// Clears the memory and disk caches for an object with a given `key`. Will trigger a full fetch on the next `request(key:)` call.
	public func clear(key: K) {
		cacher.delete(domain: cacheKey, key: String(key))
		clearMemory(key: key)
	}

	/// Clears the memory and disk caches all objects in this `MultiplexerMap`. Will trigger a full fetch on the next `request(key:)` call.
	public func clear() {
		cacher.deleteDomain(cacheKey)
		clearMemory()
	}

	private let cacher = MuxCacher<T>.self
	private let onKeyFetch: OnKeyFetch
	private var fetcherMap: [K: _MuxFetcher<K, T>] = [:]

	private func fetcherForKey(_ key: K) -> _MuxFetcher<K, T> {
		var fetcher = fetcherMap[key]
		if fetcher == nil {
			fetcher = _MuxFetcher()
			fetcherMap[key] = fetcher
		}
		return fetcher!
	}
}


// MARK: - _MuxFetcher (internal)

final private class _MuxFetcher<K: MuxKey, T: Codable & Sendable> {

	typealias OnFetch = @Sendable () async throws -> T

	var storedValue: T?
	var isDirty: Bool = false
	var refreshFlag: Bool = false

	private var task: Task<T, Error>?
	private var completionTime: TimeInterval = 0

	func request(ttl: TimeInterval, cacher: MuxCacher<T>.Type, domain: String, key: K, onFetch: @escaping OnFetch) async throws -> T {
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
