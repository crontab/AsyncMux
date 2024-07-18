//
//  AsyncError.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 14/01/2023.
//

import Foundation


public struct HTTPError: LocalizedError {
    public let status: Int

    public init(status: Int) {
        self.status = status
    }

    public var errorDescription: String? {
        "HTTP status \(status)"
    }
}


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
