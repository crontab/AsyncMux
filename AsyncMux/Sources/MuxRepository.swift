//
//  MuxRepository.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 09/01/2023.
//

import Foundation


public protocol MuxRepositoryProtocol: Sendable {
    func save() async
    func clearMemory() async
    func clear() async
    var cacheKey: String? { get }
}


/// Global repository of multiplexers. Multiplexer singletons can be registered here to be included in `clearAll()` and `saveAll()` operations.
@globalActor
public actor MuxRepository {

    public static let shared = MuxRepository()

    /// Clears caches for all registered Multiplexer objects. Useful when e.g. the user signs out of the app and there should be no traces left of the previously retrieved backend objects.
    public func clearAll() async {
        for mux in repo.values {
            await mux.clear()
        }
    }

    /// Writes all memory-cached objects to disk for each of the registered multiplexer objects. The default implementation of `Multiplexer<T>` uses simple file-based JSON caching.
    public func saveAll() async {
        for mux in repo.values {
            await mux.save()
        }
    }

    /// Free all memory-cached objects. This will force all registered multiplexer objects make a new fetch on the next call to `request()`. This method can be called on memory warnings coming from the OS.
    public func clearMemory() async {
        for mux in repo.values {
            await mux.clearMemory()
        }
    }

    func register(mux: MuxRepositoryProtocol) {
        guard let key = mux.cacheKey else {
            preconditionFailure("MuxRepository: cacheKey is required for \(String(describing: mux))")
        }
        precondition(repo[key] == nil, "MuxRepository: duplicate registration (Cache key: \(key))")
        repo[key] = mux
    }

    func unregister(mux: MuxRepositoryProtocol) {
        guard let key = mux.cacheKey else {
            preconditionFailure("MuxRepository: cacheKey is required for \(String(describing: mux))")
        }
        repo.removeValue(forKey: key)
    }

    private var repo: [String: MuxRepositoryProtocol] = [:]

    private init() { }
}


public extension MuxRepositoryProtocol {

    /// Register a `Multiplexer` object with the global repository for subsequent use in `clearAll()` and `saveAll()` operations. Note that `MuxRepository` retains the object, which means that for non-singleton multiplexer objects `unregister()` should be called prior to freeing it.
    @discardableResult
    func register() -> Self {
        Task {
            await MuxRepository.shared.register(mux: self)
        }
        return self
    }

    /// Unregister a `Multiplexer` object from the global repository `MuxRepository`. Not required for singleton multiplexers.
    func unregister() {
        Task {
            await MuxRepository.shared.unregister(mux: self)
        }
    }
}
