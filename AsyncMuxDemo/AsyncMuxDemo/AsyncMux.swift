//
//  AsyncMux.swift
//
//  Created by Hovik Melikyan on 08/01/2023.
//

import Foundation


public var MuxDefaultTTL: TimeInterval = 30 * 60


// MARK: - AsyncMuxFetcher

@MainActor
open class AsyncMuxFetcher<T: Codable> {

	public private(set) var storedValue: T?

	internal var isDirty: Bool = false
	internal var refreshFlag: Bool = false

	private var task: Task<T, Error>?
	private var completionTime: TimeInterval = 0

	func request(ttl: TimeInterval, cacher: AsyncMuxCacher<T>?, key: String, onFetch: @escaping () async throws -> T) async throws -> T {
		if !refreshFlag, let storedValue = storedValue, !isExpired(ttl: ttl) {
			return storedValue
		}

		refreshFlag = false

		if task == nil {
			task = Task {
				do {
					return try await onFetch()
				}
				catch {
					if error.isConnectivityError, let cachedValue = storedValue ?? cacher?.load(key: key) {
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

	func loadCachedValue<K: MuxKey>(key: K) -> T {
		preconditionFailure()
	}

	@discardableResult
	public func clearMemory() -> Self {
		completionTime = 0
		storedValue = nil
		return self
	}
}


// MARK: - AsyncMuxCacher

public typealias MuxKey = LosslessStringConvertible & Hashable

public class AsyncMuxCacher<T: Codable> {
	func load(key: String) -> T? { preconditionFailure() }
	func save(_ result: T, key: String) { preconditionFailure() }
	func delete(key: String) { preconditionFailure() }
	func deleteDomain() { preconditionFailure() }
}


// MARK: - MuxRepositoryProtocol

@MainActor
public protocol MuxRepositoryProtocol: AnyObject {
	@discardableResult
	func save() -> Self // store memory cache on disk

	@discardableResult
	func clearMemory() -> Self // free some memory; note that this will force a multiplexer to make a new fetch request next time

	@discardableResult
	func clear() -> Self // clear all memory and disk caches

	var cacheKey: String { get }
	var timeToLive: TimeInterval { get set }
}


// MARK: - AsyncMux

@MainActor
open class AsyncMux<T: Codable>: AsyncMuxFetcher<T>, MuxRepositoryProtocol {

	public var timeToLive: TimeInterval = MuxDefaultTTL
	public let cacheKey: String

	private let cacher: AsyncMuxCacher<T>?
	private let onFetch: () async throws -> T

	public convenience init(cacheKey: String? = nil, onFetch: @escaping () async throws -> T) {
		self.init(cacheKey: cacheKey, cacher: JSONDiskCacher<T>(domain: nil), onFetch: onFetch)
	}

	public init(cacheKey: String? = nil, cacher: AsyncMuxCacher<T>?, onFetch: @escaping () async throws -> T) {
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
		cacher?.delete(key: cacheKey)
		return clearMemory()
	}

	@discardableResult
	public func save() -> Self {
		if isDirty, let storedValue = storedValue {
			cacher?.save(storedValue, key: cacheKey)
			isDirty = false
		}
		return self
	}

	open func useCachedResultOn(error: Error) -> Bool {
		error.isConnectivityError
	}
}


// MARK: - AsyncMuxMap

@MainActor
open class AsyncMuxMap<K: MuxKey, T: Codable>: MuxRepositoryProtocol {

	public var timeToLive: TimeInterval = MuxDefaultTTL
	public let cacheKey: String

	private let cacher: AsyncMuxCacher<T>?
	private let onKeyFetch: (K) async throws -> T
	private var fetcherMap: [String: AsyncMuxFetcher<T>] = [:]

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


	open class func useCachedResultOn(error: Error) -> Bool {
		error.isConnectivityError
	}


	private func fetcherForKey(_ key: K) -> AsyncMuxFetcher<T> {
		var fetcher = fetcherMap[String(key)]
		if fetcher == nil {
			fetcher = AsyncMuxFetcher<T>()
			fetcherMap[String(key)] = fetcher
		}
		return fetcher!
	}
}


// MARK: - MuxRepository

@MainActor
public class MuxRepository {

	private static var repo: [String: MuxRepositoryProtocol] = [:]

	public static func clearAll() {
		repo.values.forEach { $0.clear() }
	}

	public static func saveAll() {
		repo.values.forEach { $0.save() }
	}

	public static func clearMemory() {
		repo.values.forEach { $0.clearMemory() }
	}

	static func register(mux: MuxRepositoryProtocol) {
		let id = mux.cacheKey
		precondition(repo[id] == nil, "MuxRepository: duplicate registration (Cache key: \(id))")
		repo[id] = mux
	}

	static func unregister(mux: MuxRepositoryProtocol) {
		repo.removeValue(forKey: mux.cacheKey)
	}
}


public extension MuxRepositoryProtocol {

	@discardableResult
	func register() -> Self {
		MuxRepository.register(mux: self)
		return self
	}

	func unregister() {
		MuxRepository.unregister(mux: self)
	}

	@discardableResult
	func setTimeToLive(_ ttl: TimeInterval) -> Self {
		timeToLive = ttl
		return self
	}
}


// MARK: - JSONDiskCacher

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
		guard domain != nil else {
			preconditionFailure()
		}
		try? FileManager.default.removeItem(at: cacheDirURL(create: false))
	}

	private func cacheFileURL(key: String, create: Bool) -> URL {
		return cacheDirURL(create: create).appendingPathComponent(key.description).appendingPathExtension("json")
	}

	private func cacheDirURL(create: Bool) -> URL {
		let dir = "AsyncMux/" + (domain ?? "")
		return FileManager.cachesDirectory(subDirectory: dir, create: create)
	}
}


// MARK: - Misc.

public extension Error {

	var isConnectivityError: Bool {
		if (self as NSError).domain == NSURLErrorDomain {
			return [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost].contains((self as NSError).code)
		}
		return false
	}
}


public extension FileManager {

	static func cachesDirectory(subDirectory: String, create: Bool = false) -> URL {
		standardDirectory(.cachesDirectory, subDirectory: subDirectory, create: create)
	}

	static func documentDirectory(subDirectory: String, create: Bool = false) -> URL {
		standardDirectory(.documentDirectory, subDirectory: subDirectory, create: create)
	}

	static func libraryDirectory(subDirectory: String, create: Bool = false) -> URL {
		standardDirectory(.libraryDirectory, subDirectory: subDirectory, create: create)
	}

	private static func standardDirectory(_ type: SearchPathDirectory, subDirectory: String, create: Bool = false) -> URL {
		let result = `default`.urls(for: type, in: .userDomainMask).first!.appendingPathComponent(subDirectory)
		if create && !`default`.fileExists(atPath: result.path) {
			try! `default`.createDirectory(at: result, withIntermediateDirectories: true, attributes: nil)
		}
		return result
	}
}
