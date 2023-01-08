//
//  ContentView.swift
//  AsyncMuxDemo
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import SwiftUI


private let predefinedPlaces = ["New York, US", "London, UK", "Paris, FR", "Tokyo, JP"]


struct ContentView: View {

	@State var items: [WeatherItem] = []
	@State var isLoading: Bool = false


	var body: some View {
		list()
			.serverTask {
				try await reload(showIndicator: true)
			}
			.refreshable {
				try? await reload(showIndicator: false)
			}
	}


	@ViewBuilder
	private func list() -> some View {
		if isLoading, items.isEmpty {
			ProgressView()
		}
		else {
			List {
				ForEach(items, id: \.self) { item in
					HStack {
						Text("\(item.place.city), \(item.place.countryCode)")
						Spacer()
						Text(item.weather.map { "\(Int($0.currentWeather.temperature))ºC" } ?? "-")
					}
				}
			}
			.listStyle(.inset)
		}
	}


	private func reload(showIndicator: Bool) async throws {
		isLoading = showIndicator
		do {
			items = try await WeatherAPI.fetch(for: predefinedPlaces)
		}
		catch {
			isLoading = false
			throw error
		}
		isLoading = false
	}
}


struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView(items: [
			.init(place: .init(city: "London", countryCode: "GB", coordinate: .init(latitude: 51.51, longitude: -0.13)), weather: .init(currentWeather: .init(temperature: 8.1, weathercode: 2))),
			.init(place: .init(city: "Paris", countryCode: "FR", coordinate: .init(latitude: 48.84, longitude: 2.36)), weather: .init(currentWeather: .init(temperature: 10.2, weathercode: 3)))
		])
	}
}