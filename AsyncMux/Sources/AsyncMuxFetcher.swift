//
//  AsyncMuxFetcher.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 09/01/2023.
//  Copyright © 2023 Hovik Melikyan. All rights reserved.
//

import Foundation


public var MuxDefaultTTL: TimeInterval = 30 * 60


@MainActor
open class _AsyncMuxFetcher<T: Codable> {

	public private(set) var storedValue: T?

	internal var isDirty: Bool = false
	internal var refreshFlag: Bool = false

	private var task: Task<T, Error>?
	private var completionTime: TimeInterval = 0

	func request(ttl: TimeInterval, cacher: some AsyncMuxCacher<T>, key: String, onFetch: @escaping () async throws -> T) async throws -> T {
		if !refreshFlag, !isExpired(ttl: ttl) {
			if let storedValue {
				return storedValue
			}
			else if let cachedValue = cacher.load(key: key) {
				storedValue = cachedValue
				return cachedValue
			}
		}

		refreshFlag = false

		if task == nil {
			task = Task {
				do {
					return try await onFetch()
				}
				catch {
					if error.isSilencable, let cachedValue = storedValue ?? cacher.load(key: key) {
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

	@discardableResult
	public func clearMemory() -> Self {
		completionTime = 0
		storedValue = nil
		return self
	}
}
