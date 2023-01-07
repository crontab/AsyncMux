//
//  AppError.swift
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import Foundation


enum AppError: LocalizedError {
	case http(status: Int)
	case app(code: String, message: String? = nil)

	static var notImpl: Self { .app(code: "not_implemented", message: "Not implemented yet") }
	static var unknown: Self { .app(code: "unknown_error", message: "Unknown error") }

	var errorDescription: String? {
		switch self {
			case .http(let status):
				return "HTTP status \(status)"
			case .app(let code, let message):
				return message ?? "Application error: \(code)"
		}
	}
}
