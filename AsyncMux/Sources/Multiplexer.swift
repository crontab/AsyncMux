//
//  Multiplexer.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 26/01/2023.
//  Copyright © 2023 Hovik Melikyan. All rights reserved.
//

import Foundation


private let defaultTTL: TimeInterval = 30 * 60
private let muxRootDomain = "_Root.Domain"

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

    public let cacheKey: String?

    /// Instantiates a `Multiplexer<T>` object with a given `onFetch` block.
    /// - parameter cacheKey (optional): a string to be used as a file name for the disk cache. If omitted, an automatic name is generated based on `T`'s description. NOTE: if you have several  multiplexers whose `T` is the same, you *should* define unique non-conflicting `cacheKey` parameters for each.
    /// - parameter onFetch: an async throwing block that should retrieve an object presumably in an asynchronous manner.
    nonisolated
    public init(cacheKey: String? = nil, onFetch: @escaping OnFetch) {
        self.cacheKey = cacheKey
        self.onFetch = onFetch
    }

    /// Performs a request either by calling the `onFetch` block supplied in the multiplexer's constructor, or by returning the previously cached object, if available. Multiple simultaneous calls to `request()` are handled by the Multiplexer so that only one `onFetch` operation can be invoked at a time, but all callers of `request()` will eventually receive the result.
    public func request() async throws -> T {
        return try await request(domain: muxRootDomain, key: cacheKey)
    }

    /// "Soft" refresh: the next call to `request()` will attempt to retrieve the object again, without discarding the caches in case of a failure. `refresh()` does not have an immediate effect on any ongoing asynchronous requests. Can be chained with the subsequent `request()`.
    @discardableResult
    public func refresh(_ flag: Bool = true) -> Self {
        if flag {
            refreshFlag = true
        }
        return self
    }

    /// Writes the previously cached object to disk.
    public func save() {
        if isDirty, let storedValue {
            if let cacheKey {
                MuxCacher.save(storedValue, domain: muxRootDomain, key: cacheKey)
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
            MuxCacher.delete(domain: muxRootDomain, key: cacheKey)
        }
        clearMemory()
    }


    // Private part

    private let onFetch: OnFetch

    internal var storedValue: T?
    internal var isDirty: Bool = false
    internal var refreshFlag: Bool = false

    private var task: Task<T, Error>?
    private var completionTime: TimeInterval = 0

    internal func request(domain: String?, key: LosslessStringConvertible?) async throws -> T {
        if !refreshFlag, !isExpired {
            if let storedValue {
                return storedValue
            }
            else if let key, let domain, let cachedValue = MuxCacher.load(domain: domain, key: key, type: T.self) {
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

    private var isExpired: Bool {
        Date().timeIntervalSinceReferenceDate > completionTime + defaultTTL
    }
}
