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


// MARK: - AsyncMux

open class AsyncMux<T: Codable>: AsyncMuxFetcher<T> {

	public var timeToLive: TimeInterval = MuxDefaultTTL

	private let onFetch: () async throws -> T
	private let cacheID: String


	init(cacheID: String? = nil, onFetch: @escaping () async throws -> T) {
		self.cacheID = cacheID ?? String(describing: T.self)
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
					if error.isConnectivityError, let cachedValue = storedValue {
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


	open func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }
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
