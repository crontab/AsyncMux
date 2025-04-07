//
//  AsyncUtils.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 09/01/2023.
//

import Foundation
import CryptoKit


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
        let u = absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        // macOS has a limitation of 255 for file names, therefore for longer URL's we use a SHA hash instead
        return u.count < 255 ? u : u.toURLSafeHash(max: 255)
    }
}


public extension String {
    func toURLSafeHash(max: Int) -> String {
        String(toSHA256().toURLSafeBase64().suffix(max))
    }

    func toSHA256() -> Data {
        data(using: .utf8).map { Data(SHA256.hash(data: $0)) } ?? Data()
    }
}


public extension Data {
    func toURLSafeBase64() -> String {
        base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "=", with: "")
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
