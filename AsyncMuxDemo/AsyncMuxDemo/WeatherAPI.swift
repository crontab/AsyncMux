//
//  WeatherAPI.swift
//  AsyncMuxDemo
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import Foundation
import CoreLocation
import AsyncMux


struct WeatherPlace: Codable, Hashable {
	let city: String
	let countryCode: String
	let lat: String
	let lon: String

	var key: String {
		"\(lat),\(lon)"
	}
}


struct Weather: Codable, Hashable {

	struct Details: Codable, Hashable {
		let temperature: Double
		let weathercode: Int
	}

	let currentWeather: Details
}


@MainActor
class WeatherAPI {

	static var placeNames: [String] = ["New York, US", "London, UK", "Paris, FR", "Tokyo, JP"] {
		didSet {
			if placeNames != oldValue {
				places.refresh()
				weather.refresh()
			}
		}
	}


	static var places = AsyncMux<[WeatherPlace]> {
		// Geocoding requests should be performed one at a time, hence the loop
		var result: [WeatherPlace] = []
		for name in placeNames {
			do {
				guard let place = try await geocoder.geocodeAddressString(name).first?.weatherPlace else {
					throw AppError(code: "geocoding_error", message: "Couldn't resolve location for \(name)")
				}
				result.append(place)
			}
			catch {
				// When there's no connection CoreLocation returns the below error; we convert it to a silencable one
				if (error as NSError).domain == kCLErrorDomain, (error as NSError).code == 2 {
					throw SilencableError(wrapped: error)
				}
				throw error
			}
		}
		return result
	}.register()


	static var weather = AsyncMuxMap<String, Weather> { key in
		guard let coordinate = CLLocationCoordinate2D(string: key) else {
			throw AppError.unknown
		}
		return try await WeatherAPI.fetchCurrent(for: coordinate)
	}.register()


	private static let geocoder = CLGeocoder()


	private static func fetchCurrent(for location: CLLocationCoordinate2D) async throws -> Weather {
		try await URLRequest(getURL: URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(location.latitude)&longitude=\(location.longitude)&current_weather=true")!)
			.perform(type: Weather.self)
	}
}


private extension CLPlacemark {

	var weatherPlace: WeatherPlace {
		WeatherPlace(city: locality ?? name ?? "-", countryCode: isoCountryCode ?? "-", lat: String(location?.coordinate.latitude ?? 0), lon: String(location?.coordinate.longitude ?? 0))
	}
}


private extension CLLocationCoordinate2D {

	init?(string: String) {
		let a = string.split(separator: ",")
		guard a.count == 2 else { return nil }
		guard let lat = Double(a[0]), let lon = Double(a[1]) else { return nil }
		self.init(latitude: lat, longitude: lon)
	}
}
