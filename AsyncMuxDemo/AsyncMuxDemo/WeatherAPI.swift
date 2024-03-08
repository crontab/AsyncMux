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
    var place: WeatherPlace
    var weather: Weather?
}


class WeatherAPI {

    static let placeNames: [String] = ["New York, US", "London, UK", "Paris, FR", "Tokyo, JP"]

    static func reload(refresh: Bool) async throws -> [WeatherItem] {
        try await places.refresh(refresh).request()
    }


    private static let places = Multiplexer<[WeatherItem]> {
        var places: [WeatherPlace] = []

        // Geocoding requests should be performed one at a time, hence the loop
        for name in placeNames {
            do {
                // Even though geocodeAddressString() has an async version, we use callback and continuation to silence Swift's strict concurrency checking warnings
                let place = try await withCheckedThrowingContinuation { continuation in
                    CLGeocoder().geocodeAddressString(name, completionHandler: { placemarks, error in
                        if let placemark = placemarks?.first?.weatherPlace {
                            continuation.resume(with: .success(placemark))
                        }
                        else if let error {
                            continuation.resume(with: .failure(error))
                        }
                        else {
                            continuation.resume(with: .failure(AppError(code: "geocoding_error", message: "Couldn't resolve location for \(name)")))
                        }
                    })
                }
                places.append(place)
            }
            catch {
                // When there's no connection CoreLocation returns the below error; we convert it to a silencable one
                if (error as NSError).domain == kCLErrorDomain, (error as NSError).code == 2 {
                    throw SilencableError(wrapped: error)
                }
                throw error
            }
        }

        // Now request weather for those places concurrently
        let tasks = places
            .map { place in
                Task {
                    try await WeatherItem(place: place, weather: fetchCurrent(lat: place.lat, lon: place.lon))
                }
            }
        var items: [WeatherItem] = []
        for task in tasks {
            try await items.append(task.value)
        }

        return items
    }.register()


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
