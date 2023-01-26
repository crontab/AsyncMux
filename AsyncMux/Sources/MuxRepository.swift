//
//  MuxRepository.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 09/01/2023.
//  Copyright © 2023 Hovik Melikyan. All rights reserved.
//

import Foundation


public protocol MuxRepositoryProtocol: Sendable {
	func save() async
	func clearMemory() async
	func clear() async
	var cacheDomain: String { get }
}


@globalActor
public actor MuxRepository {

	public static let shared = MuxRepository()

	private var repo: [String: MuxRepositoryProtocol] = [:]

	public func clearAll() async {
		for mux in repo.values {
			await mux.clear()
		}
	}

	public func saveAll() async {
		for mux in repo.values {
			await mux.save()
		}
	}

	public func clearMemory() async {
		for mux in repo.values {
			await mux.clearMemory()
		}
	}

	func register(mux: MuxRepositoryProtocol) {
		let id = mux.cacheDomain
		precondition(repo[id] == nil, "MuxRepository: duplicate registration (Cache key: \(id))")
		repo[id] = mux
	}

	func unregister(mux: MuxRepositoryProtocol) {
		repo.removeValue(forKey: mux.cacheDomain)
	}
}


public extension MuxRepositoryProtocol {

	@discardableResult
	func register() -> Self {
		Task {
			await MuxRepository.shared.register(mux: self)
		}
		return self
	}

	func unregister() {
		Task {
			await MuxRepository.shared.unregister(mux: self)
		}
	}
}
