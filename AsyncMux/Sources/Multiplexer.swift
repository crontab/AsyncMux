//
//  Multiplexer.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 26/01/2023.
//

import Foundation


public typealias MuxKey = LosslessStringConvertible & Hashable & Sendable

private let defaultTTL: TimeInterval = 30 * 60
private let muxRootDomain = "_Root.Domain"


// MARK: - Multiplexer

///
/// `Multiplexer<T>` is an asynchronous caching facility for client apps. Each multiplxer instance can manage retrieval and caching of one object of type `T: Codable & Sendable`, therefore it is best to define each multiplexer instance in your app as a singleton.
/// For each multiplexer singleton you define a block that implements asynchronous retrieval of the object, which in your app will likely be a network request, e.g. to your backend system.
/// See README.md for a more detailed discussion.
///
public actor Multiplexer<T: Codable & Sendable>: MuxRepositoryProtocol {

    public typealias OnFetch = @Sendable () async throws -> T

    public let cacheKey: String

    /// Instantiates a `Multiplexer<T>` object with a given `onFetch` block.
    /// - parameter cacheKey (optional): a string to be used as a file name for the disk cache. If omitted, an automatic name is generated based on `T`'s description. NOTE: if you have several  multiplexers whose `T` is the same, you *should* define unique non-conflicting `cacheKey` parameters for each.
    /// - parameter onFetch: an async throwing block that should retrieve an object presumably in an asynchronous manner.
    public init(cacheKey: String? = nil, onFetch: @escaping OnFetch) {
        self.cacheKey = cacheKey ?? String(describing: T.self)
        self.onFetch = onFetch
    }

    /// Performs a request either by calling the `onFetch` block supplied in the multiplexer's constructor, or by returning the previously cached object, if available. Multiple simultaneous calls to `request()` are handled by the Multiplexer so that only one `onFetch` operation can be invoked at a time, but all callers of `request()` will eventually receive the result.
    public func request() async throws -> T {
        return try await fetcher.request(domain: muxRootDomain, key: cacheKey) { [self] in
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
            MuxCacher.save(storedValue, domain: muxRootDomain, key: cacheKey)
            fetcher.isDirty = false
        }
    }

    public func clearMemory() {
        fetcher.clearMemory()
    }

    /// Clears the memory and disk caches. Will trigger a full fetch on the next `request()` call.
    public func clear() {
        MuxCacher.delete(domain: muxRootDomain, key: cacheKey)
        clearMemory()
    }

    private let onFetch: OnFetch
    private let fetcher = _MuxFetcher<String, T>()
}


// MARK: - _MuxFetcher (internal)

final private class _MuxFetcher<K: MuxKey, T: Codable & Sendable> {

    typealias OnFetch = @Sendable () async throws -> T

    var storedValue: T?
    var isDirty: Bool = false
    var refreshFlag: Bool = false

    private var task: Task<T, Error>?
    private var completionTime: TimeInterval = 0

    func request(domain: String, key: K, onFetch: @escaping OnFetch) async throws -> T {
        if !refreshFlag, !isExpired {
            if let storedValue {
                return storedValue
            }
            else if let cachedValue = MuxCacher.load(domain: domain, key: String(key), type: T.self) {
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
                    if error.isSilencable, let cachedValue = storedValue ?? MuxCacher.load(domain: domain, key: String(key), type: T.self) {
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

    func clearMemory() {
        completionTime = 0
        storedValue = nil
    }

    private var isExpired: Bool {
        Date().timeIntervalSinceReferenceDate > completionTime + defaultTTL
    }
}
