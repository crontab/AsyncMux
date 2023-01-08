//
//  AsyncMux.swift
//
//  Created by Hovik Melikyan on 08/01/2023.
//

import Foundation


public var MuxDefaultTTL: TimeInterval = 30 * 60


// MARK: - AsyncMuxFetcher

open class AsyncMuxFetcher<T: Codable> {

	public fileprivate(set) var storedValue: T?

	fileprivate var completionTime: TimeInterval = 0
	fileprivate var task: Task<T, Error>?
	fileprivate var isDirty: Bool = false
	fileprivate var refreshFlag: Bool = false

	fileprivate func isExpired(ttl: TimeInterval) -> Bool {
		Date().timeIntervalSinceReferenceDate > completionTime + ttl
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

public class AsyncMuxCacher<K: MuxKey, T: Codable> {
	func load(key: K) -> T? { preconditionFailure() }
	func save(_ result: T, key: K) { preconditionFailure() }
	func delete(key: K) { preconditionFailure() }
	func deleteDomain() { preconditionFailure() }
}


// MARK: - MuxRepositoryProtocol

public protocol MuxRepositoryProtocol: AnyObject {
	@discardableResult
	func save() -> Self // store memory cache on disk

	@discardableResult
	func clearMemory() -> Self // free some memory; note that this will force a multiplexer to make a new fetch request next time

	@discardableResult
	func clear() -> Self // clear all memory and disk caches

	var cacheKey: String { get }
}


// MARK: - AsyncMux

open class AsyncMux<T: Codable>: AsyncMuxFetcher<T>, MuxRepositoryProtocol {

	public var timeToLive: TimeInterval = MuxDefaultTTL
	public let cacheKey: String

	private let cacher: AsyncMuxCacher<String, T>?
	private let onFetch: () async throws -> T


	public convenience init(cacheKey: String? = nil, onFetch: @escaping () async throws -> T) {
		self.init(cacheKey: cacheKey, cacher: JSONDiskCacher<String, T>(domain: nil), onFetch: onFetch)
	}


	public init(cacheKey: String? = nil, cacher: AsyncMuxCacher<String, T>?, onFetch: @escaping () async throws -> T) {
		self.cacheKey = cacheKey ?? String(describing: T.self)
		self.cacher = cacher
		self.onFetch = onFetch
	}


	public func request() async throws -> T {
		if !refreshFlag, let storedValue = storedValue, !isExpired(ttl: timeToLive) {
			return storedValue
		}

		refreshFlag = false

		if task == nil {
			task = Task {
				do {
					return try await onFetch()
				}
				catch {
					if error.isConnectivityError, let cachedValue = storedValue ?? cacher?.load(key: cacheKey) {
						return cachedValue
					}
					else {
						throw error
					}
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


	@discardableResult
	public func setTimeToLive(_ ttl: TimeInterval) -> Self {
		timeToLive = ttl
		return self
	}


	@discardableResult
	public func register() -> Self {
		MuxRepository.register(mux: self)
		return self
	}


	public func unregister() {
		MuxRepository.unregister(mux: self)
	}


	open func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }
}


// MARK: - MuxRepository

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

	fileprivate static func register(mux: MuxRepositoryProtocol) {
		let id = mux.cacheKey
		precondition(repo[id] == nil, "MuxRepository: duplicate registration (Cache key: \(id))")
		repo[id] = mux
	}

	fileprivate static func unregister(mux: MuxRepositoryProtocol) {
		repo.removeValue(forKey: mux.cacheKey)
	}
}


// MARK: - JSONDiskCacher

public final class JSONDiskCacher<K: MuxKey, T: Codable>: AsyncMuxCacher<K, T> {

	private let domain: String?

	public required init(domain: String?) {
		self.domain = domain
	}

	public override func load(key: K) -> T? {
		return try? JSONDecoder().decode(T.self, from: Data(contentsOf: cacheFileURL(key: key, create: false)))
	}

	public override func save(_ result: T, key: K) {
		try! JSONEncoder().encode(result).write(to: cacheFileURL(key: key, create: true), options: .atomic)
	}

	public override func delete(key: K) {
		try? FileManager.default.removeItem(at: cacheFileURL(key: key, create: false))
	}

	public override func deleteDomain() {
		guard domain != nil else {
			preconditionFailure()
		}
		try? FileManager.default.removeItem(at: cacheDirURL(create: false))
	}

	private func cacheFileURL(key: K, create: Bool) -> URL {
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
