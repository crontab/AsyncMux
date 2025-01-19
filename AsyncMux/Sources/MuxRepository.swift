//
//  MuxRepository.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 09/01/2023.
//

import Foundation


@MuxActor
public protocol MuxRepositoryProtocol: AnyObject, Sendable {
    func save()
    func clearMemory()
    func clear()
}


/// Global repository of multiplexers. Multiplexer singletons can be registered here to be included in `clearAll()`, `clearMemory() and` `saveAll()` operations. Multiplexer objects are registered automatically by specifying the `cacheKey` parameter in their constructor.
@MuxActor
public final class MuxRepository {

    /// Clears caches for all registered Multiplexer objects. Useful when e.g. the user signs out of the app and there should be no traces left of the previously retrieved backend objects.
    public static func clearAll() {
        for mux in repo.values {
            mux.value?.clear()
        }
    }

    /// Writes all memory-cached objects to disk for each of the registered multiplexer objects. The default implementation of `Multiplexer<T>` uses simple file-based JSON caching.
    public static func saveAll() {
        for mux in repo.values {
            mux.value?.save()
        }
    }

    /// Free all memory-cached objects. This will force all registered multiplexer objects make a new fetch on the next call to `request()`. This method can be called on memory warnings coming from the OS.
    public static func clearMemory() {
        for mux in repo.values {
            mux.value?.clearMemory()
        }
    }

    // Internal and private methods

    nonisolated
    static func register(key: String, mux: MuxRepositoryProtocol) {
        Task { @MuxActor in
            precondition(repo[key] == nil, "MuxRepository: duplicate registration (cache key: \(key))")
            repo[key] = WeakMux(value: mux)
        }
    }

    nonisolated
    static func unregister(key: String) {
        Task { @MuxActor in
            repo.removeValue(forKey: key)
        }
    }

    private struct WeakMux {
        weak var value: MuxRepositoryProtocol?
    }

    private static var repo: [String: WeakMux] = [:]

    private init() { }
}
