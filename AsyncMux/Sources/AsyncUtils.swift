//
//  AsyncUtils.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 09/01/2023.
//

import Foundation


public extension FileManager {

    func cachesDirectory(subDirectory: String, create: Bool = false) -> URL {
        standardDirectory(.cachesDirectory, subDirectory: subDirectory, create: create)
    }

    func documentDirectory(subDirectory: String, create: Bool = false) -> URL {
        standardDirectory(.documentDirectory, subDirectory: subDirectory, create: create)
    }

    func libraryDirectory(subDirectory: String, create: Bool = false) -> URL {
        standardDirectory(.libraryDirectory, subDirectory: subDirectory, create: create)
    }

    private func standardDirectory(_ type: SearchPathDirectory, subDirectory: String, create: Bool = false) -> URL {
        let result = urls(for: type, in: .userDomainMask).first!.appendingPathComponent(subDirectory)
        if create && !fileExists(atPath: result.path) {
            try! createDirectory(at: result, withIntermediateDirectories: true, attributes: nil)
        }
        return result
    }

    func fileExists(_ url: URL) -> Bool {
        url.isFileURL && fileExists(atPath: url.path)
    }
}


public extension URL {
    func toFileSystemSafeString() -> String {
        absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
    }
}


@inlinable
public func DLOG(_ s: String) {
    debugOnly {
        print(s)
    }
}


@inlinable
func debugOnly(_ body: () -> Void) {
    assert({ body(); return true }())
}
