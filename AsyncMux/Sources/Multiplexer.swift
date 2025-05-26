//
//  Multiplexer.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 26/01/2023.
//

import Foundation


private let DefaultTTL: TimeInterval = 30 * 60
private let MuxRootDomain = "_Root.Domain"

@globalActor
public actor MuxActor {
    public static var shared = MuxActor()
}


// MARK: - Multiplexer

///
/// `Multiplexer<T>` is an asynchronous caching facility for client apps. Each multiplxer instance can manage retrieval and caching of one object of type `T: Codable & Sendable`, therefore it is best to define each multiplexer instance in your app as a singleton.
/// For each multiplexer singleton you define a block that implements asynchronous retrieval of the object, which in your app will likely be a network request, e.g. to your backend system.
/// See README.md for a more detailed discussion.
///
@MuxActor
public final class Multiplexer<T: Codable & Sendable>: MuxRepositoryProtocol {

    public typealias OnFetch = @Sendable () async throws -> T

    /// Instantiates a `Multiplexer<T>` object with a given `onFetch` block.
    /// - parameter cacheKey (optional): a string to be used as a file name for the disk cache. If specified, this multiplexer also registers itself in the global repository.
    /// - parameter onFetch: an async throwing block that should retrieve an object presumably in an asynchronous manner.
    nonisolated
    public init(cacheKey: String? = nil, onFetch: @escaping OnFetch) {
        self.cacheKey = cacheKey
        self.onFetch = onFetch
        if let cacheKey {
            MuxRepository.register(key: cacheKey, mux: self)
        }
    }

    deinit {
        if let cacheKey {
            MuxRepository.unregister(key: cacheKey)
        }
    }

    /// Performs a request either by calling the `onFetch` block supplied in the multiplexer's constructor, or by returning the previously cached object, if available. Multiple simultaneous calls to `request()` are handled by the Multiplexer so that only one `onFetch` operation can be invoked at a time, but all callers of `request()` will eventually receive the result.
    public func request() async throws -> T {
        return try await request(domain: MuxRootDomain, key: cacheKey)
    }

    /// "Soft" refresh: the next call to `request()` will attempt to retrieve the object again, without discarding the caches in case of a failure. `refresh()` does not have an immediate effect on any ongoing asynchronous requests. Can be chained with the subsequent `request()`.
    @discardableResult
    public func refresh(_ flag: Bool = true) -> Self {
        if flag {
            clearMemory()
        }
        return self
    }

    /// Writes the previously cached object to disk.
    public func save() {
        if isDirty, let storedValue {
            if let cacheKey {
                MuxCacher.save(storedValue, domain: MuxRootDomain, key: cacheKey)
            }
            isDirty = false
        }
    }

    public func clearMemory() {
        completionTime = 0
        storedValue = nil
    }

    /// Clears the memory and disk caches. Will trigger a full fetch on the next `request()` call.
    public func clear() {
        if let cacheKey {
            MuxCacher.delete(domain: MuxRootDomain, key: cacheKey)
        }
        clearMemory()
    }

    /// Overrides the value stored in memory if a given value is newer than the one stored, or if the cache is empty.
    public func store(value: T) {
        let newTime = Date().timeIntervalSinceReferenceDate
        if newTime >= completionTime {
            storedValue = value
            completionTime = newTime
            isDirty = true
        }
    }

    /// Returns the value currently stored in memory or on disk, ignoring the TTL
    public var cachedValue: T? {
        storedValue ?? cacheKey.flatMap {
            storedValue = MuxCacher.load(domain: MuxRootDomain, key: $0, type: T.self)
            return storedValue
        }
    }


    // Private part

    internal private(set) var storedValue: T? // exposed for MultiplexerMap
    private let cacheKey: String?
    private let onFetch: OnFetch

    internal var isDirty: Bool = false

    private var task: Task<T, Error>?
    private var completionTime: TimeInterval = 0

    internal func request(domain: String?, key: LosslessStringConvertible?) async throws -> T {
        if !isExpired {
            if let storedValue {
                return storedValue
            }
            else if let key, let domain, let cachedValue = MuxCacher.load(domain: domain, key: key, type: T.self) {
                storedValue = cachedValue
                return cachedValue
            }
        }

        if task == nil {
            task = Task {
                do {
                    return try await onFetch()
                }
                catch {
                    if error.isSilencable {
                        if let storedValue {
                            return storedValue
                        }
                        else if let key, let domain, let cachedValue = MuxCacher.load(domain: domain, key: key, type: T.self) {
                            storedValue = cachedValue
                            return cachedValue
                        }
                    }
                    throw error
                }
            }
        }

        do {
            let result = try await task!.value
            task = nil
            store(value: result)
            return result
        }
        catch {
            task = nil
            storedValue = nil
            completionTime = 0
            throw error
        }
    }

    internal var isExpired: Bool {
        Date().timeIntervalSinceReferenceDate > completionTime + DefaultTTL
    }
}
