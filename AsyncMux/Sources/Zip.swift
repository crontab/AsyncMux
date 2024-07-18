//
//  Zip.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 06.07.24.
//

import Foundation


// This is an experimental module not yet documented.


/// `Zip<T>` allows to combine two or more parallel asynchronous actions into one and receive the results from all of them at once, when they become available. The result of the execution is returned as an array of T.
public struct Zip<T: Sendable>: Sendable {

    public typealias Action = @Sendable () async throws -> T

    private var actions: [Action]

    public init(actions: [Action] = []) {
        self.actions = actions
    }

    /// Adds an asynchronous action to be executed in parallel with others. The action is not executed until `result` is called on this Zip object.
    public mutating func add(_ action: @escaping Action) {
        actions.append(action)
    }

    /// Simultaneously executes the actions added earlier using `add()` and returns the result as an array of T when all results become available.
    public var result: [T] {
        get async throws {
            guard !actions.isEmpty else {
                return []
            }
            return try await withThrowingTaskGroup(of: T.self) { group in
                for action in actions {
                    group.addTask(operation: action)
                }
                var results: [T] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }
        }
    }
}

/// Executes asynchronous actions `a` and `b` and returns their results as a tuple (A, B) when both become available.
public func zip<A, B>(
    _ a: @Sendable () async throws -> A,
    _ b: @Sendable () async throws -> B) async throws -> (A, B) {
        async let a = try await a()
        async let b = try await b()
        return try await (a, b)
    }


/// Executes asynchronous actions `a`, `b` and `c` and returns their results as a tuple (A, B, C) when all of them become available.
public func zip<A, B, C>(
    _ a: @Sendable () async throws -> A,
    _ b: @Sendable () async throws -> B,
    _ c: @Sendable () async throws -> C) async throws -> (A, B, C) {
        async let a = try await a()
        async let b = try await b()
        async let c = try await c()
        return try await (a, b, c)
    }


/// Executes asynchronous actions `a`, `b`, `c`, and `d` and returns their results as a tuple (A, B, C, D) when all of them become available.
public func zip<A, B, C, D>(
    _ a: @Sendable () async throws -> A,
    _ b: @Sendable () async throws -> B,
    _ c: @Sendable () async throws -> C,
    _ d: @Sendable () async throws -> D) async throws -> (A, B, C, D) {
        async let a = try await a()
        async let b = try await b()
        async let c = try await c()
        async let d = try await d()
        return try await (a, b, c, d)
    }


/// Executes asynchronous actions `a`, `b`, `c`, `d`, and `e` and returns their results as a tuple (A, B, C, D, E) when all of them become available.
public func zip<A, B, C, D, E>(
    _ a: @Sendable () async throws -> A,
    _ b: @Sendable () async throws -> B,
    _ c: @Sendable () async throws -> C,
    _ d: @Sendable () async throws -> D,
    _ e: @Sendable () async throws -> E) async throws -> (A, B, C, D, E) {
        async let a = try await a()
        async let b = try await b()
        async let c = try await c()
        async let d = try await d()
        async let e = try await e()
        return try await (a, b, c, d, e)
    }
