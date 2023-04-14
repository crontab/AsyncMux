//
//  MuxCacher.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 09/01/2023.
//  Copyright © 2023 Hovik Melikyan. All rights reserved.
//

import Foundation


public class MuxCacher {

    public static func load<T: Decodable>(domain: String, key: String, type: T.Type) -> T? {
        return try? JSONDecoder().decode(type, from: Data(contentsOf: cacheFileURL(domain: domain, key: key, create: false)))
    }

    public static func save<T: Encodable>(_ result: T, domain: String, key: String) {
        try! JSONEncoder().encode(result).write(to: cacheFileURL(domain: domain, key: key, create: true), options: .atomic)
    }

    public static func delete(domain: String, key: String) {
        try? FileManager.default.removeItem(at: cacheFileURL(domain: domain, key: key, create: false))
    }

    public static func deleteDomain(_ domain: String) {
        try? FileManager.default.removeItem(at: cacheDirURL(domain: domain, create: false))
    }

    private static func cacheFileURL(domain: String, key: String, create: Bool) -> URL {
        return cacheDirURL(domain: domain, create: create).appendingPathComponent(key).appendingPathExtension("json")
    }

    private static func cacheDirURL(domain: String, create: Bool) -> URL {
        let dir = "AsyncMux/" + domain
        return FileManager.default.cachesDirectory(subDirectory: dir, create: create)
    }
}
