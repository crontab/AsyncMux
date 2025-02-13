//
//  MultiRequester.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 13.02.25.
//

import Foundation


/// [EXPERIMENTAL]
/// If your backend supports multiple-ID requests ( e.g.`/profiles/[id1,id2]`), then MultiRequester can be used in tandem with an existing MultiplexerMap object to combine single and multi-requests into the same caching infrastructure. Multi-ID requests made via MultiRequester's `request(...)` method can update the map linked to it and also reuse the cached values stored by the map. Thus, objects will be cached locally regardless of whether they were requested via singular endpoints or multi-ID ones; and on the other hand, multi-ID requests can save bandwidth by reusing some of the objects already cached and requesting fewer ID's (or even none) from the backend.

@MuxActor
public class MultiRequester<K: MuxKey, T: Codable & Sendable & Identifiable> where T.ID == K {

    public typealias OnMultiFetch = @Sendable ([K]) async throws -> [T]

    nonisolated
    public init(map: MultiplexerMap<K, T>, onFetch: @escaping OnMultiFetch) {
        self.map = map
        self.onFetch = onFetch
    }

    /// This method attempts to retrieve objects associated with the set of keys [K]. The number of the results is not guaranteed to be the same as the number of keys, neither is the order guaranteed to be the same.
    public func request(keys: [K]) async throws -> [K: T] {
        var values: [K: T] = [:]

        // See if there are any good non-expired cached values in the map object; at the same time, build the set of keys to be used in a call to the user's fetcher function. (Too much packed into a single expression?)
        let remainingKeys = keys.filter { key in
            map.storedValue(for: key).map { value -> T? in
                values[key] = value
                return value
            } == nil
        }

        // Nothing to request?
        if remainingKeys.isEmpty {
            return values
        }

        // Attempt to fetch the remaining values and combine the results with the previously cached ones
        try await onFetch(remainingKeys).forEach { value in
            values[value.id] = value
            map.store(value: value, for: value.id)
        }

        return values
    }

    // Private part

    private let map: MultiplexerMap<K, T>
    private let onFetch: OnMultiFetch
}
