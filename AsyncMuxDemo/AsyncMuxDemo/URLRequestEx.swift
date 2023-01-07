//
//  URLRequestEx.swift
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import Foundation


extension URLRequest {

	init(getURL: URL) {
		self.init(url: getURL)
#if PRINT_REQUEST_URLS
		print(">>> GET \(getURL)")
#endif
	}


	func perform<T: Decodable>(type: T.Type) async throws -> T {
		try await perform().decodeJSON(type: type, diagUrl: url)
	}


	func perform() async throws -> Data {
		let (data, response) = try await Self.sharedSession.data(for: self)
		let httpResponse = response as! HTTPURLResponse
		switch httpResponse.statusCode {
			case 100..<200:
				return Data()
			case 200..<300:
				return data
			default: // >= 300
				if !data.isEmpty {
#if PRINT_JSON
					print("<<< HTTP \(httpResponse.statusCode)", self.url!.absoluteString)
					print(String(data: data, encoding: .utf8) ?? "")
#endif
				}
				throw AppError.http(status: httpResponse.statusCode)
		}
	}


	static let sharedSession = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: .main)
}


// MARK: - Data to JSON extension with diagnostic printing

extension Data {

	static let jsonDecoder: JSONDecoder = {
		let result = JSONDecoder()
		result.keyDecodingStrategy = .convertFromSnakeCase
		result.dateDecodingStrategy = .iso8601
		return result
	}()


	static let jsonEncoder: JSONEncoder = {
		let result = JSONEncoder()
		result.keyEncodingStrategy = .convertToSnakeCase
		result.dateEncodingStrategy = .iso8601
		return result
	}()


	static func encodeJSON<T: Encodable>(_ object: T) throws -> Self {
		try jsonEncoder.encode(object)
	}


	func decodeJSON<T: Decodable>(type: T.Type, diagUrl: URL?) throws -> T {
		do {
			let object = try Self.jsonDecoder.decode(type, from: self)
#if PRINT_JSON
			print("<<<", diagUrl?.absoluteString ?? "?")
			print(try! JSONSerialization.jsonObject(with: self, options: []))
#endif
			return object
		}
		catch {
#if PRINT_JSON || PRINT_JSON_ERRORS
			print("<<<", diagUrl?.absoluteString ?? "?")
			print(String(data: self, encoding: .utf8) ?? "")
			switch error {
				case DecodingError.dataCorrupted(let context), DecodingError.keyNotFound(_, let context), DecodingError.typeMismatch(_, let context), DecodingError.valueNotFound(_, let context):
					print("JSON error:", context.debugDescription, "-", context.codingPath.map({ $0.stringValue }).joined(separator: "/"))
				default:
					print("JSON error:", error.localizedDescription)
			}
#endif
			throw AppError.app(code: "invalid_json_response")
		}
	}
}
