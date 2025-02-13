//
//  ContentView.swift
//  AsyncMuxDemo
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import SwiftUI
import AsyncMux


// TODO: a function to add a custom location by city name


private let backgroundURL = URL(string: "https://images.unsplash.com/photo-1513051265668-0ebab31671ae")!


struct ContentView: View {

    @State var placeNames = WeatherAPI.defaultPlaceNames
    @State var weather: [String: WeatherItem] = [:]

    @State private var error: Error?

    var body: some View {
        listView()
            .background(backgroundImageView())
            .preferredColorScheme(.dark)

            .task {
                guard !Globals.isPreview else { return }
                do {
                    try await reload()
                }
                catch {
                    self.error = error
                }
            }

            .refreshable {
                guard !Globals.isPreview else { return }
                do {
                    await WeatherAPI.map.refresh()
                    try await reload()
                }
                catch {
                    self.error = error
                }
            }

            .errorAlert($error)

            // Purge memory caches on memory warnings from the OS
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification, object: nil)) { _ in
                Task {
                    await MuxRepository.clearMemory()
                    ImageCache.clear()
                }
            }
    }

    private func listView() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(placeNames, id: \.self) { placeName in
                    HStack {
                        Text(placeName)
                        Spacer()
                        if let item = weather[placeName] {
                            Text(item.weather.map { "\(Int(round($0.currentWeather.temperature)))ºC" } ?? "-")
                        }
                    }
                    .padding(.vertical)
                    Divider()
                }
            }
        }
        .padding()
        .font(.title2)
    }

    private func backgroundImageView() -> some View {
        RemoteImage(url: backgroundURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        } placeholder: { error in
            if error != nil {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .opacity(0.3)
            }
            else {
                ProgressView()
            }
        }
    }

    @MainActor
    private func reload() async throws {
        // Create an array of actions for the zipper
        let actions = placeNames.map { name in
            { @Sendable in 
                try await WeatherAPI.map.request(key: name)
            }
        }
        // Execute the array of actions in parallel, get the results in an array and convert them to a dictionary to be used in the UI
        weather = try await Zip(actions: actions)
            .result
            .reduce(into: [String: WeatherItem]()) {
                $0[$1.name] = $1
            }
    }
}


#Preview {
    ContentView(
        placeNames: ["London, UK", "Paris, FR"],
        weather: [
            "London, UK": .init(name: "London, UK", place: .init(city: "London", countryCode: "GB", lat: 51.51, lon: -0.13), weather: .init(currentWeather: .init(temperature: 8.1, weathercode: 2))),
            "Paris, FR": .init(name: "Paris, FR", place: .init(city: "Paris", countryCode: "FR", lat: 48.84, lon: 2.36), weather: .init(currentWeather: .init(temperature: 10.2, weathercode: 3)))
        ]
    )
}
