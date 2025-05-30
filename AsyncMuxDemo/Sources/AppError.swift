//
//  AppError.swift
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import Foundation


struct AppError: LocalizedError {
    let code: String
    let message: String?

    static var notImpl: Self { .init(code: "not_implemented", message: "Not implemented yet") }
    static var unknown: Self { .init(code: "unknown_error", message: "Unknown error") }
    static var cachedFileDamaged: Self { .init(code: "cached_file_damaged", message: "Internal: damaged cached file") }

    var errorDescription: String? {
        message ?? "Application error: \(code)"
    }
}
