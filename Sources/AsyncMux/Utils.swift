//
//  Utils.swift
//
//  Created by Hovik Melikyan on 09/01/2023.
//

import Foundation


public struct SilencableError: LocalizedError {
	let wrapped: Error?

	public init(wrapped: Error?) {
		self.wrapped = wrapped
	}

	public var errorDescription: String? {
		wrapped?.localizedDescription ?? "SilencableError"
	}
}


public extension Error {

	var isSilencable: Bool {
		if (self as NSError).domain == NSURLErrorDomain {
			return [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost].contains((self as NSError).code)
		}
		if self is SilencableError {
			return true
		}
		return false
	}
}


public extension FileManager {

	static func cachesDirectory(subDirectory: String, create: Bool = false) -> URL {
		standardDirectory(.cachesDirectory, subDirectory: subDirectory, create: create)
	}

	static func documentDirectory(subDirectory: String, create: Bool = false) -> URL {
		standardDirectory(.documentDirectory, subDirectory: subDirectory, create: create)
	}

	static func libraryDirectory(subDirectory: String, create: Bool = false) -> URL {
		standardDirectory(.libraryDirectory, subDirectory: subDirectory, create: create)
	}

	private static func standardDirectory(_ type: SearchPathDirectory, subDirectory: String, create: Bool = false) -> URL {
		let result = `default`.urls(for: type, in: .userDomainMask).first!.appendingPathComponent(subDirectory)
		if create && !`default`.fileExists(atPath: result.path) {
			try! `default`.createDirectory(at: result, withIntermediateDirectories: true, attributes: nil)
		}
		return result
	}
}
