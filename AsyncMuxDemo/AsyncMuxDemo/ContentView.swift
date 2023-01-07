//
//  ContentView.swift
//  AsyncMuxDemo
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import SwiftUI

struct ContentView: View {
	@State var temp: String = "-"

	var body: some View {
		VStack {
			Image(systemName: "globe")
				.imageScale(.large)
				.foregroundColor(.accentColor)
			Text("Temperature: \(temp)")
		}
		.padding()
		.task {
			guard !Globals.isPreview else { return }
			temp = "-24ºC"
		}
	}
}


struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView(temp: "12ºC")
	}
}
