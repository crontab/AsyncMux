//
//  WeatherAPI.swift
//  AsyncMuxDemo
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import Foundation
import CoreLocation


struct WeatherItem: Hashable {
	let place: WeatherPlace
	let weather: Weather?
}


struct WeatherPlace: CustomDebugStringConvertible, Hashable {

	let city: String
	let countryCode: String
	let coordinate: CLLocationCoordinate2D

	var description: String {
		"\(city), \(countryCode) [\(coordinate.latitude), \(coordinate.longitude)]"
	}

	var debugDescription: String {
		description
	}
}


struct Weather: Decodable, Hashable {

	struct Details: Decodable, Hashable {
		let temperature: Double
		let weathercode: Int
	}

	let currentWeather: Details
}


class WeatherAPI {

	static let geocoder = CLGeocoder()


	static func fetch(for placeNames: [String]) async throws -> [WeatherItem] {
		// Geocoding requests should be performed one at a time, hence:
		var result: [WeatherItem] = []
		for name in placeNames {
			guard let place = try await geocoder.geocodeAddressString(name).first?.weatherPlace else {
				throw AppError.app(code: "geocoding_error", message: "Couldn't resolve location for \(name)")
			}
			let weather = try await WeatherAPI.fetchCurrent(for: place.coordinate)
			result.append(WeatherItem(place: place, weather: weather))
		}
		return result
	}


	private static func fetchCurrent(for location: CLLocationCoordinate2D) async throws -> Weather {
		try await URLRequest(getURL: URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(location.latitude)&longitude=\(location.longitude)&current_weather=true")!)
			.perform(type: Weather.self)
	}
}


extension CLPlacemark {

	var weatherPlace: WeatherPlace {
		WeatherPlace(city: locality ?? name ?? "-", countryCode: isoCountryCode ?? "-", coordinate: location?.coordinate ?? .init())
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
