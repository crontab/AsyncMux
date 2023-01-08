//
//  MuxRepository.swift
//
//  Created by Hovik Melikyan on 09/01/2023.
//

import Foundation


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
