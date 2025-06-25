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


public struct SilenceableError: LocalizedError {
    let wrapped: Error?

    public init(wrapped: Error?) {
        self.wrapped = wrapped
    }

    public var errorDescription: String? {
        wrapped?.localizedDescription ?? "SilenceableError"
    }
}


public extension Error {

    var isSilenceable: Bool {
        if (self as NSError).domain == NSURLErrorDomain {
            // No connection?
            return [
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorSecureConnectionFailed,
                NSURLErrorBackgroundSessionInUseByAnotherProcess
            ].contains((self as NSError).code)
        }
        else {
            // Otherwise, user-defined silenceable error?
            return self is SilenceableError
        }
    }
}
