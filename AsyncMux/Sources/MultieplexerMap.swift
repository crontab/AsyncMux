//
//  MultieplexerMap.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 02.07.24.
//  Copyright © 2023 Hovik Melikyan. All rights reserved.
//

import Foundation


public typealias MuxKey = LosslessStringConvertible & Hashable & Sendable


// MARK: - MultieplexerMap

///
/// `MultiplexerMap<K, T>` is similar to `Multiplexer<T>` in many ways except it maintains a dictionary of objects of the same type. One example would be e.g. user profile objects in your social app.
/// The `K` generic paramter should conform to  `LosslessStringConvertible & Hashable & Sendable`. The string convertibility requirement is because it simplifies the disk cacher's job of storing objects on disk or a database.
/// See README.md for a more detailed discussion.
///
@MuxActor
public final class MultiplexerMap<K: MuxKey, T: Codable & Sendable>: MuxRepositoryProtocol {

    public typealias OnFetch = @Sendable (K) async throws -> T

    public let cacheKey: String

    /// Instantiates a `MultiplexerMap<T>` object with a given `onFetch` block.
    /// - parameter cacheKey (optional): a string to be used as a file name for the disk cache. If omitted, an automatic name is generated based on `T`'s description. NOTE: if you have several  multiplexers whose `T` is the same, you *should* define unique non-conflicting `cacheKey` parameters for each.
    /// - parameter onFetch: an async throwing block that should retrieve an object by a given key presumably in an asynchronous manner.
    nonisolated
    public init(cacheKey: String? = nil, onFetch: @escaping OnFetch) {
        self.cacheKey = cacheKey ?? String(describing: T.self)
        self.onFetch = onFetch
    }

    /// Performs a request either by calling the `onFetch` block supplied in the multiplexer's constructor, or by returning the previously cached object, if available. Multiple simultaneous calls to `request(key:)` are handled by the MultiplexerMap so that only one `onFetch` operation is invoked at a time for any given `key`, but all callers of `request(key:)` will eventually receive the result.
    public func request(key: K) async throws -> T {
        let mux = muxMap[key] ?? {
            let onFetch = onFetch // avoid capture of `self`
            let mux = Multiplexer {
                try await onFetch(key)
            }
            muxMap[key] = mux
            return mux
        }()
        return try await mux.request(domain: cacheKey, key: key)
    }

    /// "Soft" refresh: the next call to `request(key:)` will attempt to retrieve the object again, without discarding the caches in case of a failure. `refresh(key:)` does not have an immediate effect on any ongoing asynchronous requests. Can be chained with the subsequent `request(key:)`.
    @discardableResult
    public func refresh(_ flag: Bool = true, key: K) -> Self {
        if flag {
            muxMap[key]?.refreshFlag = true
        }
        return self
    }

    /// "Soft" refresh for all objects stored in this `MultiplexerMap`: the next call to `request(key:)` with any key will attempt to retrieve the object again, without discarding the caches in case of a failure. `refresh()` does not have an immediate effect on any ongoing asynchronous requests. Can be chained with the subsequent `request(key:)`.
    @discardableResult
    public func refresh(_ flag: Bool = true) -> Self {
        if flag {
            muxMap.values.forEach {
                $0.refreshFlag = true
            }
        }
        return self
    }

    /// Writes all previously cached objects in this `MultiplexerMap` to disk.
    public func save() {
        muxMap.forEach { key, mux in
            if mux.isDirty, let storedValue = mux.storedValue {
                MuxCacher.save(storedValue, domain: cacheKey, key: String(key))
                mux.isDirty = false
            }
        }
    }

    public func clearMemory(key: K) {
        muxMap.removeValue(forKey: key)
    }

    public func clearMemory() {
        muxMap = [:]
    }

    /// Clears the memory and disk caches for an object with a given `key`. Will trigger a full fetch on the next `request(key:)` call.
    public func clear(key: K) {
        MuxCacher.delete(domain: cacheKey, key: String(key))
        clearMemory(key: key)
    }

    /// Clears the memory and disk caches all objects in this `MultiplexerMap`. Will trigger a full fetch on the next `request(key:)` call.
    public func clear() {
        MuxCacher.deleteDomain(cacheKey)
        clearMemory()
    }


    // Private part

    private let onFetch: OnFetch
    private var muxMap: [K: Multiplexer<T>] = [:]
}
