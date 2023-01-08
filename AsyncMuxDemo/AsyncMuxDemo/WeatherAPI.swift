//
//  WeatherAPI.swift
//  AsyncMuxDemo
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import Foundation
import CoreLocation


struct WeatherItem: Codable, Hashable {
	let place: WeatherPlace
	let weather: Weather?
}


struct WeatherPlace: Codable, CustomDebugStringConvertible, Hashable {

	let city: String
	let countryCode: String
	let latitude: Double
	let longitude: Double

	var description: String {
		"\(city), \(countryCode) [\(latitude), \(longitude)]"
	}

	var debugDescription: String {
		description
	}

	var coordinate: CLLocationCoordinate2D {
		.init(latitude: latitude, longitude: longitude)
	}
}


struct Weather: Codable, Hashable {

	struct Details: Codable, Hashable {
		let temperature: Double
		let weathercode: Int
	}

	let currentWeather: Details
}


class WeatherAPI {

	static var placeNames: [String] = ["New York, US", "London, UK", "Paris, FR", "Tokyo, JP"] {
		didSet {
			if placeNames != oldValue {
				mux.refresh()
			}
		}
	}


	static var mux = AsyncMux<[WeatherItem]> {
		// Geocoding requests should be performed one at a time, hence the loop
		var result: [WeatherItem] = []
		for name in placeNames {
			guard let place = try await geocoder.geocodeAddressString(name).first?.weatherPlace else {
				throw AppError.app(code: "geocoding_error", message: "Couldn't resolve location for \(name)")
			}
			let weather = try await WeatherAPI.fetchCurrent(for: place.coordinate)
			result.append(WeatherItem(place: place, weather: weather))
		}
		return result
	}.register()


	private static let geocoder = CLGeocoder()


	private static func fetchCurrent(for location: CLLocationCoordinate2D) async throws -> Weather {
		try await URLRequest(getURL: URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(location.latitude)&longitude=\(location.longitude)&current_weather=true")!)
			.perform(type: Weather.self)
	}
}


extension CLPlacemark {

	var weatherPlace: WeatherPlace {
		WeatherPlace(city: locality ?? name ?? "-", countryCode: isoCountryCode ?? "-", latitude: location?.coordinate.latitude ?? 0, longitude: location?.coordinate.longitude ?? 0)
	}
}


extension CLLocationCoordinate2D: Hashable {

	public func hash(into hasher: inout Hasher) {
		hasher.combine(latitude)
		hasher.combine(longitude)
	}

	public static func == (a: CLLocationCoordinate2D, b: CLLocationCoordinate2D) -> Bool {
		a.latitude == b.latitude && a.longitude == b.longitude
	}
}
