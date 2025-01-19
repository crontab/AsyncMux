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
    let lat: CLLocationDegrees
    let lon: CLLocationDegrees
}


struct Weather: Codable, Hashable {

    struct Details: Codable, Hashable {
        let temperature: Double
        let weathercode: Int
    }

    let currentWeather: Details
}


struct WeatherItem: Hashable, Codable {
    let name: String
    let place: WeatherPlace
    let weather: Weather?
}


final class WeatherAPI {

    static let defaultPlaceNames: [String] = ["New York, US", "London, UK", "Paris, FR", "Yerevan, AM", "Tokyo, JP"]

    static let map = MultiplexerMap<String, WeatherItem>(cacheKey: "WeatherMap") { key in
        do {
            if let place = try await CLGeocoder().geocodeAddressString(key).first?.weatherPlace {
                return try await WeatherItem(name: key, place: place, weather: fetchCurrent(lat: place.lat, lon: place.lon))
            }
            else {
                throw AppError(code: "geocoding_error", message: "Couldn't resolve location for \(key)")
            }
        }
        catch {
            print("ERROR:", error)
            // When there's no connection CoreLocation returns the below error; we convert it to a silencable one
            if (error as NSError).domain == kCLErrorDomain, (error as NSError).code == 2 {
                throw SilencableError(wrapped: error)
            }
            throw error
        }
    }

    private static func fetchCurrent(lat: Double, lon: Double) async throws -> Weather {
        try await URLRequest(getURL: URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true")!)
            .perform(type: Weather.self)
    }
}


private extension CLPlacemark {

    var weatherPlace: WeatherPlace {
        WeatherPlace(city: locality ?? name ?? "-", countryCode: isoCountryCode ?? "-", lat: location?.coordinate.latitude ?? 0, lon: location?.coordinate.longitude ?? 0)
    }
}
