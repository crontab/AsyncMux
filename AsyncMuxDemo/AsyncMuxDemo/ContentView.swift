//
//  ContentView.swift
//  AsyncMuxDemo
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import SwiftUI


struct ContentView: View {

	struct Item: Hashable {
		var place: WeatherPlace
		var weather: Weather?
	}

	@State var items: [Item] = []
	@State var isLoading: Bool = false


	var body: some View {
		list()
			.serverTask(withAlert: true) {
				try await reload(showIndicator: true, refresh: false)
			}
			.serverRefreshable(withAlert: false) {
				try? await reload(showIndicator: false, refresh: true)
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
						Text(item.weather.map { "\(Int(round($0.currentWeather.temperature)))ºC" } ?? "-")
					}
				}
			}
			.listStyle(.inset)
			.font(.title2)
		}
	}

	private func reload(showIndicator: Bool, refresh: Bool) async throws {
		isLoading = showIndicator
		do {
			items = try await WeatherAPI.places
				.refresh(refresh)
				.request()
				.map { Item(place: $0, weather: nil) }
			for i in items.indices {
				Task {
					items[i].weather = try await WeatherAPI.weather
						.refresh(refresh)
						.request(key: items[i].place.key)
				}
			}
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
			.init(place: .init(city: "London", countryCode: "GB", lat: "51.51", lon: "-0.13"), weather: .init(currentWeather: .init(temperature: 8.1, weathercode: 2))),
			.init(place: .init(city: "Paris", countryCode: "FR", lat: "48.84", lon: "2.36"), weather: .init(currentWeather: .init(temperature: 10.2, weathercode: 3)))
		])
	}
}
